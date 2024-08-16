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
        // Initialize RPC URLs
        CHAINA_RPC = vm.envString("ETHEREUM_SEPOLIA_RPC_URL");
        CHAINB_RPC = vm.envString("ARBITRUM_SEPOLIA_RPC_URL");

        // Create and select forks for both chains
        chainAForkID = vm.createSelectFork(CHAINA_RPC);
        chainBForkID = vm.createFork(CHAINB_RPC);

        // Initialize CCIP local simulator fork
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));
        // Create prize pool
        _createPrizePool();
        // Set up Chain A
        setupChain(chainAForkID, "A");
        // Set up Chain B
        setupChain(chainBForkID, "B");

        // Fund games with LINK from the faucet
        fundGameWithLink(chainAForkID, address(gameA), ownerA);
        fundGameWithLink(chainBForkID, address(gameB), ownerB);
    }
    modifier whenPlayerHasZeroBalance(
        address player,
        Token token,
        uint256 chainForkID
    ) {
        vm.selectFork(chainForkID);
        vm.startPrank(player);
        token.approve(address(this), type(uint256).max);
        token.transfer(address(this), token.balanceOf(player));
        vm.stopPrank();
        _;
    }
    function setupChain(
        uint256 chainForkID,
        string memory chainLabel
    ) internal {
        vm.selectFork(chainForkID);
        (
            address spha,
            address mike,
            address owner,
            uint256 sphaPK,
            uint256 mikePK,
            uint256 ownerPK
        ) = createUsers(chainLabel);

        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork
            .getNetworkDetails(block.chainid);
        vm.startPrank(owner);

        // Set up VRF
        VRFCoordinatorV2Mock vrfMockCoordinator = new VRFCoordinatorV2Mock(
            BASEFEE,
            GASPRICELINK
        );
        uint64 subscriptionID = vrfMockCoordinator.createSubscription();
        VRFConsumerMod vrfConsumer = new VRFConsumerMod(
            subscriptionID,
            prizePool.length + 5,
            address(vrfMockCoordinator)
        );
        vrfMockCoordinator.fundSubscription(subscriptionID, 10000000 ether);
        vrfMockCoordinator.addConsumer(subscriptionID, address(vrfConsumer));

        // Set up Controller
        Controller controller = new Controller();

        // Set up Game
        Game game = new Game(
            address(networkDetails.routerAddress),
            address(networkDetails.linkAddress)
        );

        // Set up GameAttestation
        GameAttestation gameAttestation = new GameAttestation();

        // Set up Sign Protocol
        SP signProtocol = new SP();

        // Set up Token and NFT
        Token token = new Token("PlayToken", "PT");
        NFT nft = new NFT("PlayNFT", "PNFT");

        // Set up Sablier
        SablierV2Comptroller sablierV2Comptroller = new SablierV2Comptroller(
            owner
        );
        SablierV2NFTDescriptor sablierV2NFTDescriptor = new SablierV2NFTDescriptor();
        {
            SablierV2LockupLinear lockupLinear = new SablierV2LockupLinear(
                owner,
                sablierV2Comptroller,
                sablierV2NFTDescriptor
            );
            StreamCreator streamCreator = new StreamCreator(
                lockupLinear,
                address(token)
            );

            // Initialize game
            game.initialise(
                token,
                gameAttestation,
                nft,
                streamCreator,
                address(vrfConsumer),
                networkDetails.chainSelector
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
            controller.grantRole(
                controller.OWNER_ROLE(),
                address(streamCreator)
            );

            // Set up GameAttestation
            gameAttestation.setSPInstance(address(signProtocol));
            gameAttestation.registerSchema(
                Schema({
                    hook: ISPHook(address(0)), // No hook for now
                    revocable: true,
                    registrant: address(gameAttestation),
                    maxValidFor: 7 days,
                    timestamp: uint64(block.timestamp),
                    data: "{"
                    '"name":"No name Game Play Token",'
                    '"description":"Schema for Play token",'
                    '"data":[]'
                    "}",
                    dataLocation: DataLocation.ONCHAIN
                })
            );

            game.setPrizePool(prizePool);
            game.setPlayCost(COST_TO_PLAY);

            // Mint tokens
            _faucetMint(address(token), owner, spha, 1000000000000 ether);
            _faucetMint(address(token), owner, mike, 1000000000000 ether);
            _faucetMint(address(token), owner, owner, 1000000000000 ether);
            _faucetMint(
                address(token),
                owner,
                address(game),
                10000000000000000 ether
            );

            // Approve tokens for game
            token.approve(address(game), type(uint256).max);

            // Assign variables for Chain A or Chain B
            if (keccak256(abi.encodePacked(chainLabel)) == keccak256("A")) {
                sphaA = spha;
                mikeA = mike;
                ownerA = owner;
                sphaPKA = sphaPK;
                mikePKA = mikePK;
                ownerPKA = ownerPK;
                chainANetworkDetails = networkDetails;
                vrfMockCoordinatorA = vrfMockCoordinator;
                SUBSCRIPTION_IDA = subscriptionID;
                vrfConsumerA = vrfConsumer;
                controllerA = controller;
                gameA = game;
                gameAttestationA = gameAttestation;
                signProtocolA = signProtocol;
                tokenA = token;
                nftA = nft;
                lockupLinearA = lockupLinear;
                streamCreatorA = streamCreator;
            } else {
                sphaB = spha;
                mikeB = mike;
                ownerB = owner;
                sphaPKB = sphaPK;
                mikePKB = mikePK;
                ownerPKB = ownerPK;
                chainBNetworkDetails = networkDetails;
                vrfMockCoordinatorB = vrfMockCoordinator;
                SUBSCRIPTION_IDB = subscriptionID;
                vrfConsumerB = vrfConsumer;
                controllerB = controller;
                gameB = game;
                gameAttestationB = gameAttestation;
                signProtocolB = signProtocol;
                tokenB = token;
                nftB = nft;
                sablierV2NFTDescriptorB = sablierV2NFTDescriptor;
                lockupLinearB = lockupLinear;
                streamCreatorB = streamCreator;
            }

            vm.stopPrank();
        }
    }

    function createUsers(
        string memory chainLabel
    ) internal returns (address, address, address, uint256, uint256, uint256) {
        (address spha, uint256 sphaPK) = _createUser(
            string(abi.encodePacked("sphaCHAIN", chainLabel))
        );
        (address mike, uint256 mikePK) = _createUser(
            string(abi.encodePacked("mikeCHAIN", chainLabel))
        );
        (address owner, uint256 ownerPK) = _createUser(
            string(abi.encodePacked("ownerCHAIN", chainLabel))
        );
        return (spha, mike, owner, sphaPK, mikePK, ownerPK);
    }

    function fundGameWithLink(
        uint256 chainForkID,
        address gameAddress,
        address owner
    ) internal {
        vm.selectFork(chainForkID);
        vm.startPrank(owner);
        ccipLocalSimulatorFork.requestLinkFromFaucet(gameAddress, 5 ether);
        vm.stopPrank();
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

    function _createPrizePool() internal {
        for (uint256 i = 0; i < 4; i++) {
            prizePool.push(PoolPrize({prizeType: Prize.NFT, amount: 1}));
        }
        for (uint256 i = 0; i < 4; i++) {
            prizePool.push(
                PoolPrize({prizeType: Prize.Token, amount: 5 ether})
            );
        }
        for (uint256 i = 0; i < 4; i++) {
            prizePool.push(
                PoolPrize({prizeType: Prize.Sablier, amount: 10 ether})
            );
        }
    }
}
