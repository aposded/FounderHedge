// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title ExitContribution
 * @dev Processes encrypted exit reports and verifies contributions
 */
contract ExitContribution {
    // Encrypted state variables
    mapping(address => uint256) private lastContributionAmount;
    mapping(address => uint256) private totalProcessedValue;
    mapping(address => uint256) private lastProcessTime;
    
    // Constants
    uint256 public constant MIN_PROCESS_INTERVAL = 1 days;
    uint256 public constant MAX_CONTRIBUTION = 1e27;
    
    // Emergency controls
    bool public paused;
    address public admin;
    address public poolContract;
    
    // Events
    event ContributionProcessed(address indexed contributor, uint256 timestamp);
    event ContributionVerified(address indexed contributor);
    event EmergencyPaused();
    event EmergencyUnpaused();
    event AdminChanged(address indexed newAdmin);
    event PoolContractUpdated(address indexed newPool);
    
    // Errors
    error ContractPaused();
    error Unauthorized();
    error ProcessTooFrequent();
    error ContributionTooLarge();
    
    constructor() {
        admin = msg.sender;
    }
    
    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }
    
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }
    
    modifier onlyPool() {
        require(msg.sender == poolContract, "Only pool can call");
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
     * @dev Set pool contract address - only used during initialization
     */
    function setPoolContract(address _poolContract) external onlyAdmin {
        require(poolContract == address(0), "Pool already set");
        require(_poolContract != address(0), "Invalid pool address");
        poolContract = _poolContract;
        emit PoolContractUpdated(_poolContract);
    }
    
    /**
     * @dev Process a contribution from a member
     * @param contributor The contributing member's address
     * @param contribution The encrypted contribution amount
     */
    function processContribution(address contributor, suint256 contribution) external onlyPool whenNotPaused {
        require(contributor != address(0), "Invalid contributor address");
        require(uint256(contribution) <= MAX_CONTRIBUTION, "Contribution too large");
        
        // Validate contribution timing
        if (block.timestamp < lastProcessTime[contributor] + MIN_PROCESS_INTERVAL) {
            revert ProcessTooFrequent();
        }
        
        // Update state
        uint256 plainAmount = uint256(contribution);
        lastContributionAmount[contributor] = plainAmount;
        totalProcessedValue[contributor] += plainAmount;
        lastProcessTime[contributor] = block.timestamp;
        
        emit ContributionProcessed(contributor, block.timestamp);
    }
    
    /**
     * @dev Get the last contribution amount for a member (only viewable by the member)
     */
    function getLastContribution() external view returns (uint256) {
        return lastContributionAmount[msg.sender];
    }
    
    /**
     * @dev Get total processed value for a member (only viewable by the member)
     */
    function getTotalProcessedValue() external view returns (uint256) {
        return totalProcessedValue[msg.sender];
    }
    
    /**
     * @dev Get last process time for a member
     */
    function getLastProcessTime() external view returns (uint256) {
        return lastProcessTime[msg.sender];
    }
} 