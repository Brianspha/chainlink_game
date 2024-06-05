// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {GameUtils} from "../utils/GameUtils.sol";

/// @title Game Interface
/// @dev Interface for the game contract, providing functions to manage gameplay, prizes, and player interactions
interface IGame is GameUtils {
    /// @notice Fetches random numbers from Chainlink VRF based on the total winnings count
    /// @dev Uses ECDSA to ensure that the scores were submitted via the game
    /// @param totalCollected The total number of game items collected in the game
    /// @param signature The signature to verify the legitimacy of the submission; this uses the owner of the contract's signature (see implementation)
    /// @return items The array of random numbers representing the winnings
    function getWinnings(uint16 totalCollected, bytes calldata signature) external returns (uint256[] memory items);

    /// @notice Returns the prize pool set for the game
    /// @return pool An array of PoolPrize structures representing the prize pool
    function getPrizePool() external view returns (PoolPrize[] memory pool);

    /// @notice Sets the prize pool for the game
    /// @param prizes An array of PoolPrize structures representing the new prize pool
    function setPrizePool(PoolPrize[] memory prizes) external;

    /// @notice Blacklists a player, preventing them from participating in the game
    /// @param player The address of the player to blacklist
    function blackListPlayer(address player) external;

    /// @notice Whitelists a player, allowing them to participate in the game
    /// @param player The address of the player to whitelist
    function whiteListPlayer(address player) external;

    /// @notice Allows a player to pay the cost of playing a game
    /// @dev Issues an attestation ID using the Sign protocol representing the play token for the player
    /// @return ok A boolean value indicating whether the operation was successful
    function play() external returns (bool ok);

    /// @notice Allows a player to play for free
    function freePlay() external;

    /// @notice Allows a player to use an existing play token from Chain B in Chain A
    /// @dev This operation requires cross-chain verification, which takes time
    /// @param message The game message containing play token details from Chain B
    /// @param destinationChainSelector The chain selector for the destination chain
    /// @return messageId The message ID for tracking the cross-chain transaction
    function crossChainPlay(GameMessage memory message, uint64 destinationChainSelector)
        external
        returns (bytes32 messageId);

    /// @notice Sets the cost to play the game
    /// @param cost The new cost to play the game
    function setPlayCost(uint256 cost) external;

    /// @notice Submits a user's score together with a signature from the off-chain game
    /// @dev Ensures the game was played within the client and not submitted via Etherscan. Uses ECDSA to verify that the scores were submitted via the game
    /// @param userScores An array of user scores to submit
    /// @param addressScores An array of user addresses each address is 1 to 1 with the userscores param
    /// @param signature The signature to verify the legitimacy of the submission (see implementation)
    /// @param winnings The array of indexes representing the prizes the user has won
    function submitScore(
        uint256[] memory userScores,
        address[] memory addressScores,
        bytes calldata signature,
        uint256[] memory winnings
    ) external;

    /// @notice Returns the scores of all players
    /// @return An array of scores
    function scores() external view returns (uint256[] memory, address[] memory);

    /// @notice Returns the details of a player
    /// @param player_ The address of the player to retrieve
    /// @return player A Player structure containing the player's details
    function getPlayer(address player_) external view returns (Player memory player);
}
