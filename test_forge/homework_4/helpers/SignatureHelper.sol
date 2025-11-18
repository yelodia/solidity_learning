// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

/**
 * @title SignatureHelper
 * @notice Хелпер для создания EIP-712 подписей в тестах
 */
contract SignatureHelper is Test {
    bytes32 private constant PERMIT_TYPEHASH = 
        keccak256("Permit(address owner,address spender,uint256 tokenId,uint256 nonce)");
    
    bytes32 private constant MINT_TYPEHASH = 
        keccak256("Mint(address owner,uint256 nonce)");
    
    bytes32 private constant FREE_MINT_TYPEHASH = 
        keccak256("FreeMint(address owner,bytes32[] proof,uint256 nonce)");
    
    string private constant NAME = "MimimiCat";
    string private constant VERSION = "1.0.0";
    
    address private immutable contractAddress;
    uint256 private immutable chainId;
    
    constructor(address _contractAddress) {
        contractAddress = _contractAddress;
        chainId = block.chainid;
    }
    
    function domainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(NAME)),
                keccak256(bytes(VERSION)),
                chainId,
                contractAddress
            )
        );
    }


    function signPermit(
        uint256 ownerPrivateKey,
        address spender,
        uint256 tokenId,
        uint256 nonce
    ) external view returns (uint8 v, bytes32 r, bytes32 s) {
        address owner = vm.addr(ownerPrivateKey);
        
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                tokenId,
                nonce
            )
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator(),
                structHash
            )
        );
        
        return vm.sign(ownerPrivateKey, digest);
    }
    

    function signMint(
        uint256 ownerPrivateKey,
        uint256 nonce
    ) external view returns (uint8 v, bytes32 r, bytes32 s) {
        address owner = vm.addr(ownerPrivateKey);
        
        bytes32 structHash = keccak256(
            abi.encode(
                MINT_TYPEHASH,
                owner,
                nonce
            )
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator(),
                structHash
            )
        );
        
        return vm.sign(ownerPrivateKey, digest);
    }
    

    function signFreeMint(
        uint256 ownerPrivateKey,
        bytes32[] calldata proof,
        uint256 nonce
    ) external view returns (uint8 v, bytes32 r, bytes32 s) {
        address owner = vm.addr(ownerPrivateKey);
        
        bytes32 structHash = keccak256(
            abi.encode(
                FREE_MINT_TYPEHASH,
                owner,
                keccak256(abi.encodePacked(proof)),
                nonce
            )
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator(),
                structHash
            )
        );
        
        return vm.sign(ownerPrivateKey, digest);
    }
    

    function signClose(
        uint256 signerPrivateKey,
        string calldata uri
    ) external view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                domainSeparator(),
                uri
            )
        );
        
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                messageHash
            )
        );
        
        return vm.sign(signerPrivateKey, ethSignedMessageHash);
    }
}
