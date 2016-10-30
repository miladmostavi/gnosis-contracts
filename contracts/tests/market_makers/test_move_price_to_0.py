from ..abstract_test import AbstractTestContract, accounts, keys, TransactionFailed


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.market_makers.test_move_price_to_0
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.outcome_token_name, self.outcome_token_library_name,
                                 self.dao_name, self.math_library_name, self.lmsr_name,
                                 self.market_factory_name, self.ultimate_oracle_name, self.ether_token_name]

    def test(self):
        # Create event
        event_hash = self.create_event()
        # Create market
        market_hash = self.create_market(event_hash)
        # User buys all outcomes
        user = 1
        outcome = 1
        opposite_outcome = 0
        number_of_shares = 100 * 10 ** 18  # 100 Ether
        loop_count = 10
        self.buy_ether_tokens(user=user, amount=number_of_shares * loop_count + self.calc_base_fee_for_shares(
            number_of_shares * loop_count), approved_contract=self.event_factory)
        self.event_factory.buyAllOutcomes(event_hash, number_of_shares * loop_count + self.calc_base_fee_for_shares(
            number_of_shares * loop_count), sender=keys[user])
        # User sells shares
        user_balance = self.ether_token.balanceOf(accounts[user])
        initial_funding = self.MIN_MARKET_BALANCE
        share_distribution = [initial_funding, initial_funding]
        earnings = 0
        # User approves market contract to trade/sell event shares
        self.event_factory.permitPermanentApproval(self.market_factory.address, sender=keys[user])
        for i in range(loop_count):
            # Calculate earnings for selling shares
            earnings = self.lmsr.calcEarningsSelling("".zfill(64).decode('hex'), initial_funding, share_distribution,
                                                     outcome, number_of_shares)
            if earnings == 0:
                break
            # Attempt fails because expected earnings are too high
            self.assertRaises(TransactionFailed, self.market_factory.sellShares, market_hash, outcome, number_of_shares,
                              earnings + 1, sender=keys[user])
            # Failed selling attempt does not influence costs
            self.assertEqual(
                self.lmsr.calcEarningsSelling("".zfill(64).decode('hex'), initial_funding, share_distribution, outcome,
                                              number_of_shares), earnings)
            # Selling shares successfully
            self.assertEqual(
                self.market_factory.sellShares(market_hash, outcome, number_of_shares, earnings, sender=keys[user]),
                earnings)
            # User has less shares now
            self.assertEqual(self.event_token(event_hash, outcome, "balanceOf", user, [accounts[user]]),
                             number_of_shares * (loop_count - 1 - i))
            # User has more Ether
            self.assertGreater(self.ether_token.balanceOf(accounts[user]), user_balance)
            # Market maker has more shares of sold outcome
            share_distribution[outcome] -= (earnings - number_of_shares)
            share_distribution[opposite_outcome] -= earnings
        # Selling of shares is worth less than 1 Wei
        self.assertEqual(earnings, 0)
