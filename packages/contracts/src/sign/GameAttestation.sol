// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IGameAttestation, Attestation, Schema, ISP, DataLocation} from "./IGameAttestation.sol";
import {Controller} from "../utils/Controller.sol";
import {IResourceController} from "../utils/IResourceController.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Game Attestation Contract
/// @notice This contract manages game play attestations using the Sign Protocol
/// @dev The contract is used to issue Play tokens which expire on the different chains the Game contract is deployed on
/// @dev Extends Ownable and implements IGameAttestation and IResourceController interfaces
contract GameAttestation is IGameAttestation, IResourceController, Ownable {
    /// @notice Modifier to check if the Sign Protocol instance is initialized
    modifier onlyWhenSpInitialized() {
        if (address(spInstance) == address(0)) {
            revert SPNotInitialized();
        }
        _;
    }

    // State variables
    Controller public controller;
    ISP public spInstance;
    uint64 public schemaId;
    mapping(address => address) public ipOwner;

    /// @notice Constructor for the GameAttestation contract
    constructor() Ownable(msg.sender) {}

    /// @inheritdoc IGameAttestation
    function setSPInstance(address instance) external override {
        require(controller.hasRole(controller.OWNER_ROLE(), msg.sender), "Caller does not have owner role");
        spInstance = ISP(instance);
    }

    /// @inheritdoc IGameAttestation
    function registerSchema(Schema memory schema) external override onlyWhenSpInitialized {
        require(controller.hasRole(controller.OWNER_ROLE(), msg.sender), "Caller does not have owner role");
        schemaId = spInstance.register(schema, "");
    }

    /// @inheritdoc IGameAttestation
    function attestGamePlay(GamePlayAttestation memory attestation)
        external
        override
        onlyWhenSpInitialized
        returns (uint64)
    {
        require(controller.hasRole(controller.OWNER_ROLE(), msg.sender), "Caller does not have owner role");

        Attestation memory playID = Attestation({
            schemaId: schemaId,
            linkedAttestationId: 0,
            attestTimestamp: uint64(block.timestamp),
            revokeTimestamp: 0,
            attester: address(this),
            validUntil: uint64(block.timestamp + attestation.validUntil),
            dataLocation: DataLocation.ONCHAIN,
            revoked: false,
            recipients: attestation.recipients,
            data: bytes("")
        });

        uint64 attestationId = spInstance.attest(playID, "", "", "");
        emit GamePlayStarted(attestationId, attestation.user, attestation.game);
        return attestationId;
    }

    /// @inheritdoc IResourceController
    function setController(address controllerAdd) public override onlyOwner {
        emit ControllerUpdated(address(controller), controllerAdd);
        controller = Controller(controllerAdd);
    }
}
