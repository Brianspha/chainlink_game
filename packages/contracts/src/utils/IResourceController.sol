// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IResourceController {
    event ControllerUpdated(address indexed from, address indexed to);

    function setController(address controllerAdd) external;
}
