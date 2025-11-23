// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";
import {Merkle} from "murky/src/Merkle.sol";
import {MimimiCat} from "../../contracts/homework_4/mimimiCat.sol";
import {SignatureHelper} from "./helpers/SignatureHelper.sol";
import {Accounts} from "../helpers/Accounts.sol";


abstract contract MimimiCatTestBase is Test, Accounts {
    using stdStorage for StdStorage;
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
    
    // === Contracts ===
    MimimiCat public mimimiCat;
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

        deployContracts();
        
        sigHelper = new SignatureHelper(_targetContract());
        murky = new Merkle();
        
        for (uint8 i = 0; i < 5; i++) {
            address addr = signers[30+i].addr;
            whitelistAddresses[addr] = i;
            whitelistLeaves.push( keccak256(abi.encodePacked( addr )) );
        }
        whitelistRoot = murky.getRoot(whitelistLeaves);
        
    }

    function _targetContract() internal virtual view returns (address);

    function deployContracts() public virtual;
    
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
