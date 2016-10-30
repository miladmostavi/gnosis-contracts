from ..abstract_test import AbstractTestContract, accounts, keys, TransactionFailed


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.oracles.test_futarchy_oracle
    """

    ONE_YEAR = 31536000

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.outcome_token_name, self.outcome_token_library_name,
                                 self.dao_name, self.math_library_name, self.lmsr_name,
                                 self.market_factory_name, self.ether_token_name, self.ultimate_oracle_name,
                                 self.futarchy_oracle_name]

    def test(self):
        # Create futarchy decision
        market_maker = 0
        proposal_hash = "a621d969951b20c5cf2008cbfc282a2d496ddfe75a76afe7b6b32f1470b8a449".decode('hex')
        decision_time = self.s.block.timestamp + self.ONE_YEAR
        lower_bound = 0
        upper_bound = 100
        resolver_address = self.ultimate_oracle.address
        oracle_id = 0
        oracle_fee = 0
        oracle_token_address = self.ether_token.address
        v, r, s = self.sign_data(self.get_fee_hash(proposal_hash, oracle_fee, oracle_token_address),
                                 keys[oracle_id])  # signed fee of 10
        data = [proposal_hash, self.i2b(oracle_fee), self.s2b(oracle_token_address), v, r, s]
        initial_funding = self.MIN_MARKET_BALANCE
        investment = initial_funding + self.calc_base_fee_for_shares(initial_funding)
        investment += self.calc_base_fee_for_shares(investment)
        self.buy_ether_tokens(user=market_maker, amount=investment, approved_contract=self.futarchy_oracle)
        profiling_futarchy_decision = self.futarchy_oracle.createFutarchyDecision(proposal_hash, decision_time,
                                                                                  lower_bound, upper_bound,
                                                                                  resolver_address, data,
                                                                                  initial_funding,
                                                                                  sender=keys[market_maker],
                                                                                  profiling=True)
        print "Create futarchy decision gas costs: {}".format(profiling_futarchy_decision["gas"])
        parent_event_hash = self.get_event_hash(proposal_hash, False, 0, 0, 2, self.ether_token.address,
                                                self.futarchy_oracle.address, [proposal_hash])
        depended_event_hash_1 = self.get_event_hash(proposal_hash, True, lower_bound, upper_bound, 2,
                                                    self.event_factory.getOutcomeToken(parent_event_hash, 0).decode(
                                                        "hex"), resolver_address, data)
        depended_event_hash_2 = self.get_event_hash(proposal_hash, True, lower_bound, upper_bound, 2,
                                                    self.event_factory.getOutcomeToken(parent_event_hash, 1).decode(
                                                        "hex"), resolver_address, data)
        market_hash_1 = self.get_market_hash(depended_event_hash_1, self.futarchy_oracle.address, self.lmsr.address)
        market_hash_2 = self.get_market_hash(depended_event_hash_2, self.futarchy_oracle.address, self.lmsr.address)
        result_is_set = 0
        result = 0
        self.assertEqual(self.futarchy_oracle.getFutarchyDecisions([proposal_hash]),
                         [self.b2i(proposal_hash), self.b2i(market_hash_1), self.b2i(market_hash_2), decision_time,
                          result_is_set, result])
        # User buys shares on dependent market
        # User buys all outcomes from parent event to buy shares of dependent market
        user = 1
        parent_event_shares = 10 * 10 ** 18  # Shares valued 10 ether
        self.buy_ether_tokens(user=user, amount=parent_event_shares, approved_contract=self.event_factory)
        self.event_factory.buyAllOutcomes(parent_event_hash, parent_event_shares, sender=keys[user])
        # User buys shares of dependent market
        outcome = 1
        number_of_shares = 1 * 10 ** 18  # Shares valued 1 ether
        share_distribution = [initial_funding, initial_funding]
        shares_to_spend = self.lmsr.calcCostsBuying("".zfill(64).decode('hex'), initial_funding, share_distribution,
                                                    outcome, number_of_shares)
        shares_to_spend += self.calc_base_fee_for_shares(number_of_shares)
        # User approves market contract to transfer shares
        market_outcome_1 = 0
        self.assertTrue(self.event_token(parent_event_hash, market_outcome_1, "approve", user,
                                         [self.market_factory.address, shares_to_spend]))
        # Transaction is successful
        self.assertEqual(
            self.market_factory.buyShares(market_hash_1, outcome, number_of_shares, shares_to_spend, sender=keys[user]),
            shares_to_spend)
        # Number of shares of parent event outcome decreased
        self.assertEqual(self.event_token(parent_event_hash, market_outcome_1, "balanceOf", user, [accounts[user]]),
                         parent_event_shares - self.calc_base_fee(parent_event_shares) - shares_to_spend)
        # After buy transaction completed successfully buyer should have number_of_shares shares
        self.assertEqual(self.event_token(depended_event_hash_1, outcome, "balanceOf", user, [accounts[user]]),
                         number_of_shares)
        # ... and no shares of the other outcome
        self.assertEqual(self.event_token(depended_event_hash_1, 0, "balanceOf", user, [accounts[user]]), 0)
        # Set winning outcome
        # Fails, because decision date is not reached yet
        self.assertRaises(TransactionFailed, self.futarchy_oracle.setOutcome, proposal_hash, [])
        self.s.block.timestamp += self.ONE_YEAR
        self.futarchy_oracle.setOutcome(proposal_hash, [])
        # Winning outcome was set
        self.assertTrue(self.futarchy_oracle.isOutcomeSet(proposal_hash))
        # Market 1 is the winning market, because a user bought long shares on market 1
        self.assertEqual(self.futarchy_oracle.getOutcome(proposal_hash), 0)
