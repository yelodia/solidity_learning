// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Permissions } from "./permissions.sol";
import { RoleControlUp } from "./roleControlUpgradeable.sol";


contract MimimiCatUp is Permissions, ERC721Upgradeable, RoleControlUp {
    using Strings for uint256;
    uint8 private constant STATE_PAUSE = 1; 
    uint8 private constant STATE_OPEN = 2; 
    uint8 private constant STATE_CLOSE = 3; 
    uint256 public constant REWARD_FOR_CLOSE=1e18*2; 

    uint8 public state = STATE_PAUSE;
    uint32 public immutable maxSupply; 
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

    constructor(uint32 _maxSupply) Permissions() payable {
        maxSupply = _maxSupply;
    }

    function initialize(uint32 _whiteListSupply, string memory _uri, uint256 _mintPrice, address signer) public initializer {
        __ERC721_init("MimimiCat", "MCT");
        whiteListSupply = _whiteListSupply;
        baseURI = _uri;
        mintPrice = _mintPrice;
        roleControlInit(signer);
    }

    function supportsInterface(bytes4 interfaceId) public view override(RoleControlUp, ERC721Upgradeable) returns (bool) {
        return ERC721Upgradeable.supportsInterface(interfaceId) || RoleControlUp.supportsInterface(interfaceId);
    }


    function tokenURI(uint256 _tokenId) public view override(ERC721Upgradeable) returns (string memory) {
        _requireOwned(_tokenId);
        if (state == STATE_CLOSE) {
            return bytes(baseURI).length > 0 ? string.concat(baseURI, _tokenId.toString()) : "";
        }

        return baseURI; 
    }

    function mint() external payable {
        _mintMCT(msg.sender);
    }


    function signedMint(address _owner, uint8 v, bytes32 r, bytes32 s) external payable {
        _validateMint(_owner, v, r, s); 
        _mintMCT(_owner);

    }

    function freeMint(bytes32[] calldata _proof) external {
        _freeMintMCT(msg.sender, _proof);
    }


    function signedFreeMint(address _owner, bytes32[] calldata _proof, uint8 v, bytes32 r, bytes32 s) external {
        _validateFreeMint(_owner, _proof, v, r, s); 
        _freeMintMCT(_owner, _proof);
    }

    function _mintMCT(address _account) internal mintEnabled(maxSupply - whiteListSupply) {
        require(!blackList[_account], MCTAdddresInBlackList(_account)); 
        require(msg.value == mintPrice, MCTInvalidEthers(_account, mintPrice, msg.value)); 
        _mint(_account, tokenIdCounter);
    }

    function _freeMintMCT(address _account, bytes32[] calldata _proof) internal mintEnabled(maxSupply) {
        require(inWhiteList(_account, _proof), MCTAdddresNotInWiteList(_account)); 
        require(!whiteListMinted[_account], MCTAlreadyHasFreeMint(_account)); 
        
        whiteListMinted[_account] = true;
        _mint(_account, tokenIdCounter);
        unchecked {
            --whiteListSupply; 
        }
    }

    function inWhiteList(address _addr, bytes32[] calldata _proof) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(_addr));
        return MerkleProof.verify(_proof, whiteList, leaf);
    }

    function permit(address _owner, address _spender, uint256 _tokenId, uint8 v, bytes32 r, bytes32 s) external {
        _validatePermit(_owner, _spender, _tokenId, v, r, s);
        _approve(_spender, _tokenId, _owner, true);
    }

    

    function setToBlackList(address _account, bool _value) external onlyRole(ROLE_MODERATOR) { 
        blackList[_account] = _value;
    }

    function setWhiteList(bytes32 _whiteList) external onlyMultisigner {
        whiteList = _whiteList;
    }


    function setState(uint8 _state) external onlyRole(ROLE_MODERATOR) {
        require(state != STATE_CLOSE && _state != STATE_CLOSE, MCTInvalidTransition());
        
        state = _state;
        emit SetState(_state);
    }
 

    function setMintPrice(uint256 _amount) external onlyRole(ROLE_STAKEHOLDER) {
        mintPrice = _amount;
    }


    function withdraw(uint256 _amount) external onlyRole(ROLE_STAKEHOLDER) {
        require(state == STATE_CLOSE, MCTMintIsNotClosed());

        (bool success, ) = msg.sender.call{value: _amount}("");
        if (!success) {
            revert WithdrawFailed();
        }
    }
    

    function close(string memory _uri) external onlyMultisigner {
        _close(_uri);
    }
    
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

    modifier mintEnabled(uint32 _limit) {
        unchecked {
            require(state == STATE_OPEN, MCTMintIsNotOpened());
            require(tokenIdCounter++ < _limit, MCTLimitExceed(msg.sender));
        }
        _;
    }

}
