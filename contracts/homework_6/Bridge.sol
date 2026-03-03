// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IBridgeableToken } from "./IBridgeableToken.sol";

/*
 Мост без ончейн-верификаторов (условно трастлесс):
    - Идемпотентность: release(originChainId, nonce) выполняется не более одного раза для пары (originChainId, nonce).
    - chainId: releasse принимает только originChainId == remoteChainId (проверка происхождения).
    - transferFrom: в lock() используется SafeERC20 — при неуспехе перевод откатывается.
 
 Релейер следит за событием BridgeLock на удалённой цепи и вызывает release(to, amount, originChainId, nonce) здесь.
*/
contract Bridge {
    using SafeERC20 for IERC20;

    // Токен, который блокируется/чеканится мостом
    IBridgeableToken public immutable token;
    // chainId удалённой цепи (откуда принимаем release)
    uint64 public immutable remoteChainId;

    // Счётчик lock на этой цепи; передаётся в событии для идемпотентности на другой цепи
    uint64 public nonce;

    // Идемпотентность: processed[keccak256(originChainId, nonce)] = true после успешного release
    mapping(bytes32 => bool) public processed;

    // Событие: пользователь заблокировал токены для перевода на другую цепь
    event BridgeLock(address indexed user, uint256 amount, uint64 chainId, uint64 nonce);

    error TransferFailed();
    error WrongChain();
    error AlreadyProcessed();

    constructor(address token_, uint64 remoteChainId_) {
        token = IBridgeableToken(token_);
        remoteChainId = remoteChainId_;
    }

    // Заблокировать токены на этой цепи (перевод на мост + сжигание). Эмитит BridgeLock для релейера.
    function lock(uint256 amount) external {
        IERC20(address(token)).safeTransferFrom(msg.sender, address(this), amount);
        token.burn(address(this), amount);
        nonce++;
        emit BridgeLock(msg.sender, amount, uint64(block.chainid), nonce);
    }

    /*
     Выпустить токены получателю после lock на удалённой цепи.
     Вызывающий (релейер) должен был увидеть BridgeLock(user, amount, originChainId, nonce_) на удалённой цепи.
     originChainId должен совпадать с remoteChainId
    */
    function release(address to, uint256 amount, uint64 originChainId, uint64 nonce_) external {
        if (originChainId != remoteChainId) revert WrongChain();

        bytes32 id = keccak256(abi.encodePacked(originChainId, nonce_));
        if (processed[id]) revert AlreadyProcessed();
        processed[id] = true;

        token.mint(to, amount);
    }
}
