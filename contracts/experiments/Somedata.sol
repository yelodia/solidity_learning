// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

contract Somedata {
    uint8 public lock;
    address public owner; 
    uint16 public commissionBp; 
    uint256 public accumulator; 
    uint16 public bps = 10000;
    mapping(address client => uint256 balance) public balanceOf; 
    address[] public stakeHolders;
    bytes32 public whiteList;
    uint32 public lolkek;
    string public myname;
    mapping(uint8 index => address holder) public mapHolder;
    uint32[] public numbers32;
    uint8[] public numbers8;
    uint256[] public numbers;
    string[5] public sstrings;
    string[] public dstrings;
    uint24[7] public numbers24;
    mapping(address => mapping(address => bool)) public doubleMap;
    mapping(address => mapping(uint256 => mapping(bool => string))) public tripleMap;
    mapping(address => mapping(uint => mapping(bool => mapping(bytes32 => uint)))) public quadMap;
}