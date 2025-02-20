// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title Governance
 * @dev Handles pool governance and dispute resolution
 */
contract Governance {
    // Governance parameters
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_QUORUM = 51; // 51% quorum required
    uint256 public constant PROPOSAL_DELAY = 1 days;
    uint256 public constant MIN_PROPOSAL_STAKE = 1e18; // Minimum stake to create proposal
    uint256 public constant MAX_PROPOSALS_PER_WINDOW = 3; // Max proposals per time window
    uint256 public constant PROPOSAL_WINDOW = 7 days; // Time window for proposal limit
    
    // Encrypted state variables
    mapping(bytes32 => suint256) private proposalVotes;
    mapping(address => mapping(bytes32 => sbool)) private hasVoted;
    mapping(address => suint256) private votingPower;
    
    // Public state variables
    mapping(bytes32 => uint256) public proposalDeadlines;
    mapping(bytes32 => bool) public proposalExecuted;
    mapping(bytes32 => address) public proposalCreator;
    mapping(address => uint256) public proposalCount;
    mapping(address => uint256) public lastProposalTimestamp;
    uint256 public totalProposals;
    
    // Emergency controls
    bool public paused;
    address public admin;
    
    // Events
    event ProposalCreated(bytes32 indexed proposalId, address indexed proposer);
    event VoteCast(bytes32 indexed proposalId, address indexed voter);
    event ProposalExecuted(bytes32 indexed proposalId);
    event EmergencyPaused();
    event EmergencyUnpaused();
    event AdminChanged(address indexed newAdmin);
    
    // Errors
    error InsufficientStake();
    error TooManyProposals();
    error ContractPaused();
    error Unauthorized();
    
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
     * @dev Create a new governance proposal
     * @param proposalId The unique identifier of the proposal
     */
    function createProposal(bytes32 proposalId) external whenNotPaused {
        require(proposalDeadlines[proposalId] == 0, "Proposal already exists");
        require(uint256(votingPower[msg.sender]) >= MIN_PROPOSAL_STAKE, "Insufficient stake");
        
        // Check proposal rate limiting
        if (block.timestamp - lastProposalTimestamp[msg.sender] <= PROPOSAL_WINDOW) {
            require(proposalCount[msg.sender] < MAX_PROPOSALS_PER_WINDOW, "Too many proposals");
        } else {
            proposalCount[msg.sender] = 0;
        }
        
        proposalDeadlines[proposalId] = block.timestamp + PROPOSAL_DELAY + VOTING_PERIOD;
        proposalCreator[proposalId] = msg.sender;
        proposalCount[msg.sender]++;
        lastProposalTimestamp[msg.sender] = block.timestamp;
        totalProposals++;
        
        emit ProposalCreated(proposalId, msg.sender);
    }
    
    /**
     * @dev Cast a vote on a proposal
     * @param proposalId The proposal identifier
     * @param vote The encrypted vote amount
     */
    function castVote(bytes32 proposalId, suint256 vote) external whenNotPaused {
        require(proposalDeadlines[proposalId] > block.timestamp, "Voting period ended");
        require(block.timestamp >= proposalDeadlines[proposalId] - VOTING_PERIOD, "Voting not started");
        require(!bool(hasVoted[msg.sender][proposalId]), "Already voted");
        require(uint256(vote) <= uint256(votingPower[msg.sender]), "Vote exceeds power");
        
        proposalVotes[proposalId] += vote;
        hasVoted[msg.sender][proposalId] = sbool(true);
        
        emit VoteCast(proposalId, msg.sender);
    }
    
    /**
     * @dev Execute a proposal if it has passed
     * @param proposalId The proposal identifier
     */
    function executeProposal(bytes32 proposalId) external whenNotPaused {
        require(block.timestamp >= proposalDeadlines[proposalId], "Voting period not ended");
        require(!proposalExecuted[proposalId], "Proposal already executed");
        
        uint256 totalVotes = uint256(proposalVotes[proposalId]);
        require(totalVotes >= MIN_QUORUM, "Quorum not reached");
        
        proposalExecuted[proposalId] = true;
        
        emit ProposalExecuted(proposalId);
    }
    
    /**
     * @dev Get the total votes for a proposal (only after voting period ends)
     * @param proposalId The proposal identifier
     */
    function getProposalVotes(bytes32 proposalId) external view returns (uint256) {
        require(block.timestamp >= proposalDeadlines[proposalId], "Voting period not ended");
        return uint256(proposalVotes[proposalId]);
    }
    
    /**
     * @dev Set voting power for a member (only callable by authorized contracts)
     * @param member The member address
     * @param power The voting power amount
     */
    function setVotingPower(address member, suint256 power) external {
        // TODO: Add authorization check for the calling contract
        require(member != address(0), "Invalid member address");
        votingPower[member] = power;
    }
    
    /**
     * @dev Get voting power for a member
     */
    function getVotingPower() external view returns (uint256) {
        return uint256(votingPower[msg.sender]);
    }
} 