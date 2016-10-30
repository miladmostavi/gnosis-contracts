from ..abstract_test import AbstractTestContract


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.market_makers.test_calc_costs_and_earnings
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.lmsr_name, self.math_library_name]

    def test(self):
        # Calculating costs for buying shares and earnings for selling shares
        outcome = 1
        initial_funding = self.MIN_MARKET_BALANCE
        share_distribution = [initial_funding, initial_funding]
        number_of_shares = 10**18
        self.assertEqual(
            self.lmsr.calcCostsBuying(
                "".zfill(64).decode('hex'), initial_funding, share_distribution, outcome, number_of_shares
            ),
            508672777026889653
        )
        self.assertEqual(
            self.lmsr.calcEarningsSelling(
                "".zfill(64).decode('hex'), initial_funding, share_distribution, outcome, number_of_shares
            ),
            491327565610525849
        )
