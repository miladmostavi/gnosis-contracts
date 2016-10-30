from unittest import TestCase
from ethereum import tester as t
from contracts.preprocessor import PreProcessor


class TestPreProcessor(TestCase):
    """
    run test with python -m unittest contracts.tests.others.test_preprocessor
    """

    def test_compile(self):
        s = t.state()
        code = '''
        contract Test {

            struct S {
                uint x;
                int y;
            }

            mapping (uint => S) SS;

            function t1(uint a1, uint a2) returns (uint) {
                macro: $storage=SS[a1].x;
                $storage += a2;
                return $storage;
            }

            function t2(uint a1, int a2) returns (int) {
                macro: $storage=SS[a1].y;
                $storage -= a2;
                return $storage;
            }

        }
        '''

        pp = PreProcessor()
        code = pp.resolve_macros(code)
        c = s.abi_contract(code, language='solidity')
        self.assertEqual(c.t1(0, 10), 10)
        self.assertEqual(c.t2(0, 4), -4)
