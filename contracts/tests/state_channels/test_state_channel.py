from ..abstract_test import AbstractTestContract, accounts, keys, sha3


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.state_channels.test_state_channel
    """

    SECURITY_VALUE = 10 * 10**18
    CHALLENGE_PERIOD = 86400
    ONE_YEAR = 31536000

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.dao_name, self.ultimate_oracle_name,
                                 self.outcome_token_name, self.outcome_token_library_name, self.ether_token_name]

    def calc_state_hash(self, trades_hash, nonce, timestamp, lock_hash):
        return sha3(
            trades_hash +
            self.i2b(nonce) +
            self.i2b(timestamp) +
            lock_hash
        )

    @staticmethod
    def calc_trades_hash(trades):
        return sha3(
            b"".join(trades)
        )

    def calc_trade_hash(self, trade):
        return sha3(
            trade["sender"] +
            trade["destination"] +
            self.i2b(trade["value"]) +
            trade["data"]
        )

    def test(self):
        user = 0
        market_maker = 1
        # Create state channel
        constructor_parameters = (
            [accounts[user], accounts[market_maker]], self.ether_token.address, self.SECURITY_VALUE,
            self.CHALLENGE_PERIOD
        )
        state_channel = self.s.abi_contract(
            self.pp.process('StateChannels/StateChannel.sol', add_dev_code=True, contract_dir=self.contract_dir),
            language='solidity',
            constructor_parameters=constructor_parameters
        )
        state_channel_proxy = self.s.abi_contract(
            self.pp.process('StateChannels/StateChannel.sol', add_dev_code=True, contract_dir=self.contract_dir),
            language='solidity',
            contract_name='StateChannelProxy'
        )
        party = state_channel.proxyContracts(accounts[user])
        counter_party = state_channel.proxyContracts(accounts[market_maker])
        # Create event
        outcome_count = 2
        event_hash = self.create_event(outcome_count=outcome_count)
        # Both parties do a security deposit
        value = 100000
        # User does security deposit
        self.ether_token.buyTokens(value=value, sender=keys[user])
        self.assertTrue(self.ether_token.transfer(party, value, sender=keys[user]))
        # Market maker does security deposit
        self.ether_token.buyTokens(value=value, sender=keys[market_maker])
        self.assertTrue(self.ether_token.transfer(counter_party, value, sender=keys[market_maker]))
        # ABIs
        ether_abi = self.ether_token.translator
        events_abi = self.event_factory.translator
        event_token_abi = self.event_token_c.translator
        state_channel_proxy_abi = state_channel_proxy.translator
        # Create off chain state
        event_token = self.event_factory.getOutcomeToken(event_hash, 0)
        valid_until_timestamp = self.s.block.timestamp + self.ONE_YEAR
        nonce = 1
        secret = "d621d969951b20c5cf2008cbfc282a2d496ddfe75a76afe7b6b32f1470b8a449".decode('hex')
        hash_lock = sha3(secret)
        trades = [{
            "sender": party.decode('hex'),
            "destination": self.ether_token.address,
            "value": 0,
            "data": ether_abi.encode("transfer", [counter_party, 50000])
        }, {
            "sender": counter_party.decode('hex'),
            "destination": self.ether_token.address,
            "value": 0,
            "data": ether_abi.encode("approve", [self.event_factory.address, 70000])
        }, {
            "sender": counter_party.decode('hex'),
            "destination": self.event_factory.address,
            "value": 0,
            "data": events_abi.encode("buyAllOutcomes", [event_hash, 70000])
        }, {
            "sender": counter_party.decode('hex'),
            "destination": event_token.decode("hex"),
            "value": 0,
            "data": event_token_abi.encode("transfer", [party, 60000])
        }]
        trade_hashes = [self.calc_trade_hash(trade) for trade in trades]
        trades_hash = self.calc_trades_hash(trade_hashes)
        state_hash = self.calc_state_hash(trades_hash, nonce, valid_until_timestamp, hash_lock)
        # User and market maker sign state
        u_v, u_r, u_s = self.sign_data(state_hash, keys[user])
        mm_v, mm_r, mm_s = self.sign_data(state_hash, keys[market_maker])
        # User requests settlement
        self.buy_ether_tokens(user=user, amount=self.SECURITY_VALUE, approved_contract=state_channel)
        state_channel.requestSettlement(trades_hash, nonce, valid_until_timestamp, hash_lock, secret, [u_v, mm_v],
                                        [u_r, mm_r], [u_s, mm_s], sender=keys[user])
        self.s.block.timestamp += self.CHALLENGE_PERIOD
        # State is settled
        state_channel.submitTradeHashes(trade_hashes, nonce, valid_until_timestamp, hash_lock)
        # Execute trades
        for trade in trades:
            state_channel.executeTrade(trade["sender"], trade["destination"], trade["value"], trade["data"])
        self.assertTrue(
            state_channel_proxy_abi.decode("isSettled", self.s.send(
                keys[user], party, 0, state_channel_proxy_abi.encode("isSettled", []))
                                           )[0]
        )
        self.assertTrue(
            state_channel_proxy_abi.decode("isSettled", self.s.send(
                keys[market_maker], counter_party, 0, state_channel_proxy_abi.encode("isSettled", []))
                                           )[0]
        )
        self.assertEqual(self.event_token(event_hash, 0, "balanceOf", user, [party]), 60000)
        self.assertEqual(self.event_token(event_hash, 0, "balanceOf", user, [counter_party]), 10000)
