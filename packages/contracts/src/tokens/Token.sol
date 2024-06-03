// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Controller} from "../utils/Controller.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IResourceController} from "../utils/IResourceController.sol";

contract Token is ERC20, Ownable, IResourceController {
    Controller public controller;
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {}

    function setController(address controllerAdd) public override onlyOwner {
        emit ControllerUpdated(address(controller), controllerAdd);
        controller = Controller(controllerAdd);
    }
    function mint(address to, uint256 amount) public {
        require(controller.hasRole(controller.OWNER_ROLE(), msg.sender) || msg.sender == owner());
        _mint(to, amount);
    }
}
