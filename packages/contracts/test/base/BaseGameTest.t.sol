// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SP} from "@ethsign/sign-protocol-evm/src/core/SP.sol";
import {Attestation} from "@ethsign/sign-protocol-evm/src/models/Attestation.sol";
import {Schema, ISPHook} from "@ethsign/sign-protocol-evm/src/models/Schema.sol";
import {DataLocation} from "@ethsign/sign-protocol-evm/src/models/DataLocation.sol";
import {Game, IGame} from "../../src/game/Game.sol";
import {GameUtils} from "../../src/utils/GameUtils.sol";
import {GameAttestation, IGameAttestation} from "../../src/sign/GameAttestation.sol";
import {NFT} from "../..//src/nft/NFT.sol";
import {Token} from "../../src/tokens/Token.sol";
import {VRFConsumerMod} from "../../src/chainlink/VRFConsumerMod.sol";
import {VRFCoordinatorV2Mock} from "../../src/chainlink/VRFCoordinatorV2Mock.sol";
import {StreamCreator} from "../../src/sablier/StreamCreator.sol";
import {Controller} from "../../src/utils/Controller.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {CCIPLocalSimulator, IRouterClient, LinkToken} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {SablierV2LockupLinear} from "@sablier/v2-core/src/SablierV2LockupLinear.sol";
import {SablierV2Comptroller} from "@sablier/v2-core/src/SablierV2Comptroller.sol";
import {SablierV2NFTDescriptor} from "@sablier/v2-core/src/SablierV2NFTDescriptor.sol";
import {ISablierV2LockupLinear} from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import "forge-std/Test.sol";
abstract contract BaseGameTest is Test, GameUtils {
    SablierV2LockupLinear public lockupLinearA;
    SablierV2LockupLinear public lockupLinearB;
    SablierV2NFTDescriptor public sablierV2NFTDescriptorA;
    SablierV2NFTDescriptor public sablierV2NFTDescriptorB;
    VRFCoordinatorV2Mock public vrfMockCoordinatorA;
    VRFCoordinatorV2Mock public vrfMockCoordinatorB;
    VRFConsumerMod public vrfConsumerA;
    VRFConsumerMod public vrfConsumerB;
    GameAttestation public gameAttestationA;
    GameAttestation public gameAttestationB;
    StreamCreator public streamCreatorA;
    StreamCreator public streamCreatorB;
    NFT public nftA;
    NFT public nftB;
    SP public signProtocolA;
    SP public signProtocolB;
    Token public tokenA;
    Token public tokenB;
    Controller public controllerA;
    Controller public controllerB;
    CCIPLocalSimulator public ccipLocalSimulator;
    Game public gameA;
    Game public gameB;
    uint256 public chainAForkID;
    uint256 public chainBForkID;
    uint64 public SUBSCRIPTION_IDA;
    uint64 public SUBSCRIPTION_IDB;
    uint96 public immutable BASEFEE = 100000000000000000;
    uint96 public immutable GASPRICELINK = 1000000000;
    uint256 public constant COST_TO_PLAY = 5 ether;
    string public CHAINA_RPC = "";
    string public CHAINB_RPC = "";
    address public sphaA;
    address public mikeA;
    address public ownerA;
    uint256 public sphaPKA;
    uint256 public mikePKA;
    uint256 public ownerPKA;
    address public sphaB;
    address public mikeB;
    address public ownerB;
    uint256 public sphaPKB;
    uint256 public mikePKB;
    uint256 public ownerPKB;
    uint64 public chainSelector;
    IRouterClient public sourceRouter;
    IRouterClient public destinationRouter;
    LinkToken public linkToken;
    PoolPrize[] public prizePool;
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    Register.NetworkDetails public chainANetworkDetails;
    Register.NetworkDetails chainBNetworkDetails;
    function setUp() public virtual {
        CHAINA_RPC = vm.envString("ETHEREUM_SEPOLIA_RPC_URL");
        CHAINB_RPC = vm.envString("ARBITRUM_SEPOLIA_RPC_URL");
        chainAForkID = vm.createSelectFork(CHAINA_RPC, 6028236);
        chainBForkID = vm.createFork(CHAINB_RPC, 50643503);
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));
        vm.selectFork(chainAForkID);
        (sphaA, sphaPKA) = _createUser("sphaCHAINA");
        (mikeA, mikePKA) = _createUser("mikeCHAINA");
        (ownerA, ownerPKA) = _createUser("ownerCHAINA");
        chainANetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        vm.startPrank(ownerA);
        vrfMockCoordinatorA = new VRFCoordinatorV2Mock(BASEFEE, GASPRICELINK);
        SUBSCRIPTION_IDA = vrfMockCoordinatorA.createSubscription();
        vrfConsumerA = new VRFConsumerMod(
            SUBSCRIPTION_IDA,
            10000,
            address(vrfMockCoordinatorA)
        );
        vrfMockCoordinatorA.fundSubscription(
            SUBSCRIPTION_IDA,
            1000000000000000000
        );
        controllerA = new Controller();
        gameA = new Game(
            address(chainANetworkDetails.routerAddress),
            address(chainANetworkDetails.linkAddress)
        );

        gameAttestationA = new GameAttestation();
        signProtocolA = new SP();
        tokenA = new Token("PlayToken", "PT");
        nftA = new NFT("PlayNFT", "PNFT");
        gameAttestationA.setController(address(controllerA));
        SablierV2Comptroller sablierV2ComptrollerA = new SablierV2Comptroller(
            ownerA
        );
        sablierV2NFTDescriptorA = new SablierV2NFTDescriptor();
        lockupLinearA = new SablierV2LockupLinear(
            ownerA,
            sablierV2ComptrollerA,
            sablierV2NFTDescriptorA
        );
        streamCreatorA = new StreamCreator(lockupLinearA, address(tokenA));
        gameA.initialise(
            tokenA,
            gameAttestationA,
            nftA,
            streamCreatorA,
            address(vrfConsumerA),
            chainANetworkDetails.chainSelector
        );
        gameA.setController(address(controllerA));
        tokenA.setController(address(controllerA));
        nftA.setController(address(controllerA));
        streamCreatorA.setController(address(controllerA));
        controllerA.grantRole(controllerA.OWNER_ROLE(), address(gameA));
        controllerA.grantRole(controllerA.OWNER_ROLE(), address(nftA));
        controllerA.grantRole(controllerA.OWNER_ROLE(), address(tokenA));
        controllerA.grantRole(
            controllerA.OWNER_ROLE(),
            address(streamCreatorA)
        );
        gameAttestationA.setSPInstance(address(signProtocolA));
        gameAttestationA.registerSchema(
            Schema({
                hook: ISPHook(address(0)), //@dev no hook for now
                revocable: true,
                registrant: address(gameAttestationA),
                maxValidFor: 7 days,
                timestamp: uint64(block.timestamp),
                data: "{"
                "name"
                ":"
                "No name Game Play Token"
                ","
                "description"
                ":"
                "Schema for Play token"
                ", "
                "data"
                ":"
                "[]"
                "}",
                dataLocation: DataLocation.ONCHAIN
            })
        );
        prizePool.push(PoolPrize({prizeType: Prize.NFT, amount: 1}));
        prizePool.push(PoolPrize({prizeType: Prize.Token, amount: 5 ether}));
        prizePool.push(
            PoolPrize({prizeType: Prize.Sablier, amount: 10 ether})
        );
        controllerA.grantRole(
            controllerA.OWNER_ROLE(),
            address(streamCreatorA)
        );
        gameA.setPrizePool(prizePool);
        gameA.setPlayCost(COST_TO_PLAY);
        _faucetMint(address(tokenA), ownerA, sphaA, 1000000000000 ether);
        _faucetMint(address(tokenA), ownerA, mikeA, 1000000000000 ether);
        _faucetMint(address(tokenA), ownerA, ownerA, 1000000000000 ether);
        _faucetMint(
            address(tokenA),
            ownerA,
            address(gameA),
            10000000000000000 ether
        );
        tokenA.approve(address(gameA), type(uint256).max);
        //Setup B
        vm.selectFork(chainBForkID);
        (sphaB, sphaPKB) = _createUser("sphaCHAINB");
        (mikeB, mikePKB) = _createUser("mikeCHAINB");
        (ownerB, ownerPKB) = _createUser("ownerCHAINB");
        chainBNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        vm.startPrank(ownerB);
        vrfMockCoordinatorB = new VRFCoordinatorV2Mock(BASEFEE, GASPRICELINK);
        SUBSCRIPTION_IDB = vrfMockCoordinatorB.createSubscription();
        vrfConsumerA = new VRFConsumerMod(
            SUBSCRIPTION_IDB,
            10000,
            address(vrfMockCoordinatorB)
        );
        vrfMockCoordinatorB.fundSubscription(
            SUBSCRIPTION_IDB,
            1000000000000000000
        );
        controllerB = new Controller();
        gameB = new Game(
            address(chainBNetworkDetails.routerAddress),
            address(chainBNetworkDetails.linkAddress)
        );

        gameAttestationB = new GameAttestation();
        signProtocolB = new SP();
        tokenB = new Token("PlayToken", "PT");
        nftB = new NFT("PlayNFT", "PNFT");
        gameAttestationB.setController(address(controllerB));
        SablierV2Comptroller sablierV2ComptrollerB = new SablierV2Comptroller(
            ownerB
        );
        sablierV2NFTDescriptorB = new SablierV2NFTDescriptor();
        lockupLinearB = new SablierV2LockupLinear(
            ownerB,
            sablierV2ComptrollerB,
            sablierV2NFTDescriptorB
        );
        streamCreatorB = new StreamCreator(lockupLinearB, address(tokenB));
        streamCreatorB.setController(address(controllerB));
        gameB.initialise(
            tokenB,
            gameAttestationB,
            nftB,
            streamCreatorB,
            address(vrfConsumerB),
            chainBNetworkDetails.chainSelector
        );
        gameB.setController(address(controllerB));
        tokenB.setController(address(controllerB));
        nftB.setController(address(controllerB));
        controllerB.grantRole(controllerB.OWNER_ROLE(), address(gameB));
        controllerB.grantRole(controllerB.OWNER_ROLE(), address(nftB));
        controllerB.grantRole(controllerB.OWNER_ROLE(), address(tokenB));
        controllerB.grantRole(
            controllerB.OWNER_ROLE(),
            address(streamCreatorB)
        );
        controllerB.grantRole(
            controllerB.OWNER_ROLE(),
            address(streamCreatorB)
        );
        gameAttestationB.setSPInstance(address(signProtocolB));
        gameAttestationB.registerSchema(
            Schema({
                hook: ISPHook(address(0)), //@dev no hook for now
                revocable: true,
                registrant: address(gameAttestationB),
                maxValidFor: 7 days,
                timestamp: uint64(block.timestamp),
                data: "{"
                "name"
                ":"
                "No name Game Play Token"
                ","
                "description"
                ":"
                "Schema for Play token"
                ", "
                "data"
                ":"
                "[]"
                "}",
                dataLocation: DataLocation.ONCHAIN
            })
        );
        gameB.setPrizePool(prizePool);
        gameB.setPlayCost(COST_TO_PLAY);
        _faucetMint(address(tokenB), ownerB, sphaB, 1000000000000 ether);
        _faucetMint(address(tokenB), ownerB, mikeB, 1000000000000 ether);
        _faucetMint(address(tokenB), ownerB, ownerB, 1000000000000 ether);
        _faucetMint(
            address(tokenB),
            ownerB,
            address(gameB),
            10000000000000000 ether
        );
        vm.startPrank(ownerB);
        tokenB.approve(address(gameB), type(uint256).max);
        vm.stopPrank();
        vm.selectFork(chainAForkID);
        vm.startPrank(ownerA);
        ccipLocalSimulatorFork.requestLinkFromFaucet(address(gameA), 5 ether);
        vm.selectFork(chainBForkID);
        vm.startPrank(ownerB);
        ccipLocalSimulatorFork.requestLinkFromFaucet(address(gameB), 5 ether);
    }
    function _createUser(
        string memory name
    ) internal returns (address payable, uint256) {
        (address user, uint256 privateKey) = makeAddrAndKey(name);
        vm.deal({account: user, newBalance: 1000 ether});
        vm.label(user, name);
        return (payable(user), privateKey);
    }

    function _createUserWithTokenBalance(
        string memory name,
        Token token
    ) internal returns (address payable, uint256) {
        (address user, uint256 privateKey) = _createUser(name);
        vm.startPrank(user);
        token.mint(user, 10000 ether);
        assertEq(token.balanceOf(user), 10000 ether);
        vm.stopPrank();
        return (payable(user), privateKey);
    }
    function _faucetMint(
        address tokenAddress,
        address admin,
        address to,
        uint256 amount
    ) internal {
        vm.startPrank(admin);
        Token(tokenAddress).mint(to, amount);
        vm.stopPrank();
    }
    function _faucetToken(
        address tokenAddress,
        address whale,
        address to,
        uint256 amount
    ) internal {
        vm.startPrank(whale);
        assert(Token(tokenAddress).balanceOf(whale) > 0);
        Token(tokenAddress).transfer(to, amount);
        vm.stopPrank();
    }
}
