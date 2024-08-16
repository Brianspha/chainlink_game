// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title Game Utility Interface for Game-Related Structures, Events, and Errors
/// @author [Author]
/// @notice This interface defines utility structures, events, and custom errors for the game.
interface GameUtils {
    /// @notice Enum representing the different types of prizes available in the game.
    enum Prize {
        Token,
        Sablier,
        NFT
    }

    /// @notice Enum representing the different types of messages that can be sent.
    enum MessageType {
        Verify,
        Verified
    }

    /// @notice Structure representing a prize in the prize pool.
    /// @param prizeType Type of the prize.
    /// @param amount Amount or value of the prize.
    struct PoolPrize {
        Prize prizeType;
        uint256 amount;
    }

    /// @notice Structure representing a player in the game.
    /// @param player Address of the player.
    /// @param collected Number of collected items or points.
    /// @param token Token associated with the player i.e. The Attestation ID.
    /// @param score Score of the player.
    struct Player {
        address player;
        uint16 collected;
        uint64 token;
        uint64 score;
    }

    /// @notice Structure representing a message sent between chains.
    /// @param player Address of the player.
    /// @param playerChainB Address of the player on chain B.
    /// @param receiver Address of the receiver.
    /// @param messageType Type of the message.
    /// @param validToken Token associated with the message.
    /// @param validUntil Expiry time of the token.
    struct GameMessage {
        address player;
        address playerChainB;
        address receiver;
        MessageType messageType;
        bool validToken;
        uint64 validUntil;
    }

    /// @notice Event emitted when a message is sent to another chain.
    /// @param messageId The unique ID of the message.
    /// @param destinationChainSelector The chain selector of the destination chain.
    /// @param receiver The address of the receiver on the destination chain.
    /// @param message The message being sent.
    /// @param fees The fees paid for sending the message.
    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address receiver,
        GameMessage message,
        uint256 fees
    );

    /// @notice Event emitted when a message is received from another chain.
    /// @param messageId The unique ID of the message.
    /// @param sourceChainSelector The chain selector of the source chain.
    /// @param sender The address of the sender from the source chain.
    /// @param message The message that was received.
    event MessageReceived(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address sender,
        GameMessage message
    );

    /// @notice Event emitted when the game prize is set.
    /// @param prizes The array of prizes set for the game.
    event GamePrizeSet(PoolPrize[] indexed prizes);

    /// @notice Event emitted when the prize pool is set.
    /// @param pool The array of prizes set in the pool.
    event PrizePoolSet(PoolPrize[] indexed pool);

    /// @notice Event emitted when a player is blacklisted.
    /// @param player The address of the blacklisted player.
    event BlackListed(address indexed player);

    /// @notice Event emitted when a player is whitelisted.
    /// @param player The address of the whitelisted player.
    event WhiteListed(address indexed player);

    /// @notice Event emitted when a player plays for free.
    /// @param player The address of the player.
    /// @param amount The amount associated with the free play.
    /// @param playTokenId The token id issued by the sign protocol
    event FreePlay(
        address indexed player,
        uint256 indexed amount,
        uint64 indexed playTokenId
    );

    /// @notice Event emitted when a player pays to play.
    /// @param player The address of the player.
    /// @param amount The amount paid to play.
    /// @param playTokenId The token id issued by the sign protocol
    event PaidPlay(
        address indexed player,
        uint256 indexed amount,
        uint64 indexed playTokenId
    );

    /// @notice Event emitted when the cost to play the game is updated.
    /// @param from The previous cost to play.
    /// @param to The new cost to play.
    event PlayCostUpdate(uint256 indexed from, uint256 indexed to);

    /// @notice Error indicating insufficient balance.
    error InsufficientBalance();

    /// @notice Error indicating that the free play has already been claimed.
    error FreePlayAlreadyClaimed();

    /// @notice Error indicating an inability to grant free play.
    error UnableToGrantFreePlay();

    /// @notice Error indicating that the player is blacklisted.
    error BlackListedPlayer();

    /// @notice Error indicating that the play cost cannot be zero.
    error CostCannotBeZero();

    /// @notice Error indicating that prizes have not been set.
    error PrizesNotSet();

    /// @notice Error indicating that prizes have already been set.
    error PrizesAlreadySet();

    /// @notice Error indicating that the play token has expired.
    error PlayTokenExpired();

    /// @notice Error indicating that the action is not allowed.
    error NotAllowed();

    /// @notice Error indicating that cross play is not allowed.
    error CrossPlayNotAllowed();

    /// @notice Error indicating an invalid client signature.
    error InvalidClientSignature();

    /// @notice Error indicating that the action is restricted to the top ten players.
    error TopTenOnly();

    /// @notice Error indicating that the winnings exceed twelve in length.
    error MaxTwelveWinnings();

    /// @notice Error indicating that the prize pool exceeds twelve in length.
    error MaxTwelvePrizePool();

    /// @notice Error indicating that the two arrays dont match in length
    error ArrayLengthMissmatch();

    /// @notice Error indicating that a signature has been used already
    error UsedSignature();
    /// @notice Error indicating that the period is invalid we only ever allow a period of 365 days at a time
    error InvalidPeriod();
}
