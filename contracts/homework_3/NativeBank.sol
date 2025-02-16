// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { INativeBank } from "./INativeBank.sol";

// контракт-банк, принимает от пользователей коины на хранение. При депозите пользовтаель платит комиссию, которая составляет доход владельцев

contract NativeBank is INativeBank {
    uint16 public commissionBp; // размер комиссии
    uint256 public accumulator; // баланс владельцев, сумма всех комиссий за переводы
    uint16 public bps = 10000; // base points для установки нецелочисленного процента комиссии. commissionBp / bps = comissionPercent
    address public owner; // владелец контракта
    mapping(address client => uint256 balance) public balanceOf; // балансы пользователей
    address[] public stakeHolders; // стейкхолдеры, которые получают доход с владельцем. По условиям контракта их всегда трое
    uint8 private lock; // защита от reentrancy

    error NotContractOwner();
    error WithdrawFailed();
    error InsufficientDeposit(address account);
    error ReetrancyAttack();

    constructor(address[3] memory _holders) {
        owner = msg.sender;
        for(uint256 i=0; i<3; i++) {
            stakeHolders.push(_holders[i]);
        }
        commissionBp = 100; // по умолчанию ставим 1% комиссии
    }

    function deposit() external payable {
        // если пришла сумма, с которой мы не сможем взять комиссию, откат транзакции
        if (commissionBp > 0 && (msg.value * commissionBp) < bps) {
            revert InsufficientDeposit(msg.sender);
        }
        uint256 _amount;
        uint256 _fee = (msg.value * commissionBp) / bps; // вычисляем комиссию с полученной суммы
        _amount = msg.value - _fee; // unch 
        balanceOf[msg.sender] += _amount; // платеж за вычетом комиссии кладем на баланс пользователя
        accumulator += _fee; // комиссию кладем н а баланс овнера
        emit Deposit(msg.sender, _amount);
    }

    // note: при такой организации кода (сначала минус баланса, потом send) нет смысла ставить защиту reentrancy, здесь она в целях эксперимента
    function withdraw(uint256 _amount) external nonReentrant allowWithdraw(_amount, balanceOf[msg.sender]) {
        balanceOf[msg.sender] -= _amount; // unch
        _send(_amount, msg.sender);

        emit Withdrawal(msg.sender, _amount);
    }

    // снятие дохода только для овнера контракта
    function withdrawAccumulator(uint256 _amount) external onlyOwner allowWithdraw(_amount, accumulator) {
        uint256 _part = _amount / 4; // делим сумму снятия на 4 - три стейкхолдера + овнер
        uint256 _diff = _amount % 4; // если сумма не делится на 4, остаток добавляется к доходу овнера
        if (_part == 0 ) { // если запрошена слишком маленькая сумма, откатываем транзакцию.
            revert WithdrawalAmountZero(msg.sender);
        }
        accumulator -= _amount; // unch

        _send((_part + _diff), msg.sender);
        for (uint256 i = 0; i < stakeHolders.length; i++) {
            _send(_part, stakeHolders[i]);
        }
    }

    // установка комиссии только для овнера
    function setCommission(uint16 _commission) external onlyOwner {
        require (_commission <= 2000, "don't be impudent"); // нельзя установить комиссию больше 20%
        commissionBp = _commission;
    }

    function setHolders(address[3] memory _holders) external onlyOwner {
        for (uint256 i = 0; i < 3; i++) {
            stakeHolders[i] = _holders[i];
        }
    }

    function _send(uint256 _amount, address _account) internal {
        (bool success, ) = _account.call{value: _amount}("");
        if (!success) {
            revert WithdrawFailed();
        }
    }

    modifier allowWithdraw(uint256 _amount, uint256 _limit) {
        if (_amount == 0) {
            revert WithdrawalAmountZero(msg.sender);
        }
        if (_amount > _limit) {
            revert WithdrawalAmountExceedsBalance(msg.sender, _amount, _limit);
        }
        _;
    }

    modifier nonReentrant() {
        if (lock == 1) {
            revert ReetrancyAttack();
        }
        lock = 1;
        _;
        lock = 0;
    }

    modifier onlyOwner() {
        if (owner != msg.sender) {
            revert NotContractOwner();
        }
        _;
    }

}
