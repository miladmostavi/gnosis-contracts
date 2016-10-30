/// @title Abstract market maker contract - Functions to be implemented by market maker contracts.
contract MarketMaker {
    function calcCostsBuying(bytes32 marketHash, uint initialFunding, uint[] shareDistribution, uint8 outcomeIndex, uint shareCount) constant returns (uint costs);
    function calcEarningsSelling(bytes32 marketHash, uint initialFunding, uint[] shareDistribution, uint8 outcomeIndex, uint shareCount) constant returns (uint earnings);

    // Market maker meta data
    // This is not an abstract functions, because solc won't recognize generated getter functions for public variables as functions.
    function name() constant returns (string) {}
}
