pragma solidity ^0.4.0;
import "Tokens/AbstractToken.sol";
import "EventFactory/OutcomeTokenLibrary.sol";


/// @title Outcome token contract - Issuing and trading event outcomes.
/// @author Stefan George - <stefan.george@consensys.net>
contract OutcomeToken is Token {

    /*
     *  External contracts
     */
    address eventFactory;

    /*
     *  Data structures
     */
    OutcomeTokenLibrary.Data outcomeTokenData;

    /*
     *  Modifiers
     */
    modifier isEventFactory () {
        if (msg.sender != eventFactory) {
            // Only event contract is allowed to proceed.
            throw;
        }
        _;
    }

    /*
     *  Read and write functions
     */
    /// @dev Events contract issues new tokens for address. Returns success.
    /// @param _for Address of receiver.
    /// @param tokenCount Number of tokens to issue.
    /// @return success Returns success of function call.
    function issueTokens(address _for, uint tokenCount)
        external
        isEventFactory
    {
        outcomeTokenData.balances[_for] += tokenCount;
        outcomeTokenData.totalTokens += tokenCount;
    }

    /// @dev Events contract revokes tokens for address. Returns success.
    /// @param _for Address of token holder.
    /// @param tokenCount Number of tokens to revoke.
    /// @return success Returns success of function call.
    function revokeTokens(address _for, uint tokenCount)
        external
        isEventFactory
    {
        if (tokenCount > outcomeTokenData.balances[_for]) {
            // Balance too low
            throw;
        }
        outcomeTokenData.balances[_for] -= tokenCount;
        outcomeTokenData.totalTokens -= tokenCount;
    }

    /// @dev Transfers sender's tokens to a given address. Returns success.
    /// @param to Address of token receiver.
    /// @param value Number of tokens to transfer.
    /// @return success Returns success of function call.
    function transfer(address to, uint256 value)
        public
        returns (bool success)
    {
        return OutcomeTokenLibrary.transfer(outcomeTokenData, to, value);
    }

    /// @dev Allows allowed third party to transfer tokens from one address to another. Returns success.
    /// @param from Address from where tokens are withdrawn.
    /// @param to Address to where tokens are sent.
    /// @param value Number of tokens to transfer.
    /// @return success Returns success of function call.
    function transferFrom(address from, address to, uint256 value)
        public
        returns (bool success)
    {
        return OutcomeTokenLibrary.transferFrom(outcomeTokenData, from, to, value, eventFactory);
    }

    /// @dev Sets approved amount of tokens for spender. Returns success.
    /// @param spender Address of allowed actokenCount.
    /// @param value Number of approved tokens.
    /// @return success Returns success of function call.
    function approve(address spender, uint256 value)
        public
        returns (bool success)
    {
        return OutcomeTokenLibrary.approve(outcomeTokenData, spender, value);
    }

    /*
     * Read functions
     */
    /// @dev Returns number of tokens owned by given address.
    /// @param owner Address of token owner.
    /// @return balance Returns owner's balance.
    function balanceOf(address owner)
        constant
        public
        returns (uint256 balance)
    {
        return outcomeTokenData.balances[owner];
    }

    /// @dev Returns number of allowed tokens for given address.
    /// @param owner Address of token owner.
    /// @param spender Address of token spender.
    /// @return remaining Returns remaining allowance.
    function allowance(address owner, address spender)
        constant
        public
        returns (uint256 remaining)
    {
      return outcomeTokenData.allowed[owner][spender];
    }

    /// @dev Returns total supply of tokens.
    /// @return total Returns total amount of tokens.
    function totalSupply()
        constant
        public
        returns (uint256 total)
    {
        return outcomeTokenData.totalTokens;
    }

    /// @dev Constructor sets events contract address.
    function OutcomeToken() {
        eventFactory = msg.sender;
    }
}
