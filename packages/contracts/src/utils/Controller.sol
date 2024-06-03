// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract Controller is AccessControl {
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant GAME_CONTROLLER = keccak256("GAME_CONTROLLER");
    constructor() {
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);
        _grantRole(OWNER_ROLE, msg.sender);
    }
}
