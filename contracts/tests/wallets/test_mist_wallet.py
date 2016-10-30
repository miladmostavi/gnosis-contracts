from ..abstract_test import AbstractTestContract, keys, accounts


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.wallets.test_multisig_wallet
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.outcome_token_library_name, self.dao_name,
                                 self.math_library_name, self.lmsr_name, self.market_factory_name,
                                 self.ultimate_oracle_name, self.ether_token_name,
                                 self.outcome_token_name]

    def test(self):
        # Create mist wallet
        required_accounts = 2
        daily_limit = 10**18*1000  # 1000 ETH
        wa_1 = 1
        wa_2 = 2
        wa_3 = 3
        constructor_parameters = (
            [accounts[wa_1], accounts[wa_2], accounts[wa_3]],
            required_accounts,
            daily_limit
        )
        self.mist_wallet = self.s.abi_contract(
            self.pp.process('Wallets/MistWallet.sol', add_dev_code=True, contract_dir=self.contract_dir),
            language='solidity',
            constructor_parameters=constructor_parameters
        )
        # Create ABIs
        ether_abi = self.ether_token.translator
        market_abi = self.market_factory.translator
        # Create event
        outcome_count = 2
        event_hash = self.create_event(outcome_count=outcome_count)
        # Create market
        fee = 0
        initial_funding = self.MIN_MARKET_BALANCE
        # Send money to wallet contract
        investment = initial_funding + self.calc_base_fee_for_shares(self.MIN_MARKET_BALANCE)
        self.s.send(keys[wa_1], self.mist_wallet.address, investment)
        # Buy ether tokens
        buy_ether_data = ether_abi.encode("buyTokens", [])
        self.mist_wallet.execute(self.ether_token.address, investment, buy_ether_data)
        approve_ether_data = ether_abi.encode("approve", [self.market_factory.address, investment])
        self.mist_wallet.execute(self.ether_token.address, 0, approve_ether_data)
        create_market_data = market_abi.encode("createMarket", [event_hash, fee, initial_funding, self.lmsr.address])
        profiling_create_market = self.mist_wallet.execute(self.market_factory.address, 0, create_market_data,
                                                           profiling=True)
        print "Create market gas costs: {}".format(profiling_create_market["gas"])
        self.assertEqual(self.event_factory.getShares(self.market_factory.address, [event_hash]),
                         [self.b2i(event_hash), outcome_count, initial_funding, initial_funding])
