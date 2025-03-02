// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Permissions } from "./permissions.sol";
import { RoleControl } from "./roleControl.sol";

/*
 контракт-лотерея НФТ. При деплое устанавливается общая мета для всех токенов. 
 за одну транзакцию разрешается минт одного токена. Количество токенов ограничено, по достижении лимита минт запрещен
 после минта владелец токена не знает, какие у него характеристики
 владелец контракта может в любой момент завершить лотерею и открыть мету. 
 После завершения минт запрещен, пользователи видят характеристики своих токенов и оценивают их редкость

 Есть черный список пользователей, которые каким-то образом нарушили правила лотереи, после добавления адреса в список ему запрещено минтить
 Пользователи с ролью модератор управляют списком

 Есть белый список пользователей, которым разрешено минтить бесплатно. Этот список может сформироваться в результате розыгрыша на сайте лотереи.
 Количество бесплатных токенов дополнительно ограничено. Пул бесплатных токенов гранатирован, то есть проверка общего лимита токенов идет с учетом свободных мест в пуле.
 Таким образом мы гарантируем, что любой участник вайтлиста получит бесплатный токен
 Каждый пользователь из белого списка может заминтить только один токен бесплатно
 Вайтлист устанавливают модераторы

 Также предусмотрен конкурс на лучшую коллекцию.
 Победитель имеет право закрыть лотерею со своей метадатой. Ему гарантирована награда в 2 эфира с баланса контракта.
 Конкрус может быть не разыгран, в этом случае модераторы закрывают лотерею с запланированной коллекцией.

 Контрактом управляют адреса с разными ролями
 
*/

