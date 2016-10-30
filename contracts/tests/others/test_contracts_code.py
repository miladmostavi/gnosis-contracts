from ..abstract_test import AbstractTestContract


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.others.test_contracts_code
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.outcome_token_library_name, self.dao_name,
                                 self.math_library_name, self.lmsr_name, self.market_factory_name,
                                 self.ultimate_oracle_name, self.ether_token_name,
                                 self.outcome_token_name, self.hunchgame_name,
                                 self.difficulty_oracle_name, self.oraclize_name, self.oraclize_oracle_name,
                                 self.futarchy_oracle_name, self.crowdfunding_name, self.hunchgame_token_name]

    def test(self):
        max_size = 15000
        contract_size = len(self.s.blocks[-1].get_code(self.dao.address))
        self.assertLess(contract_size, max_size)
        print "DAO contract byte length: {}".format(str(contract_size))
        contract_size = len(self.s.blocks[-1].get_code(self.event_factory.address))
        self.assertLess(contract_size, max_size)
        print "Event manager contract byte length: {}".format(str(contract_size))
        contract_size = len(self.s.blocks[-1].get_code(self.event_token_c.address))
        self.assertLess(contract_size, max_size)
        print "Event token contract byte length: {}".format(str(contract_size))
        contract_size = len(self.s.blocks[-1].get_code(self.market_factory.address))
        self.assertLess(contract_size, max_size)
        print "Market manager contract byte length: {}".format(str(contract_size))
        contract_size = len(self.s.blocks[-1].get_code(self.lmsr.address))
        self.assertLess(contract_size, max_size)
        print "LMSR contract byte length: {}".format(str(contract_size))
        contract_size = len(self.s.blocks[-1].get_code(self.math_library.address))
        self.assertLess(contract_size, max_size)
        print "Math library byte length: {}".format(str(contract_size))
        contract_size = len(self.s.blocks[-1].get_code(self.ultimate_oracle.address))
        self.assertLess(contract_size, max_size)
        print "Ultimate oracle contract byte length: {}".format(str(contract_size))
        contract_size = len(self.s.blocks[-1].get_code(self.ether_token.address))
        self.assertLess(contract_size, max_size)
        print "Ether token contract byte length: {}".format(str(contract_size))
        contract_size = len(self.s.blocks[-1].get_code(self.crowdfunding.address))
        self.assertLess(contract_size, max_size)
        print "Crowdfunding contract byte length: {}".format(str(contract_size))
        contract_size = len(self.s.blocks[-1].get_code(self.futarchy_oracle.address))
        self.assertLess(contract_size, max_size)
        print "Futarchy contract byte length: {}".format(str(contract_size))
        contract_size = len(self.s.blocks[-1].get_code(self.difficulty_oracle.address))
        self.assertLess(contract_size, max_size)
        print "Difficulty contract byte length: {}".format(str(contract_size))
        contract_size = len(self.s.blocks[-1].get_code(self.oraclize_oracle.address))
        self.assertLess(contract_size, max_size)
        print "Oraclize contract byte length: {}".format(str(contract_size))
        contract_size = len(self.s.blocks[-1].get_code(self.hunchgame.address))
        self.assertLess(contract_size, max_size)
        print "Hunch Game contract byte length: {}".format(str(contract_size))
