from ..abstract_test import AbstractTestContract, accounts, keys


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.market_factories.test_create_and_close_market
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.outcome_token_library_name, self.dao_name,
                                 self.math_library_name, self.lmsr_name, self.market_factory_name,
                                 self.ultimate_oracle_name, self.ether_token_name,
                                 self.outcome_token_name]

    def test(self):
        # Create event
        outcome_count = 2
        event_hash = self.create_event(outcome_count=outcome_count)
        # Create market
        # User buys Ether tokens
        market_maker = 0
        initial_funding = self.MIN_MARKET_BALANCE
        initial_funding_investment = initial_funding + self.calc_base_fee_for_shares(initial_funding)
        self.ether_token.buyTokens(value=initial_funding_investment, sender=keys[market_maker])
        self.assertEqual(self.ether_token.balanceOf(accounts[market_maker]), initial_funding_investment)
        self.ether_token.approve(self.market_factory.address, initial_funding_investment)
        self.assertEqual(self.ether_token.allowance(accounts[market_maker], self.market_factory.address),
                         initial_funding_investment)
        # Create market
        fee = 0
        profiling_create_market = self.market_factory.createMarket(event_hash, fee, initial_funding, self.lmsr.address,
                                                                   sender=keys[market_maker], profiling=True)
        print "Create market gas costs: {}".format(profiling_create_market["gas"])
        market_hash = profiling_create_market['output']
        # Market hash is equal to sha3 hash of event hash, investor address and market maker address
        self.assertEqual(market_hash, self.get_market_hash(event_hash, accounts[market_maker], self.lmsr.address))
        self.assertEqual(self.event_factory.getShares(self.market_factory.address, [event_hash]),
                         [self.b2i(event_hash), outcome_count, initial_funding, initial_funding])
        # Close market
        profiling_close_market = self.market_factory.closeMarket(market_hash, profiling=True)
        self.assertEqual(len(self.market_factory.getMarkets([market_hash], 0)), 0)
        print "Close market gas costs: {}".format(profiling_close_market["gas"])
        self.assertEqual(self.market_factory.getMarket(market_hash)[0], "".zfill(64).decode('hex'))
        # Create two markets
        market_maker_1 = 1
        market_hash_1 = self.create_market(event_hash=event_hash, user=market_maker_1)
        # The second market is created by another investor
        market_maker_2 = 2
        market_hash_2 = self.create_market(event_hash=event_hash, user=market_maker_2)
        # Market hashes are different, because they have been created by different investors
        self.assertNotEqual(market_hash_1, market_hash_2)
        # Only two markets are returned, because first market was closed
        self.assertEqual(len(self.market_factory.getMarkets([market_hash, market_hash_1, market_hash_2], 20)), 0)
        # There are three markets associated to the event hash
        self.assertEqual(self.market_factory.getMarketHashes([event_hash],
                                                             [accounts[market_maker], accounts[market_maker_1],
                                                              accounts[market_maker_2]]),
                         [self.b2i(event_hash), 3, self.b2i(market_hash), self.b2i(market_hash_1),
                          self.b2i(market_hash_2)])
        # Close the first market
        self.market_factory.closeMarket(market_hash_1, sender=keys[market_maker_1])
        # There is only one market left associated to the event hash
        self.assertEqual(len(self.market_factory.getMarkets([market_hash, market_hash_1, market_hash_2], 10)), 0)
