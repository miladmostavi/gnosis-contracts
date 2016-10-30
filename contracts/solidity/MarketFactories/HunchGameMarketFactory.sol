pragma solidity ^0.4.0;
import "EventFactory/AbstractEventFactory.sol";
import "MarketFactories/DefaultMarketFactory.sol";
import "Tokens/HunchGameToken.sol";


/// @title Hunch Game token contract - Implements token trading and high-score calculation.
/// @author Stefan George - <stefan.george@consensys.net>
/// @author Martin Koeppelmann - <martin.koeppelmann@consensys.net>
contract HunchGameMarketFactory is DefaultMarketFactory {

    /*
     *  External contracts
     */
    EventFactory constant eventFactory = EventFactory({{EventFactory}});
    HunchGameToken constant hunchGameToken = HunchGameToken({{HunchGameToken}});

    /*
     *  Constants
     */
    uint16 constant TWELVE_HOURS = 12 hours; // 12h
    uint constant CREDIT = 1000 * 10**18;
    uint constant MIN_FUNDING = 10 * 10**18; // Minimum amount of tokens needed to create a market

    // Market factory meta data
    string constant public name = "HunchGame Market Manager";

    /*
     *  Data structures
     */
    // owner address => timestamp
    mapping (address => uint) lastCredits;

    // owner address => event hash => number of tokens
    mapping (address => mapping (bytes32 => int)) tokensInEvents;

    // owner address => event hash => outcomeIndex => number of shares
    mapping (address => mapping (bytes32 => mapping(uint8 => uint))) eventShares;

    // owner address => high score
    mapping (address => uint) highScores;

    /*
     *  Modifiers
     */
    modifier minFunding (uint initialFunding) {
        if (initialFunding < MIN_FUNDING) {
            // Check there is enough funding
            throw;
        }
        _;
    }

    /*
     *  Read and write functions
     */
    /// @dev Returns user level.
    /// @param userAddress Address of user account.
    /// @return level Returns user's level.
    function userLevel(address userAddress)
        public
        returns (uint level)
    {
        level = 0;
        while (10**level * CREDIT < highScores[userAddress]) {
            level += 1;
        }
    }

    /// @dev Adds credits to user account every 12 hours.
    function addCredit()
        public
    {
        if (lastCredits[msg.sender] + TWELVE_HOURS >= now) {
            // Last credits were issued less than 12 hours ago
            throw;
        }
        uint level = userLevel(msg.sender);
        uint addedCredit = 10**level * CREDIT;
        hunchGameToken.issueTokens(msg.sender, addedCredit);
        lastCredits[msg.sender] = now;
    }

    /// @dev Buys more credits with Ether. One 12h credits for 0.5 Ether.
    function buyCredits()
        public
        payable
    {
        if (msg.value == 0) {
            // No ether was sent
            throw;
        }
        uint level = userLevel(msg.sender);
        uint addedCredit = 10**level * CREDIT * msg.value / (10**18 / 2);
        hunchGameToken.issueTokens(msg.sender, addedCredit);
    }

    /// @dev Creates market and sets initial shares for market maker. Returns market hash.
    /// @param eventHash Hash identifying an event.
    /// @param fee Fee charged by market maker for trades.
    /// @param initialFunding Initial funding for market maker in tokens.
    /// @param marketMakerAddress Address of automated market maker contract.
    /// @return marketHash Returns market hash.
    function createMarket(bytes32 eventHash, uint fee, uint initialFunding, address marketMakerAddress)
        public
        minFunding(initialFunding)
        returns (bytes32 marketHash)
    {
        var (, , , , , eventTokenAddress, , , , ) = eventFactory.getEvent(eventHash);
        if (eventTokenAddress != address(hunchGameToken)) {
            // Event is not using Hunch Game tokens
            throw;
        }
        return super.createMarket(eventHash, fee, initialFunding, marketMakerAddress);
    }

    /// @dev Wraps buy share function of market contract.
    /// @param marketHash Hash identifying a market.
    /// @param outcomeIndex Outcome selected to buy shares from.
    /// @param shareCount Number of shares to buy.
    /// @param maxSpending Number of shares to invest in case of a market traded in tokens.
    /// @return costs Returns total costs.
    function buyShares(bytes32 marketHash, uint8 outcomeIndex, uint shareCount, uint maxSpending)
        public
        returns (uint costs)
    {
        bytes32 eventHash = markets[marketHash].eventHash;
        costs = super.buyShares(marketHash, outcomeIndex, shareCount, maxSpending);
        if (costs > 0) {
            tokensInEvents[msg.sender][eventHash] += int(costs);
            eventShares[msg.sender][eventHash][outcomeIndex] += shareCount;
        }
    }

    /// @dev Short sells outcome by buying all outcomes and selling selected outcome shares. Returns invested tokens.
    /// @param marketHash Hash identifying a market.
    /// @param outcomeIndex Outcome selected to sell shares from.
    /// @param shareCount Number of shares to buy from all outcomes.
    /// @param expectedEarnings Money to earn from selling selected outcome.
    /// @return costs Returns total costs.
    function shortSellShares(bytes32 marketHash, uint8 outcomeIndex, uint shareCount, uint expectedEarnings)
        public
        returns (uint costs)
    {
        costs = super.shortSellShares(marketHash, outcomeIndex, shareCount, expectedEarnings);
        if (costs > 0) {
            bytes32 eventHash = markets[marketHash].eventHash;
            var (, , , , eventOutcomeCount, , , , , ) = eventFactory.getEvent(eventHash);
            for (uint8 i =0; i<eventOutcomeCount; i++) {
                if (i != outcomeIndex){
                    eventShares[msg.sender][eventHash][i] += shareCount;
                }
            }
            tokensInEvents[msg.sender][eventHash] += int(costs);
        }
    }

    /// @dev Wraps sell shares function of market contract.
    /// @param marketHash Hash identifying a market.
    /// @param outcomeIndex Outcome selected to sell shares from.
    /// @param shareCount Number of shares to sell.
    /// @param expectedEarnings Number of shares to invest in case of a market traded in tokens.
    /// @return earnings Returns total earnings.
    function sellShares(bytes32 marketHash, uint8 outcomeIndex, uint shareCount, uint expectedEarnings)
        public
        returns (uint earnings)
    {
        bytes32 eventHash = markets[marketHash].eventHash;
        // User transfers shares to HunchGame and HunchGame approves market contract to sell shares
        earnings = super.sellShares(marketHash, outcomeIndex, shareCount, expectedEarnings);
        if (   int(earnings) > tokensInEvents[msg.sender][eventHash]
            && eventShares[msg.sender][eventHash][outcomeIndex] >= shareCount)
        {
            if (tokensInEvents[msg.sender][eventHash] < 0) {
                highScores[msg.sender] += earnings;
            }
            else {
                highScores[msg.sender] += earnings - uint(tokensInEvents[msg.sender][eventHash]);
            }
        }
        tokensInEvents[msg.sender][eventHash] -= int(earnings);
        eventShares[msg.sender][eventHash][outcomeIndex] -= shareCount;
    }

    /// @dev Wraps redeem winnings function in event contract.
    /// @param eventHash Hash identifying an event.
    /// @return winnings Returns total winnings.
    function redeemWinnings(bytes32 eventHash)
        public
        returns (uint winnings)
    {
        var (, , , , eventOutcomeCount, , , , , ) = eventFactory.getEvent(eventHash);
        bool fraudulentNumberOfShares = false;
        for (uint8 i=0; i<eventOutcomeCount; i++) {
            uint shareCount = Token(eventFactory.getOutcomeToken(eventHash, i)).balanceOf(msg.sender);
            if (eventShares[msg.sender][eventHash][i] < shareCount) {
                fraudulentNumberOfShares = true;
                eventShares[msg.sender][eventHash][i] = 0;
            }
            Token(eventFactory.getOutcomeToken(eventHash, i)).transferFrom(msg.sender, this, shareCount);
        }
        uint balanceBeforeRedemption = hunchGameToken.balanceOf(this);
        winnings = eventFactory.redeemWinnings(eventHash);
        if (winnings == 0) {
            // No winnings earned
            throw;
        }
        hunchGameToken.transfer(msg.sender, winnings);
        if (int(winnings) > tokensInEvents[msg.sender][eventHash] && !fraudulentNumberOfShares) {
            if (tokensInEvents[msg.sender][eventHash] < 0) {
                highScores[msg.sender] += winnings;
            }
            else {
                highScores[msg.sender] += winnings - uint(tokensInEvents[msg.sender][eventHash]);
            }
        }
        tokensInEvents[msg.sender][eventHash] -= int(winnings);
    }

    /*
     * Read functions
     */
    /// @dev Returns all tokens sender has invested in events.
    /// @param user User's address.
    /// @param eventHashes Array of hashes identifying events.
    /// @return allTokens Returns all tokens in events.
    function getTokensInEvents(address user, bytes32[] eventHashes)
        constant
        public
        returns (uint[] allTokens)
    {
        // Calculate array size
        uint arrPos = 0;
        for (uint i=0; i<eventHashes.length; i++) {
            if (tokensInEvents[user][eventHashes[i]] > 0) {
                arrPos += 2;
            }
        }
        // Fill array
        allTokens = new uint[](arrPos);
        arrPos = 0;
        for (i=0; i<eventHashes.length; i++) {
            if (tokensInEvents[user][eventHashes[i]] > 0) {
                allTokens[arrPos] = uint(eventHashes[i]);
                allTokens[arrPos + 1] = uint(tokensInEvents[user][eventHashes[i]]);
                arrPos += 2;
            }
        }
    }

    /// @dev Returns all high scores for all given user addresses.
    /// @param userAddresses Users' addresses.
    /// @return allHighScores Returns high-scores of all users.
    function getHighScores(address[] userAddresses)
        constant
        public
        returns (uint[] allHighScores)
    {
        // Calculate array site
        uint arrPos = 0;
        for (uint i=0; i<userAddresses.length; i++) {
            if (highScores[userAddresses[i]] > 0) {
                arrPos += 2;
            }
        }
        // Fill array
        allHighScores = new uint[](arrPos);
        arrPos = 0;
        for (i=0; i<userAddresses.length; i++) {
            if (highScores[userAddresses[i]] > 0) {
                allHighScores[arrPos] = uint(userAddresses[i]);
                allHighScores[arrPos + 1] = highScores[userAddresses[i]];
                arrPos += 2;
            }
        }
    }

    /// @dev Returns timestamp of last credits.
    /// @param _owner Address of token owner.
    /// @return lastCredit Returns timestamp of last credit.
    function getLastCredit(address _owner)
        constant
        public
        returns (uint lastCredit)
    {
        return lastCredits[_owner];
    }

    /// @dev Returns minimum funding for market creation.
    /// @return success Returns success of function call.
    function getMinFunding()
        constant
        public
        returns (uint minFunding)
    {
        return MIN_FUNDING;
    }
}
