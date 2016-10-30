from ..abstract_test import AbstractTestContract, keys, accounts
from ethereum.tester import TransactionFailed


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
        # Create wallet
        required_accounts = 2
        wa_1 = 1
        wa_2 = 2
        wa_3 = 3
        constructor_parameters = (
            [accounts[wa_1], accounts[wa_2], accounts[wa_3]],
            required_accounts
        )
        self.multisig_wallet = self.s.abi_contract(
            self.pp.process('Wallets/MultiSigWallet.sol', add_dev_code=True, contract_dir=self.contract_dir),
            language='solidity',
            constructor_parameters=constructor_parameters
        )
        # Validate deployment
        self.assertEqual(self.multisig_wallet.owners(0), accounts[wa_1].encode('hex'))
        self.assertEqual(self.multisig_wallet.owners(1), accounts[wa_2].encode('hex'))
        self.assertEqual(self.multisig_wallet.owners(2), accounts[wa_3].encode('hex'))
        self.assertEqual(self.multisig_wallet.required(), required_accounts)
        self.assertTrue(self.multisig_wallet.isOwner(accounts[wa_1]))
        self.assertTrue(self.multisig_wallet.isOwner(accounts[wa_2]))
        self.assertTrue(self.multisig_wallet.isOwner(accounts[wa_3]))
        # Create ABIs
        ether_abi = self.ether_token.translator
        market_abi = self.market_factory.translator
        multisig_abi = self.multisig_wallet.translator
        # Create event
        outcome_count = 2
        event_hash = self.create_event(outcome_count=outcome_count)
        # Create market
        fee = 0
        initial_funding = self.MIN_MARKET_BALANCE
        # Send money to wallet contract
        investment = initial_funding + self.calc_base_fee_for_shares(self.MIN_MARKET_BALANCE)
        self.s.send(keys[wa_1], self.multisig_wallet.address, investment)
        # Buy ether tokens
        buy_ether_data = ether_abi.encode("buyTokens", [])
        # A third party cannot submit transactions
        self.assertRaises(TransactionFailed, self.multisig_wallet.submitTransaction, self.ether_token.address,
                          investment, buy_ether_data, 0, sender=keys[0])
        # Only a wallet owner (in this case wa_1) can do this. Owner confirms transaction at the same time.
        transaction_hash = self.multisig_wallet.submitTransaction(self.ether_token.address, investment, buy_ether_data,
                                                                  0, sender=keys[wa_1])
        self.assertTrue(self.multisig_wallet.confirmations(transaction_hash, accounts[wa_1]))
        # But owner wa_1 revokes confirmation
        self.multisig_wallet.revokeConfirmation(transaction_hash, sender=keys[wa_1])
        self.assertFalse(self.multisig_wallet.confirmations(transaction_hash, accounts[wa_1]))
        # He changes his mind, confirms again
        self.multisig_wallet.confirmTransaction(transaction_hash, sender=keys[wa_1])
        self.assertTrue(self.multisig_wallet.confirmations(transaction_hash, accounts[wa_1]))
        self.assertEqual(self.multisig_wallet.confirmationCount(transaction_hash), 1)
        # Other owner wa_2 confirms and executes transaction at the same time as min sig are available
        self.assertFalse(self.multisig_wallet.transactions(transaction_hash)[4])
        self.multisig_wallet.confirmTransaction(transaction_hash, sender=keys[wa_2])
        self.assertEqual(self.multisig_wallet.confirmationCount(transaction_hash), 2)
        # Transaction was executed and deleted
        self.assertTrue(self.multisig_wallet.transactions(transaction_hash)[4])
        # Approve tokens transaction
        approve_ether_data = ether_abi.encode("approve", [self.market_factory.address, investment])
        transaction_hash = self.multisig_wallet.submitTransaction(self.ether_token.address, 0, approve_ether_data, 0,
                                                                  sender=keys[wa_1])
        self.multisig_wallet.confirmTransaction(transaction_hash, sender=keys[wa_2])
        # Create market transaction
        create_market_data = market_abi.encode("createMarket", [event_hash, fee, initial_funding, self.lmsr.address])
        transaction_hash = self.multisig_wallet.submitTransaction(self.market_factory.address, 0, create_market_data, 0,
                                                                  sender=keys[wa_1])
        self.multisig_wallet.confirmTransaction(transaction_hash, sender=keys[wa_3])
        self.assertEqual(self.event_factory.getShares(self.market_factory.address, [event_hash]),
                         [self.b2i(event_hash), outcome_count, initial_funding, initial_funding])
        # Add owner wa_4
        wa_4 = 4
        add_owner_data = multisig_abi.encode("addOwner", [accounts[wa_4]])
        transaction_hash = self.multisig_wallet.submitTransaction(self.multisig_wallet.address, 0, add_owner_data, 0,
                                                                  sender=keys[wa_1])
        self.multisig_wallet.confirmTransaction(transaction_hash, sender=keys[wa_2])
        self.assertEqual(self.multisig_wallet.owners(3), accounts[wa_4].encode('hex'))
        # Update required to 4
        update_required_data = multisig_abi.encode("updateRequired", [4])
        transaction_hash = self.multisig_wallet.submitTransaction(self.multisig_wallet.address, 0, update_required_data,
                                                                  0, sender=keys[wa_1])
        self.multisig_wallet.confirmTransaction(transaction_hash, sender=keys[wa_2])
        self.assertEqual(self.multisig_wallet.owners(3), accounts[wa_4].encode('hex'))
        self.assertEqual(self.multisig_wallet.required(), required_accounts + 2)
        # Delete owner wa_3. All parties have to confirm.
        remove_owner_data = multisig_abi.encode("removeOwner", [accounts[wa_3]])
        transaction_hash = self.multisig_wallet.submitTransaction(self.multisig_wallet.address, 0, remove_owner_data, 0,
                                                                  sender=keys[wa_1])
        self.multisig_wallet.confirmTransaction(transaction_hash, sender=keys[wa_2])
        self.multisig_wallet.confirmTransaction(transaction_hash, sender=keys[wa_3])
        self.multisig_wallet.confirmTransaction(transaction_hash, sender=keys[wa_4])
        # Transaction was successfully processed
        self.assertEqual(self.multisig_wallet.required(), required_accounts + 1)
        self.assertEqual(self.multisig_wallet.owners(0), accounts[wa_1].encode('hex'))
        self.assertEqual(self.multisig_wallet.owners(1), accounts[wa_2].encode('hex'))
        self.assertEqual(self.multisig_wallet.owners(2), accounts[wa_4].encode('hex'))
        # Send money to wallet
        self.s.send(keys[0], self.multisig_wallet.address, 1000)
        self.assertEqual(self.s.block.get_balance(self.multisig_wallet.address), 1000)
