// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ud60x18} from "@prb/math/src/UD60x18.sol";
import {ISablierV2LockupLinear} from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import {Broker, LockupLinear} from "@sablier/v2-core/src/types/DataTypes.sol";
import {Controller} from "../utils/Controller.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IResourceController} from "../utils/IResourceController.sol";

/// @title Stream Creator Contract
/// @notice This contract allows the creation of linear lockup streams using Sablier V2
/// @dev Extends OpenZeppelin's Ownable contract and implements the IResourceController interface
contract StreamCreator is Ownable, IResourceController {
    /**
     * @dev Errors to provide specific revert messages for failed operations
     */
    error InvalidCliff();
    error InvalidDuration();
    error InvalidStart();
    error InvalidAmount();
    error ZeroAddress();
    error InvalidStreamId();

    /**
     * @dev State variables
     * @notice streamingToken is the ERC20 token used for streaming
     * @notice sablier is the Sablier V2 Lockup Linear contract
     * @notice controller is the contract controlling access to certain functions
     * @notice userStreams is a mapping of user addresses to their stream IDs
     */
    IERC20 public immutable streamingToken;
    ISablierV2LockupLinear public immutable sablier;
    Controller public controller;
    mapping(address => uint256[]) public userStreams;

    /// @notice Constructor for the StreamCreator contract
    /// @param sablier_ The Sablier V2 Lockup Linear contract address
    /// @param token The ERC20 token address used for streaming
    constructor(ISablierV2LockupLinear sablier_, address token) Ownable(msg.sender) {
        sablier = sablier_;
        streamingToken = IERC20(token);
    }

    /// @notice Creates a linear lockup stream
    /// @param recipient The address to receive the stream
    /// @param totalAmount The total amount of tokens to be streamed
    /// @param duration The duration of the stream
    /// @param unlockAfter The time after which the stream starts unlocking
    /// @param start The start time of the stream
    /// @return streamId The ID of the created stream
    function createLockupLinearStream(
        address recipient,
        uint256 totalAmount,
        uint40 duration,
        uint40 unlockAfter,
        uint40 start
    ) external returns (uint256 streamId) {
        require(
            controller.hasRole(controller.OWNER_ROLE(), msg.sender) || msg.sender == owner(),
            "Caller is not authorized to create stream"
        );

        if (recipient == address(0)) revert ZeroAddress();
        if (start == 0) revert InvalidStart();
        if (duration == 0) revert InvalidDuration();
        if (unlockAfter == 0) revert InvalidCliff();
        if (totalAmount == 0) revert InvalidAmount();

        // Transfer the provided amount of streamingToken tokens to this contract
        require(streamingToken.transferFrom(msg.sender, address(this), totalAmount), "Token transfer failed");

        // Approve the Sablier contract to spend streamingToken
        streamingToken.approve(address(sablier), totalAmount);

        // Declare the params struct
        LockupLinear.CreateWithRange memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = recipient; // The recipient of the streamed assets
        params.totalAmount = uint128(totalAmount); // Total amount is the amount inclusive of all fees
        params.asset = streamingToken; // The streaming asset
        params.cancelable = false; // Whether the stream will be cancelable or not
        params.range = LockupLinear.Range({
            start: start,
            cliff: unlockAfter, // Ensure that the value is a multiple of an hour or day
            end: start + duration // Ensure that the value is a multiple of an hour or day
        });
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter for charging a fee

        // Create the Sablier stream using a function that sets the start time to `block.timestamp`
        streamId = sablier.createWithRange(params);
        userStreams[msg.sender].push(streamId);
    }

    /// @inheritdoc IResourceController
    function setController(address controllerAdd) public override onlyOwner {
        emit ControllerUpdated(address(controller), controllerAdd);
        controller = Controller(controllerAdd);
    }
}
