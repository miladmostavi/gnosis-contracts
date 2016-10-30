pragma solidity ^0.4.0;
import "Oracles/OraclizeFakeAPI.sol";
import "Oracles/AbstractOracle.sol";


/// @title Oraclize proxy resolver contract - On chain oracle to resolve events using Oraclize oracle.
/// @author Stefan George - <stefan.george@consensys.net>
contract OraclizeOracle is Oracle, usingOraclize {

    /*
     *  Data structures
     */
    // queryID => Result
    mapping (bytes32 => Result) results;

    // queryID => is winning outcome set?
    mapping (bytes32 => bool) winningOutcomeSet;

    // queryID =>
    mapping (bytes32 => bytes32[]) eventData;

    struct Result {
        int result;
        uint precision;
        bytes proof;
    }

    /*
     *  Constants
     */
    // Oracle meta data
    string constant public name = "Oraclize wrapper Oracle";

    /*
     *  Read and write functions
     */
    /// @dev Contract constructor tells Oraclize to store TLSNotary proof with result.
    function OraclizeOracle() {
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
    }

    /// @dev Callback called by Oraclize to set result.
    /// @param queryID Query id of Oraclize query.
    /// @param result Result returned as string.
    /// @param proof TLSNotary proof.
    function __callback(bytes32 queryID, string result, bytes proof) {
        if (msg.sender != oraclize_cbAddress()) {
            // Only Oraclize is allowed to call callback
            throw;
        }
        results[queryID].result = parseToInt(result, results[queryID].precision);
        results[queryID].proof = proof;
        winningOutcomeSet[queryID] = true;
    }

    /// @dev Validates and registers event. Returns event identifier.
    /// @param data Array of oracle addresses used for event resolution.
    /// @return eventIdentifier Returns event identifier.
    function registerEvent(bytes32[] data)
        public
        returns (bytes32 queryID)
    {
        uint dataSourceIndex = uint(data[0]);
        string memory dataSource;
        if (dataSourceIndex == 0) {
            dataSource = "URL";
        }
        else if (dataSourceIndex == 1) {
            dataSource = "WolframAlpha";
        }
        else if (dataSourceIndex == 2) {
            dataSource = "Blockchain";
        }
        else {
            // Wrong data source type
            throw;
        }
        uint timestamp = uint(data[1]);
        uint precision = uint(data[2]);
        bytes32[] memory urlData = new bytes32[](data.length - 3);
        for (uint i=3; i<data.length; i++) {
            urlData[i-3] = data[i];
        }
        string memory url = bytes32ArrayToString(urlData);
        // Send query to Oraclize
        queryID = oraclize_query(timestamp, dataSource, url);
        // Save query information
        results[queryID].precision = precision;
        eventData[queryID] = urlData;
        EventRegistration(msg.sender, queryID);
    }

    /*
     *  Read functions
     */
    /// @dev Returns if winning outcome is set for given event.
    /// @param eventIdentifier Hash identifying an event.
    /// @return isSet Returns if outcome is set.
    function isOutcomeSet(bytes32 eventIdentifier)
        constant
        public
        returns (bool isSet)
    {
        return winningOutcomeSet[eventIdentifier];
    }

    /// @dev Returns winning outcome for given event.
    /// @param eventIdentifier Hash identifying an event.
    /// @return outcome Returns outcome.
    function getOutcome(bytes32 eventIdentifier)
        constant
        public
        returns (int outcome)
    {
        return results[eventIdentifier].result;
    }

    /// @dev Returns string concatenating bytes32.
    /// @param data Array of bytes32 strings.
    /// @return concatenation Returns concatenated string.
    function bytes32ArrayToString (bytes32[] data)
        constant
        public
        returns (string concatenation)
    {
        bytes memory bytesString = new bytes(data.length * 32);
        uint urlLength;
        for (uint i=0; i<data.length; i++) {
            for (uint j=0; j<32; j++) {
                byte char = data[i][j];
                if (char != 0) {
                    bytesString[urlLength] = char;
                    urlLength += 1;
                }
            }
        }
        bytes memory bytesStringTrimmed = new bytes(urlLength);
        for (i=0; i<urlLength; i++) {
            bytesStringTrimmed[i] = bytesString[i];
        }
        return string(bytesStringTrimmed);
    }

    /// @dev Parses a string to an integer.
    /// @param _a String with number.
    /// @param _b Number of decimal places.
    /// @return mint Returns parsed integer.
    function parseToInt(string _a, uint _b)
        constant
        public
        returns (int mint)
    {
        bytes memory bresult = bytes(_a);
        mint = 0;
        bool decimals = false;
        for (uint i=0; i<bresult.length; i++) {
            if ((bresult[i] >= 48) && (bresult[i] <= 57)) {
                if (decimals) {
                    if (_b == 0) {
                        break;
                    }
                    else {
                        _b--;
                    }
                }
                mint *= 10;
                mint += int(bresult[i]) - 48;
            }
            else if (bresult[i] == 46) {
                decimals = true;
            }
        }
        mint *= int(10**_b);
        if (bresult[0] == 45) {
            mint *= -1;
        }
    }

    /// @dev Returns data needed to identify an event.
    /// @param eventIdentifier Hash identifying an event.
    /// @return data Returns event data.
    function getEventData(bytes32 eventIdentifier)
        constant
        public
        returns (bytes32[] data)
    {
        return eventData[eventIdentifier];
    }

    /// @dev Returns total fees for oracle.
    /// @param data Event data used for event resolution.
    /// @return fee Returns fee.
    /// @return token Returns token.
    function getFee(bytes32[] data)
        constant
        public
        returns (uint fee, address token)
    {
        fee = 0;
        token = 0;
    }
}
