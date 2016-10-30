from ..abstract_test import AbstractTestContract, accounts, keys


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.oracles.test_difficulty_oracle
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.outcome_token_library_name, self.dao_name,
                                 self.math_library_name, self.lmsr_name, self.market_factory_name,
                                 self.ether_token_name, self.outcome_token_name,
                                 self.difficulty_oracle_name]

    def test(self):
        # Create event
        block_number = self.HOMESTEAD_BLOCK + 10
        lower_bound = 0
        upper_bound = 150000
        event_data = [self.i2b(block_number)]
        event_hash = self.create_event(is_ranged=True,
                                       outcome_count=2,
                                       lower_bound=lower_bound,
                                       upper_bound=upper_bound,
                                       oracle_address=self.difficulty_oracle.address,
                                       data=event_data)
        event_identifier = self.event_factory.getEvent(event_hash)[7]
        self.assertEqual(self.difficulty_oracle.getEventData(event_identifier)[0], self.i2b(block_number))
        # Create market
        market_maker = 0
        market_hash = self.create_market(event_hash, user=market_maker)
        # Buy shares
        number_of_shares = 10**18
        outcome = 1
        user = 1
        self.buy_shares(market_hash, share_count=number_of_shares, outcome=outcome, user=user)
        self.assertEqual(self.event_token(event_hash, outcome, "balanceOf", user,  [accounts[user]]), number_of_shares)
        # Set winning outcome
        self.s.mine(20)
        self.difficulty_oracle.setOutcome(event_identifier, [])
        # User redeems winnings
        balance_before_winnings = self.ether_token.balanceOf(accounts[user])
        self.event_factory.redeemWinnings(event_hash, sender=keys[user])
        # User has no shares left
        self.assertEqual(self.event_token(event_hash, outcome, "balanceOf", user,  [accounts[user]]), 0)
        self.assertLess(balance_before_winnings, self.ether_token.balanceOf(accounts[user]))
