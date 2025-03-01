// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract RoleControl is Ownable, AccessControl {
    bytes32 public constant ROLE_MODERATOR = keccak256("ROLE_MODERATOR");
    bytes32 public constant ROLE_STAKEHOLDER = keccak256("ROLE_STAKEHOLDER");
    address public multiSigner;

    constructor(address signer) Ownable(msg.sender) payable {
        multiSigner = signer;
    }

    function renounceOwnership() public override(Ownable) pure { revert("disabled"); }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
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
    
}