// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {JsonDeploymentHandler} from "./JsonDeploymentHandler.sol";
import {NFT} from "../src/nft/NFT.sol";
import {Token} from "../src/tokens/Token.sol";
import {GameAttestation, IGameAttestation} from "../src/sign/GameAttestation.sol";
import {Attestation} from "@ethsign/sign-protocol-evm/src/models/Attestation.sol";
import {Schema, ISPHook} from "@ethsign/sign-protocol-evm/src/models/Schema.sol";
import {SP} from "@ethsign/sign-protocol-evm/src/core/SP.sol";
import {JsonDeploymentHandler} from "./JsonDeploymentHandler.sol";
import {DataLocation} from "@ethsign/sign-protocol-evm/src/models/DataLocation.sol";
import {Game, IGame} from "../src/game/Game.sol";
import {GameUtils} from "../src/utils/GameUtils.sol";
import {VRFConsumerMod} from "../src/chainlink/VRFConsumerMod.sol";
import {VRFCoordinatorV2Mock} from "../src/chainlink/VRFCoordinatorV2Mock.sol";
import {StreamCreator} from "../src/sablier/StreamCreator.sol";
import {Controller} from "../src/utils/Controller.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {CCIPLocalSimulator, IRouterClient, LinkToken} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {SablierV2LockupLinear} from "@sablier/v2-core/src/SablierV2LockupLinear.sol";
import {SablierV2Comptroller} from "@sablier/v2-core/src/SablierV2Comptroller.sol";
import {SablierV2NFTDescriptor} from "@sablier/v2-core/src/SablierV2NFTDescriptor.sol";
import {ISablierV2LockupLinear} from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";

