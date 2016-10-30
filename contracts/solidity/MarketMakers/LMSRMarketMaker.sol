pragma solidity ^0.4.0;
import "Utils/MathLibrary.sol";
import "MarketMakers/AbstractMarketMaker.sol";


/// @title LMSR market maker contract - Calculates share prices based on share distribution and initial funding.
/// @author Stefan George - <stefan.george@consensys.net>
/// @author Martin Koeppelmann - <martin.koeppelmann@consensys.net>
/// @author Michael Lu - <michael.lu@consensys.net>
contract LMSRMarketMaker is MarketMaker {

    /*
     *  Constants
     */
    uint constant ONE = 0x10000000000000000;

    // Market maker meta data
    string constant public name = "LMSR Market Maker";

    /*
     *  Read functions
     */
    /// @dev Returns costs to buy given number of shares.
    /// @param marketHash Market hash identifying market.
    /// @param initialFunding Initial funding for market maker.
    /// @param shareDistribution Array of shares of all outcomes.
    /// @param outcomeIndex Outcome selected to buy shares from.
    /// @param shareCount Number of shares to buy.
    /// @return costs Returns costs.
    function calcCostsBuying(bytes32 marketHash, uint initialFunding, uint[] shareDistribution, uint8 outcomeIndex, uint shareCount)
        constant
        public
        returns (uint costs)
    {
        // C = b * ln(e^(q1/b) + e^(q2/b) + ...)
        // We have to invert it so that it is accurate
        uint invB = MathLibrary.ln(shareDistribution.length * ONE) / 10000; // map initial funding to 10k
        uint[2] memory shareRange = getShareRange(shareDistribution);
        uint c1 = calcCosts(invB, shareRange, shareDistribution, initialFunding);
        shareDistribution[outcomeIndex] -= shareCount;
        uint c2 = calcCosts(invB, shareRange, shareDistribution, initialFunding);
        // Calculate costs
        costs = (c2-c1) * (initialFunding / 10000) * (100000 + 2) / 100000 / ONE;
        if (costs > shareCount) {
            // Make sure costs are not bigger than 1 per share
            costs = shareCount;
        }
    }

    /// @dev Returns earnings for selling given number of shares.
    /// @param marketHash Market hash identifying market.
    /// @param initialFunding Initial funding for market maker.
    /// @param shareDistribution Array of shares of all outcomes.
    /// @param outcomeIndex Outcome selected to sell shares from.
    /// @param shareCount Number of shares to sell.
    /// @return earnings Returns earnings.
    function calcEarningsSelling(bytes32 marketHash, uint initialFunding, uint[] shareDistribution, uint8 outcomeIndex, uint shareCount)
        constant
        public
        returns (uint earnings)
    {
        // We have to invert it so that it is accurate
        uint invB = MathLibrary.ln(shareDistribution.length * ONE) / 10000; // map initial funding to 10k
        uint[2] memory shareRange = getShareRange(shareDistribution);
        shareRange[1] += shareCount;
        uint c1 = calcCosts(invB, shareRange, shareDistribution, initialFunding);
        shareDistribution[outcomeIndex] += shareCount;
        uint c2 = calcCosts(invB, shareRange, shareDistribution, initialFunding);
        // Calculate earnings
        earnings = (c1-c2) * (initialFunding / 10000) * (100000 - 2) / 100000 / ONE;
    }

    function calcCosts(uint invB, uint[2] shareRange, uint[] shareDistribution, uint initialFunding)
        private
        returns(uint costs)
    {
        // Inside the ln()
        uint innerSum = 0;
        uint initialFundingDivisor = initialFunding / 10000;
        for (uint8 i=0; i<shareDistribution.length; i++) {
            innerSum += MathLibrary.eExp((shareRange[1] - shareRange[0] - (shareDistribution[i] - shareRange[0])) / initialFundingDivisor * invB);
        }
        costs = MathLibrary.ln(innerSum) * ONE / invB;
    }

    function getShareRange(uint[] shareDistribution)
        private
        returns (uint[2] shareRange)
    {
        // Lowest shares
        shareRange[0] = shareDistribution[0];
        // Highest shares
        shareRange[1] = shareDistribution[0];
        for (uint8 i=0; i<shareDistribution.length; i++) {
            if (shareDistribution[i] < shareRange[0]) {
                shareRange[0] = shareDistribution[i];
            }
            if (shareDistribution[i]> shareRange[1]) {
                shareRange[1] = shareDistribution[i];
            }
        }
    }
}
