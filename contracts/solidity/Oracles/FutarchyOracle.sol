pragma solidity ^0.4.0;
import "Oracles/AbstractOracle.sol";
import "EventFactory/AbstractEventFactory.sol";
import "MarketFactories/AbstractMarketFactory.sol";
import "Tokens/AbstractToken.sol";


/// @title Futarchy oracle contract - Allows resolving an event based on other events.
/// @author Stefan George - <stefan.george@consensys.net>
/// @author Martin Koeppelmann - <martin.koeppelmann@consensys.net>
contract FutarchyOracle is Oracle {

    /*
     *  External contracts
     */
    EventFactory constant eventFactory = EventFactory({{EventFactory}});
    MarketFactory constant marketFactory = MarketFactory({{DefaultMarketFactory}});
    Token constant etherToken = Token({{EtherToken}});
    address constant marketMaker = {{LMSRMarketMaker}};

    /*
     *  Constants
     */
    // Oracle meta data
    string constant public name = "Futarchy Oracle";

    /*
     *  Data structures
     */
    // proposalHash => FutarchyDecision
    mapping (bytes32 => FutarchyDecision) public futarchyDecisions;

    struct FutarchyDecision {
        bytes32 marketHash1;
        bytes32 marketHash2;
        uint decisionTime;
        bool isWinningOutcomeSet;
        int winningOutcome;
    }

    /*
     *  Read and write functions
     */
    // @dev Contract constructor allows market contract to permanently trade event shares.
    function FutarchyOracle() {
        // Give permanent approval to market contract to trade event shares
        eventFactory.permitPermanentApproval(marketFactory);
    }

    /// @dev Creates parent and depended eventFactory and marketFactory for futarchy decision. Returns success.
    /// @param proposalHash Hash identifying proposal description.
    /// @param decisionTime Time when parent event can be resolved.
    /// @param lowerBound Lower bound for valid outcomes for depended eventFactory.
    /// @param upperBound Upper bound for valid outcomes for depended eventFactory..
    /// @param resolverAddress Resolver for depended eventFactory.
    /// @param data Encoded data used to resolve event.
    /// @param initialFunding Initial funding for marketFactory.
    function createFutarchyDecision(bytes32 proposalHash,
                                    uint decisionTime,
                                    int lowerBound,
                                    int upperBound,
                                    address resolverAddress,
                                    bytes32[] data,
                                    uint initialFunding
    )
        public
    {
        macro: $futarchyDecision = futarchyDecisions[proposalHash];
        if ($futarchyDecision.decisionTime > 0 || now >= decisionTime) {
            // Futarchy decision exists already or decision time is in the past
            throw;
        }
        $futarchyDecision.decisionTime = decisionTime;
        // Create parent event traded in Ether
        bytes32[] memory parentData = new bytes32[](1);
        parentData[0] = proposalHash;
        bytes32 parentEventHash = eventFactory.createEvent(proposalHash, false, 0, 0, 2, etherToken, this, parentData);
        if (parentEventHash == 0) {
            // Creation of parent event failed
            throw;
        }
        // Buy all outcomes of parent event to create depended eventFactory
        uint buyAllOutcomesCosts = initialFunding + eventFactory.calcBaseFeeForShares(initialFunding);
        buyAllOutcomesCosts += eventFactory.calcBaseFeeForShares(buyAllOutcomesCosts);
        if (   !etherToken.transferFrom(msg.sender, this, buyAllOutcomesCosts)
            || !etherToken.approve(eventFactory, buyAllOutcomesCosts))
        {
            // Buy all outcomes failed
            throw;
        }
        eventFactory.buyAllOutcomes(parentEventHash, buyAllOutcomesCosts);
        // Create depended eventFactory traded in parent event shares
        bytes32[2] memory dependedEventFactoryHashes = createEventFactory(proposalHash,
                                                                          lowerBound,
                                                                          upperBound,
                                                                          resolverAddress,
                                                                          data,
                                                                          parentEventHash);
        if (dependedEventFactoryHashes[0] == 0 || dependedEventFactoryHashes[1] == 0) {
            // Creation of eventFactory failed
            throw;
        }
        // Create marketFactory based on depended eventFactory
        bytes32[2] memory dependedMarketFactoryHashes = createMarketFactory(dependedEventFactoryHashes, initialFunding);
        if (dependedMarketFactoryHashes[0] == 0 || dependedMarketFactoryHashes[1] == 0) {
            // Creation of marketFactory failed
            throw;
        }
        // Add futarchy decision
        $futarchyDecision.marketHash1 = dependedMarketFactoryHashes[0];
        $futarchyDecision.marketHash2 = dependedMarketFactoryHashes[1];
        $futarchyDecision.decisionTime = decisionTime;
    }

    function createEventFactory(bytes32 proposalHash,
                                int lowerBound,
                                int upperBound,
                                address resolverAddress,
                                bytes32[] data,
                                bytes32 parentEventHash
    )
        private
        returns (bytes32[2] dependedEventFactoryHashes)
    {
        dependedEventFactoryHashes[0] = eventFactory.createEvent(proposalHash,
                                                                 true,
                                                                 lowerBound,
                                                                 upperBound,
                                                                 2,
                                                                 eventFactory.getOutcomeToken(parentEventHash, 0),
                                                                 resolverAddress,
                                                                 data);
        dependedEventFactoryHashes[1] = eventFactory.createEvent(proposalHash,
                                                                 true,
                                                                 lowerBound,
                                                                 upperBound,
                                                                 2,
                                                                 eventFactory.getOutcomeToken(parentEventHash, 1),
                                                                 resolverAddress,
                                                                 data);
    }

    function createMarketFactory(bytes32[2] dependedEventFactoryHashes, uint shareCount)
        private
        returns (bytes32[2] dependedMarketFactoryHashes)
    {
        // MarketFactory have no fee
        dependedMarketFactoryHashes[0] = marketFactory.createMarket(dependedEventFactoryHashes[0],
                                                                    0,
                                                                    shareCount,
                                                                    marketMaker);
        dependedMarketFactoryHashes[1] = marketFactory.createMarket(dependedEventFactoryHashes[1],
                                                                    0,
                                                                    shareCount,
                                                                    marketMaker);
    }

    /// @dev Sets difficulty as winning outcome for a specific block. Returns success.
    /// @param proposalHash Hash identifying proposal description.
    /// @param data Not used.
    function setOutcome(bytes32 proposalHash, bytes32[] data)
        external
    {
        macro: $futarchyDecision = futarchyDecisions[proposalHash];
        if (now < $futarchyDecision.decisionTime || $futarchyDecision.isWinningOutcomeSet) {
            // Decision time is not reached yet or outcome was set already
            throw;
        }
        uint[256] memory shareDistributionMarket1 = marketFactory.getShareDistribution($futarchyDecision.marketHash1);
        uint[256] memory shareDistributionMarket2 = marketFactory.getShareDistribution($futarchyDecision.marketHash2);
        if (int(shareDistributionMarket1[0] - shareDistributionMarket1[1]) > int(shareDistributionMarket2[0] - shareDistributionMarket2[1])) {
            $futarchyDecision.winningOutcome = 0;
        }
        else {
            $futarchyDecision.winningOutcome = 1;
        }
        $futarchyDecision.isWinningOutcomeSet = true;
    }

    /*
     *  Read functions
     */
    /// @dev Validates and registers event. Returns event identifier.
    /// @param data Array of oracle addresses used for event resolution.
    /// @return proposalHash Returns proposal hash.
    function registerEvent(bytes32[] data)
        public
        returns (bytes32 proposalHash)
    {
        proposalHash = data[0];
        if (futarchyDecisions[proposalHash].decisionTime == 0) {
            // There is no futarchy event
            throw;
        }
        EventRegistration(msg.sender, proposalHash);
    }

    /// @dev Returns if winning outcome is set.
    /// @param proposalHash Hash identifying proposal description.
    /// @return isSet Returns if outcome is set.
    function isOutcomeSet(bytes32 proposalHash)
        constant
        public
        returns (bool isSet)
    {
        return futarchyDecisions[proposalHash].isWinningOutcomeSet;
    }

    /// @dev Returns winning outcome/difficulty for a specific block number.
    /// @param proposalHash Hash identifying proposal description.
    /// @return outcome Returns outcome.
    function getOutcome(bytes32 proposalHash)
        constant
        public
        returns (int outcome)
    {
        return futarchyDecisions[proposalHash].winningOutcome;
    }

    /// @dev Returns encoded futarchy decisions associated to proposal hashes.
    /// @param proposalHashes Array of hashes identifying proposals.
    /// @return allFutarchyDecisions Returns encoded futarchy decisions.
    function getFutarchyDecisions(bytes32[] proposalHashes)
        constant
        public
        returns (uint[] allFutarchyDecisions)
    {
        // Calculate array size
        uint arrPos = 0;
        for (uint i=0; i<proposalHashes.length; i++) {
            macro: $futarchyDecision = futarchyDecisions[proposalHashes[i]];
            if ($futarchyDecision.decisionTime > 0) {
                arrPos += 6;
            }
        }
        // Fill array
        allFutarchyDecisions = new uint[](arrPos);
        arrPos = 0;
        for (i=0; i<proposalHashes.length; i++) {
            macro: $futarchyDecision = futarchyDecisions[proposalHashes[i]];
            allFutarchyDecisions[arrPos] = uint(proposalHashes[i]);
            allFutarchyDecisions[arrPos + 1] = uint($futarchyDecision.marketHash1);
            allFutarchyDecisions[arrPos + 2] = uint($futarchyDecision.marketHash2);
            allFutarchyDecisions[arrPos + 3] = $futarchyDecision.decisionTime;
            if ($futarchyDecision.isWinningOutcomeSet) {
                allFutarchyDecisions[arrPos + 4] = 1;
            }
            else {
                allFutarchyDecisions[arrPos + 4] = 0;
            }
            allFutarchyDecisions[arrPos + 5] = uint($futarchyDecision.winningOutcome);
        }
    }

    /// @dev Returns data needed to identify an event.
    /// @param proposalHash Hash identifying an event.
    /// @return data Returns event data.
    function getEventData(bytes32 proposalHash)
        constant
        public
        returns (bytes32[] data)
    {
        data = new bytes32[](3);
        data[0] = futarchyDecisions[proposalHash].marketHash1;
        data[1] = futarchyDecisions[proposalHash].marketHash2;
        data[2] = bytes32(futarchyDecisions[proposalHash].decisionTime);
    }

    /// @dev Returns total fees for oracle.
    /// @param data Event data used for event resolution.
    /// @return fee Returns fee.
    /// @return token Returns token.
    function getFee(bytes32[] data)
        constant
        public
        returns (uint fee, address token)
    {
        fee = 0;
        token = 0;
    }
}
