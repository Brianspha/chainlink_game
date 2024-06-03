// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
interface GameUtils {
    enum Prize {
        Token,
        Sablier,
        NFT
    }
    enum MessageType {
        Verify,
        Verified
    }
    struct PoolPrize {
        Prize prizeType;
        uint256 amount;
    }
    struct Player {
        address player;
        uint16 collected;
        uint64 token;
        uint256 score;
    }
    struct GameMessage {
        address player;
        address reciever; // The address of the receiver on the destination chain.
        MessageType messageType;
        bool validToken;
        uint64 validUntil;
    }
    // Event emitted when a message is sent to another chain.
    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        GameMessage message, // The message being sent.
        uint256 fees // The fees paid for sending the message.
    );

    // Event emitted when a message is received from another chain.
    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        GameMessage message // The message that was received.
    );

    event GamePrizeSet(PoolPrize[] indexed prizes);
    event PrizePoolSet(PoolPrize[] indexed pool);
    event BlackListed(address indexed player);
    event WhiteListed(address indexed player);
    event FreePlay(address indexed player, uint256 indexed amount);
    event PaidPlay(address indexed player, uint256 indexed amount);
    event PlayCostUpdate(uint256 indexed from, uint256 indexed to);
    error InsufficientBalance();
    error FreePlayAlreadyClaimed();
    error UnableToGrantFreePlay();
    error BlackListedPlayer();
    error CostCannotBeZero();
    error PrizesNotSet();
    error PrizesAlreadySet();
    error PlayTokenExpired();
    error NotAllowed();
    error CrossPlayNotAllowed();
    error InvalidClientSignature();
    error TopTenOnly();
    error MaxTwelveWinnings();
    error MaxTwelvePrizePool();
}
