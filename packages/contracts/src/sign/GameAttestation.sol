// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IGameAttestation, Attestation, Schema, ISP, DataLocation} from "./IGameAttestation.sol";
import {Controller} from "../utils/Controller.sol";
import {IResourceController} from "../utils/IResourceController.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract GameAttestation is IGameAttestation, IResourceController, Ownable {
    modifier onlyWhenSpInitialized() {
        if (address(spInstance) == address(0)) {
            revert SPNotInitialized();
        }
        _;
    }

    Controller public controller;
    ISP public spInstance;
    uint64 public schemaId;
    mapping(address => address) public ipOwner;

    constructor() Ownable(msg.sender) {}

    /// @inheritdoc IGameAttestation
    function setSPInstance(address instance) external override {
        require(controller.hasRole(controller.OWNER_ROLE(), msg.sender));
        spInstance = ISP(instance);
    }

    /// @inheritdoc IGameAttestation
    function registerSchema(
        Schema memory schema
    ) external override onlyWhenSpInitialized {
        require(controller.hasRole(controller.OWNER_ROLE(), msg.sender));
        schemaId = spInstance.register(schema, "");
    }

    /// @inheritdoc IGameAttestation
    function attestGamePlay(
        GamePlayAttestion memory attestation
    ) external override onlyWhenSpInitialized returns (uint64) {
        require(controller.hasRole(controller.OWNER_ROLE(), msg.sender));
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
