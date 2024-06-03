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
        uint256[] memory userScoresA = gameA.scores();
        vm.selectFork(chainBForkID);
        uint256[] memory userScoresB = gameB.scores();
        vm.selectFork(chainAForkID);
        uint256[] memory userScores = _mergeArrays(
            userScoresA,
            userScoresB,
            1200
        );
        bytes32 hash = keccak256(
            abi.encodePacked(userScores, ownerA, block.chainid)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            ownerPKA,
            MessageHashUtils.toEthSignedMessageHash(hash)
        );
        console.log("gameA.owner():", gameA.owner());
        console.log(" owner:", ownerA);
        require(gameA.owner() == ownerA, "Not owner");
        bytes memory signedMessage = abi.encodePacked(r, s, v);
        uint256[] memory sablierWins = new uint256[](3);
        uint256[] memory nftWins = new uint256[](3);
        uint256[] memory tokenWins = new uint256[](3);
        sablierWins[0] = 0;
        sablierWins[1] = 1;
        sablierWins[2] = 2;
        nftWins[0] = 0;
        nftWins[1] = 1;
        nftWins[2] = 2;
        tokenWins[0] = 0;
        tokenWins[1] = 1;
        tokenWins[2] = 2;
        console.log("ownerA: ", gameA.owner());
        gameA.submitScore(
            userScores,
            signedMessage,
            sablierWins,
            nftWins,
            tokenWins
        );
        assertEq(tokenA.balanceOf(sphaA), 1000000000010 ether);
        assertEq(nftA.balanceOf(sphaA), 1);

        vm.stopPrank();
    }
    function crossPlayChainA_B() public {
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
                reciever: address(gameA),
                messageType: MessageType.Verify,
                validToken: false,
                validUntil: 0
            }),
            uint64(chainANetworkDetails.chainSelector)
        );
        ccipLocalSimulatorFork.switchChainAndRouteMessage(chainAForkID);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(chainBForkID);
        Player memory player = gameB.getPlayer(sphaB);
        console.log("playerToken: ", player.token);
        vm.stopPrank();
    }
    event Here(uint256 indexed num);
    function _mergeArrays(
        uint256[] memory a,
        uint256[] memory b,
        uint256 score
    ) public returns (uint256[] memory) {
        uint256[] memory finalArray = new uint256[](a.length + b.length + 1);
        uint256 i;
        for (; i < a.length; i++) {
            finalArray[i] = a[i];
            emit Here(finalArray[i]);
        }
        i = 0;
        for (; i < b.length; i++) {
            finalArray[a.length + i] = b[i];
        }
        finalArray[finalArray.length - 1] = score;
        return finalArray;
    }
}
