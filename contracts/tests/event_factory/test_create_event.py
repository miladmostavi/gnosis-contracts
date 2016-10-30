from ..abstract_test import AbstractTestContract, keys


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.event_factory.test_create_event
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.dao_name, self.ultimate_oracle_name,
                                 self.outcome_token_library_name, self.ether_token_name]

    def test(self):
        # Create event
        oracle_1 = 0
        oracle_2 = 1
        description_hash = 'd621d969951b20c5cf2008cbfc282a2d496ddfe75a76afe7b6b32f1470b8a449'.decode('hex')
        is_ranged = False
        lower_bound = 0
        upper_bound = 0
        outcome_count = 2
        resolver_address = self.ultimate_oracle.address
        # Two oracles are used, their public keys are passed in event_data
        oracle_fee = 10
        oracle_token_address = self.ether_token.address
        # Signed fee of 0 for first oracle
        v, r, s = self.sign_data(self.get_fee_hash(description_hash, oracle_fee, oracle_token_address), keys[oracle_1])
        # Signed fee of 0 for second oracle
        v_2, r_2, s_2 = self.sign_data(self.get_fee_hash(description_hash, oracle_fee, oracle_token_address),
                                       keys[oracle_2])
        oracle_fees = [description_hash, self.i2b(oracle_fee), self.s2b(oracle_token_address), v, r, s,
                       self.i2b(oracle_fee), self.s2b(oracle_token_address), v_2, r_2, s_2]
        token_address = self.ether_token.address
        # Validate calculated oracle fee
        total_fee = oracle_fee * 2
        self.assertEqual(self.ultimate_oracle.getFee(oracle_fees), [total_fee, self.ether_token.address.encode('hex')])
        # Buy tokens to pay fee
        event_creator = 0
        self.ether_token.buyTokens(value=total_fee, sender=keys[event_creator])
        self.ether_token.approve(self.event_factory.address, total_fee, sender=keys[event_creator])
        # Create event transaction
        profiling_create_event = self.event_factory.createEvent(description_hash,
                                                                is_ranged,
                                                                lower_bound,
                                                                upper_bound,
                                                                outcome_count,
                                                                token_address,
                                                                resolver_address,
                                                                oracle_fees,
                                                                sender=keys[event_creator],
                                                                profiling=True)
        print "Create event with 2 oracles gas costs: {}".format(profiling_create_event["gas"])
        event_hash = profiling_create_event['output']
        # Retrieve event from chain
        self.assertEqual(self.event_factory.getEvent(event_hash)[:7], [
            description_hash,
            is_ranged,
            lower_bound,
            upper_bound,
            outcome_count,
            token_address.encode('hex'),
            resolver_address.encode('hex')
        ])
