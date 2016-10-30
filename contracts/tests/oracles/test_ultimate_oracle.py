from ..abstract_test import AbstractTestContract, accounts, keys, TransactionFailed


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.oracles.test_ultimate_oracle
    """

    TWENTY_FOUR_HOURS = 86400  # 24h
    CHALLENGE_FEE = 10 ** 18 * 100  # 100 Ether

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.outcome_token_name, self.outcome_token_library_name,
                                 self.dao_name, self.math_library_name, self.lmsr_name, self.fallback_oracle_name,
                                 self.market_factory_name, self.ultimate_oracle_name, self.ether_token_name]

    def test(self):
        # Create event
        description_hash = "d621d969951b20c5cf2008cbfc282a2d496ddfe75a76afe7b6b32f1470b8a449".decode('hex')
        event_hash = self.create_event(outcome_count=2, description_hash=description_hash)
        event_identifier = self.event_factory.getEvent(event_hash)[7]
        # Check event data
        oracle_id = 0
        self.assertEqual(self.b2i(self.ultimate_oracle.getEventData(event_identifier)[0]),
                         self.h2i(description_hash.encode("hex")))
        self.assertEqual(self.b2i(self.ultimate_oracle.getEventData(event_identifier)[1]),
                         self.b2i(accounts[oracle_id]))
        # Create market
        initial_funding = self.MIN_MARKET_BALANCE
        market_hash = self.create_market(event_hash, initial_funding=initial_funding)
        # User buys shares
        user_1 = 1
        outcome = 1
        share_count = 10**18
        self.buy_shares(market_hash, user=user_1, outcome=outcome, share_count=share_count)
        # Fallback oracle is registered
        self.ultimate_oracle.registerFallbackOracle(self.fallback_oracle.address, sender=keys[oracle_id])
        self.assertEqual(self.ultimate_oracle.getFallbackOracles([accounts[oracle_id]]),
                         [self.fallback_oracle.address.encode('hex')])
        # Oracle was compromised, we set it as invalid in fallback oracle
        self.fallback_oracle.setInvalidSigner(accounts[oracle_id])
        # Ops, we set wrong winning outcome in fallback oracle
        result_fallback = 0  # wrong outcome
        self.fallback_oracle.setOutcome(description_hash, result_fallback)
        # Compromised oracle sets wrong winning outcome
        result = 222  # wrong outcome
        result_hash = self.get_result_hash(description_hash, result)
        # Oracle signs data
        v, r, s = self.sign_data(result_hash, keys[oracle_id])
        results = [self.i2b(result), v, r, s]
        timestamp = self.s.block.timestamp
        self.ultimate_oracle.setOutcome(event_identifier, results)
        # Fallback oracle result was used
        self.assertEqual(self.ultimate_oracle.getOracleOutcomes([description_hash], [accounts[oracle_id]]),
                         [self.b2i(description_hash), 1, self.b2i(accounts[oracle_id]), timestamp, result_fallback, 0])
        # User challenges oracle
        self.buy_ether_tokens(user_1, self.CHALLENGE_FEE, approved_contract=self.ultimate_oracle)
        self.ultimate_oracle.challengeOracle(description_hash, accounts[oracle_id], outcome, sender=keys[user_1])
        self.assertEqual(self.ultimate_oracle.shares(accounts[user_1], description_hash, outcome), self.CHALLENGE_FEE)
        # User 2 votes for wrong outcome but doesn't change front runner
        voting_outcome = 0
        vote_value_2 = 10 * 10 ** 18
        user_2 = 2
        self.buy_ether_tokens(user_2, vote_value_2, approved_contract=self.ultimate_oracle)
        self.ultimate_oracle.voteForUltimateOutcome(description_hash, voting_outcome, vote_value_2,
                                                                    sender=keys[user_2])
        self.assertEqual(self.ultimate_oracle.shares(accounts[user_2], description_hash, voting_outcome), vote_value_2)
        # Redeem winnings fails because oracle has been challenged
        self.assertEqual(self.ultimate_oracle.isOutcomeSet(event_identifier), False)
        self.assertRaises(TransactionFailed, self.event_factory.redeemWinnings, event_hash, sender=keys[user_1])
        # User still has all of his shares
        self.assertEqual(self.event_token(event_hash, outcome, "balanceOf", user_1, [accounts[user_1]]), share_count)
        # Wait until ultimate oracle challenge period is over
        self.s.block.timestamp += self.TWENTY_FOUR_HOURS
        timestamp = self.s.block.timestamp
        self.ultimate_oracle.setUltimateOutcome(description_hash)
        self.assertEqual(self.ultimate_oracle.getUltimateOutcomes([description_hash], [voting_outcome]),
                         [self.b2i(description_hash), 1, timestamp, outcome, self.CHALLENGE_FEE + vote_value_2,
                          self.CHALLENGE_FEE, vote_value_2, 0, 0, 0])
        # User 1 redeems his winnings
        balance_before_winnings = self.ether_token.balanceOf(accounts[user_1])
        self.assertEqual(self.ultimate_oracle.isOutcomeSet(event_identifier), True)
        self.assertEqual(self.ultimate_oracle.getOutcome(event_identifier), outcome)
        self.event_factory.redeemWinnings(event_hash, sender=keys[user_1])
        self.assertEqual(self.event_token(event_hash, outcome, "balanceOf", user_1, [accounts[user_1]]), 0)
        # User won, his balance increased
        self.assertGreater(self.ether_token.balanceOf(accounts[user_1]), balance_before_winnings)
        # User withdraws shares
        self.assertEqual(self.ultimate_oracle.getShares(accounts[user_1], [description_hash], [outcome]),
                         [self.CHALLENGE_FEE])
        self.assertEqual(self.ultimate_oracle.getShares(accounts[user_2], [description_hash], [voting_outcome]),
                         [vote_value_2])
        self.ultimate_oracle.redeemWinnings(description_hash, sender=keys[user_1])
        self.assertEqual(self.ultimate_oracle.shares(accounts[user_1], description_hash, outcome), 0)
