// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ERC721, IERC721Errors} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Controller} from "../utils/Controller.sol";
import {IResourceController} from "../utils/IResourceController.sol";

/// @title NFT Contract
/// @notice This contract implements an ERC721 token with custom minting and controller management functionality
/// @dev Extends OpenZeppelin's ERC721 and Ownable contracts
contract NFT is ERC721, Ownable, IResourceController {
    // Public array to store all minted token IDs. Useful for tracking and displaying all tokens.
    uint256[] public tokens;

    // Custom errors to provide specific revert messages for failed operations.
    error InvalidTokenQuantity(); // Error to be thrown if a function receives an invalid number of tokens.
    error TokensNotMinted(); // Error to be thrown if a token minting operation fails.

    // State variable to keep track of the total number of tokens minted.
    uint256 public totalSupply;
    Controller public controller;

    /// @notice Constructor for the NFT contract
    /// @dev Initializes the ERC721 token with a name and a symbol
    /// @param name_ The name of the NFT collection
    /// @param symbol_ The symbol of the NFT collection
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) Ownable(msg.sender) {}

    /// @inheritdoc IResourceController
    function setController(address controllerAdd) public override onlyOwner {
        emit ControllerUpdated(address(controller), controllerAdd);
        controller = Controller(controllerAdd);
    }

    /// @notice Public function to mint a new token
    /// @dev Increments the total supply, mints the new token to the specified address, and returns the new token ID
    /// @param to The address to which the new token will be minted
    /// @return The new token ID that was minted
    function mint(address to) public returns (uint256) {
        require(
            controller.hasRole(controller.OWNER_ROLE(), msg.sender) || msg.sender == owner(),
            "Caller is not authorized to mint"
        );

        ++totalSupply; // Increment the total supply counter before minting to use as the new token ID.
        _safeMint(to, totalSupply);
        tokens.push(totalSupply);
        return totalSupply;
    }
}
