// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseGameTest} from "./base/BaseGameTest.t.sol";
import {console} from "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract GameTest is BaseGameTest {
    function setUp() public override {
        BaseGameTest.setUp();
    }

    function test_freePlayChainA() public {
        vm.selectFork(chainAForkID);
        vm.startPrank(sphaA);
        gameA.freePlay();
        Player memory player = gameA.getPlayer(sphaA);
        assertEq(player.player, sphaA);
        assertEq(player.token, 0);
        vm.stopPrank();
    }

    function test_PlayChainB() public {
        vm.selectFork(chainBForkID);
        vm.startPrank(sphaB);
        tokenB.approve(address(gameB), type(uint256).max);
        gameB.play();
        Player memory player = gameB.getPlayer(sphaB);
        assertEq(player.player, sphaB);
        assertEq(player.token, 0);
        vm.stopPrank();
    }

    function test_freePlayChainA_Wins() public {
        vm.selectFork(chainAForkID);
        vm.startPrank(sphaA);
        gameA.freePlay();
        Player memory player = gameA.getPlayer(sphaA);
        assertEq(player.player, sphaA);
        assertEq(player.token, 0);
        (
            uint256[] memory userScoresA,
            address[] memory crosschainAddressesA
        ) = gameA.scores();
        vm.selectFork(chainBForkID);
        (
            uint256[] memory userScoresB,
            address[] memory crosschainAddressesB
        ) = gameB.scores();
        vm.selectFork(chainAForkID);
        uint256[] memory userScores = _mergeArrays(
            userScoresA,
            userScoresB,
            1200
        );
        address[] memory userAddresses = _mergeAddressArrays(
            crosschainAddressesA,
            crosschainAddressesB,
            sphaA
        );
        bytes32 hash = keccak256(
            abi.encodePacked(userScores, userAddresses, block.chainid)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            ownerPKA,
            MessageHashUtils.toEthSignedMessageHash(hash)
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(
            ownerPKA,
            MessageHashUtils.toEthSignedMessageHash(
                keccak256(abi.encodePacked(sphaA, block.chainid))
            )
        );
        bytes memory signedMessage = abi.encodePacked(r, s, v);
        bytes memory signedMessage1 = abi.encodePacked(r1, s1, v1);
        uint256[] memory wins = gameA.getWinnings(10, signedMessage1);
        gameA.submitScore(userScores, userAddresses, signedMessage, wins);
        assertEq(tokenA.balanceOf(sphaA), 1000000000015 ether);
        assertEq(nftA.balanceOf(sphaA), 2);
        vm.stopPrank();
    }

    function test_crossPlayChainA_B() public {
        vm.selectFork(chainAForkID);
        vm.startPrank(sphaA);
        tokenA.approve(address(gameA), type(uint256).max);
        gameA.freePlay();
        vm.stopPrank();
        vm.selectFork(chainBForkID);
        vm.startPrank(sphaB);
        gameB.crossChainPlay(
            GameMessage({
                player: sphaA,
                playerChainB: sphaB,
                receiver: address(gameA),
                messageType: MessageType.Verify,
                validToken: false,
                validUntil: 0
            }),
            uint64(chainANetworkDetails.chainSelector)
        );
        ccipLocalSimulatorFork.switchChainAndRouteMessage(chainAForkID);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(chainBForkID);

        Player memory player = gameB.getPlayer(sphaB);
        assertEq(player.player, sphaB);
        vm.stopPrank();
    }

  

    function _mergeArrays(
        uint256[] memory a,
        uint256[] memory b,
        uint256 score
    ) public pure returns (uint256[] memory) {
        uint256[] memory finalArray = new uint256[](a.length + b.length + 1);
        uint256 i;
        for (; i < a.length; i++) {
            finalArray[i] = a[i];
        }
        i = 0;
        for (; i < b.length; i++) {
            finalArray[a.length + i] = b[i];
        }
        finalArray[finalArray.length - 1] = score;
        return finalArray;
    }

    function _mergeAddressArrays(
        address[] memory a,
        address[] memory b,
        address player
    ) public pure returns (address[] memory) {
        address[] memory finalArray = new address[](a.length + b.length + 1);
        uint256 i;
        for (; i < a.length; i++) {
            finalArray[i] = a[i];
        }
        i = 0;
        for (; i < b.length; i++) {
            finalArray[a.length + i] = b[i];
        }
        finalArray[finalArray.length - 1] = player;
        return finalArray;
    }
}
