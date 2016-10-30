from ..abstract_test import AbstractTestContract


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.utils.test_ln
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.math_library_name]

    def test(self):
        x = 2
        self.assertEqual(self.math_library.ln(x * 2**64) / 2.0**64, 0.6931471805599453)