contract GameDeployerScript is Script, GameUtils, JsonDeploymentHandler {
    SablierV2LockupLinear public lockupLinear;
    SablierV2NFTDescriptor public sablierV2NFTDescriptor;
    VRFCoordinatorV2Mock public vrfMockCoordinator;
    VRFConsumerMod public vrfConsumer;
    GameAttestation public gameAttestation;
    StreamCreator public streamCreator;
    NFT public nft;
    SP public signProtocol;
    Token public token;
    Controller public controller;
    CCIPLocalSimulator public ccipLocalSimulator;
    Game public game;
    uint256 public chainAForkID;
    uint64 public SUBSCRIPTION_ID;
    uint96 public immutable BASEFEE = 100000000000000000;
    uint96 public immutable GASPRICELINK = 1000000000;
    uint256 public constant COST_TO_PLAY = 5 ether;
    address public spha;
    address public mike;
    address public owner;
    uint64 public chainSelector;
    IRouterClient public sourceRouter;
    IRouterClient public destinationRouter;
    LinkToken public linkToken;
    PoolPrize[] public prizePool;
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    Register.NetworkDetails public chainNetworkDetails;
    Register.NetworkDetails chainBNetworkDetails;

    constructor() JsonDeploymentHandler("main") {}
    function setUp() public virtual {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        // Create prize pool
        _createPrizePool();
        // Set up Chain A
        owner = vm.addr(deployerPrivateKey);
        vm.label(owner, "Owner");
        setupChain();
        _postdeploy("SablierV2LockupLinear", address(lockupLinear));
        _postdeploy("SablierV2NFTDescriptor", address(sablierV2NFTDescriptor));
        _postdeploy("VRFCoordinatorV2Mock", address(vrfMockCoordinator));
        _postdeploy("VRFConsumerMod", address(vrfConsumer));
        _postdeploy("GameAttestation", address(gameAttestation));
        _postdeploy("StreamCreator", address(streamCreator));
        _postdeploy("NFT", address(nft));
        _postdeploy("SP", address(signProtocol));
        _postdeploy("Token", address(token));
        _postdeploy("Controller", address(controller));
        _postdeploy("Game", address(game));
        _writeDeployment(false, "./deploy-out/deploymentSepolia.json");
    }

    function setupChain() internal {
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(11155111);

        // Set up VRF
        vrfMockCoordinator = new VRFCoordinatorV2Mock(BASEFEE, GASPRICELINK);
        uint64 subscriptionID = vrfMockCoordinator.createSubscription();
        vrfConsumer = new VRFConsumerMod(subscriptionID, prizePool.length + 5, address(vrfMockCoordinator));
        vrfMockCoordinator.fundSubscription(subscriptionID, 10000 ether);
        vrfMockCoordinator.addConsumer(subscriptionID, address(vrfConsumer));

        // Set up Controller
        controller = new Controller();

        // Set up Game
        game = new Game(address(networkDetails.routerAddress), address(networkDetails.linkAddress));

        // Set up GameAttestation
        gameAttestation = new GameAttestation();

        // Set up Sign Protocol
        signProtocol = new SP();

        // Set up Token and NFT
        token = new Token("PlayToken", "PT");
        nft = new NFT("PlayNFT", "PNFT");

        // Set up Sablier
        SablierV2Comptroller sablierV2Comptroller = new SablierV2Comptroller(owner);
        sablierV2NFTDescriptor = new SablierV2NFTDescriptor();
        {
            lockupLinear = new SablierV2LockupLinear(owner, sablierV2Comptroller, sablierV2NFTDescriptor);
            streamCreator = new StreamCreator(lockupLinear, address(token));

            // Initialize game
            game.initialise(
                token, gameAttestation, nft, streamCreator, address(vrfConsumer), networkDetails.chainSelector
            );

            // Set controllers
            vrfConsumer.setController(address(controller));
            game.setController(address(controller));
            token.setController(address(controller));
            nft.setController(address(controller));
            streamCreator.setController(address(controller));
            gameAttestation.setController(address(controller));

            // Grant roles
            controller.grantRole(controller.OWNER_ROLE(), address(game));
            controller.grantRole(controller.OWNER_ROLE(), address(nft));
            controller.grantRole(controller.OWNER_ROLE(), address(token));
            controller.grantRole(controller.OWNER_ROLE(), address(streamCreator));

            // Set up GameAttestation
            gameAttestation.setSPInstance(address(signProtocol));
            gameAttestation.registerSchema(
                Schema({
                    hook: ISPHook(address(0)), // No hook for now
                    revocable: true,
                    registrant: address(gameAttestation),
                    maxValidFor: 7 days,
                    timestamp: uint64(block.timestamp),
                    data: "{" '"name":"No name Game Play Token",' '"description":"Schema for Play token",' '"data":[]' "}",
                    dataLocation: DataLocation.ONCHAIN
                })
            );

            game.setPrizePool(prizePool);
            game.setPlayCost(COST_TO_PLAY);

            // Mint tokens
            _faucetMint(address(token), owner, 11000000000000 ether);
            _faucetMint(address(token), address(game), 10000000000000000 ether);

            // Approve tokens for game
            token.approve(address(game), type(uint256).max);
            chainNetworkDetails = networkDetails;
            SUBSCRIPTION_ID = subscriptionID;
        }
    }

    function _createPrizePool() internal {
        for (uint256 i = 0; i < 4; i++) {
            prizePool.push(PoolPrize({prizeType: Prize.NFT, amount: 1}));
        }
        for (uint256 i = 0; i < 4; i++) {
            prizePool.push(PoolPrize({prizeType: Prize.Token, amount: 5 ether}));
        }
        for (uint256 i = 0; i < 4; i++) {
            prizePool.push(PoolPrize({prizeType: Prize.Sablier, amount: 10 ether}));
        }
    }

    function _faucetMint(address tokenAddress, address to, uint256 amount) internal {
        Token(tokenAddress).mint(to, amount);
    }

    function _postdeploy(string memory contractKey, address newAddress) private {
        _writeAddress(contractKey, newAddress);
        console2.log(string.concat(contractKey, " deployed to:"), newAddress);
    }
}
