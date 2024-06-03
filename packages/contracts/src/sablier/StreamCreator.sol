// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ud60x18} from "@prb/math/src/UD60x18.sol";
import {ISablierV2LockupLinear} from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import {Broker, LockupLinear} from "@sablier/v2-core/src/types/DataTypes.sol";
import {Controller} from "../utils/Controller.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IResourceController} from "../utils/IResourceController.sol";

contract StreamCreator is Ownable, IResourceController {
    /**
     *
     *                              Errors
     *
     */
    error InvalidCliff();
    error InvalidDuration();
    error InvalidStart();
    error InvalidAmount();
    error ZeroAddress();
    error InvalidStreamId();

    /**
     *
     *                              State variables
     *
     */

    IERC20 public immutable streamingToken;
    ISablierV2LockupLinear public immutable sablier;
    Controller public controller;
    mapping(address user => uint256[] streams) public userStreams;

    constructor(
        ISablierV2LockupLinear sablier_,
        address token
    ) Ownable(msg.sender) {
        sablier = sablier_;
        streamingToken = IERC20(token);
    }

    function createLockupLinearStream(
        address receipient,
        uint256 totalAmount,
        uint40 duration,
        uint40 unlockAfter,
        uint40 start
    ) external returns (uint256 streamId) {
        require(
            controller.hasRole(controller.OWNER_ROLE(), msg.sender) ||
                msg.sender == owner()
        );

        if (receipient == address(0)) revert ZeroAddress();
        if (start == 0) revert InvalidStart();
        if (duration == 0) revert InvalidDuration();
        if (unlockAfter == 0) revert InvalidCliff();
        if (totalAmount == 0) revert InvalidAmount();
        // Transfer the provided amount of streamingToken tokens to this contract
        assert(
            streamingToken.transferFrom(msg.sender, address(this), totalAmount)
        );

        // Approve the Sablier contract to spend streamingToken
        streamingToken.approve(address(sablier), totalAmount);

        // Declare the params struct
        LockupLinear.CreateWithRange memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = receipient; // The recipient of the streamed assets
        params.totalAmount = uint128(totalAmount); // Total amount is the amount inclusive of all fees
        params.asset = streamingToken; // The streaming asset
        params.cancelable = false; // Whether the stream will be cancelable or not
        params.range = LockupLinear.Range({
            start: start,
            cliff: unlockAfter, //ensure that the  value is a multiple of an hour or day
            end: uint40(block.timestamp + duration) //ensure that the  value is a multiple of an hour or day
        });
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter for charging a fee

        // Create the Sablier stream using a function that sets the start time to `block.timestamp`
        userStreams[msg.sender].push(streamId);
        streamId = sablier.createWithRange(params);
    }
    /// @inheritdoc IResourceController
    function setController(address controllerAdd) public override onlyOwner {
        emit ControllerUpdated(address(controller), controllerAdd);
        controller = Controller(controllerAdd);
    }
}
