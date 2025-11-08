// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract Permissions {
    using MessageHashUtils for bytes32;
    string private pVersion = "1.0.0";
    string private pName = "MimimiCat";
    uint256 internal immutable INITIAL_CHAIN_ID;
    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;
    mapping(address => uint256) public nonces;

    constructor(string memory _name, string memory _version) {
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
        pVersion = _version;
        pName = _name;
    }

    error InvalidSignature();


    function domainSeparator() public view returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : _computeDomainSeparator();
    }

    function _computeDomainSeparator() internal view returns (bytes32) {
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

    // здесь используется персональную подпись, так как ее формирует бекенд и отдает пользовтаелю. Подписан domainSeparator и урл коллекции (чтобы пользователь не провел транзакцию с другим урлом)
    // nonce не используется, так как дочерний конракт не даст повторно закрыть лотерею
    function _validateClose(string calldata _uri, address _signer, uint8 v, bytes32 r, bytes32 s) internal view {
        bytes32 data = keccak256(abi.encodePacked(domainSeparator(), _uri));
        //раньше здесь была цельная сигнатура и код --address recovered = data.toEthSignedMessageHash().recover(_signature);-- 
        // recover - метод из библиотеки ECSDA, который сам делает сплит сигнатуры. Это увеличивает стоимость газа на 1000, поэтому везде используем готовые сплиты v, r, s
        address recoveredAddress = ecrecover(data.toEthSignedMessageHash(), v, r, s); // через toEthSignedMessageHash дописываем к хешу сообщение Ethereum signed message
        require(recoveredAddress != address(0) && recoveredAddress == _signer, InvalidSignature());
    }

    // в остальных функциях используем стандарт EIP721, так как эти данные подписывают сами пользователи

    function _validatePermit( address _owner, address _spender, uint256 _tokenId, uint8 v, bytes32 r, bytes32 s) internal { // а я решила, что мне не нужен deadline. Пусть делают свои аппрувы, когда хотят
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