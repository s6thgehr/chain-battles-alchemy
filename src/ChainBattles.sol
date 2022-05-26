// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "openzeppelin-contracts/contracts/utils/Counters.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/utils/Base64.sol";
import "chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

// Example Contract Address on Polygon Mumbai: 0xd8cbd670490fd1680b2947f2ae5e18ba81b4bc68
// Transaction hash: 0xf23dcb595c3c0429f288b17b4edab0180c05922cc11fd7172f3a9b567b991713

// Verification on Polygonscan:
// GUID: yxhm4lr8egqnab5uhbjnu8ik6asbtkkuyvnt1bqsejeuie6xws
// URL: https://mumbai.polygonscan.com/address/0xd8cbd670490fd1680b2947f2ae5e18ba81b4bc68#code

contract ChainBattles is ERC721URIStorage, VRFConsumerBaseV2 {
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct Properties {
        uint256 level;
        uint256 speed;
        uint256 strength;
        uint256 life;
    }

    mapping(uint256 => Properties) public tokenIdToProperties;

    // Chainlink VRF
    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // Mumbai coordinator. For other networks,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    address vrfCoordinator = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 keyHash =
        0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 3;

    address s_owner;

    mapping(uint256 => address) requestIdToSender;

    constructor(uint64 subscriptionId)
        ERC721("Chain Battles", "CBTLS")
        VRFConsumerBaseV2(vrfCoordinator)
    {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
    }

    function generateCharacter(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350">',
            "<style>.base { fill: white; font-family: serif; font-size: 14px; }</style>",
            '<rect width="100%" height="100%" fill="black" />',
            '<text x="50%" y="40%" class="base" dominant-baseline="middle" text-anchor="middle">',
            "Warrior",
            "</text>",
            '<text x="50%" y="50%" class="base" dominant-baseline="middle" text-anchor="middle">',
            "Levels: ",
            getLevels(tokenId),
            "</text>",
            "</svg>"
        );
        return
            string(
                abi.encodePacked(
                    "data:image/svg+xml;base64,",
                    Base64.encode(svg)
                )
            );
    }

    function getLevels(uint256 tokenId) public view returns (string memory) {
        Properties memory property = tokenIdToProperties[tokenId];
        return property.level.toString();
    }

    function getTokenURI(uint256 tokenId) public view returns (string memory) {
        bytes memory dataURI = abi.encodePacked(
            "{",
            '"name": "Chain Battles #',
            tokenId.toString(),
            '",',
            '"description": "Battles on chain",',
            '"image": "',
            generateCharacter(tokenId),
            '",',
            '"attributes": [',
            "{",
            '"display_type": "number",',
            '"train_type": "Speed",',
            '"value": "',
            tokenIdToProperties[tokenId].speed.toString(),
            '"',
            "},",
            "{",
            '"display_type": "number",',
            '"train_type": "Strength",',
            '"value": "',
            tokenIdToProperties[tokenId].strength.toString(),
            '"',
            "},",
            "{",
            '"display_type": "number",',
            '"train_type": "Life",',
            '"value": "',
            tokenIdToProperties[tokenId].life.toString(),
            '"',
            "}",
            "]",
            "}"
        );
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(dataURI)
                )
            );
    }

    function mint() public {
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        requestIdToSender[requestId] = msg.sender;
    }

    // It would be better to save random words and use another function to perform the logic like minting etc.
    // See Chainlink docs security considerations
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        uint256 _speed = 10 + (randomWords[0] % 5);
        uint256 _strength = 10 + (randomWords[1] % 5);
        uint256 _life = 10 + (randomWords[2] % 5);

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        address owner = requestIdToSender[requestId];
        _safeMint(owner, newItemId);

        tokenIdToProperties[newItemId] = Properties({
            level: 0,
            speed: _speed,
            strength: _strength,
            life: _life
        });
        _setTokenURI(newItemId, getTokenURI(newItemId));
    }

    function train(uint256 tokenId) public {
        require(_exists(tokenId), "This tokenId does not exists.");
        require(
            msg.sender == ownerOf(tokenId),
            "You must own this NFT to train it."
        );
        tokenIdToProperties[tokenId].level += 1;
        tokenIdToProperties[tokenId].speed += 1;
        tokenIdToProperties[tokenId].strength += 1;
        tokenIdToProperties[tokenId].life += 1;
        _setTokenURI(tokenId, getTokenURI(tokenId));
    }
}
