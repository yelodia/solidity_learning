// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test,console} from "forge-std/Test.sol";
import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";
import {Merkle} from "murky/src/Merkle.sol";
import {MimimiCat} from "../../../contracts/homework_4/mimimiCat.sol";
import {MockMultiSigWallet} from "./MockMultiSigWallet.sol";
import {SignatureHelper} from "./SignatureHelper.sol";
import {Accounts} from "../../helpers/Accounts.sol";


abstract contract MimimiCatTestBase is Test, Accounts {
    using stdStorage for StdStorage;
    
    // === Константы ===
    uint8 constant STATE_PAUSE = 1;
    uint8 constant STATE_OPEN = 2;
    uint8 constant STATE_CLOSE = 3;
    
    uint32 constant MAX_SUPPLY = 15;
    uint32 constant WHITELIST_SUPPLY = 5;
    uint256 constant MINT_PRICE = 0.05 ether;
    
    string constant BASE_URI = "ipfs://hidden_metadata";
    string constant REVEALED_URI = "ipfs://revealed_metadata/";
    string constant AWESOME_URI = "ipfs://awesome_metadata/";
    string constant INVALID_URI = "ipfs://another_metadata/";
    
    bytes32 constant ROLE_MODERATOR = keccak256("ROLE_MODERATOR");
    bytes32 constant ROLE_STAKEHOLDER = keccak256("ROLE_STAKEHOLDER");
    
    // === Контракты ===
    MimimiCat public mimimiCat;
    MockMultiSigWallet public mockMultiSig;
    SignatureHelper public sigHelper;
    Merkle public murky;
    
    // === Whitelist ===
    mapping(address addr => uint8 index) public whitelistAddresses;
    bytes32[] public whitelistLeaves;
    bytes32 public whitelistRoot;

    Signer public owner;
    
    function setUp() public virtual {
        createSigners(35);
        owner = signers[0];
        vm.startPrank(owner.addr);
        
        mockMultiSig = new MockMultiSigWallet();
        mimimiCat = new MimimiCat(
            MAX_SUPPLY,
            WHITELIST_SUPPLY,
            BASE_URI,
            MINT_PRICE,
            address(mockMultiSig)
        );
        
        vm.stopPrank();
        
        // Инициализация хелперов
        sigHelper = new SignatureHelper(address(mimimiCat));
        murky = new Merkle();
        
        // Генерируем leaves и root
        for (uint8 i = 0; i < 5; i++) {
            address addr = signers[30+i].addr;
            whitelistAddresses[addr] = i;
            whitelistLeaves.push( keccak256(abi.encodePacked( addr )) );
        }
        whitelistRoot = murky.getRoot(whitelistLeaves);
        
    }
    
    // === Модификаторы для setup состояний ===
    
    modifier withBalance(uint256 amount) {
        vm.deal(address(mimimiCat), amount);
        _;
    }
    
    modifier withState(uint8 state) {
        stdstore
            .target(address(mimimiCat))
            .enable_packed_slots()
            .sig("state()")
            .checked_write(uint8(state));
        _;
    }

    modifier withStakeholder(address addr) {
        vm.prank(owner.addr);
        mimimiCat.addStakeHolders(_toArray(addr));
        _;
    }

    modifier withModerator(address addr) {
        vm.prank(owner.addr);
        mimimiCat.addModerators(_toArray(addr));
        _;
    }
    
    modifier withWhitelist() {
        vm.prank(address(mockMultiSig));
        mimimiCat.setWhiteList(whitelistRoot);
        _;
    }
    
    modifier withBlacklist(address addr) {
        stdstore
            .target(address(mimimiCat))
            .enable_packed_slots()
            .sig("blackList(address)")
            .with_key(addr)
            .checked_write(true);
        _;
    }
    
    modifier withMintPrice(uint256 price) {
        stdstore
            .target(address(mimimiCat))
            .enable_packed_slots()
            .sig("mintPrice()")
            .checked_write(uint256(price));
        _;
    }

    modifier withMintToken(address addr) {
        stdstore
            .target(address(mimimiCat))
            .enable_packed_slots()
            .sig("state()")
            .checked_write(uint8(STATE_OPEN));
        vm.startPrank(addr);
        mimimiCat.mint{value: mimimiCat.mintPrice()}();
        vm.stopPrank();
        _;
    }
    
    function getProof(address addr) public view returns (bytes32[] memory) {
        uint8 index = whitelistAddresses[addr];
        return murky.getProof(whitelistLeaves, index);
    }
    
    
    function _toArray(address addr) internal pure returns (address[] memory) {
        address[] memory arr = new address[](1);
        arr[0] = addr;
        return arr;
    }

    // dynamic array of any length
    function _toArray(bytes memory data) internal pure returns (address[] memory) {
        uint256 count = data.length / 32;
        address[] memory arr = new address[](count);
        
        assembly {
            let dataPtr := add(data, 32)
            let arrPtr := add(arr, 32)
            
            for { let i := 0 } lt(i, count) { i := add(i, 1) } {
                mstore(add(arrPtr, mul(i, 32)), mload(add(dataPtr, mul(i, 32))))
            }
        }
        
        return arr;
    }
    
    receive() external payable {}
}
