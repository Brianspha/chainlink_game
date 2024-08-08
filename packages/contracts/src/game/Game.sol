// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IGame} from "./IGame.sol";
import {Controller} from "../utils/Controller.sol";
import {IResourceController} from "../utils/IResourceController.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {VRFConsumer} from "../chainlink/VRFConsumer.sol";
import {Token} from "../tokens/Token.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {GameAttestation, IGameAttestation, Attestation, Schema, ISP, DataLocation} from "../sign/GameAttestation.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {StreamCreator} from "../sablier/StreamCreator.sol";
import {NFT} from "../nft/NFT.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title Game Contract
/// @notice This contract manages game logic, including token management, cross-chain functionality, and prize distribution.
/// @dev This contract utilizes UUPS upgradeability, Ownable, CCIPReceiver, and ReentrancyGuard features.
contract Game is
    IGame,
    IResourceController,
    OwnableUpgradeable,
    UUPSUpgradeable,
    CCIPReceiver,
    ReentrancyGuardUpgradeable
{
    using ECDSA for bytes32;
    // Modifiers

    modifier notAlreadyClaimed() virtual {
        if (freePlays[msg.sender]) {
            revert FreePlayAlreadyClaimed();
        }
        _;
    }

    modifier prizesNotSet() virtual {
        if (gamePrizes.length > 0) {
            revert PrizesAlreadySet();
        }
        _;
    }

    modifier notBlackListed() virtual {
        if (blackList[msg.sender]) {
            revert BlackListedPlayer();
        }
        _;
    }

    modifier canPlayGame() {
        if (gamePrizes.length == 0) {
            revert PrizesNotSet();
        }

        _;
    }
    // State variables

    VRFConsumer public vrfConsumer;
    Token public playToken;
    NFT public nft;
    StreamCreator public streamCreator;
    Controller public controller;
    GameAttestation public playTokenAttestor;
    uint256 public playCost;
    address public router;
    address public link;
    uint64 public chainSelector;
    PoolPrize[] public gamePrizes;
    uint256[] public crosschainScores;
    address[] public crosschainUsers;
    mapping(address player => bool claimed) public freePlays;
    mapping(address player => Player playerData) public playTokens;
    mapping(address player => bool blackListed) public blackList;
    mapping(bytes signature => bool used) public usedSignatures;
    /// @custom:oz-upgrades-unsafe-allow constructor

    constructor(address router_, address link_) CCIPReceiver(router_) {
        router = router_;
        link = link_;
    }

    /// @notice Initializes the game contract with necessary dependencies
    /// @param acceptedPlayToken The token accepted for play
    /// @param attestor The attestor for game play tokens
    /// @param nft_ The NFT contract
    /// @param streamCreator_ The stream creator contract
    /// @param vconsumer The VRF consumer contract
    /// @param chainSelector_ The chain selector for cross-chain operations
    function initialise(
        Token acceptedPlayToken,
        GameAttestation attestor,
        NFT nft_,
        StreamCreator streamCreator_,
        address vconsumer,
        uint64 chainSelector_
    ) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        vrfConsumer = VRFConsumer(vconsumer);
        playToken = acceptedPlayToken;
        playTokenAttestor = attestor;
        nft = nft_;
        streamCreator = streamCreator_;
        chainSelector = chainSelector_;
        playToken.approve(address(streamCreator), type(uint256).max);
    }

    /// @inheritdoc IGame
    function submitScore(
        uint256[] memory userScores,
        address[] memory addressScores,
        bytes calldata signature,
        uint256[] memory winnings
    ) public override canPlayGame notBlackListed nonReentrant {
        if (
            userScores.length != addressScores.length || userScores.length == 0
        ) {
            revert ArrayLengthMissmatch();
        }
        if (usedSignatures[signature]) {
            revert UsedSignature();
        }
        bytes32 messageHash = keccak256(
            abi.encodePacked(userScores, msg.sender, block.chainid)
        );
        bytes32 message = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address recoveredAddress = ECDSA.recover(message, signature);
        if (recoveredAddress != owner()) {
            revert InvalidClientSignature();
        }
        if (userScores.length > 10) {
            revert TopTenOnly();
        }
        if (winnings.length > 12) {
            revert MaxTwelveWinnings();
        }
        if (usedSignatures[signature]) {
            revert UsedSignature();
        }

        crosschainScores = new uint256[](userScores.length);
        crosschainUsers = new address[](addressScores.length);
        for (uint256 i = 0; i < userScores.length; i++) {
            crosschainScores[i] = userScores[i];
            crosschainUsers[i] = addressScores[i];
        }

        uint256 totalTokens;
        uint256 totalSablier;
        for (uint256 i = 0; i < winnings.length; i++) {
            if (winnings[i] >= gamePrizes.length) continue;
            if (gamePrizes[winnings[i]].prizeType == Prize.NFT) {
                nft.mint(msg.sender);
            } else if (gamePrizes[winnings[i]].prizeType == Prize.Sablier) {
                totalSablier += gamePrizes[winnings[i]].amount;
            } else if (gamePrizes[winnings[i]].prizeType == Prize.Token) {
                totalTokens += gamePrizes[winnings[i]].amount;
            }
        }

        if (totalSablier > 0) {
            streamCreator.createLockupLinearStream(
                msg.sender,
                totalSablier,
                uint40(block.timestamp + 30 days),
                uint40(block.timestamp + 2 minutes),
                uint40(block.timestamp + 1 minutes)
            );
        }

        if (totalTokens > 0) {
            playToken.transfer(msg.sender, totalTokens);
        }
        usedSignatures[signature] = true;
    }

    /// @inheritdoc IGame
    function getWinnings(
        uint16 totalCollected,
        bytes calldata signature
    ) public override returns (uint256[] memory items) {
        bytes32 messageHash = keccak256(
            abi.encodePacked(msg.sender, block.chainid)
        );
        bytes32 message = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address recoveredAddress = ECDSA.recover(message, signature);
        if (recoveredAddress != owner()) {
            revert InvalidClientSignature();
        }
        uint256 requestId = vrfConsumer.requestRandomNumbers();
        uint256[] memory wins = new uint256[](totalCollected);
        for (uint256 i = 0; i < totalCollected; i++) {
            requestId = vrfConsumer.requestRandomNumbers();
            (bool fullfilled, bool exists, uint256 randomWord) = vrfConsumer
                .randomNumbersRequests(requestId);
            if (fullfilled && exists) {
                wins[i] = randomWord;
            }
        }
        items = wins;
        usedSignatures[signature] = true;
    }

    /// @inheritdoc IGame
    function play()
        public
        override
        canPlayGame
        notBlackListed
        returns (bool ok)
    {
        Player storage player = playTokens[msg.sender];
        Attestation memory attestation = playTokenAttestor
            .spInstance()
            .getAttestation(player.token);
        bool pay = true;
        uint64 tokenId;
        if (
            player.player != address(0) &&
            attestation.validUntil >= block.timestamp
        ) {
            pay = false;
            ok = true;
        }
        bool success;
        if (pay) {
            success = playToken.transferFrom(
                msg.sender,
                address(this),
                playCost
            );
            if (!success) {
                revert InsufficientBalance();
            }
        }

        if (pay && success) {
            tokenId = _createPlayToken(3600, msg.sender);
            player.player = msg.sender;
            player.token = tokenId;
        }
        emit PaidPlay(msg.sender, playCost, tokenId);
    }
    /// @inheritdoc IGame
    function play(
        uint64 periodInDays
    ) public override canPlayGame notBlackListed returns (bool ok) {
        Player storage player = playTokens[msg.sender];
        Attestation memory attestation = playTokenAttestor
            .spInstance()
            .getAttestation(player.token);
        bool pay = true;
        uint64 tokenId;
        if (
            player.player != address(0) &&
            attestation.validUntil >= block.timestamp
        ) {
            pay = false;
            ok = true;
        }
        bool success;
        if (pay) {
            success = playToken.transferFrom(
                msg.sender,
                address(this),
                playCost
            );
            if (!success) {
                revert InsufficientBalance();
            }
        }

        if (pay && success) {
            tokenId = _createPlayToken(periodInDays, msg.sender);
            player.player = msg.sender;
            player.token = tokenId;
        }
        emit PaidPlay(msg.sender, playCost, tokenId);
    }

    /// @inheritdoc IGame
    function freePlay()
        public
        override
        notAlreadyClaimed
        canPlayGame
        notBlackListed
    {
        Player storage player = playTokens[msg.sender];
        uint64 tokenId = _createPlayToken(1800, msg.sender);
        player.player = msg.sender;
        player.token = tokenId;
        freePlays[msg.sender] = true;
        emit FreePlay(msg.sender, playCost, tokenId);
    }

    /// @inheritdoc IGame
    function crossChainPlay(
        GameMessage memory message,
        uint64 destinationChainSelector
    ) public override returns (bytes32 messageId) {
        if (msg.sender != address(this)) {
            message.validUntil = 0;
            message.validToken = false;
        }

        Client.EVM2AnyMessage memory message_ = Client.EVM2AnyMessage({
            receiver: abi.encode(message.receiver),
            data: abi.encode(message),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 500_000})
            ),
            feeToken: link
        });

        uint256 fee = IRouterClient(router).getFee(
            destinationChainSelector,
            message_
        );

        IERC20(link).approve(address(router), fee);

        messageId = IRouterClient(router).ccipSend(
            destinationChainSelector,
            message_
        );
        emit MessageSent(
            messageId,
            destinationChainSelector,
            message.receiver,
            message,
            fee
        );
    }

    /// @inheritdoc IGame
    function getPlayer(
        address player_
    ) external view override returns (Player memory player) {
        return playTokens[player_];
    }

    /// @inheritdoc IGame
    function getPrizePool()
        public
        view
        override
        returns (PoolPrize[] memory pool)
    {
        return gamePrizes;
    }

    /// @return The cross-chain scores and user addresses
    function scores()
        external
        view
        returns (uint256[] memory, address[] memory)
    {
        return (crosschainScores, crosschainUsers);
    }

    /// @inheritdoc IGame
    function setPrizePool(
        PoolPrize[] memory prizes
    ) public onlyOwner prizesNotSet {
        if (prizes.length > 12) {
            revert MaxTwelvePrizePool();
        }

        uint256 length = prizes.length;
        for (uint256 i = 0; i < length; i++) {
            gamePrizes.push(prizes[i]);
        }
        emit GamePrizeSet(prizes);
    }

    /// @inheritdoc IGame
    function blackListPlayer(address player) public override onlyOwner {
        blackList[player] = true;
        emit BlackListed(player);
    }

    /// @inheritdoc IGame
    function whiteListPlayer(address player) public override onlyOwner {
        blackList[player] = false;
        emit WhiteListed(player);
    }

    /// @inheritdoc IResourceController
    function setController(address controllerAdd) public override onlyOwner {
        emit ControllerUpdated(address(controller), controllerAdd);
        controller = Controller(controllerAdd);
    }

    /// @inheritdoc IGame
    function setPlayCost(uint256 cost) public onlyOwner {
        if (cost == 0) {
            revert CostCannotBeZero();
        }
        emit PlayCostUpdate(playCost, cost);
        playCost = cost;
    }

    /// @return tokenId The ID of the created play token
    function _createPlayToken(
        uint64 validUntil,
        address player
    ) internal returns (uint64 tokenId) {
        bytes[] memory recipients;
        tokenId = playTokenAttestor.attestGamePlay(
            IGameAttestation.GamePlayAttestation({
                user: player,
                game: address(this),
                cost: playCost,
                recipients: recipients,
                validUntil: validUntil
            })
        );
    }

    /// @inheritdoc CCIPReceiver
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        GameMessage memory message = abi.decode(
            any2EvmMessage.data,
            (GameMessage)
        );
        if (message.receiver != address(this)) {
            revert NotAllowed();
        }
        Player storage player = playTokens[message.player];
        if (message.messageType == MessageType.Verify) {
            Attestation memory attestation = playTokenAttestor
                .spInstance()
                .getAttestation(player.token);
            if (attestation.validUntil <= block.timestamp) {
                revert PlayTokenExpired();
            }
            message.validToken = true;
            message.validUntil = attestation.validUntil;
            message.messageType = MessageType.Verified;
            message.receiver = abi.decode(any2EvmMessage.sender, (address));
            emit MessageReceived(
                any2EvmMessage.messageId,
                any2EvmMessage.sourceChainSelector,
                abi.decode(any2EvmMessage.sender, (address)),
                message
            );
            crossChainPlay(message, chainSelector);
            return;
        }

        if (message.messageType != MessageType.Verified || message.validToken) {
            revert CrossPlayNotAllowed();
        }
        player = playTokens[message.playerChainB];
        player.player = message.playerChainB;
        uint64 tokenId = _createPlayToken(message.validUntil, player.player);
        player.token = tokenId;

        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address)),
            message
        );
    }

    /// @notice Authorizes the upgrade of the contract
    /// @param newImplementation The address of the new implementation
    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
