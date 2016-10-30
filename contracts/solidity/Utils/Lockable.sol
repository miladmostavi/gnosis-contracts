pragma solidity ^0.4.0;


/// @title Lockable contract - Allows to limit code execution to one time per transaction.
/// @author Stefan George - <stefan.george@consensys.net>
contract Lockable {

    bool internal isLocked;

    modifier isUnlocked () {
        if (isLocked) {
            // There is a global lock active.
            throw;
        }
        isLocked = true;
        _;
        isLocked = false;
    }
}
