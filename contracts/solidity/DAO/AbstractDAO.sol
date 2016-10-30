/// @title Abstract DAO contract - Functions to be implemented by DAO contracts.
contract DAO {
    function calcBaseFee(address sender, uint tokenCount) returns (uint fee);
    function calcBaseFeeForShares(address sender, uint shareCount) returns (uint fee);
}
