from ..abstract_test import AbstractTestContract, accounts, keys


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.market_makers.test_move_price_to_1
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
        # User buys shares
        user = 1
        outcome = 1
        opposite_outcome = 0
        number_of_shares = 50 * 10 ** 18  # 10 Ether
        loop_count = 10
        initial_funding = self.MIN_MARKET_BALANCE
        share_distribution = [initial_funding, initial_funding]
        costs = 0
        self.buy_ether_tokens(user=user, amount=number_of_shares * loop_count + self.calc_base_fee_for_shares(
            number_of_shares * loop_count), approved_contract=self.market_factory)
        for i in range(loop_count):
            # Calculating costs for buying shares
            costs = self.lmsr.calcCostsBuying("".zfill(64).decode('hex'), initial_funding, share_distribution, outcome,
                                              number_of_shares)
            # Commented out, because base fee is now 0
            # # Attempt fails because costs are higher, base fee is missing
            # self.assertEqual(
            #     self.market_factory.buyShares(market_hash, outcome, number_of_shares, costs, sender=keys[user]), 0)
            # Failed buying attempt does not influence costs
            self.assertEqual(
                self.lmsr.calcCostsBuying("".zfill(64).decode('hex'), initial_funding, share_distribution, outcome,
                                          number_of_shares), costs)
            # Buying shares successfully
            costs_and_fee = costs + self.calc_base_fee_for_shares(number_of_shares)
            self.market_factory.buyShares(market_hash, outcome, number_of_shares, costs_and_fee, sender=keys[user])
            # User has more shares
            self.assertEqual(self.event_token(event_hash, outcome, "balanceOf", user, [accounts[user]]),
                             number_of_shares * (i + 1))
            # Market maker increases shares of the opposite outcome
            share_distribution[outcome] += costs - number_of_shares
            share_distribution[opposite_outcome] += costs
        # Price is equal to 1
        self.assertEqual(costs, number_of_shares)
