/// @title Abstract markets contract - Functions to be implemented by markets contracts.
contract MarketFactory {
    function createMarket(bytes32 eventHash, uint fee, uint initialFunding, address marketMakerAddress) returns (bytes32 marketHash);
    function closeMarket(bytes32 marketHash);
    function withdrawFees(bytes32 marketHash) returns (uint fees);
    function buyShares(bytes32 marketHash, uint8 outcomeIndex, uint shareCount, uint maxSpending) returns (uint totalCosts);
    function sellShares(bytes32 marketHash, uint8 outcomeIndex, uint shareCount, uint expectedEarnings) returns (uint netEarnings);
    function shortSellShares(bytes32 marketHash, uint8 outcomeIndex, uint shareCount, uint expectedEarnings) returns (uint totalCosts);

    function calcMarketFee(bytes32 marketHash, uint tokenCount) constant returns (uint fee);
    function getMarketHashes(bytes32[] eventHashes, address[] investors) constant returns (uint[] allMarketHashes);
    function getMarkets(bytes32[] marketHashes, address investor) constant returns (uint[] allMarkets);
    function getMarket(bytes32 marketHash) constant returns (bytes32 eventHash, uint fee, uint collectedFees, uint initialFunding, address investor, address marketMaker, uint createdAtBlock);
    function getShareDistributionWithTimestamp(bytes32 marketHash) constant returns (uint[] shareDistribution);
    function getShareDistribution(bytes32 marketHash) constant returns (uint[256] shareDistribution);
    function getMinFunding() constant returns (uint minFunding);

    // Market factory meta data
    // This is not an abstract functions, because solc won't recognize generated getter functions for public variables as functions.
    function name() constant returns (string) {}

    event MarketCreation(address indexed investor, bytes32 indexed marketHash);
    event MarketClosing(address indexed investor, bytes32 indexed marketHash);
}
