pragma solidity ^0.4.0;
import "Oracles/Oraclize.sol";


/// @title Oraclize fake API contract - Fake API to test Oraclize.
/// @author Stefan George - <stefan.george@consensys.net>
contract usingOraclize {

    /*
     *  Constants
     */
    byte constant proofType_TLSNotary = 0x10;
    byte constant proofStorage_IPFS = 0x01;

    /*
     *  External contracts
     */
    Oraclize constant oraclize = Oraclize({{Oraclize}});

    /// @dev Fake setting of TLSNotary proof.
    /// @param proof TLSNotary proof.
    function oraclize_setProof(byte proof) {}

    /// @dev Callback called by Oraclize to set result.
    /// @param queryID Query id of Oraclize query.
    /// @param result Result returned as string.
    /// @param proof TLSNotary proof.
    function __callback(bytes32 queryID, string result, bytes proof) {}

    /// @dev Returns address of Oraclize contract.
    function oraclize_cbAddress() returns (address) {
        return oraclize;
    }

    /// @dev Fake sending query to Oraclize.
    /// @param timestamp Timestamp, when to set the oracle result.
    /// @param dataSource Data source used to retrieve result.
    /// @param arg Query arguments. E.g. a URL.
    function oraclize_query(uint timestamp, string dataSource, string arg) returns (bytes32) {
        return oraclize.oraclize_query(timestamp, dataSource, arg);
    }
}
