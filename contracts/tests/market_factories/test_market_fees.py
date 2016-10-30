from ..abstract_test import AbstractTestContract, keys


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.market_factories.test_market_fees
    """

    FEE_RANGE = 1000000

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.outcome_token_name, self.outcome_token_library_name,
                                 self.dao_name, self.math_library_name, self.lmsr_name,
                                 self.market_factory_name, self.ultimate_oracle_name, self.ether_token_name]

    def test(self):
        # Create event
        event_hash = self.create_event()
        # Create market
        market_maker = 0
        fee = 10000  # 1%
        initial_funding = self.MIN_MARKET_BALANCE
        market_hash = self.create_market(event_hash, fee=fee, initial_funding=initial_funding, user=market_maker)
        # Calculate costs to buy shares
        outcome = 0
        number_of_shares = 10**18
        share_distribution = [initial_funding, initial_funding]
        costs = self.lmsr.calcCostsBuying("".zfill(64).decode('hex'), initial_funding, share_distribution, outcome,
                                          number_of_shares)
        shares_to_spend = costs * fee / self.FEE_RANGE + costs
        shares_to_spend += self.calc_base_fee_for_shares(number_of_shares)
        # User buys shares
        user = 1
        self.ether_token.buyTokens(sender=keys[user], value=shares_to_spend)
        self.ether_token.approve(self.market_factory.address, shares_to_spend, sender=keys[user])
        self.assertEqual(
            self.market_factory.buyShares(market_hash, outcome, number_of_shares, shares_to_spend, sender=keys[user]),
            shares_to_spend)
        # Fees have been collected by market
        self.assertGreater(self.market_factory.getMarket(market_hash)[2], 0)
        # Market maker withdraws his collected fees
        self.market_factory.withdrawFees(market_hash, sender=keys[market_maker])
        # Fees have been withdrawn from market
        self.assertEqual(self.market_factory.getMarket(market_hash)[2], 0)
