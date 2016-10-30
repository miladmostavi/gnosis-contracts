pragma solidity ^0.4.0;


contract Token {
    function transfer(address to, uint256 value) returns (bool);
    function transferFrom(address from, address to, uint256 value) returns (bool);
}


contract StateChannelProxy {

    address public owner;
    address public stateChannel;
    bool public isSettled = false;

    modifier isOwnerOrStateChannel () {
        if (!(msg.sender == stateChannel || isSettled && msg.sender == owner))
            throw;
        _;
    }

    modifier isStateChannel () {
        if (msg.sender != stateChannel)
            throw;
        _;
    }

    function sendTransaction(address destination, uint value, bytes data) isOwnerOrStateChannel {
        if (!destination.call.value(value)(data))
            throw;
    }

    function setSettled() isStateChannel {
        isSettled = true;
    }

    function StateChannelProxy(address _owner) {
        owner = _owner;
        stateChannel = msg.sender;
    }
}


/// @title State channel - Generic settlement contract for state channels.
/// @author Stefan George - <stefan.george@consensys.net>
contract StateChannel {

    mapping (address => StateChannelProxy) public proxyContracts;
    address[] owners;
    State public state;
    Token public securityToken;
    uint public securityValue;
    uint public challengePeriod;

    struct State {
        uint timestamp;
        uint nonce;
        bytes32 hash;
        address requester;
        bytes32[] txHashes;
        uint txIndex;
    }

    function requestSettleZeroState() {
        if (state.timestamp > 0 || !securityToken.transferFrom(msg.sender, this, securityValue))
            throw;
        state.timestamp = now;
        state.requester = msg.sender;
    }

    function settleZeroState() {
        if (   !(state.timestamp > 0 && state.timestamp + challengePeriod <= now && state.hash == 0)
            || !securityToken.transfer(msg.sender, securityValue))
            throw;
        for (uint i=0; i<owners.length; i++)
            proxyContracts[owners[i]].setSettled();
    }

    function requestSettlement(bytes32 txsHash, uint nonce, uint timestamp, bytes32 hash, bytes32 secret, uint8[] sigV, bytes32[] sigR, bytes32[] sigS) {
        bytes32 stateHash = sha3(txsHash, nonce, timestamp, hash);
        for (uint i=0; i<owners.length; i++)
            if (owners[i] != ecrecover(stateHash, sigV[i], sigR[i], sigS[i]))
                throw;
        if (   state.timestamp > 0
            || now > timestamp
            || hash > 0 && sha3(secret) != hash
            || !securityToken.transferFrom(msg.sender, this, securityValue))
            throw;
        state.timestamp = now;
        state.nonce = nonce;
        state.hash = stateHash;
        state.requester = msg.sender;
    }

    function submitTradeHashes(bytes32[] txHashes, uint nonce, uint timestamp, bytes32 hash) {
        bytes32 txsHash = sha3(txHashes);
        bytes32 stateHash = sha3(txsHash, nonce, timestamp, hash);
        if (state.hash == stateHash && state.timestamp + challengePeriod <= now)
            state.txHashes = txHashes;
    }

    function executeTrade(address sender, address destination, uint value, bytes data) {
        bytes32 txHash = sha3(sender, destination, value, data);
        if (state.txHashes[state.txIndex] == txHash) {
            StateChannelProxy(sender).sendTransaction(destination, value, data);
            state.txIndex += 1;
            if (state.txIndex == state.txHashes.length)
                for (uint i=0; i<owners.length; i++)
                    proxyContracts[owners[i]].setSettled();
        }
    }

    function punishWrongState(bytes32 txHash, uint nonce, uint timestamp, bytes32 hash, uint8[] sigV, bytes32[] sigR, bytes32[] sigS) {
        bytes32 stateHash = sha3(txHash, nonce, timestamp, hash);
        for (uint i=0; i<owners.length; i++)
            if (owners[i] != ecrecover(stateHash, sigV[i], sigR[i], sigS[i]))
                throw;
        if (   state.nonce > nonce
            || now > timestamp
            || !securityToken.transfer(msg.sender, securityValue))
            throw;
        delete state;
    }

    function StateChannel(address[] _owners, address _securityToken, uint _securityValue, uint _challengePeriod) {
        for (uint i=0; i<_owners.length; i++)
            proxyContracts[_owners[i]] = new StateChannelProxy(_owners[i]);
        owners = _owners;
        securityToken = Token(_securityToken);
        securityValue = _securityValue;
        challengePeriod = _challengePeriod;
    }
}
