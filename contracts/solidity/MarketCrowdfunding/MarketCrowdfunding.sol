pragma solidity ^0.4.0;
import "MarketFactories/AbstractMarketFactory.sol";
import "Tokens/AbstractToken.sol";
import "MarketMakers/AbstractMarketMaker.sol";
import "EventFactory/AbstractEventFactory.sol";


/// @title Market crowdfunding contract - Allows crowdfunding of markets.
/// @author Stefan George - <stefan.george@consensys.net>
/// @author Martin Koeppelmann - <martin.koeppelmann@consensys.net>
contract MarketCrowdfunding {

    /*
     *  Events
     */
    event CampaignCreation(address indexed creator, bytes32 indexed campaignHash);
    event Funding(address indexed investor, uint256 investment, bytes32 indexed campaignHash);

    /*
     *  External contracts
     */
    EventFactory constant eventFactory = EventFactory({{EventFactory}});

    /*
     *  Data structures
     */
    // campaign hash => Campaign
    mapping(bytes32 => Campaign) public campaigns;

    // event hash => campaign hashes
    mapping (bytes32 => bytes32[]) public campaignHashes;

    // user address => campaign hash => funding
    mapping(address => mapping(bytes32 => uint)) public shares;

    struct Campaign {
        MarketFactory marketFactory;
        Token token;
        MarketMaker marketMaker;
        bytes32 eventHash;
        bytes32 marketHash;
        uint fee;
        uint initialFunding; // For market
        uint totalFunding; // Funding for market and initial shares
        uint raisedAmount;
        uint closingAtTimestamp;
        uint collectedFees;
        /* outcome => shares */
        uint[] initialShares;
    }

    /*
     *  Read and write functions
     */
    /// @dev Starts a new crowdfunding campaign to fund a market for an event. Returns campaign hash.
    /// @param marketFactory Address of market factory contract.
    /// @param eventHash Hash identifying event for market.
    /// @param fee Fee charged by investors for trades on market.
    /// @param initialFunding Initial funding for automated market maker.
    /// @param totalFunding Total funding needed for campaign to complete successfully.
    /// @param marketMaker Contract address of automated market maker.
    /// @param closingAtTimestamp Block number when campaign ends. Funding has to be completed until this block.
    /// @param initialShares An array of an initial share distribution. The market maker buys those shares from his own market on creation. This is why total funding is not necessarily equal to initial funding of market.
    /// @return campaignHash Returns campaign hash.
    function startCampaign(address marketFactory,
                           bytes32 eventHash,
                           uint fee,
                           uint initialFunding,
                           uint totalFunding,
                           address marketMaker,
                           uint closingAtTimestamp,
                           uint[] initialShares
    )
        external
        returns (bytes32 campaignHash)
    {
        campaignHash = sha3(marketFactory,
                            eventHash,
                            fee,
                            initialFunding,
                            totalFunding,
                            marketMaker,
                            closingAtTimestamp,
                            initialShares);
        var (, , , , eventOutcomeCount, eventTokenAddress, , , , ) = eventFactory.getEvent(eventHash);
        if (campaigns[campaignHash].closingAtTimestamp > 0 || eventOutcomeCount == 0) {
            // Campaign exists already or event is invalid
            throw;
        }
        campaigns[campaignHash].marketFactory = MarketFactory(marketFactory);
        campaigns[campaignHash].eventHash = eventHash;
        campaigns[campaignHash].fee = fee;
        campaigns[campaignHash].initialFunding = initialFunding;
        campaigns[campaignHash].totalFunding = totalFunding;
        campaigns[campaignHash].marketMaker = MarketMaker(marketMaker);
        campaigns[campaignHash].token = Token(eventTokenAddress);
        campaigns[campaignHash].closingAtTimestamp = closingAtTimestamp;
        campaigns[campaignHash].initialShares = initialShares;
        campaignHashes[eventHash].push(campaignHash);
        CampaignCreation(msg.sender, campaignHash);
    }

    /// @dev Creates market once funding is successfully completed. Returns success.
    /// @param campaignHash Hash identifying campaign.
    function createMarket(bytes32 campaignHash)
        external
        returns (bytes32 marketHash)
    {
        MarketFactory marketFactory = campaigns[campaignHash].marketFactory;
        Token token = campaigns[campaignHash].token;
        if (campaigns[campaignHash].raisedAmount < campaigns[campaignHash].totalFunding) {
            // Campaign funding goal was not reached
            throw;
        }
        if (!token.approve(marketFactory, campaigns[campaignHash].totalFunding)) {
            // Tokens could not be transferred
            throw;
        }
        marketHash = marketFactory.createMarket(campaigns[campaignHash].eventHash,
                                           campaigns[campaignHash].fee,
                                           campaigns[campaignHash].initialFunding,
                                           campaigns[campaignHash].marketMaker);
        if (marketHash == 0) {
            // Market could not be created
            throw;
        }
        campaigns[campaignHash].marketHash = marketHash;
        uint totalCosts = 0;
        for (uint8 i=0; i<campaigns[campaignHash].initialShares.length; i++) {
            uint buyValue = campaigns[campaignHash].totalFunding - campaigns[campaignHash].initialFunding - totalCosts;
            totalCosts += marketFactory.buyShares(marketHash, i, campaigns[campaignHash].initialShares[i], buyValue);
        }
    }

    /// @dev Funds campaign until total funding is reached with Ether or tokens. Returns success.
    /// @param campaignHash Hash identifying campaign.
    /// @param tokens Number of tokens used for funding in case funding is not done in Ether.
    function fund(bytes32 campaignHash, uint tokens)
        external
    {
        Token token = campaigns[campaignHash].token;
        if (   campaigns[campaignHash].closingAtTimestamp < now
            || campaigns[campaignHash].raisedAmount == campaigns[campaignHash].totalFunding)
        {
            // Campaign is over or funding goal was reached
            throw;
        }
        uint investment = tokens;
        if (campaigns[campaignHash].raisedAmount + investment > campaigns[campaignHash].totalFunding) {
            // Sender send too much value, difference is returned to sender
            investment = campaigns[campaignHash].totalFunding - campaigns[campaignHash].raisedAmount;
        }
        if (investment == 0 || !token.transferFrom(msg.sender, this, investment)) {
            // Tokens could not be transferred
            throw;
        }
        campaigns[campaignHash].raisedAmount += investment;
        shares[msg.sender][campaignHash] += investment;
        Funding(msg.sender, investment, campaignHash);
    }

    /// @dev Withdraws funds from an investor in case of an unsuccessful campaign. Returns success.
    /// @param campaignHash Hash identifying campaign.
    function withdrawFunding(bytes32 campaignHash)
        external
    {
        if (   campaigns[campaignHash].closingAtTimestamp >= now
            || campaigns[campaignHash].raisedAmount == campaigns[campaignHash].totalFunding)
        {
            // Campaign is still going or market has been created
            throw;
        }
        uint funding = shares[msg.sender][campaignHash];
        shares[msg.sender][campaignHash] = 0;
        Token token = campaigns[campaignHash].token;
        if (funding > 0 && !token.transfer(msg.sender, funding)) {
            // Tokens could not be transferred
            throw;
        }
    }

    /// @dev Withdraws fees earned by market. Has to be done before a market investor can get its share of those winnings. Returns success.
    /// @param campaignHash Hash identifying campaign.
    function withdrawContractFees(bytes32 campaignHash)
        external
    {
        campaigns[campaignHash].collectedFees += campaigns[campaignHash].marketFactory.withdrawFees(campaigns[campaignHash].marketHash);
    }

    /// @dev Withdraws investor's share of earned fees by a market. Returns success.
    /// @param campaignHash Hash identifying campaign.
    function withdrawFees(bytes32 campaignHash)
        external
    {
        if (campaigns[campaignHash].collectedFees == 0) {
            // No fees collected
            throw;
        }
        Token token = campaigns[campaignHash].token;
        uint userFees = campaigns[campaignHash].collectedFees * shares[msg.sender][campaignHash] / campaigns[campaignHash].totalFunding;
        shares[msg.sender][campaignHash] = 0;
        if (userFees > 0 && !token.transfer(msg.sender, userFees)) {
            // Tokens could not be transferred
            throw;
        }
    }

    /*
     *  Read functions
     */
    /// @dev Returns array of all campaign hashes of corresponding event hashes.
    /// @param eventHashes Array of event hashes identifying events.
    /// @return allCampaignHashes Returns all campaign hashes.
    function getCampaignHashes(bytes32[] eventHashes)
        constant
        external
        returns (uint[] allCampaignHashes)
    {
        // Calculate array size
        uint arrPos = 0;
        for (uint i=0; i<eventHashes.length; i++) {
            uint campaignHashesCount = campaignHashes[eventHashes[i]].length;
            if (campaignHashesCount > 0) {
                arrPos += 2 + campaignHashesCount;
            }
        }
        // Fill array
        allCampaignHashes = new uint[](arrPos);
        arrPos = 0;
        for (i=0; i<eventHashes.length; i++) {
            campaignHashesCount = campaignHashes[eventHashes[i]].length;
            if (campaignHashesCount > 0) {
                allCampaignHashes[arrPos] = uint(eventHashes[i]);
                allCampaignHashes[arrPos + 1] = campaignHashesCount;
                for (uint j=0; j<campaignHashesCount; j++) {
                    allCampaignHashes[arrPos + 2 + j] = uint(campaignHashes[eventHashes[i]][j]);
                }
                arrPos += 2 + campaignHashesCount;
            }
        }
    }

    /// @dev Returns array of encoded campaigns.
    /// @param _campaignHashes Array of campaign hashes identifying campaigns.
    /// @return _campaignHashes Returns campaign hashes.
    function getCampaigns(bytes32[] _campaignHashes)
        constant
        external
        returns (uint[] allCampaigns)
    {
        // Calculate array size
        uint arrPos = 0;
        for (uint i=0; i<_campaignHashes.length; i++) {
            arrPos += 13 + campaigns[_campaignHashes[i]].initialShares.length;
        }
        // Fill array
        allCampaigns = new uint[](arrPos);
        arrPos = 0;
        for (i=0; i<_campaignHashes.length; i++) {
            bytes32 campaignHash = _campaignHashes[i];
            Campaign campaign = campaigns[campaignHash];
            allCampaigns[arrPos] = uint(campaignHash);
            allCampaigns[arrPos + 1] = uint(campaign.marketFactory);
            allCampaigns[arrPos + 2] = uint(campaign.token);
            allCampaigns[arrPos + 3] = uint(campaign.marketMaker);
            allCampaigns[arrPos + 4] = uint(campaign.eventHash);
            allCampaigns[arrPos + 5] = uint(campaign.marketHash);
            allCampaigns[arrPos + 6] = campaign.fee;
            allCampaigns[arrPos + 7] = campaign.initialFunding;
            allCampaigns[arrPos + 8] = campaign.totalFunding;
            allCampaigns[arrPos + 9] = campaign.raisedAmount;
            allCampaigns[arrPos + 10] = campaign.closingAtTimestamp;
            allCampaigns[arrPos + 11] = campaign.collectedFees;
            allCampaigns[arrPos + 12] = campaign.initialShares.length;
            for (uint j=0; j<campaign.initialShares.length; j++) {
                allCampaigns[arrPos + 13 + j] = campaign.initialShares[j];
            }
            arrPos += 13 + campaign.initialShares.length;
        }
    }

    /// @dev Returns array of encoded investments an investor holds in campaigns.
    /// @param _campaignHashes Array of campaign hashes identifying campaigns.
    /// @return allShares Returns all user's shares.
    function getShares(address user, bytes32[] _campaignHashes)
        constant
        external
        returns (uint[] allShares)
    {
        // Calculate array size
        uint arrPos = 0;
        for (uint i=0; i<_campaignHashes.length; i++) {
            bytes32 campaignHash = _campaignHashes[i];
            if (shares[user][campaignHash] > 0) {
                arrPos += 2;
            }
        }
        // Fill array
        allShares = new uint[](arrPos);
        arrPos = 0;
        for (i=0; i<_campaignHashes.length; i++) {
            campaignHash = _campaignHashes[i];
            if (shares[user][campaignHash] > 0) {
                allShares[arrPos] = uint(campaignHash);
                allShares[arrPos + 1] = shares[user][campaignHash];
                arrPos += 2;
            }
        }
    }
}
