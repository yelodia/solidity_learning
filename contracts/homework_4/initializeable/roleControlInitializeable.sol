// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

abstract contract RoleControlInitializeable is AccessControlUpgradeable {
    bytes32 public constant ROLE_MODERATOR = keccak256("ROLE_MODERATOR");
    bytes32 public constant ROLE_STAKEHOLDER = keccak256("ROLE_STAKEHOLDER");
    address public multiSigner;
    address private _owner;
    error OwnableUnauthorizedAccount(address account);

    function roleControlInit(address signer, address _sender) internal {
        multiSigner = signer;
        _owner = _sender;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function addModerators(address[] calldata _accounts) external onlyOwner {
        uint256 len = _accounts.length;
        for (uint256 i = 0; i < len; ++i) {
            _grantRole(ROLE_MODERATOR, _accounts[i]);
        } 
    }

    function removeModerators(address[] calldata _accounts) external onlyOwner {
        uint256 len = _accounts.length;
        for (uint256 i = 0; i < len; ++i) {
            _revokeRole(ROLE_MODERATOR, _accounts[i]);
        } 
    }

    function addStakeHolders(address[] calldata _accounts) external onlyOwner {
        uint256 len = _accounts.length;
        for (uint256 i = 0; i < len; ++i) {
            _grantRole(ROLE_STAKEHOLDER, _accounts[i]);
        } 
    }

    function removeStakeHolders(address[] calldata _accounts) external onlyOwner {
        uint256 len = _accounts.length;
        for (uint256 i = 0; i < len; ++i) {
            _revokeRole(ROLE_STAKEHOLDER, _accounts[i]);
        } 
    }

    function setMultiSigner(address _signer) external onlyOwner {
        multiSigner = _signer;
    }

    modifier onlyMultisigner() {
        require(msg.sender == multiSigner, OwnableUnauthorizedAccount(msg.sender));
        _;
    }

    modifier onlyOwner() {
        if (owner() != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }
    
}