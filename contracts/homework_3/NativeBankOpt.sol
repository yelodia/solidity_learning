// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { INativeBank } from "./INativeBank.sol";

// оптимизированный контракт

contract NativeBankOpt is INativeBank {
    uint16 public constant BPS = 10000; // base points нужен только для расчетов, использование константы экономит ~ 7100 газа при деплое и ~ 2200 при депозите
    // uint16 + address влезают в один слот, экономия ~ 18600 газа при деплое
    uint16 public commissionBp;
    // установка адреса овнера в immutable увеличивает расход газа на деплой ~ на 10000, но экономит ~ 2000 при снятии баланса
    address public immutable OWNER; 
    // если есть возможность заменить массив на мапу, меняем, т.к push дороже, чем запись в мапу, экономия при деплое ~ 40000 газа
    mapping(uint8 index => address holder) public stakeHolders;
    uint256 public accumulator; 
    mapping(address client => uint256 balance) public balanceOf;
    // смена типа c uin8 на uint256 должна экономить газ при депозите, но почему-то экономит при деплое ~ на 16500
    // не сбрасываем лок в 0. Увеличивает стоимость деплоя, но сильно экономит газ на снятии
    uint256 private lock = 1;

    error NotContractOwner();
    error WithdrawFailed();
    error InsufficientDeposit(address account);
    error ReetrancyAttack();

    // после всех манипуляций итоговая стоимость деплоя уменьшилась ~ на 70 000 газа
    constructor(address[3] memory _holders) payable { // payable конструктора экономит ~ 200 газа. Мелочь, а приятно
        OWNER = msg.sender;
        for(uint8 i=0; i<3; ++i) {
            stakeHolders[i] = _holders[i];
        }
        commissionBp = 100;
    }

    // итоговая стоимость транзакции уменьшилась ~ на 2600 газа
    function deposit() external payable {
        uint16 _bp = commissionBp; // обращаемся к переменной стораджа только один раз, экономия ~ 300 
        
        if (_bp > 0 && (msg.value * _bp) < BPS) {
            revert InsufficientDeposit(msg.sender);
        }
        uint256 _amount;
        uint256 _fee = (msg.value * _bp) / BPS; 
        unchecked { // все еще экономит газ ~ на 200. При сложении тоже не проверяем на переполнение, так как практически невозможно собрать на контракте весь бюджет сети
            _amount = msg.value - _fee;
            balanceOf[msg.sender] += _amount; 
            accumulator += _fee;
        }
        emit Deposit(msg.sender, _amount);
    }

    // итоговая стоимость транзакции уменьшилась ~ на 8600 газа
    function withdraw(uint256 _amount) external nonReentrant allowWithdraw(_amount, balanceOf[msg.sender]) {
        unchecked { // небольшая экономия ~ 70. Чем больше операций в блоке, тем больше экономия. В этой транзакции имеет мало смысла, но если у нас много операций, которые не требуют проверки, или операции в цикле, тогда можно ставить этот блок.
            balanceOf[msg.sender] -= _amount;
        }
        _send(_amount, msg.sender);

        emit Withdrawal(msg.sender, _amount);
    }

    // итоговая стоимость транзакции уменьшилась ~ на 5000,
    function withdrawAccumulator(uint256 _amount) external onlyOwner allowWithdraw(_amount, accumulator) {
        uint256 _part = _amount >> 2; // меняем деление на побитовый сдвиг, экономия ~ 50
        uint256 _diff = _amount % 4; 
        if (_part == 0 ) { 
            revert WithdrawalAmountZero(msg.sender);
        }
        unchecked { // экономия ~ 80
            accumulator -= _amount; // unch
        }

        _send((_part + _diff), msg.sender);
        for (uint8 i = 0; i < 3; i++) { // убрали получение длины массива в цикле, экономия ~ 2600
            _send(_part, stakeHolders[i]);
        }
    }

    // итоговая стоимость транзакции уменьшилась ~ на 2000
    function setCommission(uint16 _commission) external onlyOwner {
        require (_commission <= 2000, "don't be impudent"); 
        commissionBp = _commission;
    }

    // итоговая стоимость транзакции уменьшилась ~ на 4500
    function setHolders(address[3] calldata _holders) external onlyOwner { // смена memory на calldata, экономия ~ 200
        for (uint8 i = 0; i < 3; i++) {
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
        if (lock == 2) {
            revert ReetrancyAttack();
        }
        lock = 2;
        _;
        lock = 1;
    }

    modifier onlyOwner() {
        if (OWNER != msg.sender) {
            revert NotContractOwner();
        }
        _;
    }

}
