// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ISP} from "@ethsign/sign-protocol-evm/src/interfaces/ISP.sol";
import {Schema} from "@ethsign/sign-protocol-evm/src/models/Schema.sol";
import {Attestation} from "@ethsign/sign-protocol-evm/src/models/Attestation.sol";
import {DataLocation} from "@ethsign/sign-protocol-evm/src/models/DataLocation.sol";

/// @title Game Attestation Interface
/// @notice Provides functions to manage game play attestations using the Sign Protocol
interface IGameAttestation {
    // Custom error to indicate that the Sign Protocol instance has not been initialized
    error SPNotInitialized();

    /// @notice Struct to represent a game play attestation
    /// @param user The address of the user
    /// @param game The address of the game
    /// @param cost The cost of the game play
    /// @param recipients The addresses of the recipients
    /// @param validUntil The timestamp until which the attestation is valid
    struct GamePlayAttestation {
        address user;
        address game;
        uint256 cost;
        bytes[] recipients;
        uint64 validUntil;
    }

    /// @notice Event emitted when a game play starts usually after an attestation is completed
    /// @param attestationId The ID of the attestation
    /// @param user The address of the user
    /// @param game The address of the game
    event GamePlayStarted(
        uint64 indexed attestationId,
        address indexed user,
        address indexed game
    );

    /// @notice Sets the instance of the Sign Protocol to be used
    /// @param instance Address of the Sign Protocol instance
    function setSPInstance(address instance) external;

    /// @notice Registers and sets a new schema ID to be used to attest IPs
    /// @param schema The schema used for creating attestations
    function registerSchema(Schema memory schema) external;

    /// @notice Attests to a game play
    /// @dev This function is used to issue playtokens for any user
    /// @param attestation The attestation details for the game play
    /// @return attestationId The ID of the created attestation
    function attestGamePlay(
        GamePlayAttestation memory attestation
    ) external returns (uint64);
}
