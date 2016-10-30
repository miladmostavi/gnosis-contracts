# ethereum
from ethereum import tester as t
from ethereum.tester import keys, accounts, TransactionFailed
from ethereum.utils import sha3
from contracts.preprocessor import PreProcessor
# signing
from bitcoin import ecdsa_raw_sign
# standard libraries
from unittest import TestCase


class AbstractTestContract(TestCase):
    """
    run all tests with python -m unittest discover contracts
    """

    NUMERIC_RANGE = 10000
    MIN_MARKET_BALANCE = 10 * 10 ** 18  # 10 Ether
    # BASE_FEE = 2000  # 0.2%
    BASE_FEE = 0  # 0%
    BASE_FEE_RANGE = 1000000
    HOMESTEAD_BLOCK = 1150000

    EVENT_MANAGER_DIR = 'EventFactory/'
    DAO_DIR = 'DAO/'
    UTILS_DIR = 'Utils/'
    ORACLES_DIR = 'Oracles/'
    MARKET_MANAGERS_DIR = 'MarketFactories/'
    MARKET_MAKERS_DIR = 'MarketMakers/'
    STATE_CHANNELS_DIR = 'StateChannels/'
    MARKET_CROWDFUNDING_DIR = 'MarketCrowdfunding/'
    WALLETS_DIR = 'Wallets/'
    TOKENS_DIR = 'Tokens/'

    def __init__(self, *args, **kwargs):
        super(AbstractTestContract, self).__init__(*args, **kwargs)
        self.pp = PreProcessor()
        self.s = t.state()
        self.s.block.number = self.HOMESTEAD_BLOCK
        t.gas_limit = 4712388
        self.coinbase = self.s.block.coinbase.encode("hex")
        # Contract code
        self.contract_dir = 'contracts/solidity/'
        self.deploy_contracts = []
        self.event_factory_name = self.EVENT_MANAGER_DIR + 'EventFactory.sol'
        self.outcome_token_name = self.EVENT_MANAGER_DIR + 'OutcomeToken.sol'
        self.outcome_token_library_name = self.EVENT_MANAGER_DIR + 'OutcomeTokenLibrary.sol'
        self.dao_name = self.DAO_DIR + 'DAO.sol'
        self.dao_auction_name = self.DAO_DIR + 'DAODutchAuction.sol'
        self.dao_token_name = self.DAO_DIR + 'DAOToken.sol'
        self.ether_token_name = self.TOKENS_DIR + 'EtherToken.sol'
        self.hunchgame_name = self.MARKET_MANAGERS_DIR + 'HunchGameMarketFactory.sol'
        self.hunchgame_token_name = self.TOKENS_DIR + 'HunchGameToken.sol'
        self.market_factory_name = self.MARKET_MANAGERS_DIR + 'DefaultMarketFactory.sol'
        self.lmsr_name = self.MARKET_MAKERS_DIR + 'LMSRMarketMaker.sol'
        self.math_library_name = self.UTILS_DIR + 'MathLibrary.sol'
        self.crowdfunding_name = self.MARKET_CROWDFUNDING_DIR + 'MarketCrowdfunding.sol'
        self.difficulty_oracle_name = self.ORACLES_DIR + 'DifficultyOracle.sol'
        self.fallback_oracle_name = self.ORACLES_DIR + 'DefaultFallbackOracle.sol'
        self.ultimate_oracle_name = self.ORACLES_DIR + 'UltimateOracle.sol'
        self.futarchy_oracle_name = self.ORACLES_DIR + 'FutarchyOracle.sol'
        self.oraclize_name = self.ORACLES_DIR + 'Oraclize.sol'
        self.oraclize_oracle_name = self.ORACLES_DIR + 'OraclizeOracle.sol'

    def setUp(self):
        if self.dao_name in self.deploy_contracts:
            self.dao = self.s.abi_contract(self.pp.process(self.dao_name,
                                                           add_dev_code=True,
                                                           contract_dir=self.contract_dir), language='solidity')
        if self.dao_auction_name in self.deploy_contracts:
            self.dao_auction = self.s.abi_contract(self.pp.process(self.dao_auction_name,
                                                                   add_dev_code=True,
                                                                   contract_dir=self.contract_dir), language='solidity')
        if self.dao_token_name in self.deploy_contracts:
            self.dao_token = self.s.abi_contract(self.pp.process(self.dao_token_name,
                                                                 add_dev_code=True,
                                                                 contract_dir=self.contract_dir),
                                                 language='solidity',
                                                 constructor_parameters=[self.dao_auction.address])
        if self.outcome_token_library_name in self.deploy_contracts:
            self.outcome_token_library = self.s.abi_contract(self.pp.process(self.outcome_token_library_name,
                                                                             add_dev_code=True,
                                                                             contract_dir=self.contract_dir),
                                                             language='solidity')
        if self.event_factory_name in self.deploy_contracts:
            self.event_factory = self.s.abi_contract(self.pp.process(self.event_factory_name,
                                                                     add_dev_code=True,
                                                                     contract_dir=self.contract_dir,
                                                                     addresses={
                                                                            'DAO': self.a2h(self.dao)
                                                                        }),
                                                     language='solidity',
                                                     libraries={
                                                        'OutcomeTokenLibrary': self.a2h(self.outcome_token_library)
                                                     })
        if self.outcome_token_name in self.deploy_contracts:
            self.event_token_c = self.s.abi_contract(self.pp.process(self.outcome_token_name,
                                                                     add_dev_code=True,
                                                                     contract_dir=self.contract_dir),
                                                     language='solidity',
                                                     libraries={
                                                         'OutcomeTokenLibrary': self.outcome_token_library.address.encode(
                                                             'hex')
                                                     })
        if self.ether_token_name in self.deploy_contracts:
            self.ether_token = self.s.abi_contract(self.pp.process(self.ether_token_name,
                                                                   add_dev_code=True,
                                                                   contract_dir=self.contract_dir), language='solidity')
        if self.math_library_name in self.deploy_contracts:
            self.math_library = self.s.abi_contract(self.pp.process(self.math_library_name,
                                                                    add_dev_code=True,
                                                                    contract_dir=self.contract_dir),
                                                    language='solidity')
        if self.market_factory_name in self.deploy_contracts:
            self.market_factory = self.s.abi_contract(self.pp.process(self.market_factory_name,
                                                                      add_dev_code=True,
                                                                      contract_dir=self.contract_dir,
                                                                      addresses={
                                                                          'EventFactory': self.a2h(self.event_factory)
                                                                      }), language='solidity')
        if self.crowdfunding_name in self.deploy_contracts:
            self.crowdfunding = self.s.abi_contract(self.pp.process(self.crowdfunding_name,
                                                                    add_dev_code=True,
                                                                    contract_dir=self.contract_dir,
                                                                    addresses={
                                                                        'EventFactory': self.a2h(self.event_factory)
                                                                    }), language='solidity')
        if self.lmsr_name in self.deploy_contracts:
            self.lmsr = self.s.abi_contract(self.pp.process(self.lmsr_name,
                                                            add_dev_code=True,
                                                            contract_dir=self.contract_dir),
                                            language='solidity',
                                            libraries={
                                                'MathLibrary': self.math_library.address.encode('hex')
                                            })
        if self.difficulty_oracle_name in self.deploy_contracts:
            self.difficulty_oracle = self.s.abi_contract(self.pp.process(self.difficulty_oracle_name,
                                                                         add_dev_code=True,
                                                                         contract_dir=self.contract_dir),
                                                         language='solidity')
        if self.fallback_oracle_name in self.deploy_contracts:
            self.fallback_oracle = self.s.abi_contract(self.pp.process(self.fallback_oracle_name,
                                                                       add_dev_code=True,
                                                                       contract_dir=self.contract_dir),
                                                       language='solidity')
        if self.ultimate_oracle_name in self.deploy_contracts:
            self.ultimate_oracle = self.s.abi_contract(self.pp.process(self.ultimate_oracle_name,
                                                                       add_dev_code=True,
                                                                       contract_dir=self.contract_dir,
                                                                       addresses={
                                                                           'EtherToken': self.a2h(self.ether_token)
                                                                       }), language='solidity')
        if self.hunchgame_token_name in self.deploy_contracts:
            self.hunchgame_token = self.s.abi_contract(
                self.pp.process(self.hunchgame_token_name, add_dev_code=True, contract_dir=self.contract_dir),
                language='solidity')
        if self.hunchgame_name in self.deploy_contracts:
            self.hunchgame = self.s.abi_contract(
                self.pp.process(self.hunchgame_name, add_dev_code=True, contract_dir=self.contract_dir, addresses={
                    'EventFactory': self.a2h(self.event_factory),
                    'HunchGameToken': self.a2h(self.hunchgame_token)
                }), language='solidity')
        if self.futarchy_oracle_name in self.deploy_contracts:
            self.futarchy_oracle = self.s.abi_contract(
                self.pp.process(self.futarchy_oracle_name, add_dev_code=True, contract_dir=self.contract_dir,
                                addresses={
                                    'EventFactory': self.a2h(self.event_factory),
                                    'DefaultMarketFactory': self.a2h(self.market_factory),
                                    'LMSRMarketMaker': self.a2h(self.lmsr),
                                    'EtherToken': self.a2h(self.ether_token)
                                }), language='solidity')
        if self.oraclize_name in self.deploy_contracts:
            self.oraclize = self.s.abi_contract(
                self.pp.process(self.oraclize_name, add_dev_code=True, contract_dir=self.contract_dir,
                                replace_unknown_addresses=True), language='solidity')
        if self.oraclize_oracle_name in self.deploy_contracts:
            self.oraclize_oracle = self.s.abi_contract(
                self.pp.process(self.oraclize_oracle_name, add_dev_code=True, contract_dir=self.contract_dir,
                                addresses={
                                    'Oraclize': self.a2h(self.oraclize)
                                }), language='solidity')

    @staticmethod
    def a2h(contract):
        return "0x{}".format(contract.address.encode('hex'))

    @staticmethod
    def h2i(_hex):
        return int(_hex, 16)

    @staticmethod
    def b2i(_bytes):
        return int(_bytes.encode('hex'), 16)

    @staticmethod
    def i2b(_integer, zfill=64):
        return format(_integer, 'x').zfill(zfill).decode('hex')

    @staticmethod
    def s2b(_string):
        return _string.encode('hex').zfill(64).decode('hex')

    def get_state_hash(self, addresses, state_validity, trades, tokens, hash_lock):
        return sha3(
            self.s2b(addresses[0]) +
            self.s2b(addresses[1]) +
            self.i2b(state_validity[0]) +
            self.i2b(state_validity[1]) +
            ''.join([self.i2b(trade) if type(trade) == int else (self.s2b(trade)) for trade in trades]) +
            ''.join([self.i2b(token) if type(token) == int else self.s2b(token) for token in tokens]) +
            hash_lock
        ).encode('hex')

    def get_fee_hash(self, description_hash, fee, token_address):
        return sha3(
            description_hash +
            self.i2b(fee) +
            token_address
        ).encode('hex')

    def get_result_hash(self, description_hash, result):
        return sha3(
            description_hash +
            self.i2b(result)
        ).encode('hex')

    def get_event_hash(self,
                       description_hash,
                       is_ranged,
                       lower_bound,
                       upper_bound,
                       outcome_count,
                       token_address,
                       resolver_address,
                       event_data):
        return sha3(
            description_hash +
            self.i2b(is_ranged, 2) +
            self.i2b(lower_bound) +
            self.i2b(upper_bound) +
            self.i2b(outcome_count, 2) +
            token_address +
            resolver_address +
            ''.join([self.i2b(datum) if type(datum) == int else self.s2b(datum) for datum in event_data])
        )

    @staticmethod
    def get_market_hash(event_hash, sender_address, market_maker_address):
        return sha3(
            event_hash +
            sender_address +
            market_maker_address
        )

    def get_campaign_hash(self,
                          market_address,
                          event_hash,
                          fee,
                          initial_funding,
                          total_funding,
                          market_maker_address,
                          closing_at_block,
                          initial_shares):
        return sha3(
            market_address +
            event_hash +
            self.i2b(fee) +
            self.i2b(initial_funding) +
            self.i2b(total_funding) +
            market_maker_address +
            self.i2b(closing_at_block) +
            ''.join([self.i2b(share) for share in initial_shares])
        )

    def sign_data(self, data, private_key):
        v, r, s = ecdsa_raw_sign(data, private_key)
        return self.i2b(v), self.i2b(r), self.i2b(s)

    def create_event(self,
                     description_hash="d621d969951b20c5cf2008cbfc282a2d496ddfe75a76afe7b6b32f1470b8a449".decode('hex'),
                     is_ranged=False,
                     lower_bound=0,
                     upper_bound=0,
                     outcome_count=2,
                     token_address=None,
                     oracle_address=None,
                     data=None,
                     oracle_token_address=None,
                     sender=None):
        oracle_id = 0
        if not oracle_address:
            oracle_address = self.ultimate_oracle.address
        oracle_fee = 0
        if not oracle_token_address:
            oracle_token_address = self.ether_token.address
        if not data:
            print oracle_token_address.encode('hex')
            v, r, s = self.sign_data(self.get_fee_hash(description_hash, oracle_fee, oracle_token_address), keys[oracle_id])  # signed 0 fee
            data = [description_hash, self.i2b(oracle_fee), self.s2b(oracle_token_address), v, r, s]
        if not token_address:
            token_address = self.ether_token.address
        if not sender:
            sender = keys[0]
        return self.event_factory.createEvent(description_hash,
                                              is_ranged,
                                              lower_bound,
                                              upper_bound,
                                              outcome_count,
                                              token_address,
                                              oracle_address,
                                              data,
                                              sender=sender)

    def create_market(self,
                      event_hash,
                      fee=0,
                      initial_funding=None,
                      market_maker_contract=None,
                      token_contract=None,
                      markets_contract=None,
                      user=0):
        if not markets_contract:
            markets_contract = self.market_factory
        if not market_maker_contract:
            market_maker_contract = self.lmsr
        if not initial_funding:
            initial_funding = self.MIN_MARKET_BALANCE
        # User buys Ether tokens
        value = initial_funding + self.calc_base_fee_for_shares(self.MIN_MARKET_BALANCE)
        if not token_contract:
            token_contract = self.ether_token
            token_contract.buyTokens(value=value, sender=keys[user])
            self.assertEqual(token_contract.balanceOf(accounts[user]), value)
        token_contract.approve(markets_contract.address, value, sender=keys[user])
        self.assertEqual(token_contract.allowance(accounts[user], markets_contract.address), value)
        # Create market
        return markets_contract.createMarket(event_hash,
                                             fee,
                                             initial_funding,
                                             market_maker_contract.address,
                                             sender=keys[user])

    def buy_shares(self,
                   market_hash,
                   outcome=0,
                   share_count=10**18,
                   initial_funding=None,
                   token_contract=None,
                   markets_contract=None,
                   user=0):
        if not markets_contract:
            markets_contract = self.market_factory
        if not initial_funding:
            initial_funding = self.MIN_MARKET_BALANCE
        share_distribution = [initial_funding, initial_funding]
        # Calculate costs for buying shares
        max_spending = self.lmsr.calcCostsBuying("".zfill(64).decode('hex'),
                                                 initial_funding,
                                                 share_distribution,
                                                 outcome,
                                                 share_count)
        max_spending += self.calc_base_fee_for_shares(share_count)
        if not token_contract:
            token_contract = self.ether_token
            token_contract.buyTokens(value=max_spending, sender=keys[user])
            self.assertEqual(self.ether_token.balanceOf(accounts[user]), max_spending)
        token_contract.approve(markets_contract.address, max_spending, sender=keys[user])
        self.assertEqual(token_contract.allowance(accounts[user], markets_contract.address), max_spending)
        return markets_contract.buyShares(market_hash, outcome, share_count, max_spending, sender=keys[user])

    def buy_ether_tokens(self, user=0, amount=0, approved_contract=None):
        if not approved_contract:
            approved_contract = self.market_factory
        self.ether_token.buyTokens(value=amount, sender=keys[user])
        self.assertEqual(self.ether_token.balanceOf(accounts[user]), amount)
        self.ether_token.approve(approved_contract.address, amount, sender=keys[user])
        self.assertEqual(self.ether_token.allowance(accounts[user], approved_contract.address), amount)

    def event_token(self, event_hash, outcome, func_name, sender, params):
        event_token_abi = self.event_token_c.translator
        event_token_address = self.event_factory.getOutcomeToken(event_hash, outcome)
        result = event_token_abi.decode(
            func_name,
            self.s.send(
                keys[sender], event_token_address, 0, event_token_abi.encode(func_name, params)
            )
        )
        return result[0] if len(result) == 1 else result

    def calc_base_fee(self, amount):
        return amount * self.BASE_FEE / self.BASE_FEE_RANGE

    def calc_base_fee_for_shares(self, shares):
        return shares * self.BASE_FEE_RANGE / (self.BASE_FEE_RANGE - self.BASE_FEE) - shares
