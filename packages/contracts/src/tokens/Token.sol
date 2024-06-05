// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Controller} from "../utils/Controller.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IResourceController} from "../utils/IResourceController.sol";

/// @title Token Contract
/// @notice This contract represents an ERC20 token with custom minting and controller management functionality
/// @dev Extends OpenZeppelin's ERC20 and Ownable contracts, and implements the IResourceController interface
contract Token is ERC20, Ownable, IResourceController {
    /// @notice The controller that manages access to certain functions
    Controller public controller;

    event Spha(address indexed spha, uint256 indexed balance);
    /// @notice Constructor for the Token contract
    /// @dev Initializes the ERC20 token with a name and a symbol, and sets the initial owner
    /// @param name_ The name of the token
    /// @param symbol_ The symbol of the token

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) Ownable(msg.sender) {
        _mint(msg.sender, 10000000000000000 ether);
        emit Spha(msg.sender, balanceOf(msg.sender));
    }

    /// @inheritdoc IResourceController
    /// @notice Sets the controller contract address
    /// @param controllerAdd The address of the new controller contract
    function setController(address controllerAdd) public override onlyOwner {
        emit ControllerUpdated(address(controller), controllerAdd);
        controller = Controller(controllerAdd);
    }

    /// @notice Mints new tokens to a specified address
    /// @dev Only callable by addresses with the OWNER_ROLE or the contract owner
    /// @param to The address to mint tokens to
    /// @param amount The amount of tokens to mint
    function mint(address to, uint256 amount) public {
        require(
            controller.hasRole(controller.OWNER_ROLE(), msg.sender) || msg.sender == owner(),
            "Caller does not have permission to mint"
        );
        _mint(to, amount);
    }
}
