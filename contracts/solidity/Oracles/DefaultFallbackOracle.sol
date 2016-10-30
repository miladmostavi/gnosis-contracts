/// @title Abstract oracle contract - Functions to be implemented by oracles.
contract DefaultFallbackOracle {

    /*
     *  Storage
     */
    address owner;
    // signer address => is valid?
    mapping (address => bool) invalidSigners;
    // description hash => signer address => is valid?
    mapping (bytes32 => mapping (address => bool)) invalidSignersForDescriptions;
    // description hash => OracleOutcome
    mapping (bytes32 => OracleOutcome) oracleOutcomes;

    struct OracleOutcome {
        int outcome;
        bool isSet;
    }

    /*
     *  Modifiers
     */
    modifier isOwner() {
        if (msg.sender != owner) {
            // Only owner is allowed to do this action.
            throw;
        }
        _;
    }

    /*
     * Read and write functions
     */
    /// @dev Sets signer as invalid.
    /// @param signer Signer's address.
    function setInvalidSigner(address signer)
        public
        isOwner
    {
        invalidSigners[signer] = true;
    }

    /// @dev Sets signer as invalid.
    /// @param signer Signer's address.
    function setInvalidSignerForDescription(bytes32 descriptionHash, address signer)
        public
        isOwner
    {
        invalidSignersForDescriptions[descriptionHash][signer] = true;
    }

    /// @dev Sets the outcome for an event.
    /// @param descriptionHash Hash identifying off chain event description.
    /// @param outcome Event's outcome.
    function setOutcome(bytes32 descriptionHash, int outcome)
        public
        isOwner
    {
        OracleOutcome oracleOutcome = oracleOutcomes[descriptionHash];
        oracleOutcome.outcome = outcome;
        oracleOutcome.isSet = true;
    }

    /// @dev Contract constructor function sets owner.
    function DefaultFallbackOracle() {
        owner = msg.sender;
    }

    /*
     *  Read functions
     */
    /// @dev Votes for given outcome by adding Ether sent to outcome's stake. Returns success.
    /// @param signer Signer's address.
    /// @return isValid Returns if signer is valid.
    function isValidSigner(bytes32 descriptionHash, address signer)
        public
        returns (bool isValid)
    {
        return !(invalidSigners[signer] || invalidSignersForDescriptions[descriptionHash][signer]);
    }

    /// @dev Returns if winning outcome is set for given event.
    /// @param descriptionHash Hash identifying an event.
    /// @return isSet Returns if outcome is set.
    function isOutcomeSet(bytes32 descriptionHash)
        public
        returns (bool isSet)
    {
        return oracleOutcomes[descriptionHash].isSet;
    }

    /// @dev Returns winning outcome for given event.
    /// @param descriptionHash Hash identifying an event.
    /// @return outcome Returns outcome.
    function getOutcome(bytes32 descriptionHash)
        public
        returns (int outcome)
    {
        return oracleOutcomes[descriptionHash].outcome;
    }
}
