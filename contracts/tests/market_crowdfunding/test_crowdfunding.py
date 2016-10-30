from ..abstract_test import AbstractTestContract, accounts, keys, TransactionFailed


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.market_crowdfunding.test_crowdfunding
    """

    FEE_RANGE = 1000000
    THIRTY_DAYS = 2592000

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.outcome_token_name, self.outcome_token_library_name,
                                 self.dao_name, self.math_library_name, self.lmsr_name,
                                 self.market_factory_name, self.ultimate_oracle_name,
                                 self.ether_token_name, self.crowdfunding_name]

    def test(self):
        # Create event
        event_hash = self.create_event()
        # Start campaign
        market_address = self.market_factory.address
        fee = 100000  # 10%
        initial_funding = self.MIN_MARKET_BALANCE
        total_funding = initial_funding + self.calc_base_fee_for_shares(initial_funding)
        market_maker_address = self.lmsr.address
        closing_at_timestamp = self.s.block.timestamp + self.THIRTY_DAYS
        initial_shares = [initial_funding, initial_funding]
        shares_to_buy = [10 * 10**18, 1 * 10**18]
        # Calculate total costs of funding by adding the costs for initial buys to initial funding costs
        for outcome_index, number_of_shares in enumerate(shares_to_buy):
            costs = self.lmsr.calcCostsBuying("".zfill(64).decode('hex'), initial_funding, initial_shares,
                                              outcome_index, number_of_shares)
            total_funding += costs + costs * fee / self.FEE_RANGE + self.calc_base_fee_for_shares(number_of_shares)
            initial_shares[0] += costs
            initial_shares[1] += costs
            initial_shares[outcome_index] -= number_of_shares
        _campaign_hash = self.crowdfunding.startCampaign(market_address, event_hash, fee, initial_funding,
                                                         total_funding, market_maker_address, closing_at_timestamp,
                                                         shares_to_buy)
        # Returned campaign hash is equal to sha3 hash of campaign information
        campaign_hash = self.get_campaign_hash(market_address, event_hash, fee, initial_funding, total_funding,
                                               market_maker_address, closing_at_timestamp, shares_to_buy)
        self.assertEqual(campaign_hash, _campaign_hash)
        # One campaign hash is associated to the event hash
        self.assertEqual(self.crowdfunding.getCampaigns([campaign_hash])[4], self.b2i(event_hash))
        # Funding market
        user_1 = 0
        user_2 = 1
        # Users approves crowdfuning contract to trade tokens
        self.ether_token.approve(self.crowdfunding.address, initial_funding, sender=keys[user_1])
        self.ether_token.approve(self.crowdfunding.address, total_funding - initial_funding, sender=keys[user_2])
        # Users buy tokens with ether
        self.ether_token.buyTokens(sender=keys[user_1], value=initial_funding)
        self.ether_token.buyTokens(sender=keys[user_2], value=total_funding - initial_funding)
        # Funding campaign
        # User 1 funds campaign
        self.crowdfunding.fund(campaign_hash, initial_funding, sender=keys[user_1])
        # User 1 holds shares of campaign
        self.assertEqual(self.crowdfunding.shares(accounts[user_1], campaign_hash), initial_funding)
        # User 2 funds campaign
        self.crowdfunding.fund(campaign_hash, total_funding - initial_funding - 1, sender=keys[user_2])
        # User 2 holds shares of campaign
        self.assertEqual(self.crowdfunding.shares(accounts[user_2], campaign_hash), total_funding - initial_funding - 1)
        # Trying to create market fails because funding goal is not reached yet
        self.assertRaises(TransactionFailed, self.crowdfunding.createMarket, campaign_hash)
        # User 2 funds missing 1 Wei
        self.crowdfunding.fund(campaign_hash, 1, sender=keys[user_2])
        # Trying to create market succeeds now
        self.crowdfunding.createMarket(campaign_hash)
        # Campaign getter returns market hash as second element
        market_hash = self.crowdfunding.campaigns(campaign_hash)[4]
        # Share distribution in market is equal to initial shares
        self.assertEqual(initial_shares, self.market_factory.getShareDistributionWithTimestamp(market_hash)[1:])
        # User 1 fails to withdraw his funds, because the market has been created already
        self.assertRaises(TransactionFailed, self.crowdfunding.withdrawFunding, campaign_hash, sender=keys[user_1])
        # User 1 buys shares on the new market and market is collecting fees
        outcome = 1
        number_of_shares = 10 * 10 ** 18
        costs = self.lmsr.calcCostsBuying("".zfill(64).decode('hex'), initial_funding, initial_shares, outcome,
                                          number_of_shares)
        _fee = costs * (self.FEE_RANGE + fee) / self.FEE_RANGE - costs
        value = costs + _fee + self.calc_base_fee_for_shares(number_of_shares)
        # User 1 approves market contract to trade tokens
        self.ether_token.approve(self.market_factory.address, value, sender=keys[user_1])
        self.assertEqual(self.ether_token.allowance(accounts[user_1], self.market_factory.address), value)
        self.ether_token.buyTokens(value=value, sender=keys[user_1])
        # Buy transaction succeeded
        self.assertEqual(
            self.market_factory.buyShares(market_hash, outcome, number_of_shares, value, sender=keys[user_1]), value)
        # Fees have been generated from trade; fees are the third element
        self.assertGreater(self.market_factory.getMarket(market_hash)[2], 0)
        # Withdraw fees from market to distribute them among investors
        self.crowdfunding.withdrawContractFees(campaign_hash)
        # User 1 is a shareholder of the campaign
        self.assertGreater(self.crowdfunding.shares(accounts[user_1], campaign_hash), 0)
        # User 1 withdraws his share of collected fees
        self.crowdfunding.withdrawFees(campaign_hash, sender=keys[user_1])
        # User 1 lost his campaign share because he withdrew his share of collected fees
        self.assertEqual(self.crowdfunding.shares(accounts[user_1], campaign_hash), 0)
