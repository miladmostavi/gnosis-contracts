from ..abstract_test import AbstractTestContract, accounts, keys


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.event_factory.test_get_event_hashes
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.dao_name, self.ultimate_oracle_name,
                                 self.outcome_token_library_name, self.ether_token_name]

    def test(self):
        # Create event
        description_hash = "d621d969951b20c5cf2008cbfc282a2d496ddfe75a76afe7b6b32f1470b8a449".decode('hex')
        description_hash_2 = "d621d969951b20c5cf2008cbfc282a2d496ddfe75a76afe7b6b32f1470b8a448".decode('hex')
        event_hash = self.create_event(description_hash=description_hash)
        event_hash_2 = self.create_event(description_hash=description_hash_2, sender=keys[1])
        # One event hash is associated to one description hash
        self.assertEqual(
            self.event_factory.getEventHashes([description_hash, description_hash_2], [accounts[0], accounts[1]]),
            [self.b2i(description_hash), 1, self.b2i(event_hash),
             self.b2i(description_hash_2), 1, self.b2i(event_hash_2)])
