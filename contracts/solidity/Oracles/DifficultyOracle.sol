pragma solidity ^0.4.0;
import "Oracles/AbstractOracle.sol";


/// @title Difficulty oracle contract - On chain oracle to resolve difficulty events at given block.
/// @author Stefan George - <stefan.george@consensys.net>
/// @author Martin Koeppelmann - <martin.koeppelmann@consensys.net>
contract DifficultyOracle is Oracle {

    /*
     *  Constants
     */
    // Oracle meta data
    string constant public name = "Difficulty Oracle";

    /*
     *  Data structures
     */
    // block number => result
    mapping (uint => uint) difficultyResults;

    // event identifier => block number
    mapping (bytes32 => uint) eventIdentifiers;

    /*
     *  Read and write functions
     */
    /// @dev Sets difficulty as winning outcome for a specific block. Returns success.
    /// @param eventIdentifier Hash identifying an event.
    /// @param data Encodes data used to resolve event. In this case block number.
    function setOutcome(bytes32 eventIdentifier, bytes32[] data)
        external
    {
        uint blockNumber = eventIdentifiers[eventIdentifier];
        if (block.number < blockNumber || difficultyResults[blockNumber] != 0) {
            // Block number was not reached yet or it was set already
            throw;
        }
        difficultyResults[blockNumber] = block.difficulty;
    }

    /// @dev Validates and registers event. Returns event identifier.
    /// @param data Array of oracle addresses used for event resolution.
    /// @return eventIdentifier Returns event identifier.
    function registerEvent(bytes32[] data)
        public
        returns (bytes32 eventIdentifier)
    {
        uint blockNumber = uint(data[0]);
        if (blockNumber <= block.number) {
            // Block number was already reached
            throw;
        }
        eventIdentifier = sha3(data);
        eventIdentifiers[eventIdentifier] = blockNumber;
        EventRegistration(msg.sender, eventIdentifier);
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
        uint blockNumber = eventIdentifiers[eventIdentifier];
        // Difficulty will never be == 0
        return difficultyResults[blockNumber] > 0;
    }

    /// @dev Returns winning outcome for given event.
    /// @param eventIdentifier Hash identifying an event.
    /// @return outcome Returns outcome.
    function getOutcome(bytes32 eventIdentifier)
        constant
        public
        returns (int outcome)
    {
        uint blockNumber = eventIdentifiers[eventIdentifier];
        return int(difficultyResults[blockNumber]);
    }

    /// @dev Returns data needed to identify an event.
    /// @param eventIdentifier Hash identifying an event.
    /// @return data Returns event data.
    function getEventData(bytes32 eventIdentifier)
        constant
        public
        returns (bytes32[] data)
    {
        data = new bytes32[](1);
        data[0] = bytes32(eventIdentifiers[eventIdentifier]);
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
