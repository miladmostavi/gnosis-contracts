from ..abstract_test import AbstractTestContract, accounts, keys


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.event_factory.test_buy_and_sell_all_outcomes
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.dao_name, self.ultimate_oracle_name,
                                 self.outcome_token_library_name, self.ether_token_name]

    def test(self):
        # Create event
        outcome_count = 2
        event_hash = self.create_event(outcome_count=outcome_count)
        value = 10
        # User buys Ether tokens
        user = 0
        self.ether_token.buyTokens(value=value, sender=keys[user])
        self.assertEqual(self.ether_token.balanceOf(accounts[user]), value)
        self.ether_token.approve(self.event_factory.address, value)
        self.assertEqual(self.ether_token.allowance(accounts[user], self.event_factory.address), value)
        # User buys all outcomes for 10 Wei
        profiling_buy_all = self.event_factory.buyAllOutcomes(
            event_hash, value, sender=keys[user], profiling=True)
        print "Buy all outcomes gas costs: {}".format(profiling_buy_all["gas"])
        # After buying of all outcomes for 10 Wei user has 10 shares of each outcome
        self.assertEqual(self.event_factory.getShares(accounts[user], [event_hash]),
                         [self.b2i(event_hash), outcome_count, value, value])
        # User sells all outcomes
        user_balance = self.ether_token.balanceOf(accounts[user])
        profiling_sell_all = self.event_factory.sellAllOutcomes(
            event_hash, value, sender=keys[user], profiling=True)
        print "Redeem all outcomes gas costs: {}".format(profiling_sell_all["gas"])
        # User has no shares left
        self.assertEqual(self.event_factory.getShares(accounts[user], [event_hash]), [])
        # User's balance increased
        self.assertGreater(self.ether_token.balanceOf(accounts[user]), user_balance)
