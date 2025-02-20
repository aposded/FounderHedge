// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title DividendDistributor
 * @dev Handles encrypted dividend distribution to pool members
 */
contract DividendDistributor {
    // Encrypted state variables
    mapping(address => suint256) private pendingDividends;
    mapping(address => suint256) private totalDividendsReceived;
    mapping(address => suint256) private commitmentPercentages;
    mapping(address => uint256) private lastCommitmentUpdate;    // Track when commitments were last updated
    mapping(address => uint256) private lastDistributionTime;    // Track last distribution per member
    suint256 private totalCommitmentPercentage;
    suint256 private totalDistributed;
    
    // Constants
    uint256 public constant MIN_COMMITMENT_PERCENTAGE = 1;      // 1%
    uint256 public constant MAX_COMMITMENT_PERCENTAGE = 10;     // 10%
    uint256 public constant COMMITMENT_LOCK_PERIOD = 30 days;   // Extended lock period
    uint256 public constant MIN_DISTRIBUTION_INTERVAL = 1 days; // Minimum time between distributions
    uint256 public constant MAX_CLAIM_AMOUNT = 1e27;           // Safety cap on claims
    uint256 public constant PRECISION = 1e18;                  // Precision for calculations
    address public immutable poolContract;                     // Pool contract that can call protected functions
    
    // Emergency controls
    bool public paused;
    address public admin;
    
    // State tracking
    bool private _notEntered = true;  // Reentrancy guard
    
    // Events
    event DividendsDistributed(uint256 memberCount, uint256 timestamp);
    event DividendsClaimed(address indexed member, uint256 timestamp);
    event CommitmentUpdated(address indexed member, uint256 timestamp);
    event EmergencyPaused();
    event EmergencyUnpaused();
    event AdminChanged(address indexed newAdmin);
    
    // Errors
    error ReentrancyGuard();
    error DistributionTooFrequent();
    error ClaimAmountTooLarge();
    error ContractPaused();
    error Unauthorized();
    error PrecisionError();
    
    constructor(address _poolContract) {
        require(_poolContract != address(0), "Invalid pool address");
        poolContract = _poolContract;
        admin = msg.sender;
    }
    
    modifier nonReentrant() {
        if (!_notEntered) revert ReentrancyGuard();
        _notEntered = false;
        _;
        _notEntered = true;
    }
    
    modifier onlyPool() {
        require(msg.sender == poolContract, "Only pool can call");
        _;
    }
    
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }
    
    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }
    
    /**
     * @dev Emergency pause functionality
     */
    function pause() external onlyAdmin {
        paused = true;
        emit EmergencyPaused();
    }
    
    /**
     * @dev Emergency unpause functionality
     */
    function unpause() external onlyAdmin {
        paused = false;
        emit EmergencyUnpaused();
    }
    
    /**
     * @dev Change admin address
     */
    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid admin address");
        admin = newAdmin;
        emit AdminChanged(newAdmin);
    }
    
    /**
     * @dev Update a member's commitment percentage
     * @param member The member's address
     * @param percentage Their commitment percentage
     */
    function updateCommitment(address member, suint256 percentage) external onlyPool whenNotPaused {
        // Validate percentage bounds after decryption
        require(uint256(percentage) >= MIN_COMMITMENT_PERCENTAGE, "Commitment too low");
        require(uint256(percentage) <= MAX_COMMITMENT_PERCENTAGE, "Commitment too high");
        
        // Ensure commitment hasn't been updated recently
        require(
            block.timestamp >= lastCommitmentUpdate[member] + COMMITMENT_LOCK_PERIOD,
            "Commitment locked"
        );
        
        // Update state following checks-effects-interactions
        suint256 oldPercentage = commitmentPercentages[member];
        totalCommitmentPercentage = totalCommitmentPercentage - oldPercentage + percentage;
        commitmentPercentages[member] = percentage;
        lastCommitmentUpdate[member] = block.timestamp;
        
        emit CommitmentUpdated(member, block.timestamp);
    }

    /**
     * @dev Distribute dividends to pool members based on their commitment percentages
     * @param member The address of the member receiving dividends
     * @param amount The encrypted amount to distribute
     * @param memberCount The number of active members
     */
    function distributeDividends(address member, suint256 amount, uint256 memberCount) 
        external 
        onlyPool 
        nonReentrant 
        whenNotPaused 
    {
        require(memberCount > 0, "No members to distribute to");
        require(uint256(totalCommitmentPercentage) > 0, "No commitments registered");
        require(uint256(commitmentPercentages[member]) > 0, "Member has no commitment");
        
        // Prevent rapid distributions
        if (block.timestamp < lastDistributionTime[member] + MIN_DISTRIBUTION_INTERVAL) {
            revert DistributionTooFrequent();
        }
        
        // Calculate share with higher precision to avoid rounding issues
        // Convert uint256 PRECISION to suint256 for multiplication
        suint256 precisionFactor = suint256(PRECISION);
        suint256 memberShare = amount;
        memberShare = memberShare * commitmentPercentages[member];
        memberShare = memberShare * precisionFactor;
        memberShare = memberShare / totalCommitmentPercentage;
        memberShare = memberShare / precisionFactor;
        
        // Verify share calculation
        require(uint256(memberShare) <= uint256(amount), "Share calculation error");
        
        // Update state
        totalDistributed += amount;
        pendingDividends[member] += memberShare;
        lastDistributionTime[member] = block.timestamp;
        
        emit DividendsDistributed(memberCount, block.timestamp);
    }
    
    /**
     * @dev Claim pending dividends for a member
     * @param member The address of the member claiming dividends
     * @param amount The encrypted amount to claim
     */
    function claimDividends(address member, suint256 amount) 
        external 
        onlyPool 
        nonReentrant 
        whenNotPaused 
    {
        require(uint256(amount) > 0, "No dividends to claim");
        require(uint256(commitmentPercentages[member]) > 0, "Member has no commitment");
        
        // Safety checks - switch order to check max amount first
        if (uint256(amount) > MAX_CLAIM_AMOUNT) revert ClaimAmountTooLarge();
        require(uint256(amount) <= uint256(pendingDividends[member]), "Insufficient dividends");
        
        // Update state before external interactions
        pendingDividends[member] -= amount;
        totalDividendsReceived[member] += amount;
        
        emit DividendsClaimed(member, block.timestamp);
    }
    
    /**
     * @dev Get pending dividends for a member (only viewable by the member)
     */
    function getPendingDividends() external view returns (uint256) {
        return uint256(pendingDividends[msg.sender]);
    }
    
    /**
     * @dev Get total dividends received by a member (only viewable by the member)
     */
    function getTotalDividendsReceived() external view returns (uint256) {
        return uint256(totalDividendsReceived[msg.sender]);
    }

    /**
     * @dev Get member's commitment percentage (only viewable by the member)
     */
    function getCommitmentPercentage() external view returns (uint256) {
        return uint256(commitmentPercentages[msg.sender]);
    }

    /**
     * @dev Get when member's commitment was last updated
     */
    function getLastCommitmentUpdate() external view returns (uint256) {
        return lastCommitmentUpdate[msg.sender];
    }
} 