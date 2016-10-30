from ..abstract_test import AbstractTestContract, accounts, keys


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.oracles.test_oraclize_oracle
    """

    ONE_WEEK = 604800

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.outcome_token_library_name, self.dao_name,
                                 self.math_library_name, self.lmsr_name, self.market_factory_name,
                                 self.ether_token_name, self.outcome_token_name,
                                 self.oraclize_name, self.oraclize_oracle_name]

    def test(self):
        def split_string(x, chunk_size=32):
            return [x[i:i+chunk_size] for i in range(0, len(x), chunk_size)]
        # Create event
        data_source_indexes = {
            "URL": 0,
            "WolframAlpha": 1,
            "Blockchain": 2
        }
        data_sources = dict((v, k) for k, v in data_source_indexes.iteritems())
        data_source_index = data_source_indexes["URL"]
        url = "json(https://api.kraken.com/0/public/Ticker?pair=ETHXBT).result.XETHXXBT.c.0"
        url_data = split_string(url)
        self.assertEqual(self.oraclize_oracle.bytes32ArrayToString(url_data), url)
        self.assertEqual(self.oraclize_oracle.parseToInt("100.12", 2), 10012)
        timestamp = self.s.block.timestamp + self.ONE_WEEK
        precision = 5
        event_data = [self.i2b(data_source_index), self.i2b(timestamp), self.i2b(precision)] + url_data
        lower_bound = int(0.00100 * 10**precision)
        upper_bound = int(0.00855 * 10**precision)
        event_hash = self.create_event(is_ranged=True, data=event_data, upper_bound=upper_bound,
                                       lower_bound=lower_bound, oracle_address=self.oraclize_oracle.address,
                                       outcome_count=2)
        event_identifier = self.event_factory.getEvent(event_hash)[7]
        self.assertEqual(self.oraclize_oracle.getEventData(event_identifier)[:2], url_data[:2])
        # Create market
        market_maker = 0
        market_hash = self.create_market(event_hash, user=market_maker)
        # Buy shares
        outcome = 1
        number_of_shares = 10**18
        user = 1
        self.buy_shares(market_hash, outcome=outcome, share_count=number_of_shares, user=user)
        # After buy transaction completed buyer has number_of_shares shares
        self.assertEqual(self.event_token(event_hash, outcome, "balanceOf", user,  [accounts[user]]), number_of_shares)
        # Set winning outcome
        result = "0.0080"
        proof = self.s2b("This is true :)")
        data_source = data_sources[data_source_index]
        self.oraclize.oraclize_setResult(timestamp, data_source, url, result, proof)
        self.assertTrue(self.oraclize_oracle.isOutcomeSet(event_identifier))
        # User redeems winnings
        balance_before_winnings = self.ether_token.balanceOf(accounts[user])
        self.event_factory.redeemWinnings(event_hash, sender=keys[user])
        # User has no shares left
        self.assertEqual(self.event_token(event_hash, outcome, "balanceOf", user,  [accounts[user]]), 0)
        self.assertLess(balance_before_winnings, self.ether_token.balanceOf(accounts[user]))
