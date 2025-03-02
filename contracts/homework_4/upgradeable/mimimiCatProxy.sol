// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

error ZeroImplementationAddress();

error ZeroData();

error InitializationFailed();

contract MimimiCatProxy {
    bytes32 public constant MIMIMICAT_STORAGE = 0x3e596b5924e4cbd652ac0c0844961e3c6d4e09860b46e84c2417e0039c826860;

    constructor(address implementation, bytes memory data) {
        if (implementation == address(0)) {
            revert ZeroImplementationAddress();
        }

        if (data.length == 0) {
            revert ZeroData();
        }

        assembly {
            sstore(MIMIMICAT_STORAGE, implementation)
        }

        (bool success, ) = implementation.delegatecall(data);
        if (!success) {
            revert InitializationFailed();
        }
    }

    fallback() external payable {
        assembly {
            let implementation := sload(MIMIMICAT_STORAGE)
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if eq(success, 0) {
                revert(0, returndatasize())
            }
            return(0, returndatasize())
        }
    }

    receive() external payable {
        revert("bad call");
    }

    function getImplementation() external view returns (address implementation) {
        // solhint-disable-next-line avoid-low-level-calls
        assembly {
            implementation := sload(MIMIMICAT_STORAGE)
        }
    }
}