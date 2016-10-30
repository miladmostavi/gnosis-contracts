/// @title Abstract oracle contract - Functions to be implemented by oracles.
contract Oracle {
    function registerEvent(bytes32[] data) returns (bytes32 eventIdentifier);
    // function setOutcome(bytes32 eventIdentifier, bytes32[] data) returns (bool success);

    function isOutcomeSet(bytes32 eventIdentifier) constant returns (bool isSet);
    function getFee(bytes32[] data) constant returns (uint fee, address token);
    function getOutcome(bytes32 eventIdentifier) constant returns (int outcome);
    function getEventData(bytes32 eventIdentifier) constant returns (bytes32[] data);

    // Oracle meta data
    // This is not an abstract functions, because solc won't recognize generated getter functions for public variables as functions.
    function name() constant returns (string) {}

    event EventRegistration(address indexed creator, bytes32 indexed eventIdentifier);
}
