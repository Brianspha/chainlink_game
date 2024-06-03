// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity >=0.8.7;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {VRFConsumerBaseV2} from "@chainlink/contracts@0.8.0/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts@0.8.0/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {Controller} from "../utils/Controller.sol";
import {IResourceController} from "../utils/IResourceController.sol";
/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
 */

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

contract VRFConsumerMod is VRFConsumerBaseV2, IResourceController,Ownable {
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    error RequestNotFound();
    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256 randomWord;
    }
    mapping(uint256 => RequestStatus)
        public randomNumbersRequests; /* requestId --> requestStatus */
    VRFCoordinatorV2InterfaceMod COORDINATOR;
    Controller public controller;
    // Your subscription ID.
    uint64 s_subscriptionId;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 1 random value in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 1;
    uint256 public immutable maxNumber;
    /**
     * HARDCODED FOR SEPOLIA
     * COORDINATOR: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
     */
    constructor(
        uint64 subscriptionId,
        uint256 maxNum,
        address vrfCoordinator
    ) VRFConsumerBaseV2(vrfCoordinator) Ownable(msg.sender) {
        COORDINATOR = VRFCoordinatorV2InterfaceMod(vrfCoordinator);
        s_subscriptionId = subscriptionId;
        maxNumber = maxNum;
    }

    // Assumes the subscription is funded sufficiently.
    function requestRandomNumbers() external returns (uint256 requestId) {
        require(
            controller.hasRole(controller.OWNER_ROLE(), msg.sender) ||
                msg.sender == owner()
        );
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        randomNumbersRequests[requestId] = RequestStatus({
            randomWord: 0,
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        COORDINATOR.fulfillRandomWords(requestId, address(this));
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        if (!randomNumbersRequests[_requestId].exists) {
            revert RequestNotFound();
        }
        randomNumbersRequests[_requestId].fulfilled = true;
        randomNumbersRequests[_requestId].randomWord =
            (_randomWords[0] % maxNumber) +
            2;
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256 randomWords) {
        require(randomNumbersRequests[_requestId].exists, "request not found");
        RequestStatus memory request = randomNumbersRequests[_requestId];
        return (request.fulfilled, request.randomWord);
    }
    /// @inheritdoc IResourceController
    function setController(address controllerAdd) public override onlyOwner {
        emit ControllerUpdated(address(controller), controllerAdd);
        controller = Controller(controllerAdd);
    }
}

interface VRFCoordinatorV2InterfaceMod is VRFCoordinatorV2Interface {
    function fulfillRandomWords(uint256 requestId, address consumer) external;
}
