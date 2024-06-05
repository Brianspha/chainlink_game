// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title Controller Contract
/// @notice This contract manages access control for different roles using OpenZeppelin's AccessControl
/// @dev Defines roles and assigns them to different addresses, allowing for role-based access control
contract Controller is AccessControl {
    /// @notice Role identifier for the owner role
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    /// @notice Role identifier for the game controller role
    bytes32 public constant GAME_CONTROLLER = keccak256("GAME_CONTROLLER");

    /// @notice Constructor that sets up the initial roles
    /// @dev Grants the deployer of the contract the OWNER_ROLE and sets it as the admin for OWNER_ROLE
    constructor() {
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);
        _grantRole(OWNER_ROLE, msg.sender);
    }
}
