// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// Importing necessary components from OpenZeppelin for upgradeability and ownership, as well as local contracts.
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Game} from "./Game.sol";
import {IGameAttestation} from "../sign/IGameAttestation.sol";

contract GameFactory is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    // Mapping from user addresses to their deployed IPHolder contract addresses.
    mapping(address => address[]) public gameCollection;
    IGameAttestation public tokenAttestor;
    address[] public gameInstances;
    // events

    event IPDeployed(address indexed user, address indexed ipHolder);

    /**
     * @dev Initializes the contract by setting up UUPS upgradeability and ownership.
     * It is meant to be called once by the factory or deployer of the contract instance.
     */
    function initialize(IGameAttestation tokenAttestor_) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);
        tokenAttestor = tokenAttestor_;
    }

    function deployGame() public returns (Game) {}

    function allInstances() public view returns (address[] memory) {
        return gameInstances;
    }

    /**
     * @dev Overrides the _authorizeUpgrade function from UUPSUpgradeable to include access control.
     * Ensures that only the owner of the contract can authorize upgrades.
     * @param newImplementation The address of the new contract implementation to upgrade to.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
