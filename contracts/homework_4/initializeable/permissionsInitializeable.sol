// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

abstract contract PermissionsInitializeable {
    using MessageHashUtils for bytes32;
    string private pVersion;
    string private pName;
    mapping(address => uint256) public nonces;

    function permissionsInit(string memory _name, string memory _version) internal {
        pVersion = _version;
        pName = _name;
    }

    error InvalidSignature();

    function domainSeparator() public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(pName)),
                    keccak256(bytes(pVersion)),
                    block.chainid,
                    address(this)
                )
            );
    }

    function version() public view returns(string memory) {
        return pVersion;
    }

    function _validateClose(string calldata _uri, address _signer, uint8 v, bytes32 r, bytes32 s) internal view {
        bytes32 data = keccak256(abi.encodePacked(domainSeparator(), _uri));
        address recoveredAddress = ecrecover(data.toEthSignedMessageHash(), v, r, s); 
        require(recoveredAddress != address(0) && recoveredAddress == _signer, InvalidSignature());
    }

    function _validatePermit( address _owner, address _spender, uint256 _tokenId, uint8 v, bytes32 r, bytes32 s) internal { 
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        domainSeparator(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 tokenId,uint256 nonce)"
                                ),
                                _owner,
                                _spender,
                                _tokenId,
                                nonces[_owner]++
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == _owner, InvalidSignature());

        }
    }

    function _validateMint(address _owner, uint8 v, bytes32 r, bytes32 s) internal {
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        domainSeparator(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Mint(address owner,uint256 nonce)"
                                ),
                                _owner,
                                nonces[_owner]++
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == _owner, InvalidSignature());

        }
    }

    function _validateFreeMint(address _owner, bytes32[] calldata _proof, uint8 v, bytes32 r, bytes32 s) internal {
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        domainSeparator(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "FreeMint(address owner,bytes32[] proof,uint256 nonce)"
                                ),
                                _owner,
                                keccak256(abi.encodePacked(_proof)),
                                nonces[_owner]++
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == _owner, InvalidSignature());

        }
    }

}