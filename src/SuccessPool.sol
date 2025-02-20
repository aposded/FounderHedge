// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./ExitContribution.sol";
import "./DividendDistributor.sol";
import "./Governance.sol";

/**
 * @title SuccessPool
 * @dev Manages an encrypted success-sharing pool for startup founders
 */
contract SuccessPool {
    // Encrypted state variables
    mapping(address => suint256) private commitmentPercentages;  // Founder's committed percentage
    mapping(address => suint256) private totalContributed;       // Total amount contributed by founder
    mapping(address => sbool) private isActiveMember;            // Active membership status
    mapping(address => uint256) private lastCommitmentUpdate;    // Track when commitments were last updated
    mapping(address => uint256) private memberJoinTime;          // Track when members joined
    suint256 private totalPoolValue;                            // Total value in the pool
    
    // Public state variables
    uint256 public constant MIN_COMMITMENT_PERCENTAGE = 1;      // 1% minimum commitment
    uint256 public constant MAX_COMMITMENT_PERCENTAGE = 10;     // 10% maximum commitment
    uint256 public constant MIN_MEMBERSHIP_PERIOD = 90 days;    // Minimum time before leaving
    uint256 public constant MAX_EXIT_VALUE = 1e27;             // Maximum exit value
    uint256 public constant MIN_CONTRIBUTION_INTERVAL = 7 days; // Minimum time between contributions
    uint256 public memberCount;                                 // Number of active members
    
    // Emergency controls
    bool public paused;
    address public admin;
    
    // Contract references
    ExitContribution public exitContribution;
    DividendDistributor public dividendDistributor;
    Governance public governance;
    
    // Events
    event MemberJoined(address indexed member);
    event MemberLeft(address indexed member);
    event ContributionReceived(address indexed member);
    event DividendsDistributed();
    event DividendDistributorUpdated(address indexed newDistributor);
    event EmergencyPaused();
    event EmergencyUnpaused();
    event AdminChanged(address indexed newAdmin);
    
    // Errors
    error ContractPaused();
    error Unauthorized();
    error MinMembershipPeriodNotMet();
    error ContributionTooFrequent();
    
    constructor(
        address _exitContribution,
        address _dividendDistributor,
        address _governance
    ) {
        require(_exitContribution != address(0), "Invalid exit contribution address");
        require(_governance != address(0), "Invalid governance address");
        
        exitContribution = ExitContribution(_exitContribution);
        dividendDistributor = DividendDistributor(_dividendDistributor);
        governance = Governance(_governance);
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
     * @dev Update the DividendDistributor reference - only used during initialization
     * @param _dividendDistributor The new distributor address
     */
    function setDividendDistributor(address _dividendDistributor) external onlyAdmin {
        require(address(dividendDistributor) == address(0), "Distributor already set");
        require(_dividendDistributor != address(0), "Invalid distributor address");
        dividendDistributor = DividendDistributor(_dividendDistributor);
        emit DividendDistributorUpdated(_dividendDistributor);
    }
    
    /**
     * @dev Join the success pool with a committed percentage
     * @param percentage The percentage of future exits to commit (encrypted)
     */
    function joinPool(suint256 percentage) external whenNotPaused {
        require(!bool(isActiveMember[msg.sender]), "Already a member");
        require(uint256(percentage) >= MIN_COMMITMENT_PERCENTAGE && 
                uint256(percentage) <= MAX_COMMITMENT_PERCENTAGE, 
                "Invalid commitment percentage");
        
        commitmentPercentages[msg.sender] = percentage;
        isActiveMember[msg.sender] = sbool(true);
        memberCount++;
        memberJoinTime[msg.sender] = block.timestamp;
        lastCommitmentUpdate[msg.sender] = block.timestamp;
        
        // Register commitment in DividendDistributor
        dividendDistributor.updateCommitment(msg.sender, percentage);
        
        // Set initial voting power in governance
        governance.setVotingPower(msg.sender, percentage);
        
        emit MemberJoined(msg.sender);
    }
    
    /**
     * @dev Submit an exit contribution to the pool
     * @param exitValue The encrypted exit value
     */
    function contributeExit(suint256 exitValue) external whenNotPaused {
        require(bool(isActiveMember[msg.sender]), "Not a member");
        require(uint256(exitValue) <= MAX_EXIT_VALUE, "Exit value too large");
        
        // Ensure minimum time between contributions
        require(
            block.timestamp >= lastCommitmentUpdate[msg.sender] + MIN_CONTRIBUTION_INTERVAL,
            "Contribution too frequent"
        );
        
        suint256 contribution = exitValue * commitmentPercentages[msg.sender] / suint256(100);
        totalContributed[msg.sender] += contribution;
        totalPoolValue += contribution;
        
        // Process contribution and distribute dividends
        exitContribution.processContribution(msg.sender, contribution);
        dividendDistributor.distributeDividends(msg.sender, contribution, memberCount);
        
        // Update last contribution time
        lastCommitmentUpdate[msg.sender] = block.timestamp;
        
        emit ContributionReceived(msg.sender);
        emit DividendsDistributed();
    }
    
    /**
     * @dev Leave the success pool
     */
    function leavePool() external whenNotPaused {
        require(bool(isActiveMember[msg.sender]), "Not a member");
        require(uint256(totalContributed[msg.sender]) > 0, "Must contribute before leaving");
        
        // Ensure minimum membership period
        require(
            block.timestamp >= memberJoinTime[msg.sender] + MIN_MEMBERSHIP_PERIOD,
            "Minimum membership period not met"
        );
        
        isActiveMember[msg.sender] = sbool(false);
        memberCount--;
        
        // Reset voting power in governance
        governance.setVotingPower(msg.sender, suint256(0));
        
        emit MemberLeft(msg.sender);
    }
    
    /**
     * @dev Get member's committed percentage (only viewable by the member)
     */
    function getCommitmentPercentage() external view returns (uint256) {
        require(bool(isActiveMember[msg.sender]), "Not a member");
        return uint256(commitmentPercentages[msg.sender]);
    }
    
    /**
     * @dev Get member's total contributed amount (only viewable by the member)
     */
    function getTotalContributed() external view returns (uint256) {
        require(bool(isActiveMember[msg.sender]), "Not a member");
        return uint256(totalContributed[msg.sender]);
    }
    
    /**
     * @dev Get member's join time
     */
    function getMemberJoinTime() external view returns (uint256) {
        return memberJoinTime[msg.sender];
    }
} 