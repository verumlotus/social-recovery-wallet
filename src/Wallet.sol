// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
import "@solmate/utils/ReentrancyGuard.sol";

/**
 * @title SocialRecoveryWallet
 * @notice Social Recovery Wallet that preserves privacy of the Guardian's identities until recovery mode.
 * Idea from https://vitalik.ca/general/2021/01/11/recovery.html
 * Note: This lightweight implementation is designed to support the case of losing the signing private key. 
 * In its current design, it is trivial for a compromised (stolen) signing key to drain the wallet. 
 * @author verum 
 */
contract Wallet is ReentrancyGuard {
    /************************************************
     *  STORAGE
    ***********************************************/
    /// @notice true if hash of guardian address, else false
    mapping(bytes32 => bool) isGuardian;

    /// @notice stores the guardian threshold
    uint256 threshold;

    /// @notice owner of the wallet
    address owner;

    /// @notice true iff wallet is in recovery mode
    bool inRecovery;

    /// @notice round of recovery we're in 
    uint256 currRecoveryRound;

    /// @notice mapping for bookkeeping when swapping guardians
    mapping(bytes32 => uint256) guardianHashToRemovalTimestamp;

    /// @notice struct used for bookkeeping during recovery mode
    /// @dev trival struct but can be extended in future (when building for malicious guardians
    /// or when owner key is compromised)
    struct Recovery {
        address proposedOwner;
        uint256 recoveryRound; // recovery round in which this recovery struct was created
        bool usedInExecuteRecovery; // set to true when we see this struct in RecoveryExecute
    }

    /// @notice mapping from guardian address to most recent Recovery struct created by them
    mapping(address => Recovery) guardianToRecovery;

    /************************************************
     *  MODIFIERS & EVENTS
    ***********************************************/
    modifier onlyOwner {
        require(msg.sender == owner, "only owner");
        _;
    }

    modifier onlyGuardian {
        require(isGuardian[keccak256(abi.encodePacked(msg.sender))], "only guardian");
        _;
    }

    modifier notInRecovery {
        require(!inRecovery, "wallet is in recovery mode");
        _;
    }

    modifier onlyInRecovery {
        require(inRecovery, "wallet is not in recovery mode");
        _;
    }

    /// @notice emitted when an external transaction/transfer is executed
    event TransactionExecuted(address indexed callee, uint256 value, bytes data);

    /// @notice emitted when guardian transfers ownership
    event GuardinshipTransferred(address indexed from, bytes32 indexed newGuardianHash);

    /// @notice emit when recovery initiated
    event RecoveryInitiated(address indexed by, address newProposedOwner, uint256 indexed round);

    /// @notice emit when recovery supported
    event RecoverySupported(address by, address newProposedOwner, uint256 indexed round);
       
    /// @notice emit when recovery is cancelled
    event RecoveryCancelled(address by, uint256 indexed round);

    /// @notice emit when recovery is executed
    event RecoveryExecuted(address oldOwner, address newOwner, uint256 indexed round);

    /// @notice emit when guardian queued for removal
    event GuardianRemovalQueued(bytes32 indexed guardianHash);

    /// @notice emit when guardian removed
    event GuardianRemoved(bytes32 indexed oldGuardianHash, bytes32 indexed newGuardianHash);

    /// @notice emit when guardian reveals themselves
    event GuardianRevealed(bytes32 indexed guardianHash, address indexed guardianAddr);

    /**
     * @notice Sets guardian hashes and threshold
     * @param guardianAddrHashes - array of guardian address hashes
     * @param _threshold - number of guardians required for guardian duties
     */
    constructor(bytes32[] memory guardianAddrHashes, uint256 _threshold) {
        require(_threshold <= guardianAddrHashes.length, "threshold too high");
        
        for(uint i = 0; i < guardianAddrHashes.length; i++) {
            require(!isGuardian[guardianAddrHashes[i]], "duplicate guardian");
            isGuardian[guardianAddrHashes[i]] = true;
        }
        
        threshold = _threshold;
        owner = msg.sender;
    }

    /************************************************
     *  Recovery
    ***********************************************/

    /**
     * @notice Allows owner to execute an arbitrary transaction 
     * @dev to transfer ETH to an EOA, pass in empty string for data parameter
     * @param callee - contract/EOA to call/transfer to
     * @param value - value to pass to callee from wallet balance
     * @param data - data to pass to callee 
     * @return result of the external call
     */
    function executeExternalTx(address callee, 
        uint256 value, 
        bytes memory data
    ) external onlyOwner nonReentrant returns (bytes memory) {
        (bool success, bytes memory result) = callee.call{value: value}(data);
        require(success, "external call reverted");
        emit TransactionExecuted(callee, value, data);
        return result;
    }

    /**
     * @notice Allows a guardian to initiate a wallet recovery
     * Wallet cannot already be in recovery mode
     * @param _proposedOwner - address of the new propsoed owner
     */
    function initiateRecovery(address _proposedOwner) onlyGuardian notInRecovery external {
        // we are entering a new recovery round
        currRecoveryRound++;
        guardianToRecovery[msg.sender] = Recovery(
            _proposedOwner,
            currRecoveryRound, 
            false
        );
        inRecovery = true;
        emit RecoveryInitiated(msg.sender, _proposedOwner, currRecoveryRound);
    }

    /**
     * @notice Allows a guardian to support a wallet recovery
     * Wallet must already be in recovery mode
     * @param _proposedOwner - address of the proposed owner;
     */
    function supportRecovery(address _proposedOwner) onlyGuardian onlyInRecovery external {
        guardianToRecovery[msg.sender] = Recovery(
            _proposedOwner,
            currRecoveryRound, 
            false
        );
        emit RecoverySupported(msg.sender, _proposedOwner, currRecoveryRound);
    }

    /**
     * @notice Allows the owner to cancel a wallet recovery (assuming they recovered private keys)
     * Wallet must already be in recovery mode
     * @dev TODO: allow guardians to cancel recovery
     * (need more than one guardian else trivially easy for one malicious guardian to DoS a wallet recovery)
     */
    function cancelRecovery() onlyOwner onlyInRecovery external {
        inRecovery = false;
        emit RecoveryCancelled(msg.sender, currRecoveryRound);
    }

    /**
     * @notice Allows a guardian to execute a wallet recovery and set a newOwner
     * Wallet must already be in recovery mode
     * @param newOwner - the new owner of the wallet
     * @param guardianList - list of addresses of guardians that have voted for this newOwner
     */
    function executeRecovery(address newOwner, address[] calldata guardianList) onlyGuardian onlyInRecovery external {
        // Need enough guardians to agree on same newOwner
        require(guardianList.length >= threshold, "more guardians required to transfer ownership");

        // Let's verify that all guardians agreed on the same newOwner in the same round
        for (uint i = 0; i < guardianList.length; i++) {
            // cache recovery struct in memory
            Recovery memory recovery = guardianToRecovery[guardianList[i]];

            require(recovery.recoveryRound == currRecoveryRound, "round mismatch");
            require(recovery.proposedOwner == newOwner, "disagreement on new owner");
            require(!recovery.usedInExecuteRecovery, "duplicate guardian used in recovery");

            // set field to true in storage, not memory
            guardianToRecovery[guardianList[i]].usedInExecuteRecovery = true;
        }

        inRecovery = false;
        address _oldOwner = owner;
        owner = newOwner;
        emit RecoveryExecuted(_oldOwner, newOwner, currRecoveryRound);
    }

    /************************************************
     *  Guardian Management
    ***********************************************/

    /**
     * @notice Allows a guardian to transfer their guardianship 
     * Cannot transfer guardianship during recovery mode
     * @param newGuardianHash - hash of the address of the new guardian
     */
    function transferGuardianship(bytes32 newGuardianHash) onlyGuardian notInRecovery external {
        // Don't let guardian queued for removal transfer their guardianship
        require(
            guardianHashToRemovalTimestamp[keccak256(abi.encodePacked(msg.sender))] == 0, 
            "guardian queueud for removal, cannot transfer guardianship"
        );
        isGuardian[keccak256(abi.encodePacked(msg.sender))] = false;
        isGuardian[newGuardianHash] = true;
        emit GuardinshipTransferred(msg.sender, newGuardianHash);
    }

    /**
     * @notice Allows the owner to queue a guardian for removal
     * @param guardianHash - hash of the address of the guardian to queue
     */
    function initiateGuardianRemoval(bytes32 guardianHash) external onlyOwner {
        // verify that the hash actually corresponds to a guardian
        require(isGuardian[guardianHash], "not a guardian");

        // removal delay fixed at 3 days
        guardianHashToRemovalTimestamp[guardianHash] = block.timestamp + 3 days;
        emit GuardianRemovalQueued(guardianHash);
    }

    /**
     * @notice Allows the owner to remove a guardian
     * Note that the guardian must have been queued for removal prior to invocation of this function
     * @param oldGuardianHash - hash of the address of the guardian to remove
     * @param newGuardianHash - new guardian hash to replace the old guardian
     */
    function executeGuardianRemoval(bytes32 oldGuardianHash, bytes32 newGuardianHash) onlyOwner external {
        require(guardianHashToRemovalTimestamp[oldGuardianHash] > 0, "guardian isn't queued for removal");
        require(guardianHashToRemovalTimestamp[oldGuardianHash] <= block.timestamp, "time delay has not passed");

        // Reset this the removal timestamp
        guardianHashToRemovalTimestamp[oldGuardianHash] = 0;

        isGuardian[oldGuardianHash] = false;
        isGuardian[newGuardianHash] = true;
        emit GuardianRemoved(oldGuardianHash, newGuardianHash);
    }

    /**
     * @notice Allows the owner to cancel the removal of a guardian
     * @param guardianHash - hash of the address of the guardian queued for removal
     */
    function cancelGuardianRemoval(bytes32 guardianHash) onlyOwner external {
        guardianHashToRemovalTimestamp[guardianHash] = 0;
    }

    /**
     * @notice Utility function that selectively allows a guardian to reveal their identity
     * If the owner passes away, this can be used for the guardians to find each other and 
     * determine a course of action
     */
    function revealGuardianIdentity() onlyGuardian external {
        emit GuardianRevealed(keccak256(abi.encodePacked(msg.sender)), msg.sender);
    }

}
