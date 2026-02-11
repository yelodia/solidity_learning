// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IWETH } from "../IWETH.sol";

contract MockWETH is IWETH {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
    }

    function withdraw(uint256 wad) external {
        require(balanceOf[msg.sender] >= wad, "MockWETH: insufficient balance");
        balanceOf[msg.sender] -= wad;
        (bool ok,) = msg.sender.call{ value: wad }("");
        require(ok, "MockWETH: transfer failed");
    }

    function transfer(address to, uint256 value) external returns (bool) {
        require(balanceOf[msg.sender] >= value, "MockWETH: insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        return true;
    }

    function transferFrom(address from, address to, uint256 wad) external returns (bool) {
        require(balanceOf[from] >= wad);
        if (from != msg.sender && allowance[from][msg.sender] != type(uint256).max) {
            require(allowance[from][msg.sender] >= wad);
            allowance[from][msg.sender] -= wad;
        }
        balanceOf[from] -= wad;
        balanceOf[to] += wad;
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        return true;
    }

    function mint(address to, uint256 value) external {
        balanceOf[to] += value;
    }

    receive() external payable {
        balanceOf[msg.sender] += msg.value;
    }
}