contract MimimiCat is RoleControl, Permissions, ERC721 {
    using Strings for uint256;
    uint8 private constant STATE_PAUSE = 1; // начальное состояние контракта, минт недоступен. На этом этапе проводятся конкурсы и формирование вайт-листа
    uint8 private constant STATE_OPEN = 2; // минт открыт
    uint8 private constant STATE_CLOSE = 3; // минт закрыт, метадата открыта
    uint256 public constant REWARD_FOR_CLOSE=1e18*2; // награда победителю в конкурсе на лучшую коллекцию

    uint8 public state;
    uint32 public immutable maxSupply; // общее количество токенов
    uint32 private whiteListSupply; // пул свободных токенов для вайтлиста, уменьшается при бесплатном минте
    uint32 private tokenIdCounter; // текущий заминченный токен
    uint256 public mintPrice; // цена за минт
    string private baseURI;
    // белый список - это корень меркл дерева. Если у нас в коллекции предполагается 5000 токенов, и 500 из них для вайтлиста, то очень накладно формировать мапу из 500 адресов. Таким образом вайтлист устанавливается целиком за одну транзакцию
    bytes32 public whiteList;
    mapping(address account => bool) public blackList; // черный список, записи будут добавляться по одной штуке
    mapping(address account => bool) public whiteListMinted; // учет адресов из вайтлиста, которые воспользовались правом бесплатного минта

    error MCTLimitExceed(address minter);
    error MCTInvalidEthers(address minter, uint256 price, uint256 payment);
    error MCTMintIsNotOpened();
    error MCTMintIsNotClosed();
    error MCTAdddresInBlackList(address account);
    error MCTAdddresNotInWiteList(address account);
    error MCTAlreadyHasFreeMint(address account);
    error WithdrawFailed();
    error MCTAlreadyClosed();
    error MCTInvalidTransition();

    event SetState(uint8 state);

    constructor(uint32 _maxSupply, uint32 _whiteListSupply, string memory _uri, uint256 _mintPrice, address signer) RoleControl(signer) Permissions("MimimiCat", "1.0.0") ERC721("MimimiCat", "MCT") payable {
        maxSupply = _maxSupply;
        whiteListSupply = _whiteListSupply;
        baseURI = _uri;
        mintPrice = _mintPrice;
        state = STATE_PAUSE;
    }

    function supportsInterface(bytes4 interfaceId) public view override(RoleControl, ERC721) returns (bool) {
        return ERC721.supportsInterface(interfaceId) || RoleControl.supportsInterface(interfaceId);
    }


    // если лотерея открыта, показываем общую метадату со скрытыми характеристиками. Если закрыта, у каждого токена будет своя метадата
    function tokenURI(uint256 _tokenId) public view override(ERC721) returns (string memory) {
        _requireOwned(_tokenId);
        if (state == STATE_CLOSE) {
            return bytes(baseURI).length > 0 ? string.concat(baseURI, _tokenId.toString()) : "";
        }

        return baseURI; 
    }

    function mint() external payable {
        _mintMCT(msg.sender);
    }

    // мета транзакция для минта
    function signedMint(address _owner, uint8 v, bytes32 r, bytes32 s) external payable {
        _validateMint(_owner, v, r, s); // проверка подписи
        _mintMCT(_owner);

    }

    function freeMint(bytes32[] calldata _proof) external {
        _freeMintMCT(msg.sender, _proof);
    }

    // мета транзакция для минта вайтлиста
    function signedFreeMint(address _owner, bytes32[] calldata _proof, uint8 v, bytes32 r, bytes32 s) external {
        _validateFreeMint(_owner, _proof, v, r, s); // проверка подписи
        _freeMintMCT(_owner, _proof);
    }

    function _mintMCT(address _account) internal mintEnabled(maxSupply - whiteListSupply) {
        require(!blackList[_account], MCTAdddresInBlackList(_account)); // проверяем, что адрес не в черном списке
        require(msg.value == mintPrice, MCTInvalidEthers(_account, mintPrice, msg.value)); // плата за минт должна соответствовать той, что установлена в контракте

        _mint(_account, tokenIdCounter);
    }

    function _freeMintMCT(address _account, bytes32[] calldata _proof) internal mintEnabled(maxSupply) {
        require(inWhiteList(_account, _proof), MCTAdddresNotInWiteList(_account)); // проверка, что адрес в вайтлисте
        require(!whiteListMinted[_account], MCTAlreadyHasFreeMint(_account)); // проверка, что адрес еще не заминтил свой бесплатный токен
        
        whiteListMinted[_account] = true;
        _mint(_account, tokenIdCounter);
        unchecked {
            --whiteListSupply; // уменьшаем количество свободных мест в пуле
        }
    }

    // после установки владельцами вайтлиста пользователь из него может вызвать публичный метод и убедиться, что он присутствует в списке
    function inWhiteList(address _addr, bytes32[] calldata _proof) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(_addr));
        return MerkleProof.verify(_proof, whiteList, leaf);
    }

    // аналогия ERC20 permit
    function permit(address _owner, address _spender, uint256 _tokenId, uint8 v, bytes32 r, bytes32 s) external {
        _validatePermit(_owner, _spender, _tokenId, v, r, s);
        _approve(_spender, _tokenId, _owner, true);
    }

    function setToBlackList(address _account, bool _value) external onlyRole(ROLE_MODERATOR) { // черным списком управляют модераторы
        blackList[_account] = _value;
    }

    // за установку белого списка должно проголосовать несколько владельцев через контракт мультиподписного кошелька, так как высока цена ошибки. Один владелец регистрирует вайтлист, остальные его проверяют и подтвержадют транзакцию
    function setWhiteList(bytes32 _whiteList) external onlyMultisigner {
        whiteList = _whiteList;
    }

    // модераторы могут открыть минт либо поставить его на паузу. После закрытия лотереи ее состояние нельзя изменить
    function setState(uint8 _state) external onlyRole(ROLE_MODERATOR) {
        require(state != STATE_CLOSE && _state != STATE_CLOSE, MCTInvalidTransition());
        
        state = _state;
        emit SetState(_state);
    }
 
    // стейкхолдеры заведуют ценами, а также могут снимать доход с баланса контракта
    function setMintPrice(uint256 _amount) external onlyRole(ROLE_STAKEHOLDER) {
        mintPrice = _amount;
    }

    // снимать баланс можно после только после закрытия лотереи. Так мы гарантируем, что адрес, закрывающий лотерею, получит свои 2 эфира
    function withdraw(uint256 _amount) external onlyRole(ROLE_STAKEHOLDER) {
        require(state == STATE_CLOSE, MCTMintIsNotClosed());

        (bool success, ) = msg.sender.call{value: _amount}("");
        if (!success) {
            revert WithdrawFailed();
        }
    }
    
    // закрыть лотерею можно только один раз, и если ее закрывают владельцы, то подтверждений должно быть несколько
    function close(string memory _uri) external onlyMultisigner {
        _close(_uri);
    }

    // закрытие лотереи для адреса, который выбран победителем конкурса на лучшую коллекцию, с подписью владельца контракта, в которую зашит урл выбранной им коллекции
    function signedClose(string calldata _uri, uint8 v, bytes32 r, bytes32 s) external {
        _validateClose(_uri, owner(), v, r, s);
        _close(_uri);
        (bool success, ) = msg.sender.call{value: REWARD_FOR_CLOSE}("");
        if (!success) {
            revert WithdrawFailed();
        }
    }


    function _close(string memory _uri) internal {
        require(state != STATE_CLOSE, MCTAlreadyClosed());

        state = STATE_CLOSE;
        baseURI = _uri;
    }

    // лотерея должа быть открытой и количество заминченных токенов (с учетом пула бесплатных) не достигло лимита. 
    modifier mintEnabled(uint32 _limit) {
        unchecked {
            require(state == STATE_OPEN, MCTMintIsNotOpened());
            require(tokenIdCounter++ < _limit, MCTLimitExceed(msg.sender));
        }
        _;
    }

}
