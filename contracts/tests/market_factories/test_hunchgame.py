from ..abstract_test import AbstractTestContract, accounts, keys, TransactionFailed


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.market_factories.test_hunchgame
    """

    TWELVE_HOURS = 43200
    CHALLENGE_PERIOD = 43200

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.outcome_token_library_name, self.dao_name,
                                 self.math_library_name, self.lmsr_name, self.hunchgame_name,
                                 self.ultimate_oracle_name, self.ether_token_name,
                                 self.outcome_token_name, self.hunchgame_token_name]

    def test(self):
        # Setup HunchGame token
        self.hunchgame_token.setup(self.hunchgame.address)
        # Create event with HunchGame token
        description_hash = "d621d969951b20c5cf2008cbfc282a2d496ddfe75a76afe7b6b32f1470b8a449".decode('hex')
        oracle_1 = 0
        oracle_2 = 1
        oracle_fee = 0
        oracle_token_address = self.ether_token.address
        v, r, s = self.sign_data(self.get_fee_hash(description_hash, oracle_fee, oracle_token_address),
                                 keys[oracle_1])  # signed fee of 0
        v_2, r_2, s_2 = self.sign_data(self.get_fee_hash(description_hash, oracle_fee, oracle_token_address),
                                       keys[oracle_2])  # signed fee of 0
        oracle_fees = [description_hash, self.i2b(oracle_fee), self.s2b(oracle_token_address), v, r, s,
                       self.i2b(oracle_fee), self.s2b(oracle_token_address), v_2, r_2, s_2]
        event_hash = self.create_event(data=oracle_fees, token_address=self.hunchgame_token.address)
        event_identifier = self.event_factory.getEvent(event_hash)[7]
        # Create market
        market_maker = 0
        initial_funding = self.MIN_MARKET_BALANCE
        self.assertEqual(self.hunchgame.getMinFunding(), initial_funding)
        market_hash = self.create_market(event_hash, token_contract=self.hunchgame_token,
                                         markets_contract=self.hunchgame, user=market_maker)
        # User adds credits to his account
        user = 1
        self.hunchgame.addCredit(sender=keys[user])
        self.assertEqual(self.hunchgame_token.balanceOf(accounts[user]), 1000 * 10 ** 18)
        self.assertEqual(self.hunchgame.getLastCredit(accounts[user]), 1410973349)
        # Adding credits another time fails, because time span to add new credits is not over yet
        self.assertRaises(TransactionFailed, self.hunchgame.addCredit, sender=keys[user])
        # Let time pass to add more credits
        self.s.block.timestamp += self.TWELVE_HOURS + 1
        # User adds credits to his account
        self.hunchgame.addCredit(sender=keys[user])
        self.assertEqual(self.hunchgame_token.balanceOf(accounts[user]), 2 * 1000 * 10 ** 18)
        # User buys more credits
        self.hunchgame.buyCredits(sender=keys[user], value=10 ** 18)  # Worth one Ether
        self.assertEqual(self.hunchgame_token.balanceOf(accounts[user]), 4 * 1000 * 10 ** 18)
        # User buys shares
        user = 1
        outcome = 1
        share_count = 10 ** 18
        share_distribution = [initial_funding, initial_funding]
        self.assertEqual(self.hunchgame.getTokensInEvents(accounts[user], [event_hash]), [])
        # Permanently approve hunchgame contract to trade event shares
        self.event_factory.permitPermanentApproval(self.hunchgame.address, sender=keys[user])
        # Calculating costs for buying shares
        shares_to_spend = self.buy_shares(market_hash, outcome=outcome, token_contract=self.hunchgame_token,
                                          markets_contract=self.hunchgame, share_count=share_count, user=user)
        self.assertEqual(self.event_token(event_hash, outcome, "balanceOf", user, [accounts[user]]), share_count)
        # User sells shares
        opposite_outcome = 0
        share_distribution[outcome] += shares_to_spend - share_count
        share_distribution[opposite_outcome] += shares_to_spend
        earnings = self.lmsr.calcEarningsSelling("".zfill(64).decode('hex'), initial_funding, share_distribution,
                                                 outcome, share_count / 2)
        self.assertEqual(self.hunchgame.sellShares(market_hash, outcome, share_count / 2, earnings, sender=keys[user]),
                         earnings)
        self.assertEqual(self.event_token(event_hash, outcome, "balanceOf", user, [accounts[user]]), share_count / 2)
        self.assertEqual(self.hunchgame.getTokensInEvents(accounts[user], [event_hash]),
                         [self.b2i(event_hash), shares_to_spend - earnings])
        # User short sells outcome
        share_distribution[outcome] -= (earnings - share_count / 2)
        share_distribution[opposite_outcome] -= earnings
        short_sell_share_count = share_count / 10
        earnings_2 = self.lmsr.calcEarningsSelling("".zfill(64).decode('hex'), initial_funding, share_distribution,
                                                   outcome, short_sell_share_count)
        self.assertEqual(self.event_token(event_hash, opposite_outcome, "balanceOf", user, [accounts[user]]), 0)
        self.assertEqual(
            self.hunchgame.shortSellShares(market_hash, outcome, short_sell_share_count, earnings_2, sender=keys[user]),
            short_sell_share_count - earnings_2 + self.calc_base_fee_for_shares(short_sell_share_count))
        self.assertEqual(self.event_token(event_hash, opposite_outcome, "balanceOf", user, [accounts[user]]),
                         share_count / 10)
        self.assertEqual(self.event_token(event_hash, outcome, "balanceOf", user, [accounts[user]]), share_count / 2)
        self.assertEqual(self.hunchgame.getTokensInEvents(accounts[user], [event_hash]), [self.b2i(event_hash), (
            shares_to_spend - earnings) + (short_sell_share_count - earnings_2 + self.calc_base_fee_for_shares(
                short_sell_share_count))])
        # Set winning outcome
        result = outcome
        result_hash = self.get_result_hash(description_hash, result)
        # Both oracles sign the same result
        v, r, s = self.sign_data(result_hash, keys[oracle_1])
        v_2, r_2, s_2 = self.sign_data(result_hash, keys[oracle_2])
        results = [self.i2b(result), v, r, s, self.i2b(result), v_2, r_2, s_2]
        self.s.mine(1)  # Don't submit outcome at block 0
        self.ultimate_oracle.setOutcome(event_identifier, results)
        # User redeems winnings
        self.assertEqual(self.hunchgame.getHighScores([accounts[user]]), [])
        # Wait until ultimate oracle challenge period is over
        self.s.block.timestamp += self.CHALLENGE_PERIOD
        # Redeem winnings now
        balance_before_winnings = self.hunchgame_token.balanceOf(accounts[user])
        winnings = self.hunchgame.redeemWinnings(event_hash, sender=keys[user])
        self.assertLess(balance_before_winnings, self.hunchgame_token.balanceOf(accounts[user]))
        self.assertEqual(self.event_token(event_hash, outcome, "balanceOf", user, [accounts[user]]), 0)
        self.assertEqual(self.hunchgame.getHighScores([accounts[user]]), [self.b2i(accounts[user]), winnings - (
            (shares_to_spend - earnings) + (
                short_sell_share_count - earnings_2 + self.calc_base_fee_for_shares(short_sell_share_count)))])
