from ..abstract_test import AbstractTestContract, accounts, keys


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.market_factories.test_short_selling
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.outcome_token_name, self.outcome_token_library_name,
                                 self.dao_name, self.math_library_name, self.lmsr_name,
                                 self.market_factory_name, self.ultimate_oracle_name, self.ether_token_name]

    def test(self):
        # Create event
        event_hash = self.create_event(outcome_count=4)
        initial_funding = self.MIN_MARKET_BALANCE
        # Create market
        market_hash = self.create_market(event_hash)
        # Market contract has shares from both outcomes equal to MIN_MARKET_BALANCE
        self.assertEqual(self.event_token(event_hash, 0, "balanceOf", 0, [self.market_factory.address]),
                         initial_funding)
        self.assertEqual(self.event_token(event_hash, 1, "balanceOf", 0, [self.market_factory.address]),
                         initial_funding)
        self.assertEqual(self.event_token(event_hash, 2, "balanceOf", 0, [self.market_factory.address]),
                         initial_funding)
        self.assertEqual(self.event_token(event_hash, 3, "balanceOf", 0, [self.market_factory.address]),
                         initial_funding)
        # Short sell shares
        outcome = 0
        number_of_shares = 10 ** 18
        buy_all_outcomes_value = number_of_shares + self.calc_base_fee_for_shares(number_of_shares)
        # Calc total investment
        share_distribution = [initial_funding, initial_funding, initial_funding, initial_funding]
        earnings = self.lmsr.calcEarningsSelling("".zfill(64).decode('hex'), initial_funding, share_distribution,
                                                 outcome, number_of_shares)
        investment = buy_all_outcomes_value - earnings
        # Short sell shares
        user = 0
        self.buy_ether_tokens(user=user, amount=buy_all_outcomes_value, approved_contract=self.market_factory)
        profiling_short_sell = self.market_factory.shortSellShares(market_hash, outcome, number_of_shares, earnings,
                                                                   sender=keys[user], profiling=True)
        print "Sell shares gas costs: {}".format(profiling_short_sell["gas"])
        self.assertEqual(profiling_short_sell["output"], investment)
        self.assertEqual(self.event_token(event_hash, outcome, "balanceOf", 0, [accounts[user]]), 0)
        self.assertEqual(self.event_token(event_hash, 1, "balanceOf", 0,  [accounts[user]]), number_of_shares)
        self.assertEqual(self.event_token(event_hash, 2, "balanceOf", 0,  [accounts[user]]), number_of_shares)
        self.assertEqual(self.event_token(event_hash, 3, "balanceOf", 0,  [accounts[user]]), number_of_shares)
