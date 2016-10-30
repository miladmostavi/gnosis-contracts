pragma solidity ^0.4.0;
import "Tokens/StandardToken.sol";


/// @title Hunch Game token contract - Implements token trading and high-score calculation.
/// @author Stefan George - <stefan.george@consensys.net>
/// @author Martin Koeppelmann - <martin.koeppelmann@consensys.net>
contract HunchGameToken is StandardToken {

    /*
     *  Constants
     */
    // Token meta data
    string constant public name = "HunchGame Token";
    string constant public symbol = "HGT";
    uint8 constant public decimals = 18;

    /*
     *  Data structures
     */
    address owner;
    address hunchGameMarketFactory;

    /*
     *  Modifiers
     */
    modifier isOwner() {
        if (msg.sender != owner) {
            // Only DAO contract is allowed to proceed
            throw;
        }
        _;
    }

    modifier isHunchGameMarketFactory() {
        if (msg.sender != hunchGameMarketFactory) {
            // Only HunchGame market factory contract is allowed to proceed
            throw;
        }
        _;
    }

    /*
     *  Read and write functions
     */
    /// @dev Contract constructor sets initial tokens to contract owner.
    function HunchGameToken() {
        owner = msg.sender;
        uint initialTokens = 2**256 / 2;
        balances[msg.sender] += initialTokens;
        totalSupply += initialTokens;
    }

    /// @dev Issues tokens for user.
    /// @param user User's address.
    /// @param tokenCount Number of tokens to issue.
    function issueTokens(address user, uint tokenCount)
        public
        isHunchGameMarketFactory
    {
        balances[user] += tokenCount;
        totalSupply += tokenCount;
    }

    /// @dev Setup function sets external contracts' addresses.
    /// @param _hunchGameMarketFactory HunchGame market factory address.
    function setup(address _hunchGameMarketFactory)
        external
        isOwner
    {
        if (hunchGameMarketFactory != 0) {
            // Setup was executed already
            throw;
        }
        hunchGameMarketFactory = _hunchGameMarketFactory;
    }

    /// @dev Allows allowed third party to transfer tokens from one address to another. Returns success.
    /// @param _from Address from where tokens are withdrawn.
    /// @param _to Address to where tokens are sent.
    /// @param _value Number of tokens to transfer.
    /// @return success Returns success of function call.
    function transferFrom(address _from, address _to, uint256 _value)
        public
        returns (bool success)
    {
        if (   balances[_from] < _value
            || (allowed[_from][msg.sender] < _value && msg.sender != hunchGameMarketFactory))
        {
            // Balance too low or allowance too low and sender is not HunchGame market factory
            throw;
        }
        balances[_to] += _value;
        balances[_from] -= _value;
        if (msg.sender != hunchGameMarketFactory) {
            allowed[_from][msg.sender] -= _value;
        }
        Transfer(_from, _to, _value);
        return true;
    }
}
