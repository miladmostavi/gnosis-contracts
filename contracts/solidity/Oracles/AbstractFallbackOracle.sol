/// @title Abstract oracle contract - Functions to be implemented by oracles.
contract FallbackOracle {
    function isValidSigner(bytes32 descriptionHash, address signer) returns (bool isValid);
    function isOutcomeSet(bytes32 descriptionHash) returns (bool isSet);
    function getOutcome(bytes32 descriptionHash) returns (int outcome);
}
