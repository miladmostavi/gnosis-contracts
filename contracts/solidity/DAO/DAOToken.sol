pragma solidity ^0.4.0;
import "Tokens/StandardToken.sol";
import "DAO/AbstractDAOAuction.sol";


/// @title Gnosis token contract - Holds tokens of Gnosis.
/// @author Stefan George - <stefan.george@consensys.net>
contract DAOToken is StandardToken {

    /*
     *  Token meta data
     */
    string constant public name = "Gnosis Token";
    string constant public symbol = "GNO";
    uint8 constant public decimals = 18;

    /*
     *  External contracts
     */
    DAOAuction public daoAuction;

    /*
     *  Modifiers
     */
    modifier tokenLaunched() {
        if (!daoAuction.tokenLaunched() && msg.sender != address(daoAuction)) {
            // Token was not launched yet and sender is not auction contract
            throw;
        }
        _;
    }

    /*
     *  Read and write functions
     */
    /// @dev Transfers sender's tokens to a given address. Returns success.
    /// @param to Address of token receiver.
    /// @param value Number of tokens to transfer.
    /// @return success Returns success of function call.
    function transfer(address to, uint256 value)
        public
        tokenLaunched
        returns (bool success)
    {
        return super.transfer(to, value);
    }

    /// @dev Allows allowed third party to transfer tokens from one address to another. Returns success.
    /// @param from Address from where tokens are withdrawn.
    /// @param to Address to where tokens are sent.
    /// @param value Number of tokens to transfer.
    /// @return success Returns success of function call.
    function transferFrom(address from, address to, uint256 value)
        public
        tokenLaunched
        returns (bool success)
    {
        return super.transferFrom(from, to, value);
    }

     /// @dev Contract constructor function sets owner.
    function DAOToken(address _daoAuction) {
        daoAuction = DAOAuction(_daoAuction);
        uint _totalSupply = 10000000 * 10**18;
        balances[_daoAuction] = _totalSupply;
        totalSupply = _totalSupply;
    }
}
