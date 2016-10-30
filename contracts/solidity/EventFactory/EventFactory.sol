pragma solidity ^0.4.0;
import "Oracles/AbstractOracle.sol";
import "DAO/AbstractDAO.sol";
import "Utils/Lockable.sol";
import "EventFactory/OutcomeToken.sol";


/// @title Event factory contract - Event management and share token storage.
/// @author Stefan George - <stefan.george@consensys.net>
/// @author Martin Koeppelmann - <martin.koeppelmann@consensys.net>
contract EventFactory is Lockable {

    /*
     *  Events
     */
    event EventCreation(address indexed creator, bytes32 indexed eventHash);

    /*
     *  External contracts
     */
    DAO dao = DAO({{DAO}});

    /*
     *  Constants
     */
    uint8 constant SHORT = 0;
    uint8 constant LONG = 1;
    uint16 constant OUTCOME_RANGE = 10000;

    /*
     *  Data structures
     */
    // event hash => Event
    mapping (bytes32 => Event) events;

    // description hash => creator => event hash
    mapping (bytes32 => mapping (address => bytes32)) eventHashes;

    // owner address => approved address => is approved?
    mapping (address => mapping (address => bool)) permanentApprovals;

    struct Event {
        bytes32 descriptionHash;
        bool isRanged;
        int lowerBound;
        int upperBound;
        Token token;
        Oracle oracle;
        bytes32 oracleEventIdentifier;
        bool isWinningOutcomeSet;
        int winningOutcome;
        OutcomeToken[] outcomeTokens;
    }

    /*
     *  Modifiers
     */
    modifier isDAOContract() {
        if (msg.sender != address(dao)) {
            // Only DAO contract is allowed to proceed
            throw;
        }
        _;
    }

    /*
     *  Read and write functions
     */
    /// @dev Sets new DAO contract address.
    /// @param daoAddress New DAO contract address.
    function changeDAO(address daoAddress)
        external
        isDAOContract
    {
        dao = DAO(daoAddress);
    }

    function addEvent(
        address creator,
        bytes32 eventHash,
        bytes32 descriptionHash,
        bool isRanged,
        int lowerBound,
        int upperBound,
        uint8 outcomeCount,
        address token,
        address oracle,
        bytes32 oracleEventIdentifier
    )
        private
    {
        eventHashes[descriptionHash][creator] = eventHash;
        events[eventHash].descriptionHash = descriptionHash;
        events[eventHash].oracle = Oracle(oracle);
        events[eventHash].oracleEventIdentifier = oracleEventIdentifier;
        events[eventHash].isRanged = isRanged;
        events[eventHash].lowerBound = lowerBound;
        events[eventHash].upperBound = upperBound;
        events[eventHash].token = Token(token);
        // Create event tokens for each outcome
        for (uint8 i=0; i<outcomeCount; i++) {
            events[eventHash].outcomeTokens.push(new OutcomeToken());
        }
    }

    /// @dev Creates event and pays fees to oracles used to resolve event. Returns event hash.
    /// @param descriptionHash Hash identifying off chain event description.
    /// @param isRanged Is event a ranged event?
    /// @param lowerBound Lower bound for valid outcomes for ranged events.
    /// @param upperBound Upper bound for valid outcomes for ranged events.
    /// @param outcomeCount Number of outcomes.
    /// @param token Address of token contract in which market is traded.
    /// @param oracle Address of resolving/oracle contract.
    /// @param data Encoded data used to resolve event.
    /// @return eventHash Returns event hash.
    function createEvent(
        bytes32 descriptionHash,
        bool isRanged,
        int lowerBound,
        int upperBound,
        uint8 outcomeCount,
        address token,
        address oracle,
        bytes32[] data
    )
        external
        returns (bytes32 eventHash)
    {
        // Calculate event hash
        eventHash = sha3(descriptionHash, isRanged, lowerBound, upperBound, outcomeCount, token, oracle, data);
        // Check that event doesn't exist and is valid
        if (   events[eventHash].descriptionHash > 0
            || isRanged && lowerBound >= upperBound
            || descriptionHash == 0
            || outcomeCount < 2
            || token == 0
            || oracle == 0)
        {
            // Event exists already or bounds or outcome count are invalid or description hash or token or oracle are not set
            throw;
        }
        // Pay fee
        var (oracleFee, oracleToken) = Oracle(oracle).getFee(data);
        if (   oracleFee > 0
            && (   !Token(oracleToken).transferFrom(msg.sender, this, oracleFee)
                || !Token(oracleToken).approve(oracle, oracleFee)))
        {
            // Tokens could not be transferred or approved
            throw;
        }
        // Register event with oracle
        bytes32 oracleEventIdentifier = Oracle(oracle).registerEvent(data);
        if (oracleEventIdentifier == 0) {
            // Event could not be registered with oracle
            throw;
        }
        // Add event to storage
        addEvent(
            msg.sender,
            eventHash,
            descriptionHash,
            isRanged,
            lowerBound,
            upperBound,
            outcomeCount,
            token,
            oracle,
            oracleEventIdentifier
        );
        EventCreation(msg.sender, eventHash);
    }

    /// @dev Buys equal number of shares of all outcomes, exchanging invested tokens and all outcomes 1:1. Returns success.
    /// @param eventHash Hash identifying an event.
    /// @param tokenCount Number of tokens to invest.
    function buyAllOutcomes(bytes32 eventHash, uint tokenCount)
        external
    {
        // Transfer tokens to events contract
        if (tokenCount > 0 && !events[eventHash].token.transferFrom(msg.sender, this, tokenCount)) {
            // Tokens could not be transferred
            throw;
        }
        // Calculate base fee
        uint fee = calcBaseFee(tokenCount);
        uint addedShares = tokenCount - fee;
        // Transfer fee to DAO contract
        if (fee > 0 && !events[eventHash].token.transfer(dao, fee)) {
            // Sending failed
            throw;
        }
        // Issue new event tokens to owner.
        for (uint8 i=0; i<events[eventHash].outcomeTokens.length; i++) {
            events[eventHash].outcomeTokens[i].issueTokens(msg.sender, addedShares);
        }
    }

    /// @dev Sells equal number of shares of all outcomes, exchanging invested tokens and all outcomes 1:1. Returns success.
    /// @param eventHash Hash identifying an event.
    /// @param shareCount Number of shares to sell.
    function sellAllOutcomes(bytes32 eventHash, uint shareCount)
        external
    {
        // Revoke tokens of all outcomes
        for (uint i=0; i<events[eventHash].outcomeTokens.length; i++) {
            events[eventHash].outcomeTokens[i].revokeTokens(msg.sender, shareCount);
        }
        // Transfer redeemed tokens
        if (shareCount > 0 && !events[eventHash].token.transfer(msg.sender, shareCount)) {
            // Tokens could not be transferred
            throw;
        }
    }

    /// @dev Redeems winnings of sender for given event. Returns success.
    /// @param eventHash Hash identifying an event.
    /// @return winnings Returns winnings.
    function redeemWinnings(bytes32 eventHash)
        external
        isUnlocked
        returns (uint winnings)
    {
        // Check is winning outcome is already set
        if (!events[eventHash].isWinningOutcomeSet) {
            if (!events[eventHash].oracle.isOutcomeSet(events[eventHash].oracleEventIdentifier)) {
                // Winning outcome is not set
                throw;
            }
            // Set winning outcome
            events[eventHash].winningOutcome = events[eventHash].oracle.getOutcome(events[eventHash].oracleEventIdentifier);
            events[eventHash].isWinningOutcomeSet = true;
        }
        // Calculate winnings for ranged events
        if (events[eventHash].isRanged) {
            uint16 convertedWinningOutcome;
            // Outcome is lower than defined lower bound
            if (events[eventHash].winningOutcome < events[eventHash].lowerBound) {
                convertedWinningOutcome = 0;
            }
            // Outcome is higher than defined upper bound
            else if (events[eventHash].winningOutcome > events[eventHash].upperBound) {
                convertedWinningOutcome = OUTCOME_RANGE;
            }
            // Map outcome on outcome range
            else {
                convertedWinningOutcome = uint16(
                    OUTCOME_RANGE * (events[eventHash].winningOutcome - events[eventHash].lowerBound)
                    / (events[eventHash].upperBound - events[eventHash].lowerBound)
                );
            }
            uint factorShort = OUTCOME_RANGE - convertedWinningOutcome;
            uint factorLong = OUTCOME_RANGE - factorShort;
            winnings = (
                events[eventHash].outcomeTokens[SHORT].balanceOf(msg.sender) * factorShort +
                events[eventHash].outcomeTokens[LONG].balanceOf(msg.sender) * factorLong
            ) / OUTCOME_RANGE;
        }
        // Calculate winnings for non ranged events
        else {
            winnings = events[eventHash].outcomeTokens[uint(events[eventHash].winningOutcome)].balanceOf(msg.sender);
        }
        // Revoke all tokens of all outcomes
        for (uint8 i=0; i<events[eventHash].outcomeTokens.length; i++) {
            uint shareCount = events[eventHash].outcomeTokens[i].balanceOf(msg.sender);
            events[eventHash].outcomeTokens[i].revokeTokens(msg.sender, shareCount);
        }
        // Payout winnings
        if (winnings > 0 && !events[eventHash].token.transfer(msg.sender, winnings)) {
            // Tokens could not be transferred
            throw;
        }
    }

    /// @dev Approves address to trade unlimited event shares.
    /// @param spender Address of allowed account.
    function permitPermanentApproval(address spender)
        external
    {
        permanentApprovals[msg.sender][spender] = true;
    }

    /// @dev Revokes approval for address to trade unlimited event shares.
    /// @param spender Address of allowed account.
    function revokePermanentApproval(address spender)
        external
    {
        permanentApprovals[msg.sender][spender] = false;
    }

    /*
     *  Read functions
     */
    /// @dev Returns base fee for amount of tokens.
    /// @param tokenCount Amount of invested tokens.
    /// @return fee Returns fee.
    function calcBaseFee(uint tokenCount)
        constant
        public
        returns (uint fee)
    {
        return dao.calcBaseFee(msg.sender, tokenCount);
    }

    /// @dev Returns base fee for wanted amount of shares.
    /// @param shareCount Amount of shares to buy.
    /// @return fee Returns fee.
    function calcBaseFeeForShares(uint shareCount)
        constant
        external
        returns (uint fee)
    {
        return dao.calcBaseFeeForShares(msg.sender, shareCount);
    }

    /// @dev Returns whether the address is allowed to trade unlimited event shares.
    /// @param owner Address of allowed account.
    /// @return approved Returns approval status.
    function isPermanentlyApproved(address owner, address spender)
        constant
        external
        returns (bool approved)
    {
        return permanentApprovals[owner][spender];
    }

    /// @dev Returns DAO address.
    /// @return dao Returns DAO address.
    function getDAO()
        constant
        external
        returns (address daoAddress)
    {
        return dao;
    }

    /// @dev Returns all event hashes for all given description hashes.
    /// @param descriptionHashes Array of hashes identifying off chain event descriptions.
    /// @param creators Array event creator addresses.
    /// @return allEventHashes Encoded event hashes.
    function getEventHashes(bytes32[] descriptionHashes, address[] creators)
        constant
        external
        returns (uint[] allEventHashes)
    {
        // Calculate array size
        uint arrPos = 0;
        uint count;
        for (uint i=0; i<descriptionHashes.length; i++) {
            count = 0;
            for (uint j=0; j<creators.length; j++) {
                if (eventHashes[descriptionHashes[i]][creators[j]] > 0) {
                    count += 1;
                }
            }
            if (count > 0) {
                arrPos += 2 + count;
            }
        }
        // Fill array
        allEventHashes = new uint[](arrPos);
        arrPos = 0;
        for (i=0; i<descriptionHashes.length; i++) {
            count = 0;
            for (j=0; j<creators.length; j++) {
                if (eventHashes[descriptionHashes[i]][creators[j]] > 0) {
                    allEventHashes[arrPos + 2 + count] = uint(eventHashes[descriptionHashes[i]][creators[j]]);
                    count += 1;
                }
            }
            if (count > 0) {
                allEventHashes[arrPos] = uint(descriptionHashes[i]);
                allEventHashes[arrPos + 1] = count;
                arrPos += 2 + count;
            }
        }
    }

    /// @dev Returns all encoded events for all given event hashes.
    /// @param _eventHashes Array of hashes identifying events.
    /// @param oracle Filter events by oracle.
    /// @param token Filter events by token.
    /// @return allEvents Encoded events.
    function getEvents(bytes32[] _eventHashes, address oracle, address token)
        constant
        external
        returns (uint[] allEvents)
    {
        // Calculate array size
        uint arrPos = 0;
        for (uint i=0; i<_eventHashes.length; i++) {
            if (events[_eventHashes[i]].descriptionHash > 0
                && (oracle == 0 || events[_eventHashes[i]].oracle == oracle)
                && (token == 0 || events[_eventHashes[i]].token == token))
            {
                arrPos += 11 + events[_eventHashes[i]].outcomeTokens.length;
            }
        }
        // Fill array
        allEvents = new uint[](arrPos);
        arrPos = 0;
        for (i=0; i<_eventHashes.length; i++) {
            if (events[_eventHashes[i]].descriptionHash > 0
                && (oracle == 0 || events[_eventHashes[i]].oracle == oracle)
                && (token == 0 || events[_eventHashes[i]].token == token))
            {
                Event _event = events[_eventHashes[i]];
                allEvents[arrPos] = uint(_eventHashes[i]);
                allEvents[arrPos + 1] = uint(_event.descriptionHash);
                if (_event.isRanged) {
                    allEvents[arrPos + 2] = 1;
                }
                else {
                    allEvents[arrPos + 2] = 0;
                }
                allEvents[arrPos + 3] = uint(_event.lowerBound);
                allEvents[arrPos + 4] = uint(_event.upperBound);
                allEvents[arrPos + 5] = uint(_event.token);
                allEvents[arrPos + 6] = uint(_event.oracle);
                allEvents[arrPos + 7] = uint(_event.oracleEventIdentifier);
                // Event result
                if (_event.isWinningOutcomeSet) {
                    allEvents[arrPos + 8] = 1;
                }
                else {
                    allEvents[arrPos + 8] = 0;
                }
                allEvents[arrPos + 9] = uint(_event.winningOutcome);
                // Event token addresses
                allEvents[arrPos + 10] = _event.outcomeTokens.length;
                for (uint j=0; j<_event.outcomeTokens.length; j++) {
                    allEvents[arrPos + 11 + j] = uint(_event.outcomeTokens[j]);
                }
                arrPos += 11 + _event.outcomeTokens.length;
            }
        }
    }

    /// @dev Returns event for event hash.
    /// @param eventHash Hash identifying an event.
    /// @return descriptionHash Hash identifying off chain event description.
    /// @return isRanged Is event a ranged event?
    /// @return lowerBound Lower bound for valid outcomes for ranged events.
    /// @return upperBound Upper bound for valid outcomes for ranged events.
    /// @return outcomeCount Number of outcomes.
    /// @return token Address of token contract in which market is traded.
    /// @return oracle Address of resolving/oracle contract.
    /// @return oracleEventIdentifier Identifier to get oracle result.
    /// @return isWinningOutcomeSet Was winning outcome set?
    /// @return winningOutcome Winning outcome.
    function getEvent(bytes32 eventHash)
        constant
        external
        returns (
            bytes32 descriptionHash,
            bool isRanged,
            int lowerBound,
            int upperBound,
            uint outcomeCount,
            address token,
            address oracle,
            bytes32 oracleEventIdentifier,
            bool isWinningOutcomeSet,
            int winningOutcome
        )
    {
        descriptionHash = events[eventHash].descriptionHash;
        isRanged = events[eventHash].isRanged;
        lowerBound = events[eventHash].lowerBound;
        upperBound = events[eventHash].upperBound;
        outcomeCount = events[eventHash].outcomeTokens.length;
        token = events[eventHash].token;
        oracle = events[eventHash].oracle;
        oracleEventIdentifier = events[eventHash].oracleEventIdentifier;
        isWinningOutcomeSet = events[eventHash].isWinningOutcomeSet;
        winningOutcome = events[eventHash].winningOutcome;
    }

    /// @dev Returns token address of outcome.
    /// @param eventHash Hash identifying an event.
    /// @param outcomeIndex Index of outcome.
    /// @return outcomeToken Returns address of event token.
    function getOutcomeToken(bytes32 eventHash, uint outcomeIndex)
        constant
        external
        returns (address outcomeToken)
    {
        return events[eventHash].outcomeTokens[outcomeIndex];
    }

    /// @dev Returns array of encoded shares sender holds in events identified with event hashes.
    /// @param owner Shareholder's address.
    /// @param _eventHashes Array of hashes identifying events.
    /// @return allShares Encoded shares in events by owner.
    function getShares(address owner, bytes32[] _eventHashes)
        constant
        external
        returns (uint[] allShares)
    {
        // Calculate array size
        uint arrPos = 0;
        for (uint i=0; i<_eventHashes.length; i++) {
            for (uint8 j=0; j<events[_eventHashes[i]].outcomeTokens.length; j++) {
                if (events[_eventHashes[i]].outcomeTokens[j].balanceOf(owner) > 0) {
                    arrPos += 2 + events[_eventHashes[i]].outcomeTokens.length;
                    break;
                }
            }
        }
        // Fill array
        allShares = new uint[](arrPos);
        arrPos = 0;
        for (i=0; i<_eventHashes.length; i++) {
            for (j=0; j<events[_eventHashes[i]].outcomeTokens.length; j++) {
                if (events[_eventHashes[i]].outcomeTokens[j].balanceOf(owner) > 0) {
                    // Add shares
                    allShares[arrPos] = uint(_eventHashes[i]); // event hash
                    allShares[arrPos + 1] = events[_eventHashes[i]].outcomeTokens.length;
                    for (j=0; j<events[_eventHashes[i]].outcomeTokens.length; j++) {
                        allShares[arrPos + 2 + j] = events[_eventHashes[i]].outcomeTokens[j].balanceOf(owner);
                    }
                    arrPos += 2 + j;
                    break;
                }
            }
        }
    }
}
