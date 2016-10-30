/// @title Abstract event factory contract - Functions to be implemented by events contracts.
contract EventFactory {
    function createEvent(bytes32 descriptionHash, bool isRanged, int lowerBound, int upperBound, uint8 outcomeCount, address oracleAddress, address tokenAddress, bytes32[] data) returns (bytes32 eventHash);
    function buyAllOutcomes(bytes32 eventHash, uint shareCount);
    function sellAllOutcomes(bytes32 eventHash, uint shareCount);
    function redeemWinnings(bytes32 eventHash) returns (uint winnings);
    function changeDAO(address _shareholderContractAddress);
    function permitPermanentApproval(address spender);
    function revokePermanentApproval(address spender);

    function calcBaseFee(uint tokenCount) constant returns (uint fee);
    function calcBaseFeeForShares(uint shareCount) constant returns (uint fee);
    function isPermanentlyApproved(address owner, address spender) constant returns (bool isApproved);
    function getDAO() constant returns (address daoAddress);
    function getEventHashes(bytes32[] descriptionHashes) constant returns (uint[] allEventHashes);
    function getEvents(bytes32[] eventHashes, address oracleAddress) constant returns (uint[] allEvents);
    function getEvent(bytes32 eventHash) constant returns (bytes32 descriptionHash, bool isRanged, int lowerBound, int upperBound, uint outcomeCount, address token, address oracle, bytes32 oracleEventIdentifier, bool isWinningOutcomeSet, int winningOutcome);
    function getOutcomeToken(bytes32 eventHash, uint outcomeIndex) constant returns (address eventToken);
    function getShares(address user, bytes32[] _eventHashes) constant returns (uint[] allShares);

    event EventCreation(address indexed creator, bytes32 indexed eventHash);
}
