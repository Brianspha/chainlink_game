// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/// @title Resource Controller Interface
/// @notice This interface defines the functions and events for managing a resource controller
interface IResourceController {
    /// @notice Event emitted when the controller is updated
    /// @param from The address of the previous controller
    /// @param to The address of the new controller
    event ControllerUpdated(address indexed from, address indexed to);

    /// @notice Sets a new controller
    /// @param controllerAdd The address of the new controller
    function setController(address controllerAdd) external;
}
