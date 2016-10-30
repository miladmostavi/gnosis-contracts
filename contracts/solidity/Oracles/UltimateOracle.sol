pragma solidity ^0.4.0;
import "Oracles/AbstractOracle.sol";
import "Oracles/AbstractFallbackOracle.sol";
import "Tokens/AbstractToken.sol";


/// @title Ultimate oracle contract - Manages oracle outcomes and allows usage of ultimate oracle
/// @author Stefan George - <stefan.george@consensys.net>
/// @author Martin Koeppelmann - <martin.koeppelmann@consensys.net>
contract UltimateOracle is Oracle {

    /*
     *  Constants
     */
    uint constant CHALLENGE_PERIOD = 12 hours;
    uint constant CHALLENGE_FEE = 100 ether;
    uint constant TWENTY_FOUR_HOURS = 1 days;
    uint constant SPREAD_MULTIPLIER = 3; // Max. 300% spread between amount on front-runner and all others

    // Oracle meta data
    string constant public name = "Ultimate Oracle";

    // Token used to pay fees
    Token constant token = Token({{EtherToken}});

    /*
     *  Data structures
     */
    // description hash => ultimate outcome
    mapping (bytes32 => UltimateOutcome) public ultimateOutcomes;

    // user address => event description hash => outcome => amount
    mapping (address => mapping (bytes32 => mapping(int => uint))) public shares;

    // user address => event description hash => outcome => amount
    mapping (address => mapping (bytes32 => mapping(int => uint))) public deposits;

    // description hash => oracle address => oracle outcome
    mapping (bytes32 => mapping (address => OracleOutcome)) public oracleOutcomes;

    // event identifier => oracle addresses
    mapping (bytes32 => address[]) public eventOracles;

    // event identifier => description hash
    mapping (bytes32 => bytes32) public descriptionHashes;

    // oracle address => fallback oracle address
    mapping (address => FallbackOracle) public fallbackOracles;

    struct OracleOutcome {
        uint submissionAtTimestamp;
        int outcome;
        bool challenged;
    }

    struct UltimateOutcome {
        bool isFinal;
        uint closingAtTimestamp;
        int frontRunner;
        uint totalShares;
        uint totalDeposits;
        /* outcome => amount */
        mapping(int => uint) totalSharesForOutcome;
        /* outcome => amount */
        mapping(int => uint) totalDepositsForOutcome;
    }

    /*
     * Read and write functions
     */
    /// @dev Challenges outcome set by oracles and starts ultimate oracle. Returns success.
    /// @param descriptionHash Hash identifying off chain event description.
    /// @param oracle Challenged oracle.
    /// @param outcome Voted outcome.
    function challengeOracle(bytes32 descriptionHash, address oracle, int outcome)
        public
    {
        OracleOutcome oracleOutcome = oracleOutcomes[descriptionHash][oracle];
        if (   oracleOutcome.challenged
            || oracleOutcome.submissionAtTimestamp == 0
            || oracleOutcome.submissionAtTimestamp + CHALLENGE_PERIOD < now
            || !token.transferFrom(msg.sender, this, CHALLENGE_FEE))
        {
            // The oracle has already been challenged or an oracle hasn't submitted a result yet or challenge period is over or fee cannot be paid.
            throw;
        }
        oracleOutcome.challenged = true;
        // Add deposit
        deposits[msg.sender][descriptionHash][outcome] += CHALLENGE_FEE;
        UltimateOutcome ultimateOutcome = ultimateOutcomes[descriptionHash];
        ultimateOutcome.totalDepositsForOutcome[outcome] += CHALLENGE_FEE;
        ultimateOutcome.totalDeposits += CHALLENGE_FEE;
        // Vote for outcome
        voteForUltimateOutcome(descriptionHash, outcome, CHALLENGE_FEE);
    }

    /// @dev Votes for given outcome by adding Ether sent to outcome's stake. Returns success.
    /// @param descriptionHash Hash identifying off chain event description.
    /// @param outcome Voted outcome.
    /// @param amount Voted amount.
    function voteForUltimateOutcome(bytes32 descriptionHash, int outcome, uint amount)
        public
    {
        UltimateOutcome ultimateOutcome = ultimateOutcomes[descriptionHash];
        // First vote required challenge fee
        if (ultimateOutcome.totalShares == 0) {
            amount = CHALLENGE_FEE;
        }
        // Amount has to be in max. spread
        else {
            uint maxAmount =   (ultimateOutcome.totalShares - ultimateOutcome.totalSharesForOutcome[outcome]) * SPREAD_MULTIPLIER
                             - ultimateOutcome.totalSharesForOutcome[outcome];
            if (amount > maxAmount) {
                amount = maxAmount;
            }
        }
        uint transferableAmount;
        uint deposit = deposits[msg.sender][descriptionHash][outcome];
        if (deposit > amount) {
            deposits[msg.sender][descriptionHash][outcome] -= amount;
            ultimateOutcome.totalDepositsForOutcome[outcome] -= amount;
            ultimateOutcome.totalDeposits -= amount;
            transferableAmount = 0;
        }
        else {
            deposits[msg.sender][descriptionHash][outcome] = 0;
            ultimateOutcome.totalDepositsForOutcome[outcome] -= deposit;
            ultimateOutcome.totalDeposits -= deposit;
            transferableAmount = amount - deposit;
        }
        if (   ultimateOutcome.isFinal
            || ultimateOutcome.closingAtTimestamp <= now && ultimateOutcome.closingAtTimestamp > 0
            || transferableAmount > 0 && !token.transferFrom(msg.sender, this, transferableAmount))
        {
            // Result is already final or voting period passed or tokens could not be transferred
            throw;
        }
        // Execute vote
        shares[msg.sender][descriptionHash][outcome] += amount;
        ultimateOutcome.totalSharesForOutcome[outcome] += amount;
        ultimateOutcome.totalShares += amount;
        if (ultimateOutcome.totalSharesForOutcome[ultimateOutcome.frontRunner] < ultimateOutcome.totalSharesForOutcome[outcome]) {
            // Front runner changed
            ultimateOutcome.closingAtTimestamp = now + TWENTY_FOUR_HOURS;
            ultimateOutcome.frontRunner = outcome;
        }
    }

    /// @dev Sets ultimate outcome result if closing block number is passed. Returns success.
    /// @param descriptionHash Hash identifying off chain event description.
    function setUltimateOutcome(bytes32 descriptionHash)
        public
    {
        UltimateOutcome ultimateOutcome = ultimateOutcomes[descriptionHash];
        if (ultimateOutcome.closingAtTimestamp > now) {
            // Voting period is not over yet
            throw;
        }
        ultimateOutcome.isFinal = true;
    }

    /// @dev Withdraws user's winnings from total winnings. Returns success.
    /// @param descriptionHash Hash identifying off chain event description.
    function redeemWinnings(bytes32 descriptionHash)
        public
    {
        UltimateOutcome ultimateOutcome = ultimateOutcomes[descriptionHash];
        if (!ultimateOutcome.isFinal) {
            // Final outcome not set
            throw;
        }
        // Calculate winnings
        uint totalFrontRunner =   ultimateOutcome.totalSharesForOutcome[ultimateOutcome.frontRunner]
                                + ultimateOutcome.totalDepositsForOutcome[ultimateOutcome.frontRunner];
        uint totalShares = ultimateOutcome.totalSharesForOutcome[ultimateOutcome.frontRunner];
        uint totalWinnings = ultimateOutcome.totalShares + ultimateOutcome.totalDeposits - totalFrontRunner;
        // Shareholder shares
        uint shareholderShares = shares[msg.sender][descriptionHash][ultimateOutcome.frontRunner];
        shares[msg.sender][descriptionHash][ultimateOutcome.frontRunner] = 0;
        // Shareholder deposit
        uint shareholderDeposit = deposits[msg.sender][descriptionHash][ultimateOutcome.frontRunner];
        deposits[msg.sender][descriptionHash][ultimateOutcome.frontRunner] = 0;
        // Add winnings
        uint shareholderWinnings =   totalWinnings * shareholderShares / totalShares
                                   + shareholderShares
                                   + shareholderDeposit;
        // Send winnings
        if (shareholderWinnings > 0 && !token.transfer(msg.sender, shareholderWinnings)) {
            // Transfer failed
            throw;
        }
    }

    /// @dev Pays fees defined by oracles. Returns success.
    /// @param data Array of oracle addresses used for event resolution.
    /// @return success Returns success of function call.
    /// @return eventIdentifier Returns event identifier.
    function registerEvent(bytes32[] data)
        public
        returns (bytes32 eventIdentifier)
    {
        eventIdentifier = sha3(data);
        bytes32 descriptionHash = data[0];
        descriptionHashes[eventIdentifier] = descriptionHash;
        // Validating signatures
        uint fee;
        address feeToken;
        uint8 v;
        bytes32 r;
        bytes32 s;
        address oracle;
        for (uint i=1; i<data.length; i+=5) {
            fee = uint(data[i]);
            feeToken = address(data[i + 1]);
            v = uint8(data[i + 2]);
            r = data[i + 3];
            s = data[i + 4];
            oracle = ecrecover(sha3(descriptionHash, fee, feeToken), v, r, s);
            FallbackOracle fallbackOracle = fallbackOracles[oracle];
            if (address(fallbackOracle) > 0 && !fallbackOracle.isValidSigner(descriptionHash, oracle)) {
                // Oracle cannot be registered because it is marked as invalid
                throw;
            }
            eventOracles[eventIdentifier].push(oracle);
            if (fee > 0 && !Token(feeToken).transferFrom(msg.sender, oracle, fee)) {
                // Tokens could not be transferred
                throw;
            }
        }
        EventRegistration(msg.sender, eventIdentifier);
    }

    /// @dev Sets winning outcomes for given oracles. Returns success.
    /// @param eventIdentifier Hash identifying an event.
    /// @param data Array of encoded signed oracle results used for event resolution.
    function setOutcome(bytes32 eventIdentifier, bytes32[] data)
        public
    {
        bytes32 descriptionHash = descriptionHashes[eventIdentifier];
        int outcome;
        uint8 v;
        bytes32 r;
        bytes32 s;
        address oracle;
        for (uint i=0; i<data.length/4; i++) {
            outcome = int(data[i * 4]);
            v = uint8(data[i * 4 + 1]);
            r = data[i * 4 + 2];
            s = data[i * 4 + 3];
            oracle = ecrecover(sha3(descriptionHash, outcome), v, r, s);
            FallbackOracle fallbackOracle = fallbackOracles[oracle];
            // Check for invalid oracle
            if (address(fallbackOracle) > 0 && !fallbackOracle.isValidSigner(descriptionHash, oracle)) {
                if (!fallbackOracle.isOutcomeSet(descriptionHash)) {
                    // Oracle cannot be set
                    continue;
                }
                outcome = fallbackOracle.getOutcome(descriptionHash);
            }
            OracleOutcome oracleOutcome = oracleOutcomes[descriptionHash][oracle];
            if (oracleOutcome.submissionAtTimestamp == 0) {
                oracleOutcome.outcome = outcome;
                oracleOutcome.submissionAtTimestamp = now;
            }
        }
    }

    /// @dev Sets fallback oracle for off-chain-oracle. Returns success.
    /// @param fallbackOracle Address of fallback oracle.
    function registerFallbackOracle(address fallbackOracle)
        public
    {
        if (address(fallbackOracles[msg.sender]) > 0) {
            // It has already been set
            throw;
        }
        fallbackOracles[msg.sender] = FallbackOracle(fallbackOracle);
    }

    /*
     *  Read functions
     */
    /// @dev Returns array with encoded results published by oracles and state of ultimate oracle.
    /// @param descriptionHashes Hash identifying off chain event description.
    /// @param oracles Array with oracle addresses.
    /// @return allOracleOutcomes Returns all encoded oracle outcomes.
    function getOracleOutcomes(bytes32[] descriptionHashes, address[] oracles)
        constant
        public
        returns (uint[] allOracleOutcomes)
    {
        // Calculate array size
        uint arrPos = 0;
        uint oracleCount;
        for (uint i=0; i<descriptionHashes.length; i++) {
            bytes32 descriptionHash = descriptionHashes[i];
            oracleCount = 0;
            for (uint j=0; j<oracles.length; j++) {
                address oracle = oracles[j];
                if (oracleOutcomes[descriptionHash][oracle].submissionAtTimestamp > 0) {
                    arrPos += 4;
                    oracleCount +=1;
                }
            }
            if (oracleCount > 0) {
                arrPos += 2;
            }
        }
        // Fill array
        allOracleOutcomes = new uint[](arrPos);
        arrPos = 0;
        for (i=0; i<descriptionHashes.length; i++) {
            descriptionHash = descriptionHashes[i];
            oracleCount = 0;
            for (j=0; j<oracles.length; j++) {
                OracleOutcome oracleOutcome = oracleOutcomes[descriptionHash][oracles[j]];
                if (oracleOutcome.submissionAtTimestamp > 0) {
                    allOracleOutcomes[arrPos + 2 + j*4] = uint(oracles[j]);
                    allOracleOutcomes[arrPos + 3 + j*4] = oracleOutcome.submissionAtTimestamp;
                    allOracleOutcomes[arrPos + 4 + j*4] = uint(oracleOutcome.outcome);
                    if (oracleOutcome.challenged) {
                        allOracleOutcomes[arrPos + 5 + j*4] = 1;
                    }
                    else {
                        allOracleOutcomes[arrPos + 5 + j*4] = 0;
                    }
                    oracleCount += 1;
                }
            }
            if (oracleCount > 0) {
                allOracleOutcomes[arrPos] = uint(descriptionHash);
                allOracleOutcomes[arrPos + 1] = oracleCount;
                arrPos += 2 + oracleCount * 4;
            }
        }
    }

    /// @dev Returns array of ultimate oracles' results for given description hashes.
    /// @param descriptionHashes Array of hashes identifying off chain event description.
    /// @param outcomes Array of outcomes with shares.
    /// @return allUltimateOutcomes Returns all encoded ultimate outcomes.
    function getUltimateOutcomes(bytes32[] descriptionHashes, int[] outcomes)
        constant
        public
        returns (uint[] allUltimateOutcomes)
    {
        allUltimateOutcomes = new uint[](descriptionHashes.length * 10);
        for (uint i=0; i<descriptionHashes.length; i+= 10) {
            bytes32 descriptionHash = descriptionHashes[i];
            UltimateOutcome ultimateOutcome = ultimateOutcomes[descriptionHash];
            allUltimateOutcomes[i] = uint(descriptionHash);
            if (ultimateOutcome.isFinal) {
                allUltimateOutcomes[i + 1] = 1;
            }
            else {
                allUltimateOutcomes[i + 1] = 0;
            }
            allUltimateOutcomes[i + 2] = ultimateOutcome.closingAtTimestamp;
            allUltimateOutcomes[i + 3] = uint(ultimateOutcome.frontRunner);
            allUltimateOutcomes[i + 4] = ultimateOutcome.totalShares;
            allUltimateOutcomes[i + 5] = uint(ultimateOutcome.totalSharesForOutcome[ultimateOutcome.frontRunner]);
            allUltimateOutcomes[i + 6] = uint(ultimateOutcome.totalSharesForOutcome[outcomes[i]]);
            allUltimateOutcomes[i + 7] = ultimateOutcome.totalDeposits;
            allUltimateOutcomes[i + 8] = uint(ultimateOutcome.totalDepositsForOutcome[ultimateOutcome.frontRunner]);
            allUltimateOutcomes[i + 9] = uint(ultimateOutcome.totalDepositsForOutcome[outcomes[i]]);
        }
    }

    /// @dev Returns sender's investments in ultimate oracles for given description hashes.
    /// @param user User's address.
    /// @param descriptionHashes Array of hashes identifying off chain event description.
    /// @param outcomes Array of outcomes with shares.
    /// @return allShares Returns all user's shares.
    function getShares(address user, bytes32[] descriptionHashes, int[] outcomes)
        constant
        public
        returns (uint[] allShares)
    {
        allShares = new uint[](descriptionHashes.length);
        for (uint i=0; i<descriptionHashes.length; i++) {
            bytes32 descriptionHash = descriptionHashes[i];
            allShares[i] = shares[user][descriptionHash][outcomes[i]];
        }
    }

    /// @dev Returns all fallback oracles associated to given oracles.
    /// @param oracles List of off-chain-oracles.
    /// @return allFallbackOracles Returns all associated fallback oracles.
    function getFallbackOracles(address[] oracles)
        constant
        public
        returns (address[] allFallbackOracles)
    {
        allFallbackOracles = new address[](oracles.length);
        for (uint i=0; i<oracles.length; i++) {
            FallbackOracle fallbackOracle = fallbackOracles[oracles[i]];
            allFallbackOracles[i] = address(fallbackOracle);
        }
    }

    function getStatusAndWinningOutcome(bytes32 eventIdentifier)
        private
        returns (bool winningOutcomeIsSet, int winningOutcome)
    {
        bytes32 descriptionHash = descriptionHashes[eventIdentifier];
        address[] oracles = eventOracles[eventIdentifier];
        int[] memory outcomes = new int[](oracles.length);
        uint8[] memory validations = new uint8[](oracles.length);
        uint finalizedOracles = 0;
        // Count the validations for each outcome
        for (uint8 i=0; i<oracles.length; i++) {
            OracleOutcome oracleOutcome = oracleOutcomes[descriptionHash][oracles[i]];
            if (   oracleOutcome.submissionAtTimestamp == 0
                || oracleOutcome.submissionAtTimestamp + CHALLENGE_PERIOD > now
                || oracleOutcome.challenged && !ultimateOutcomes[descriptionHash].isFinal)
            {
                // Outcome was not submitted or challenge period is not over yet or it was challenged and ultimate outcome is not set yet
                continue;
            }
            finalizedOracles += 1;
            int outcome;
            if (oracleOutcome.challenged) {
                outcome = ultimateOutcomes[descriptionHash].frontRunner;
            }
            else {
                outcome = oracleOutcomes[descriptionHash][oracles[i]].outcome;
            }
            for (uint8 j=0; j<=i; j++) {
                if (outcome == outcomes[j]) {
                    validations[j] += 1;
                    break;
                }
                else if (outcomes[j] == 0) {
                    outcomes[j] = outcome;
                    validations[j] += 1;
                }
            }
        }
        // Get outcome with most validations and check majority
        uint8 favoriteOutcomeValidations = 0;
        uint8 favoriteOutcomeIndex = 0;
        for (i=0; i<oracles.length; i++) {
            if (validations[i] > favoriteOutcomeValidations) {
                favoriteOutcomeValidations = validations[i];
                favoriteOutcomeIndex = i;
            }
        }
        winningOutcomeIsSet = false;
        // There is a majority vote
        if (favoriteOutcomeValidations * 2 > oracles.length) {
            winningOutcome = outcomes[favoriteOutcomeIndex];
            winningOutcomeIsSet = true;
        }
        // Check if there is a deadlock and use ultimate oracle in this case
        else if (   (favoriteOutcomeValidations + (oracles.length - finalizedOracles)) * 2 <= oracles.length
                 && ultimateOutcomes[descriptionHash].isFinal)
        {
            winningOutcome = ultimateOutcomes[descriptionHash].frontRunner;
            winningOutcomeIsSet = true;
        }
    }

    /// @dev Returns if winning outcome is set for given event.
    /// @param eventIdentifier Hash identifying an event.
    /// @return isSet Returns if outcome is set.
    function isOutcomeSet(bytes32 eventIdentifier)
        constant
        public
        returns (bool isSet)
    {
        var (winningOutcomeIsSet, ) = getStatusAndWinningOutcome(eventIdentifier);
        isSet = winningOutcomeIsSet;
    }

    /// @dev Returns winning outcome for given event.
    /// @param eventIdentifier Hash identifying an event.
    /// @return outcome Returns outcome.
    function getOutcome(bytes32 eventIdentifier)
        constant
        public
        returns (int outcome)
    {
        var (winningOutcomeIsSet, winningOutcome) = getStatusAndWinningOutcome(eventIdentifier);
        if (winningOutcomeIsSet) {
            outcome = winningOutcome;
        }
        else {
            // Outcome is not set
            throw;
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
        data = new bytes32[](1 + eventOracles[eventIdentifier].length);
        data[0] = descriptionHashes[eventIdentifier];
        for (uint i=0; i<eventOracles[eventIdentifier].length; i++) {
            data[1 + i] = bytes32(eventOracles[eventIdentifier][i]);
        }
    }

    /// @dev Returns total fees for oracles.
    /// @param data Event data used for event resolution.
    /// @return fee Returns fee.
    /// @return _token Returns token.
    function getFee(bytes32[] data)
        constant
        public
        returns (uint fee, address _token)
    {
        _token = address(data[2]);
        for (uint i=1; i<data.length; i+=5) {
            fee += uint(data[i]);
            if (_token != address(data[i + 1])) {
                // All selected oracles have to use the same fee token
                throw;
            }
        }
    }
}
