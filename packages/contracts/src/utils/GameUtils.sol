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
    struct PoolPrize {
        Prize prizeType; // Type of the prize.
        uint256 amount;  // Amount or value of the prize.
    }

    /// @notice Structure representing a player in the game.
    struct Player {
        address player;  // Address of the player.
        uint16 collected; // Number of collected items or points.
        uint64 token;    // Token associated with the player.
        uint256 score;   // Score of the player.
    }

    /// @notice Structure representing a message sent between chains.
    struct GameMessage {
        address player;           // Address of the player.
        address playerChainB;     // Address of the player on chain B.
        address receiver;         // Address of the receiver on the destination chain.
        MessageType messageType;  // Type of the message.
        bool validToken;          // Indicates if the token is valid.
        uint64 validUntil;        // Expiration time of the token.
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
    event FreePlay(address indexed player, uint256 indexed amount);

    /// @notice Event emitted when a player pays to play.
    /// @param player The address of the player.
    /// @param amount The amount paid to play.
    event PaidPlay(address indexed player, uint256 indexed amount);

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
}
