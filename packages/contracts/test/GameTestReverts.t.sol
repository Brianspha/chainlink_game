// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseGameTest} from "./base/BaseGameTest.t.sol";
import {console} from "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract GameTestReverts is BaseGameTest {
    function setUp() public override {
        BaseGameTest.setUp();
    }
    function test_freePlayChainA_Wins_InvalidSignature() public {
        vm.selectFork(chainAForkID);
        vm.startPrank(sphaA);
        gameA.freePlay();
        vm.expectRevert(InvalidClientSignature.selector);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            12,
            MessageHashUtils.toEthSignedMessageHash(
                keccak256(abi.encodePacked(sphaA, block.chainid))
            )
        );
        bytes memory signedMessage = abi.encodePacked(r, s, v);
        uint256[] memory wins = gameA.getWinnings(10, signedMessage);
        vm.stopPrank();
    }
    function test_Play_InvalidPeriod(uint64 periodInDays) public {
        vm.assume(periodInDays > 0 && periodInDays < 86400);
        vm.selectFork(chainAForkID);
        vm.startPrank(sphaA);
        tokenA.approve(address(gameA), type(uint256).max);
        vm.expectRevert(InvalidPeriod.selector);
        gameA.play(periodInDays);
        vm.stopPrank();
    }
    function test_Play_InsufficientBalance(
        uint64 periodInDays
    ) public whenPlayerHasZeroBalance(sphaA, tokenA, chainAForkID) {
        vm.assume(periodInDays >= 86400);
        vm.selectFork(chainAForkID);
        vm.startPrank(sphaA);
        tokenA.approve(address(gameA), type(uint256).max);
        vm.expectRevert();
        gameA.play(periodInDays);
        vm.stopPrank();
    }

    function test_freePlayChainA_AlreadyClaimed() public {
        vm.selectFork(chainAForkID);
        vm.startPrank(sphaA);
        gameA.freePlay();
        Player memory player = gameA.getPlayer(sphaA);
        vm.expectRevert(FreePlayAlreadyClaimed.selector);
        gameA.freePlay();
        vm.stopPrank();
    }
    function test_freePlayChainA_BlackListed() public {
        vm.selectFork(chainAForkID);
        vm.startPrank(ownerA);
        gameA.blackListPlayer(sphaA);
        vm.stopPrank();
        vm.startPrank(sphaA);
        vm.expectRevert(BlackListedPlayer.selector);
        gameA.freePlay();
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
