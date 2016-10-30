pragma solidity ^0.4.0;
import "EventFactory/AbstractEventFactory.sol";


/// @title Outcome token library - Standard token interface functions.
/// @author Stefan George - <stefan.george@consensys.net>
library OutcomeTokenLibrary {

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    struct Data {
        mapping (address => uint256) balances;
        mapping (address => mapping (address => uint256)) allowed;
        uint256 totalTokens;
    }

    /// @dev Transfers sender's tokens to a given address. Returns success.
    /// @param self Storage reference.
    /// @param _to Address of token receiver.
    /// @param _value Number of tokens to transfer.
    /// @return success Returns success of function call.
    function transfer(Data storage self, address _to, uint256 _value)
        returns (bool success)
    {
        if (   self.balances[msg.sender] < _value
            || self.balances[_to] + _value < self.balances[_to])
        {
            // Balance too low or overflow
            throw;
        }
        self.balances[msg.sender] -= _value;
        self.balances[_to] += _value;
        Transfer(msg.sender, _to, _value);
        return true;
    }

    /// @dev Allows allowed third party to transfer tokens from one address to another. Returns success.
    /// @param self Storage reference.
    /// @param _from Address from where tokens are withdrawn.
    /// @param _to Address to where tokens are sent.
    /// @param _value Number of tokens to transfer.
    /// @param eventFactoryAddress Address of events contract.
    /// @return success Returns success of function call.
    function transferFrom(Data storage self, address _from, address _to, uint256 _value, address eventFactoryAddress)
        returns (bool success)
    {
        if (   self.balances[_from] < _value
            || self.balances[_to] + _value < self.balances[_to]
            || (   self.allowed[_from][msg.sender] < _value
                && !EventFactory(eventFactoryAddress).isPermanentlyApproved(_from, msg.sender)))
        {
            // Balance too low or overflow or allowance too low and not permanently approved
            throw;
        }
        self.balances[_to] += _value;
        self.balances[_from] -= _value;
        if (!EventFactory(eventFactoryAddress).isPermanentlyApproved(_from, msg.sender)) {
            self.allowed[_from][msg.sender] -= _value;
        }
        Transfer(_from, _to, _value);
        return true;
    }

    /// @dev Sets approved amount of tokens for spender. Returns success.
    /// @param self Storage reference.
    /// @param _spender Address of allowed account.
    /// @param _value Number of approved tokens.
    /// @return success Returns success of function call.
    function approve(Data storage self, address _spender, uint256 _value)
        returns (bool success)
    {
        self.allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }
}
