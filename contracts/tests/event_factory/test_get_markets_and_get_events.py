from ..abstract_test import AbstractTestContract, accounts


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.event_factory.test_get_markets_and_get_events
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
        is_ranged_1 = False
        outcome_count = 2
        resolver_address = self.ultimate_oracle.address
        token_address = self.ether_token.address
        result = 0
        result_is_set = 0
        event_hash_1 = self.create_event(description_hash=description_hash_1, is_ranged=is_ranged_1,
                                         outcome_count=outcome_count, oracle_address=resolver_address)
        lower_bound = 0
        upper_bound = 100
        is_ranged_2 = True
        event_hash_2 = self.create_event(description_hash=description_hash_2, is_ranged=is_ranged_2,
                                         lower_bound=lower_bound, upper_bound=upper_bound, outcome_count=outcome_count,
                                         oracle_address=resolver_address)
        # Event hashes are associated to their corresponding description hashes
        self.assertEqual(self.event_factory.getEventHashes([description_hash_1, description_hash_2], [accounts[0]]),
                         [self.b2i(description_hash_1), 1, self.b2i(event_hash_1),
                          self.b2i(description_hash_2), 1, self.b2i(event_hash_2)])
        # Returns encoded events associated to their event hashes
        self.assertEqual(self.event_factory.getEvents([event_hash_1, event_hash_2], 0, 0),
                         self.event_factory.getEvents([event_hash_1, event_hash_2], resolver_address, 0))
        self.assertNotEqual(self.event_factory.getEvents([event_hash_1, event_hash_2], 0, 0),
                            self.event_factory.getEvents([event_hash_1, event_hash_2], 1, 0))
        # Filter by tokenAddress
        self.assertEqual(self.event_factory.getEvents([event_hash_1, event_hash_2], 0, 0),
                         self.event_factory.getEvents([event_hash_1, event_hash_2], 0, token_address))
        self.assertNotEqual(self.event_factory.getEvents([event_hash_1, event_hash_2], 0, 0),
                            self.event_factory.getEvents([event_hash_1, event_hash_2], 0, 1))

        oracle_event_identifier_1 = self.event_factory.getEvent(event_hash_1)[7]
        oracle_event_identifier_2 = self.event_factory.getEvent(event_hash_2)[7]

        self.assertEqual(self.event_factory.getEvents([event_hash_1, event_hash_2], 0, 0), [
            self.b2i(event_hash_1),
            self.b2i(description_hash_1),
            1 if is_ranged_1 else 0,
            0,
            0,
            self.b2i(token_address),
            self.b2i(resolver_address),
            self.b2i(oracle_event_identifier_1),
            result_is_set,
            result,
            outcome_count,
            self.h2i(self.event_factory.getOutcomeToken(event_hash_1, 0)),
            self.h2i(self.event_factory.getOutcomeToken(event_hash_1, 1)),
            # 2nd event
            self.b2i(event_hash_2),
            self.b2i(description_hash_2),
            1 if is_ranged_2 else 0,
            lower_bound,
            upper_bound,
            self.b2i(token_address),
            self.b2i(resolver_address),
            self.b2i(oracle_event_identifier_2),
            result_is_set,
            result,
            outcome_count,
            self.h2i(self.event_factory.getOutcomeToken(event_hash_2, 0)),
            self.h2i(self.event_factory.getOutcomeToken(event_hash_2, 1))
        ])

        # Create markets
        initial_funding = self.MIN_MARKET_BALANCE
        market_maker_1 = 0
        market_maker_2 = 1
        market_hash_1 = self.create_market(event_hash_1, initial_funding=initial_funding, user=market_maker_1)
        market_hash_2 = self.create_market(event_hash_2, initial_funding=initial_funding, user=market_maker_2)
        fee = 0
        collected_fee = 0
        created_at_block = self.s.block.number
        # Market hashes are associated to their corresponding event hashes
        self.assertEqual(self.market_factory.getMarketHashes([event_hash_1, event_hash_2],
                                                             [accounts[market_maker_1], accounts[market_maker_2]]),
                         [self.b2i(event_hash_1), 1, self.b2i(market_hash_1),
                          self.b2i(event_hash_2), 1, self.b2i(market_hash_2)])
        self.assertEqual(self.market_factory.getMarkets([market_hash_1], 0),
                         self.market_factory.getMarkets([market_hash_1, market_hash_2], accounts[market_maker_1]))
        self.assertNotEqual(self.market_factory.getMarkets([market_hash_2], 0),
                            self.market_factory.getMarkets([market_hash_1, market_hash_2], accounts[market_maker_1]))
        self.assertEqual(self.market_factory.getMarkets([market_hash_1, market_hash_2], 0),
                         [self.b2i(market_hash_1), self.b2i(event_hash_1), fee, collected_fee, initial_funding,
                          self.b2i(accounts[market_maker_1]), self.b2i(self.lmsr.address), created_at_block, 2,
                          initial_funding, initial_funding,
                          self.b2i(market_hash_2), self.b2i(event_hash_2), fee, collected_fee, initial_funding,
                          self.b2i(accounts[market_maker_2]), self.b2i(self.lmsr.address), created_at_block, 2,
                          initial_funding, initial_funding])
