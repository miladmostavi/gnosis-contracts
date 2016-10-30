from ..abstract_test import AbstractTestContract


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.utils.test_e_exp
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.math_library_name]

    def test(self):
        x = 10
        self.assertEqual(self.math_library.eExp(x * 2**64) / 2.0**64, 22026.464964772957)
