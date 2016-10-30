pragma solidity ^0.4.0;
import "EventFactory/AbstractEventFactory.sol";


/// @title DAO contract - Placeholder contract to be updated with governance logic at a later stage.
/// @author Stefan George - <stefan.george@consensys.net>
contract DAO {

    /*
     *  External contracts
     */
    EventFactory public eventFactory;

    /*
     *  Storage
     */
    address public wallet;
    address public owner;

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

    modifier isWallet() {
        if (msg.sender != wallet) {
            // Only wallet is allowed to do this action.
            throw;
        }
        _;
    }

    /*
     *  Read and write functions
     */
    /// @dev Exchanges DAO contract and updates events and token contracts.
    /// @param daoAddress Address of new DAO contract.
    function changeDAO(address daoAddress)
        external
        isWallet
    {
        eventFactory.changeDAO(daoAddress);
    }

    /// @dev Setup function sets external contracts' addresses.
    /// @param eventFactoryAddress Events address.
    /// @param walletAddress Wallet address.
    function setup(address eventFactoryAddress, address walletAddress)
        external
        isOwner
    {
        if (address(eventFactory) != 0 || wallet != 0) {
            // Setup was executed already
            throw;
        }
        eventFactory = EventFactory(eventFactoryAddress);
        wallet = walletAddress;
    }

    /// @dev Contract constructor function sets owner.
    function DAO() {
        owner = msg.sender;
    }

    /*
     *  Read functions
     */
    /// @dev Returns base fee for amount of tokens.
    /// @param sender Buyers address.
    /// @param tokenCount Amount of invested tokens.
    /// @return fee Returns fee.
    function calcBaseFee(address sender, uint tokenCount)
        constant
        external
        returns (uint fee)
    {
        return 0;
    }

    /// @dev Returns base fee for wanted amount of shares.
    /// @param shareCount Amount of shares to buy.
    /// @return fee Returns fee.
    function calcBaseFeeForShares(address sender, uint shareCount)
        constant
        external
        returns (uint fee)
    {
        return 0;
    }
}
