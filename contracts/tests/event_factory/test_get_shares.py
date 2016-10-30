from ..abstract_test import AbstractTestContract, accounts


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.event_factory.test_get_shares
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.outcome_token_library_name, self.dao_name,
                                 self.math_library_name, self.lmsr_name, self.market_factory_name,
                                 self.ultimate_oracle_name, self.ether_token_name,
                                 self.outcome_token_name]

    def test(self):
        # Create events
        description_hash_1 = "d621d969951b20c5cf2008cbfc282a2d496ddfe75a76afe7b6b32f1470b8a449".decode('hex')
        description_hash_2 = "d621d969951b20c5cf2008cbfc282a2d496ddfe75a76afe7b6b32f1470b8a448".decode('hex')
        event_hash_1 = self.create_event(description_hash=description_hash_1)
        event_hash_2 = self.create_event(description_hash=description_hash_2)
        user = 0
        self.assertEqual(self.event_factory.getShares(accounts[user], [event_hash_1, event_hash_2]), [])
        # Create markets
        initial_funding = self.MIN_MARKET_BALANCE
        market_hash_1 = self.create_market(event_hash_1, initial_funding=initial_funding)
        market_hash_2 = self.create_market(event_hash_2, initial_funding=initial_funding)
        # Buy shares
        # User buys shares
        outcome_1 = 1
        share_count = 10**18
        self.buy_shares(market_hash_1, user=user, outcome=outcome_1, share_count=share_count)
        outcome_2 = 0
        self.buy_shares(market_hash_2, user=user, outcome=outcome_2, share_count=share_count)
        # User owns share_count shares in both markets
        self.assertEqual(self.event_token(event_hash_1, outcome_1, "balanceOf", user,  [accounts[user]]), share_count)
        self.assertEqual(self.event_token(event_hash_2, outcome_2, "balanceOf", user,  [accounts[user]]), share_count)
        # Returns number of shares for each event
        self.assertEqual(self.event_factory.getShares(accounts[user], [event_hash_1, event_hash_2]),
                         [self.b2i(event_hash_1), 2, 0, share_count,
                          self.b2i(event_hash_2), 2, share_count, 0])
