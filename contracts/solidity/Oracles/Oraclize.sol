pragma solidity ^0.4.0;
import "Oracles/OraclizeFakeAPI.sol";


/// @title Oraclize contract - Allows to resolve Oraclize events with fake API.
/// @author Stefan George - <stefan.george@consensys.net>
contract Oraclize {

    /*
     *  Data structures
     */
    // queryHash => sender
    mapping(bytes32 => address) querySenders;

    /// @dev Fake sending query to Oraclize.
    /// @param timestamp Timestamp, when to set the oracle result.
    /// @param dataSource Data source used to retrieve result.
    /// @param arg Query arguments. E.g. a URL.
    /// @return queryHash Returns query hash.
    function oraclize_query(uint timestamp, string dataSource, string arg)
        public
        returns (bytes32 queryHash)
    {
        queryHash = sha3(timestamp, dataSource, arg);
        querySenders[queryHash] = msg.sender;
    }

    /// @dev Setting fake result in oracle.
    /// @param timestamp Timestamp, when to set the oracle result.
    /// @param dataSource Data source used to retrieve result.
    /// @param arg Query arguments. E.g. a URL.
    /// @param result Oraclize result.
    /// @param proof TLSNotary proof.
    function oraclize_setResult(uint timestamp, string dataSource, string arg, string result, bytes proof)
        public
    {
        bytes32 queryHash = sha3(timestamp, dataSource, arg);
        usingOraclize(querySenders[queryHash]).__callback(queryHash, result, proof);
    }
}
