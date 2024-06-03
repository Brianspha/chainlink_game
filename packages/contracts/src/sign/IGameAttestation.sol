// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;
import {ISP} from "@ethsign/sign-protocol-evm/src/interfaces/ISP.sol";
import {Schema} from "@ethsign/sign-protocol-evm/src/models/Schema.sol";
import {Attestation} from "@ethsign/sign-protocol-evm/src/models/Attestation.sol";
import {DataLocation} from "@ethsign/sign-protocol-evm/src/models/DataLocation.sol";
import "@ethsign/sign-protocol-evm/src/interfaces/ISP.sol";
interface IGameAttestation {
    // errors
    error SPNotInitialized();

    //structs

    struct GamePlayAttestion {
        address user;
        address game;
        uint256 cost;
        bytes[] recipients;
        uint64 validUntil;
    }

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

    function attestGamePlay(
        GamePlayAttestion memory attestation
    ) external returns (uint64);
}
