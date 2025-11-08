// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { PermissionsInitializeable } from "./permissionsInitializeable.sol";
import { RoleControlInitializeable } from "./roleControlInitializeable.sol";

// общий код для обновляемого и клонируемого контракта перенесла сюда
abstract contract LotteryInitializeable is PermissionsInitializeable, ERC721Upgradeable, RoleControlInitializeable {
    using Strings for uint256;
    uint8 private constant STATE_PAUSE = 1; 
    uint8 private constant STATE_OPEN = 2; 
    uint8 private constant STATE_CLOSE = 3; 
    uint256 public constant REWARD_FOR_CLOSE=1e18*2;

    uint8 public state;
    uint32 public immutable MAX_SUPPLY; 
    uint32 private whiteListSupply; 
    uint32 private tokenIdCounter; 
    uint256 public mintPrice; 
    string private baseURI;
    
    bytes32 public whiteList;
    mapping(address account => bool) public blackList; 
    mapping(address account => bool) public whiteListMinted; 

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

    // в конструкторе осталось только immutable значение
    constructor(uint32 _maxSupply) {
        MAX_SUPPLY = _maxSupply;
    }

    // остальное переехало в initialize
    function lotteryInit(uint32 _whiteListSupply, string memory _uri, uint256 _mintPrice, address _signer, string memory _name, string memory _symbol, string memory _version, address _owner) internal {
        __ERC721_init(_name, _symbol);
        whiteListSupply = _whiteListSupply;
        baseURI = _uri;
        mintPrice = _mintPrice;
        roleControlInit(_signer, _owner);
        permissionsInit(_name, _version);
        state = STATE_PAUSE;
    }

    function supportsInterface(bytes4 interfaceId) public view override(RoleControlInitializeable, ERC721Upgradeable) returns (bool) {
        return ERC721Upgradeable.supportsInterface(interfaceId) || RoleControlInitializeable.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 _tokenId) public virtual view override(ERC721Upgradeable) returns (string memory) {
        _requireOwned(_tokenId);
        if (state == STATE_CLOSE) {
            return bytes(baseURI).length > 0 ? string.concat(baseURI, _tokenId.toString()) : "";
        }

        return baseURI; 
    }

    function mint() external virtual payable {
        _mintMCT(msg.sender);
    }


    function signedMint(address _owner, uint8 v, bytes32 r, bytes32 s) external virtual payable {
        _validateMint(_owner, v, r, s); 
        _mintMCT(_owner);

    }

    function freeMint(bytes32[] calldata _proof) external virtual {
        _freeMintMCT(msg.sender, _proof);
    }


    function signedFreeMint(address _owner, bytes32[] calldata _proof, uint8 v, bytes32 r, bytes32 s) external virtual {
        _validateFreeMint(_owner, _proof, v, r, s); 
        _freeMintMCT(_owner, _proof);
    }

    function _mintMCT(address _account) internal virtual mintEnabled(MAX_SUPPLY - whiteListSupply) {
        require(!blackList[_account], MCTAdddresInBlackList(_account)); 
        require(msg.value == mintPrice, MCTInvalidEthers(_account, mintPrice, msg.value)); 
        _mint(_account, tokenIdCounter);
    }

    function _freeMintMCT(address _account, bytes32[] calldata _proof) internal virtual mintEnabled(MAX_SUPPLY) {
        require(inWhiteList(_account, _proof), MCTAdddresNotInWiteList(_account)); 
        require(!whiteListMinted[_account], MCTAlreadyHasFreeMint(_account)); 
        
        whiteListMinted[_account] = true;
        _mint(_account, tokenIdCounter);
        unchecked {
            --whiteListSupply; 
        }
    }

    function inWhiteList(address _addr, bytes32[] calldata _proof) public virtual view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(_addr));
        return MerkleProof.verify(_proof, whiteList, leaf);
    }

    function permit(address _owner, address _spender, uint256 _tokenId, uint8 v, bytes32 r, bytes32 s) external {
        _validatePermit(_owner, _spender, _tokenId, v, r, s);
        _approve(_spender, _tokenId, _owner, true);
    }

    

    function setToBlackList(address _account, bool _value) external virtual onlyRole(ROLE_MODERATOR) { 
        blackList[_account] = _value;
    }

    function setWhiteList(bytes32 _whiteList) external virtual onlyMultisigner {
        whiteList = _whiteList;
    }


    function setState(uint8 _state) external virtual onlyRole(ROLE_MODERATOR) {
        require(state != STATE_CLOSE && _state != STATE_CLOSE, MCTInvalidTransition());
        
        state = _state;
        emit SetState(_state);
    }
 

    function setMintPrice(uint256 _amount) external virtual onlyRole(ROLE_STAKEHOLDER) {
        mintPrice = _amount;
    }


    function withdraw(uint256 _amount) external virtual onlyRole(ROLE_STAKEHOLDER) {
        require(state == STATE_CLOSE, MCTMintIsNotClosed());

        (bool success, ) = msg.sender.call{value: _amount}("");
        if (!success) {
            revert WithdrawFailed();
        }
    }
    

    function close(string memory _uri) external virtual onlyMultisigner {
        _close(_uri);
    }
    
    function signedClose(string calldata _uri, uint8 v, bytes32 r, bytes32 s) external virtual {
        _validateClose(_uri, owner(), v, r, s);
        _close(_uri);
        (bool success, ) = msg.sender.call{value: REWARD_FOR_CLOSE}("");
        if (!success) {
            revert WithdrawFailed();
        }
    }


    function _close(string memory _uri) internal virtual {
        require(state != STATE_CLOSE, MCTAlreadyClosed());

        state = STATE_CLOSE;
        baseURI = _uri;
    }

    modifier mintEnabled(uint32 _limit) {
        unchecked {
            require(state == STATE_OPEN, MCTMintIsNotOpened());
            require(tokenIdCounter++ < _limit, MCTLimitExceed(msg.sender));
        }
        _;
    }

}
