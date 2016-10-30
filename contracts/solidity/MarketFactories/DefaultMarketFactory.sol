pragma solidity ^0.4.0;
import "EventFactory/AbstractEventFactory.sol";
import "MarketMakers/AbstractMarketMaker.sol";
import "MarketFactories/AbstractMarketFactory.sol";
import "Tokens/AbstractToken.sol";


/// @title Market library - Market management and share trading.
/// @author Stefan George - <stefan.george@consensys.net>
/// @author Martin Koeppelmann - <martin.koeppelmann@consensys.net>
contract DefaultMarketFactory is MarketFactory {

    /*
     *  External contracts
     */
    EventFactory constant eventFactory = EventFactory({{EventFactory}});

    /*
     *  Constants
     */
    uint constant MAX_FEE = 500000; // 50%
    uint constant FEE_RANGE = 1000000; // 100%

    // Market factory meta data
    string constant public name = "Default Market Manager";

    /*
     *  Data structures
     */
    // market hash => Market
    mapping (bytes32 => Market) markets;

    // event hash => investor => market hashes
    mapping (bytes32 => mapping(address => bytes32)) marketHashes;

    struct Market {
        bytes32 eventHash;
        uint fee;
        uint collectedFees;
        uint initialFunding;
        address investor;
        MarketMaker marketMaker;
        uint createdAtBlock;
        uint[] shares;
    }

    /*
     *  Modifiers
     */
    modifier isInvestor (bytes32 marketHash) {
        if (msg.sender != markets[marketHash].investor) {
            // Only Investor is allowed to proceed
            throw;
        }
        _;
    }

    /*
     *  Read and write functions
     */
    /// @dev Creates market and sets initial shares for market maker. Returns market hash.
    /// @param eventHash Hash identifying an event.
    /// @param fee Fee charged by market maker for trades.
    /// @param initialFunding Initial funding for market maker in tokens.
    /// @param marketMaker Address of automated market maker contract.
    /// @return marketHash Returns market hash.
    function createMarket(bytes32 eventHash, uint fee, uint initialFunding, address marketMaker)
        public
        returns (bytes32 marketHash)
    {
        var (, , , , eventOutcomeCount, eventToken, , , , ) = eventFactory.getEvent(eventHash);
        marketHash = sha3(eventHash, msg.sender, marketMaker);
        // Validate data
        if (markets[marketHash].eventHash > 0 || fee > MAX_FEE || eventOutcomeCount == 0) {
            // There is already a market with this hash or fee is too high or no event for the market exists
            throw;
        }
        // Calculate fee charged by gnosis
        uint buyAllOutcomesCosts = initialFunding + eventFactory.calcBaseFeeForShares(initialFunding);
        // Transfer funding to markets contract and invest initial funding
        if (   buyAllOutcomesCosts == 0
            || !Token(eventToken).transferFrom(msg.sender, this, buyAllOutcomesCosts)
            || !Token(eventToken).approve(eventFactory, buyAllOutcomesCosts))
        {
            // Sender doesn't have enough tokens to do the funding or token approval failed or buy all outcomes could not be completed
            throw;
        }
        eventFactory.buyAllOutcomes(eventHash, buyAllOutcomesCosts);
        // Add invested shares to market
        markets[marketHash].shares = new uint[](eventOutcomeCount);
        for (uint8 i=0; i<eventOutcomeCount; i++) {
            markets[marketHash].shares[i] = initialFunding;
        }
        // Add market to storage
        marketHashes[eventHash][msg.sender] = marketHash;
        markets[marketHash].fee = fee;
        markets[marketHash].initialFunding = initialFunding;
        markets[marketHash].eventHash = eventHash;
        markets[marketHash].investor = msg.sender;
        markets[marketHash].marketMaker = MarketMaker(marketMaker);
        markets[marketHash].createdAtBlock = block.number;
        MarketCreation(msg.sender, marketHash);
    }

    /// @dev Closes market and transfers shares to investor. Returns success.
    /// @param marketHash Hash identifying a market.
    function closeMarket(bytes32 marketHash)
        public
        isInvestor(marketHash)
    {
        // Transfer shares to investor
        for (uint8 i=0; i<markets[marketHash].shares.length; i++) {
            Token(eventFactory.getOutcomeToken(markets[marketHash].eventHash, i)).transfer(msg.sender, markets[marketHash].shares[i]);
            markets[marketHash].shares[i] = 0;
        }
        // Delete market from storage
        delete markets[marketHash];
        MarketClosing(msg.sender, marketHash);
    }

    /// @dev Withdraws fees earned on market to investor. Returns fees.
    /// @param marketHash Hash identifying a market.
    /// @return fees Returns fees.
    function withdrawFees(bytes32 marketHash)
        public
        isInvestor(marketHash)
        returns (uint fees)
    {
        var (, , , , , eventToken, , , , ) = eventFactory.getEvent(markets[marketHash].eventHash);
        fees = markets[marketHash].collectedFees;
        markets[marketHash].collectedFees = 0;
        // Send fees to investor
        if (fees > 0 && !Token(eventToken).transfer(msg.sender, fees)) {
            // Tokens could not be transferred
            throw;
        }
    }

    /// @dev Buys shares of defined market and outcome. Returns price including fee.
    /// @param marketHash Hash identifying a market.
    /// @param outcomeIndex Outcome selected to buy shares from.
    /// @param shareCount Number of shares to buy.
    /// @param maxSpending Number of shares to invest.
    /// @return totalCosts Returns total costs.
    function buyShares(bytes32 marketHash, uint8 outcomeIndex, uint shareCount, uint maxSpending)
        public
        returns (uint totalCosts)
    {
        var (, , , , , eventToken, , , , ) = eventFactory.getEvent(markets[marketHash].eventHash);
        // Calculate costs for requested shares
        uint costs = markets[marketHash].marketMaker.calcCostsBuying(marketHash,
                                                                     markets[marketHash].initialFunding,
                                                                     markets[marketHash].shares,
                                                                     outcomeIndex,
                                                                     shareCount);
        if (costs == 0) {
            // Amount of shares too low, rounding issue
            throw;
        }
        // Calculate fee charged by market
        uint fee = calcMarketFee(marketHash, costs);
        // Calculate fee charged by gnosis
        uint baseFee = eventFactory.calcBaseFeeForShares(shareCount);
        totalCosts = costs + fee + baseFee;
        // Check costs don't exceed max spending
        if (totalCosts > maxSpending) {
            // Shares are more expensive
            throw;
        }
        // Transfer tokens to markets contract and buy all outcomes
        if (   totalCosts == 0
            || !Token(eventToken).transferFrom(msg.sender, this, totalCosts)
            || !Token(eventToken).approve(eventFactory, costs + baseFee))
        {
            // Sender did not send enough tokens or token approval could not be completed
            throw;
        }
        eventFactory.buyAllOutcomes(markets[marketHash].eventHash, costs + baseFee);
        // Add new allocated shares to market
        for (uint8 i=0; i<markets[marketHash].shares.length; i++) {
            markets[marketHash].shares[i] += costs;
        }
        // Protect against malicious markets
        if (shareCount > markets[marketHash].shares[outcomeIndex]) {
            // Market maker out of funds
            throw;
        }
        // Add fee to collected fees
        markets[marketHash].collectedFees += fee;
        // Transfer shares to buyer
        markets[marketHash].shares[outcomeIndex] -= shareCount;
        Token(eventFactory.getOutcomeToken(markets[marketHash].eventHash, outcomeIndex)).transfer(msg.sender, shareCount);
    }

    /// @dev Sells shares of defined market and outcome. Returns earnings minus fee.
    /// @param marketHash Hash identifying a market.
    /// @param outcomeIndex Outcome selected to sell shares from.
    /// @param shareCount Number of shares to sell.
    /// @param expectedEarnings Number of shares to invest in case of a market traded in tokens.
    /// @return netEarnings Returns net earnings.
    function sellShares(bytes32 marketHash, uint8 outcomeIndex, uint shareCount, uint expectedEarnings)
        public
        returns (uint netEarnings)
    {
        var (, , , , , eventToken, , , , ) = eventFactory.getEvent(markets[marketHash].eventHash);
        // Calculate earnings for requested shares
        uint earnings = markets[marketHash].marketMaker.calcEarningsSelling(marketHash,
                                                                            markets[marketHash].initialFunding,
                                                                            markets[marketHash].shares,
                                                                            outcomeIndex,
                                                                            shareCount);
        if (earnings == 0) {
            // Amount of shares too low, rounding issue
            throw;
        }
        // Calculate fee charged by market
        uint fee = calcMarketFee(marketHash, earnings);
        netEarnings = earnings - fee;
        if (netEarnings < expectedEarnings) {
            // Invalid sell order
            throw;
        }
        // Transfer event tokens to markets contract to redeem all outcomes
        Token(eventFactory.getOutcomeToken(markets[marketHash].eventHash, outcomeIndex)).transferFrom(msg.sender, this, shareCount);
        eventFactory.sellAllOutcomes(markets[marketHash].eventHash, earnings);
        // Add shares transferred to market
        markets[marketHash].shares[outcomeIndex] += shareCount;
        // Lower shares of market by sold shares
        for (uint8 i=0; i<markets[marketHash].shares.length; i++) {
            if (markets[marketHash].shares[i] >= earnings) {
                markets[marketHash].shares[i] -= earnings;
            }
            else {
                // Market maker out of funds, revert state to protect against malicious market makers
                throw;
            }
        }
        // Add fee to collected fees
        markets[marketHash].collectedFees += fee;
        // Transfer earnings to seller
        if (netEarnings > 0 && !Token(eventToken).transfer(msg.sender, netEarnings)) {
            // Tokens could ot be transferred
            throw;
        }
    }

    /// @dev Short sells outcome by buying all outcomes and selling selected outcome shares. Returns invested tokens.
    /// @param marketHash Hash identifying a market.
    /// @param outcomeIndex Outcome selected to sell shares from.
    /// @param shareCount Number of shares to buy from all outcomes.
    /// @param expectedEarnings Money to earn from selling selected outcome.
    /// @return totalCosts Returns total costs.
    function shortSellShares(bytes32 marketHash, uint8 outcomeIndex, uint shareCount, uint expectedEarnings)
        public
        returns (uint totalCosts)
    {
        bytes32 eventHash = markets[marketHash].eventHash;
        var (, , , , eventOutcomeCount, eventToken, , , , ) = eventFactory.getEvent(eventHash);
        // Calculate fee charged by gnosis
        uint buyAllOutcomesCosts = shareCount + eventFactory.calcBaseFeeForShares(shareCount);
        // Buy all outcomes
        if (   buyAllOutcomesCosts == 0
            || !Token(eventToken).transferFrom(msg.sender, this, buyAllOutcomesCosts)
            || !Token(eventToken).approve(eventFactory, buyAllOutcomesCosts))
        {
            // Sender did not send enough tokens or buy all outcomes failed
            throw;
        }
        eventFactory.buyAllOutcomes(eventHash, buyAllOutcomesCosts);
        // Short sell selected shares
        if (!Token(eventFactory.getOutcomeToken(eventHash, outcomeIndex)).approve(this, shareCount)) {
            throw;
        }
        uint earnings = this.sellShares(marketHash, outcomeIndex, shareCount, expectedEarnings);
        if (earnings == 0) {
            // Could not sell shares for expected price
            throw;
        }
        // Transfer shares to buyer
        for (uint8 i =0; i<eventOutcomeCount; i++) {
            if (i != outcomeIndex){
                Token(eventFactory.getOutcomeToken(eventHash, i)).transfer(msg.sender, shareCount);
            }
        }
        // Send change back to buyer
        if (earnings > 0 && !Token(eventToken).transfer(msg.sender, earnings)) {
            // Couldn't send user change back
            throw;
        }
        totalCosts = buyAllOutcomesCosts - earnings;
    }

    /*
     *  Read functions
     */
    /// @dev Returns all market hashes for all given event hashes.
    /// @param eventHashes Array of hashes identifying eventFactory.
    /// @param investors Array of investor addresses.
    /// @return allMarketHashes Returns all market hashes for markets created by one of the investors.
    function getMarketHashes(bytes32[] eventHashes, address[] investors)
        constant
        public
        returns (uint[] allMarketHashes)
    {
        // Calculate array size
        uint arrPos = 0;
        uint count;
        for (uint i=0; i<eventHashes.length; i++) {
            count = 0;
            for (uint j=0; j<investors.length; j++) {
                if (marketHashes[eventHashes[i]][investors[j]] > 0) {
                    count += 1;
                }
            }
            if (count > 0) {
                arrPos += 2 + count;
            }
        }
        // Fill array
        allMarketHashes = new uint[](arrPos);
        arrPos = 0;
        for (i=0; i<eventHashes.length; i++) {
            count = 0;
            for (j=0; j<investors.length; j++) {
                if (marketHashes[eventHashes[i]][investors[j]] > 0) {
                    allMarketHashes[arrPos + 2 + count] = uint(marketHashes[eventHashes[i]][investors[j]]);
                    count += 1;
                }
            }
            if (count > 0) {
                allMarketHashes[arrPos] = uint(eventHashes[i]);
                allMarketHashes[arrPos + 1] = count;
                arrPos += 2 + count;
            }
        }
    }

    /// @dev Calculates market fee for invested tokens.
    /// @param marketHash Hash identifying market.
    /// @param tokenCount Amount of invested tokens.
    /// @return fee Returns fee.
    function calcMarketFee(bytes32 marketHash, uint tokenCount)
        constant
        public
        returns (uint fee)
    {
        return tokenCount * markets[marketHash].fee / FEE_RANGE;
    }

    /// @dev Returns all encoded markets for all given market hashes.
    /// @param marketHashes Array of hashes identifying markets.
    /// @param investor Filter markets by investor.
    /// @return allMarkets Returns all markets.
    function getMarkets(bytes32[] marketHashes, address investor)
        constant
        public
        returns (uint[] allMarkets)
    {
        // Calculate array size
        uint arrPos = 0;
        for (uint i=0; i<marketHashes.length; i++) {
            if (markets[marketHashes[i]].eventHash > 0 && (investor == 0 || markets[marketHashes[i]].investor == investor)) {
                arrPos += 9 + markets[marketHashes[i]].shares.length;
            }
        }
        // Fill array
        allMarkets = new uint[](arrPos);
        arrPos = 0;
        for (i=0; i<marketHashes.length; i++) {
            if (markets[marketHashes[i]].eventHash > 0 && (investor == 0 || markets[marketHashes[i]].investor == investor)) {
                bytes32 marketHash = marketHashes[i];
                Market market = markets[marketHash];
                allMarkets[arrPos] = uint(marketHash);
                allMarkets[arrPos + 1] = uint(market.eventHash);
                allMarkets[arrPos + 2] = market.fee;
                allMarkets[arrPos + 3] = market.collectedFees;
                allMarkets[arrPos + 4] = market.initialFunding;
                allMarkets[arrPos + 5] = uint(market.investor);
                allMarkets[arrPos + 6] = uint(market.marketMaker);
                allMarkets[arrPos + 7] = uint(market.createdAtBlock);
                allMarkets[arrPos + 8] = market.shares.length;
                for (uint j=0; j<market.shares.length; j++) {
                    allMarkets[arrPos + 9 + j] = market.shares[j];
                }
                arrPos += 9 + market.shares.length;
            }
        }
    }

    /// @dev Returns distribution of market shares at a specific time.
    /// @param marketHash Hash identifying a market.
    /// @return shareDistribution Returns share distribution and timestamp.
    function getShareDistributionWithTimestamp(bytes32 marketHash)
        constant
        public
        returns (uint[] shareDistribution)
    {
        shareDistribution = new uint[](markets[marketHash].shares.length + 1);
        shareDistribution[0] = now;
        for (uint8 i=0; i<markets[marketHash].shares.length; i++) {
            shareDistribution[1 + i] = markets[marketHash].shares[i];
        }
    }

    /// @dev Returns distribution of market shares.
    /// @param marketHash Hash identifying a market.
    /// @return shareDistribution Returns share distribution.
    function getShareDistribution(bytes32 marketHash)
        constant
        public
        returns (uint[256] shareDistribution)
    {
        for (uint8 i=0; i<markets[marketHash].shares.length; i++) {
            shareDistribution[i] = markets[marketHash].shares[i];
        }
    }

    /// @dev Returns market for market hash.
    /// @param marketHash Hash identifying a market.
    /// @return eventHash Hash identifying an event.
    /// @return fee Fee charged by market maker for trades.
    /// @return collectedFees Fees collected market maker for trades.
    /// @return initialFunding Initial funding for market maker in tokens.
    /// @return marketMaker Address of automated market maker contract.
    /// @return createdAtBlock Returns block number when market was created.
    function getMarket(bytes32 marketHash)
        constant
        public
        returns (
            bytes32 eventHash,
            uint fee,
            uint collectedFees,
            uint initialFunding,
            address investor,
            address marketMaker,
            uint createdAtBlock
        )
    {
        eventHash = markets[marketHash].eventHash;
        fee = markets[marketHash].fee;
        collectedFees = markets[marketHash].collectedFees;
        initialFunding = markets[marketHash].initialFunding;
        investor = markets[marketHash].investor;
        marketMaker = markets[marketHash].marketMaker;
        createdAtBlock = markets[marketHash].createdAtBlock;
    }

    /// @dev Returns minimum funding for market creation.
    /// @return minFunding Returns minimum funding in Wei.
    function getMinFunding()
        constant
        public
        returns (uint minFunding)
    {
        return 0;
    }
}
