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

contract Game is
    IGame,
    IResourceController,
    OwnableUpgradeable,
    UUPSUpgradeable,
    CCIPReceiver,
    ReentrancyGuardUpgradeable
{
    using ECDSA for bytes32;
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
    mapping(address player => bool claimed) freePlays;
    mapping(address user => Player player) public playTokens;
    mapping(address user => bool blackListed) public blackList;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address router_, address link_) CCIPReceiver(router_) {
        router = router_;
        link = link_;
    }

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
    event TestSablier(uint256 indexed sablierAmount);
    function submitScore(
        uint256[] memory userScores,
        bytes calldata signature,
        uint256[] memory sablierWins,
        uint256[] memory nftWins,
        uint256[] memory tokenWins
    ) public override canPlayGame canPlayGame notBlackListed nonReentrant {
        bytes32 messageHash = keccak256(
            abi.encodePacked(userScores, owner(), block.chainid)
        );
        bytes32 message = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address recoveredAddress = ECDSA.recover(message, signature);
        if (recoveredAddress != owner()) {
            revert InvalidClientSignature();
        }
        if (userScores.length > 10) {
            revert TopTenOnly();
        }
        if (
            (sablierWins.length + nftWins.length + tokenWins.length) > 12 ||
            sablierWins.length > 12 ||
            nftWins.length > 12 ||
            tokenWins.length > 12
        ) {
            revert MaxTwelveWinnings();
        }
        crosschainScores = new uint256[](userScores.length);
        uint256 i;
        for (; i < userScores.length; i++) {
            crosschainScores[i] = userScores[i];
        }
        i = 0;
        for (; i < nftWins.length; i++) {
            if (gamePrizes[nftWins[i]].prizeType == Prize.NFT) {
                nft.mint(msg.sender);
            }
        }
        uint256 totalTokens;
        i = 0;
        for (; i < sablierWins.length; i++) {
            if (gamePrizes[sablierWins[i]].prizeType == Prize.Sablier) {
                totalTokens += gamePrizes[sablierWins[i]].amount;
                emit TestSablier(gamePrizes[sablierWins[i]].amount);
            }
        }
        if (totalTokens > 0) {
            streamCreator.createLockupLinearStream(
                msg.sender,
                totalTokens,
                uint40(block.timestamp + 30 days),
                uint40(block.timestamp + 2 minutes),
                uint40(block.timestamp + 1 minutes)
            );
        }

        totalTokens = 0;
        i = 0;
        for (; i < tokenWins.length; i++) {
            if (gamePrizes[tokenWins[i]].prizeType == Prize.Sablier) {
                totalTokens += gamePrizes[tokenWins[i]].amount;
            }
        }
        if (totalTokens > 0) {
            playToken.transfer(msg.sender, totalTokens);
        }
    }
    /// @inheritdoc IGame
    function getWinnings(
        uint16 totalCollected
    ) public override returns (uint256[] memory items) {
        uint256 requestId = vrfConsumer.requestRandomNumbers();
        uint256[] memory wins = new uint256[](totalCollected);
        for (uint256 i = 0; i < totalCollected; i++) {
            (bool fullfilled, bool exists, uint256 randomWord) = vrfConsumer
                .randomNumbersRequests(requestId);
            if (fullfilled && exists) {
                wins[i] = randomWord;
            }
        }
        items = wins;
    }

    /// @inheritdoc IGame
    function play()
        public
        override
        canPlayGame
        canPlayGame
        notBlackListed
        returns (bool ok)
    {
        Player storage player = playTokens[msg.sender];
        Attestation memory attestation = playTokenAttestor
            .spInstance()
            .getAttestation(player.token);
        bool pay = true;
        if (
            player.player != address(0) &&
            attestation.validUntil >= block.timestamp
        ) {
            pay = false;
            ok = true;
        }
        bool success = playToken.transferFrom(
            msg.sender,
            address(this),
            playCost
        );
        if (pay && !success) {
            revert InsufficientBalance();
        }

        if (pay && success) {
            uint64 tokenId = _createPlayToken(3600);
            player.player = msg.sender;
            player.token = tokenId;
        }
        emit PaidPlay(msg.sender, playCost);
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
        uint64 tokenId = _createPlayToken(1800);
        player.player = msg.sender;
        player.token = tokenId;
        freePlays[msg.sender] = true;
        emit FreePlay(msg.sender, playCost);
    }
    function crossChainPlay(
        GameMessage memory message,
        uint64 destinationChainSelector
    ) public override returns (bytes32 messageId) {
        if (msg.sender != address(this)) {
            message.validUntil = 0;
            message.validToken = false;
        }

        Client.EVM2AnyMessage memory message_ = Client.EVM2AnyMessage({
            receiver: abi.encode(message.reciever),
            data: abi.encode(message),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 500_000})
            ),
            feeToken: link
        });

        uint256 fee = IRouterClient(router).getFee(
            destinationChainSelector,
            message_
        );

        IERC20(link).approve(address(router), fee + 1 ether);

        messageId = IRouterClient(router).ccipSend(
            destinationChainSelector,
            message_
        );
        emit MessageSent(
            messageId,
            destinationChainSelector,
            message.reciever,
            message,
            fee
        );
    }

    function getPlayer(
        address player_
    ) external view override returns (Player memory player) {
        return playTokens[player_];
    }

    function getPrizePool()
        public
        view
        override
        returns (PoolPrize[] memory pool)
    {
        return gamePrizes;
    }
    function scores() external view returns (uint256[] memory) {
        return crosschainScores;
    }
    /// @inheritdoc IGame
    function setPrizePool(
        PoolPrize[] memory prizes
    ) public onlyOwner prizesNotSet {
        if (prizes.length > 12) {
            revert MaxTwelvePrizePool();
        }

        uint256 i;
        uint256 length = prizes.length;
        for (; i < length; i++) {
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
    function _createPlayToken(
        uint64 validUntil
    ) internal returns (uint64 tokenId) {
        bytes[] memory recipients;
        tokenId = playTokenAttestor.attestGamePlay(
            IGameAttestation.GamePlayAttestion({
                user: msg.sender,
                game: address(this),
                cost: playCost,
                recipients: recipients,
                validUntil: validUntil
            })
        );
    }
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        GameMessage memory message = abi.decode(
            any2EvmMessage.data,
            (GameMessage)
        );
        if (message.reciever != address(this)) {
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
            message.reciever = abi.decode(any2EvmMessage.sender, (address));
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

        uint64 tokenId = _createPlayToken(message.validUntil);
        player.token = tokenId;

        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address)),
            message
        );
    }
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
