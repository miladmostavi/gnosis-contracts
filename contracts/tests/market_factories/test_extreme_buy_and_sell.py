from ..abstract_test import AbstractTestContract, accounts, keys


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.market_factories.test_extreme_buy_and_sell
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.outcome_token_library_name, self.dao_name,
                                 self.math_library_name, self.lmsr_name, self.market_factory_name,
                                 self.ultimate_oracle_name, self.ether_token_name,
                                 self.outcome_token_name]

    def test(self):
        # Create event
        event_hash = self.create_event()
        # Create market
        initial_funding = 10**19
        market_hash = self.create_market(event_hash, initial_funding=initial_funding)
        # Calculate costs to buy shares
        outcome = 0
        number_of_shares = 10**20
        share_distribution = [initial_funding, initial_funding]
        shares_to_spend = self.lmsr.calcCostsBuying("".zfill(64).decode('hex'), initial_funding, share_distribution,
                                                    outcome, number_of_shares)
        shares_to_spend += self.calc_base_fee_for_shares(number_of_shares)
        # User buys Ether tokens
        user = 0
        value = shares_to_spend
        self.ether_token.buyTokens(value=value, sender=keys[user])
        self.assertEqual(self.ether_token.balanceOf(accounts[user]), value)
        self.ether_token.approve(self.market_factory.address, value)
        self.assertEqual(self.ether_token.allowance(accounts[user], self.market_factory.address), value)
        # User buys shares
        user = 0
        profiling_buy = self.market_factory.buyShares(
            market_hash, outcome, number_of_shares, shares_to_spend, sender=keys[user], profiling=True)
        print "Buy shares gas costs: {}".format(profiling_buy["gas"])
        # Transaction was successful
        self.assertEqual(profiling_buy["output"], shares_to_spend)
        # After buy transaction completed successfully buyer has number_of_shares shares
        self.assertEqual(self.event_factory.getShares(accounts[user], [event_hash]),
                         [self.b2i(event_hash), 2, number_of_shares, 0])
        # Calculate earnings for selling shares
        # Market maker holds more shares of opposite outcome
        opposite_outcome = 1
        share_distribution[outcome] += shares_to_spend - number_of_shares
        share_distribution[opposite_outcome] += shares_to_spend
        money_to_earn = self.lmsr.calcEarningsSelling("".zfill(64).decode('hex'), initial_funding, share_distribution,
                                                      outcome, number_of_shares)
        # Approve market contract to transfer shares
        self.event_token(event_hash, outcome, "approve", user, [self.market_factory.address, number_of_shares])
        # Sell shares
        profiling_sell = self.market_factory.sellShares(
            market_hash, outcome, number_of_shares, money_to_earn, sender=keys[user], profiling=True)
        print "Sell shares gas costs: {}".format(profiling_sell["gas"])
        # Transaction was successful
        self.assertEqual(profiling_sell["output"], money_to_earn)
        # After sell transaction completed successfully seller has half of his shares left
        self.assertEqual(self.event_factory.getShares(accounts[user], [event_hash]), [])
