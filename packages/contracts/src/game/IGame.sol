// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {GameUtils} from "../utils/GameUtils.sol";
interface IGame is GameUtils {
    //fetches random numbers from chainlist vrf based on the total winings count
    function getWinnings(
        uint16 totalCollected
    ) external returns (uint256[] memory items);
    //returns the pool prize set for the game
    function getPrizePool() external view returns (PoolPrize[] memory pool);
    //sets the pool prize for the game
    function setPrizePool(PoolPrize[] memory prizes) external;
    // blacklists a player
    function blackListPlayer(address player) external;
    // whitelists a player
    function whiteListPlayer(address player) external;
    // allows a player to pay the cost of playing a game then the contract issues an attestation id using the sign protocol which
    // represents the play token for the player
    function play() external returns (bool ok);
    // allows a player to play for free
    function freePlay() external;
    // allows a player to use an existing play token from chain B in chain A this takes time to verifiy since the tx needs to be sent to the other chain
    function crossChainPlay(
        GameMessage memory message,
        uint64 destinationChainSelector
    ) external returns (bytes32 messageId);
    // sets the cost to play the game
    function setPlayCost(uint256 cost) external;
    // Submits a users score together with a signature by the offchain game ensuring the game was played within the client and not submmited via etherscan
    // The winnings array represents the indexes of the prizes the user has won each index represent the index in the prizepool globally defined
    function submitScore(
        uint256[] memory userScores,
        bytes calldata signature,
        uint256[] memory sablierWins,
        uint256[] memory nftWins,
        uint256[] memory tokenWins
    ) external;
    function scores() external view returns (uint256[] memory);
    function getPlayer(
        address player_
    ) external view returns (Player memory player);
}
