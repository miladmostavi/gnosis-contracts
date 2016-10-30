from ..abstract_test import AbstractTestContract, accounts, keys, TransactionFailed


class TestContract(AbstractTestContract):
    """
    run test with python -m unittest contracts.tests.dao.test_dao_dutch_auction
    """

    BACKER_1 = 1
    BACKER_2 = 2
    BLOCKS_PER_DAY = 5760
    TOTAL_TOKENS = 10000000 * 10**18
    WAITING_PERIOD = 60*60*24*7

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        self.deploy_contracts = [self.event_factory_name, self.outcome_token_library_name, self.dao_name,
                                 self.dao_token_name, self.dao_auction_name]

    def test(self):
        # Create mist wallet
        required_accounts = 1
        daily_limit = 0
        wa_1 = 1
        constructor_parameters = (
            [accounts[wa_1]],
            required_accounts,
            daily_limit
        )
        self.mist_wallet = self.s.abi_contract(
            self.pp.process(self.WALLETS_DIR + 'MistWallet.sol', add_dev_code=True, contract_dir=self.contract_dir),
            language='solidity',
            constructor_parameters=constructor_parameters
        )
        # Create wallet
        constructor_parameters = (
            [accounts[wa_1]],
            required_accounts
        )
        self.multisig_wallet = self.s.abi_contract(
            self.pp.process('Wallets/MultiSigWallet.sol', add_dev_code=True, contract_dir=self.contract_dir),
            language='solidity',
            constructor_parameters=constructor_parameters
        )
        self.dao.setup(self.event_factory.address, self.mist_wallet.address)
        self.dao_auction.setup(self.dao_token.address, self.multisig_wallet.address, self.mist_wallet.address)
        # Setups cannot be done twice
        self.assertRaises(TransactionFailed, self.dao.setup, self.event_factory.address, self.mist_wallet.address)
        self.assertRaises(TransactionFailed, self.dao_auction.setup, self.dao_token.address, self.mist_wallet.address)
        # Bidder 1 places a bid in the first block after auction starts
        self.assertEqual(self.dao_auction.calcTokenPrice(), 20000 * 10**18)
        bidder_1 = 0
        value_1 = 500000 * 10**18  # 500k Ether
        self.s.block.set_balance(accounts[bidder_1], value_1*2)
        self.dao_auction.bid(sender=keys[bidder_1], value=value_1)
        self.assertEqual(self.dao_auction.calcStopPrice(), value_1 / 9000000)
        # A few blocks later
        self.s.block.number += self.BLOCKS_PER_DAY*2
        self.assertEqual(self.dao_auction.calcTokenPrice(), 20000 * 10**18 / (self.BLOCKS_PER_DAY*2 + 1))
        # Stop price didn't change
        self.assertEqual(self.dao_auction.calcStopPrice(), value_1 / 9000000)
        # Bidder 2 places a bid
        bidder_2 = 1
        value_2 = 500000 * 10**18  # 1M Ether
        self.s.block.set_balance(accounts[bidder_2], value_2*2)
        self.dao_auction.bid(sender=keys[bidder_2], value=value_2)
        # Stop price changed
        self.assertEqual(self.dao_auction.calcStopPrice(), (value_1 + value_2) / 9000000)
        # A few blocks later
        self.s.block.number += self.BLOCKS_PER_DAY*3
        self.assertEqual(self.dao_auction.calcTokenPrice(), 20000 * 10 ** 18 / (self.BLOCKS_PER_DAY*5 + 1))
        # Bidder 2 tries to send 0 bid to update last price
        self.assertRaises(TransactionFailed, self.dao_auction.bid, sender=keys[bidder_2], value=0)
        # Bidder 3 places a bid
        bidder_3 = 2
        value_3 = 500000 * 10 ** 18  # 1M Ether
        self.s.block.set_balance(accounts[bidder_3], value_3 * 2)
        self.dao_auction.bid(sender=keys[bidder_3], value=value_3)
        # Auction is over, no more bids are accepted
        self.s.block.set_balance(accounts[bidder_3], value_3 * 2)
        self.assertRaises(TransactionFailed, self.dao_auction.bid, sender=keys[bidder_3], value=value_3)
        self.assertEqual(self.dao_auction.finalPrice(), self.dao_auction.calcTokenPrice())
        # There is no money left in the contract
        self.assertEqual(self.s.block.get_balance(self.dao_auction.address), 0)
        # Everyone gets their tokens
        self.dao_auction.claimTokens(sender=keys[bidder_1])
        self.dao_auction.claimTokens(sender=keys[bidder_2])
        self.dao_auction.claimTokens(sender=keys[bidder_3])
        # Confirm token balances
        self.assertEqual(self.dao_token.balanceOf(accounts[bidder_1]),
                         value_1 * 10 ** 18 / self.dao_auction.finalPrice())
        self.assertEqual(self.dao_token.balanceOf(accounts[bidder_2]),
                         value_2 * 10 ** 18 / self.dao_auction.finalPrice())
        self.assertEqual(self.dao_token.balanceOf(accounts[bidder_3]),
                         value_3 / 2 * 10 ** 18 / self.dao_auction.finalPrice())
        self.assertEqual(self.dao_token.balanceOf(self.multisig_wallet.address),
                         self.TOTAL_TOKENS - self.dao_auction.totalRaised() * 10 ** 18 / self.dao_auction.finalPrice())
        self.assertEqual(self.dao_token.totalSupply(), self.TOTAL_TOKENS)
        # Auction ended but trading is not possible yet, because there is one week pause after auction ends
        transfer_shares = 1000
        bidder_4 = 3
        self.assertRaises(TransactionFailed, self.dao_token.transfer, accounts[bidder_4], transfer_shares, sender=keys[bidder_3])
        # We wait for one week
        self.s.block.timestamp += self.WAITING_PERIOD + 1
        # Shares can be traded now. Backer 3 transfers 1000 shares to backer 4.
        self.assertTrue(self.dao_token.transfer(accounts[bidder_4], transfer_shares, sender=keys[bidder_3]))
        self.assertEqual(self.dao_token.balanceOf(accounts[bidder_4]), transfer_shares)
        # Also transferFrom works now.
        self.assertTrue(self.dao_token.approve(accounts[bidder_3], transfer_shares, sender=keys[bidder_4]))
        self.assertTrue(
            self.dao_token.transferFrom(accounts[bidder_4], accounts[bidder_3], transfer_shares, sender=keys[bidder_3]))
        self.assertEqual(self.dao_token.balanceOf(accounts[bidder_4]), 0)
        # Now we want to change the DAO contract.
        self.assertEqual(self.event_factory.getDAO(), self.dao.address.encode('hex'))
        # We deploy a new DAO.
        dao_2 = self.s.abi_contract(self.pp.process(self.dao_name, add_dev_code=True, contract_dir=self.contract_dir),
                                    language='solidity')
        dao_2.setup(self.event_factory.address, self.mist_wallet.address)
        dao_abi = self.dao.translator
        tx_data = dao_abi.encode("changeDAO", [dao_2.address])
        self.mist_wallet.execute(self.dao.address, 0, tx_data)
        # The events contract points now to the new DAO contract.
        self.assertEqual(self.event_factory.getDAO(), dao_2.address.encode('hex'))
