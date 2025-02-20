// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Governance} from "../src/Governance.sol";

contract GovernanceTest is Test {
    Governance public governance;
    address public voter1 = address(0x1);
    address public voter2 = address(0x2);
    address public voter3 = address(0x3);
    address public attacker = address(0x666);
    address public admin;

    bytes32 public constant PROPOSAL_1 = keccak256("PROPOSAL_1");
    bytes32 public constant PROPOSAL_2 = keccak256("PROPOSAL_2");

    // Events for testing
    event ProposalCreated(bytes32 indexed proposalId, address indexed proposer);
    event VoteCast(bytes32 indexed proposalId, address indexed voter);
    event ProposalExecuted(bytes32 indexed proposalId);
    event EmergencyPaused();
    event EmergencyUnpaused();
    event AdminChanged(address indexed newAdmin);

    function setUp() public {
        governance = new Governance();
        admin = address(this);
        
        // Set initial voting power for voters
        governance.setVotingPower(voter1, suint256(governance.MIN_PROPOSAL_STAKE() * 2));  // Double minimum stake
        governance.setVotingPower(voter2, suint256(governance.MIN_PROPOSAL_STAKE() * 2));
        governance.setVotingPower(voter3, suint256(governance.MIN_PROPOSAL_STAKE() * 2));
        
        // Set voting power for test account (admin)
        governance.setVotingPower(address(this), suint256(governance.MIN_PROPOSAL_STAKE() * 2));
        
        vm.label(voter1, "Voter1");
        vm.label(voter2, "Voter2");
        vm.label(voter3, "Voter3");
        vm.label(attacker, "Attacker");
        vm.label(admin, "Admin");
    }

    function test_CreateProposal() public {
        governance.createProposal(PROPOSAL_1);
        assertEq(governance.totalProposals(), 1);
        assertTrue(governance.proposalDeadlines(PROPOSAL_1) > block.timestamp);
    }

    function test_CreateProposal_AlreadyExists() public {
        governance.createProposal(PROPOSAL_1);
        vm.expectRevert("Proposal already exists");
        governance.createProposal(PROPOSAL_1);
    }

    function test_CastVote() public {
        governance.createProposal(PROPOSAL_1);
        
        // Wait for voting delay
        vm.warp(block.timestamp + governance.PROPOSAL_DELAY());
        
        vm.startPrank(voter1);
        governance.castVote(PROPOSAL_1, suint256(25)); // 25% voting power
        vm.stopPrank();
    }

    function test_CastVote_ProposalNotExists() public {
        vm.startPrank(voter1);
        vm.expectRevert("Voting period ended");
        governance.castVote(PROPOSAL_1, suint256(25));
        vm.stopPrank();
    }

    function test_CastVote_VotingPeriodEnded() public {
        governance.createProposal(PROPOSAL_1);
        
        // Fast forward past voting period
        vm.warp(block.timestamp + 8 days);
        
        vm.startPrank(voter1);
        vm.expectRevert("Voting period ended");
        governance.castVote(PROPOSAL_1, suint256(25));
        vm.stopPrank();
    }

    function test_CastVote_AlreadyVoted() public {
        governance.createProposal(PROPOSAL_1);
        
        // Wait for voting delay
        vm.warp(block.timestamp + governance.PROPOSAL_DELAY());
        
        vm.startPrank(voter1);
        governance.castVote(PROPOSAL_1, suint256(25));
        vm.expectRevert("Already voted");
        governance.castVote(PROPOSAL_1, suint256(25));
        vm.stopPrank();
    }

    function test_ExecuteProposal() public {
        governance.createProposal(PROPOSAL_1);
        
        // Wait for voting delay
        vm.warp(block.timestamp + governance.PROPOSAL_DELAY());
        
        // Cast votes to reach quorum
        vm.startPrank(voter1);
        governance.castVote(PROPOSAL_1, suint256(51)); // 51% to reach quorum
        vm.stopPrank();
        
        // Fast forward past voting period
        vm.warp(block.timestamp + governance.VOTING_PERIOD());
        
        governance.executeProposal(PROPOSAL_1);
        assertTrue(governance.proposalExecuted(PROPOSAL_1));
    }

    function test_ExecuteProposal_VotingPeriodNotEnded() public {
        governance.createProposal(PROPOSAL_1);
        
        // Wait for voting delay
        vm.warp(block.timestamp + governance.PROPOSAL_DELAY());
        
        vm.startPrank(voter1);
        governance.castVote(PROPOSAL_1, suint256(51));
        vm.stopPrank();
        
        // Try to execute before voting period ends
        vm.expectRevert("Voting period not ended");
        governance.executeProposal(PROPOSAL_1);
    }

    function test_ExecuteProposal_AlreadyExecuted() public {
        governance.createProposal(PROPOSAL_1);
        
        // Wait for voting delay
        vm.warp(block.timestamp + governance.PROPOSAL_DELAY());
        
        vm.startPrank(voter1);
        governance.castVote(PROPOSAL_1, suint256(51));
        vm.stopPrank();
        
        // Fast forward past voting period
        vm.warp(block.timestamp + governance.VOTING_PERIOD());
        
        governance.executeProposal(PROPOSAL_1);
        vm.expectRevert("Proposal already executed");
        governance.executeProposal(PROPOSAL_1);
    }

    function test_ExecuteProposal_QuorumNotReached() public {
        governance.createProposal(PROPOSAL_1);
        
        // Wait for voting delay
        vm.warp(block.timestamp + governance.PROPOSAL_DELAY());
        
        vm.startPrank(voter1);
        governance.castVote(PROPOSAL_1, suint256(50)); // Only 50%, below quorum
        vm.stopPrank();
        
        // Fast forward past voting period
        vm.warp(block.timestamp + governance.VOTING_PERIOD());
        
        vm.expectRevert("Quorum not reached");
        governance.executeProposal(PROPOSAL_1);
    }

    function test_GetProposalVotes() public {
        governance.createProposal(PROPOSAL_1);
        
        // Wait for voting delay
        vm.warp(block.timestamp + governance.PROPOSAL_DELAY());
        
        vm.startPrank(voter1);
        governance.castVote(PROPOSAL_1, suint256(30));
        vm.stopPrank();
        
        vm.startPrank(voter2);
        governance.castVote(PROPOSAL_1, suint256(25));
        vm.stopPrank();
        
        // Fast forward past voting period
        vm.warp(block.timestamp + governance.VOTING_PERIOD());
        
        assertEq(governance.getProposalVotes(PROPOSAL_1), 55); // 30 + 25 = 55
    }

    function test_GetProposalVotes_VotingPeriodNotEnded() public {
        governance.createProposal(PROPOSAL_1);
        
        // Wait for voting delay
        vm.warp(block.timestamp + governance.PROPOSAL_DELAY());
        
        vm.startPrank(voter1);
        governance.castVote(PROPOSAL_1, suint256(30));
        vm.stopPrank();
        
        vm.expectRevert("Voting period not ended");
        governance.getProposalVotes(PROPOSAL_1);
    }

    function test_MultipleProposals() public {
        // Create and vote on first proposal
        governance.createProposal(PROPOSAL_1);
        
        // Wait for voting delay
        vm.warp(block.timestamp + governance.PROPOSAL_DELAY());
        
        vm.startPrank(voter1);
        governance.castVote(PROPOSAL_1, suint256(60));
        vm.stopPrank();
        
        // Create and vote on second proposal
        governance.createProposal(PROPOSAL_2);
        
        // Wait for voting delay
        vm.warp(block.timestamp + governance.PROPOSAL_DELAY());
        
        vm.startPrank(voter2);
        governance.castVote(PROPOSAL_2, suint256(40));
        vm.stopPrank();
        
        assertEq(governance.totalProposals(), 2);
        
        // Fast forward and check votes
        vm.warp(block.timestamp + governance.VOTING_PERIOD());
        assertEq(governance.getProposalVotes(PROPOSAL_1), 60);
        assertEq(governance.getProposalVotes(PROPOSAL_2), 40);
    }

    // ======== Emergency Control Tests ========

    function test_EmergencyPause() public {
        // Pause the contract
        governance.pause();
        assertTrue(governance.paused());

        // Try operations while paused
        vm.expectRevert(Governance.ContractPaused.selector);
        governance.createProposal(PROPOSAL_1);

        vm.startPrank(voter1);
        vm.expectRevert(Governance.ContractPaused.selector);
        governance.castVote(PROPOSAL_1, suint256(25));
        vm.stopPrank();
    }

    function test_EmergencyUnpause() public {
        // Pause and then unpause
        governance.pause();
        governance.unpause();
        assertFalse(governance.paused());

        // Operations should work after unpause
        governance.createProposal(PROPOSAL_1);
        
        // Wait for voting delay
        vm.warp(block.timestamp + governance.PROPOSAL_DELAY());
        
        vm.startPrank(voter1);
        governance.castVote(PROPOSAL_1, suint256(25));
        vm.stopPrank();
    }

    function test_OnlyAdminCanPause() public {
        vm.startPrank(attacker);
        vm.expectRevert(Governance.Unauthorized.selector);
        governance.pause();
        vm.stopPrank();
    }

    function test_AdminChange() public {
        address newAdmin = address(0x123);
        governance.changeAdmin(newAdmin);
        assertEq(governance.admin(), newAdmin);

        // Old admin should no longer have access
        vm.expectRevert(Governance.Unauthorized.selector);
        governance.pause();
    }

    // ======== Proposal Rate Limiting Tests ========

    function test_ProposalRateLimit() public {
        vm.startPrank(voter1);
        governance.setVotingPower(voter1, suint256(governance.MIN_PROPOSAL_STAKE()));

        // Create max proposals
        for (uint i = 0; i < governance.MAX_PROPOSALS_PER_WINDOW(); i++) {
            governance.createProposal(keccak256(abi.encodePacked(i)));
        }

        // Try to create one more
        bytes32 oneMore = keccak256(abi.encodePacked("one more"));
        vm.expectRevert("Too many proposals");
        governance.createProposal(oneMore);

        // Wait for window to pass
        vm.warp(block.timestamp + governance.PROPOSAL_WINDOW() + 1);

        // Should work now
        governance.createProposal(oneMore);
        vm.stopPrank();
    }

    // ======== Voting Power Tests ========

    function test_VotingPowerLimit() public {
        // Set voting power for voter1
        governance.setVotingPower(voter1, suint256(25));
        
        governance.createProposal(PROPOSAL_1);
        
        // Wait for voting delay
        vm.warp(block.timestamp + governance.PROPOSAL_DELAY());
        
        vm.startPrank(voter1);
        // Try to vote with more power than owned
        vm.expectRevert("Vote exceeds power");
        governance.castVote(PROPOSAL_1, suint256(26));
        
        // Should work with owned power
        governance.castVote(PROPOSAL_1, suint256(25));
        vm.stopPrank();
    }

    function test_MinimumStakeForProposal() public {
        vm.startPrank(voter1);
        
        // Try to create proposal without minimum stake
        governance.setVotingPower(voter1, suint256(governance.MIN_PROPOSAL_STAKE() - 1));
        vm.expectRevert("Insufficient stake");
        governance.createProposal(PROPOSAL_1);
        
        // Should work with minimum stake
        governance.setVotingPower(voter1, suint256(governance.MIN_PROPOSAL_STAKE()));
        governance.createProposal(PROPOSAL_1);
        vm.stopPrank();
    }

    function test_VotingDelay() public {
        governance.createProposal(PROPOSAL_1);
        
        vm.startPrank(voter1);
        governance.setVotingPower(voter1, suint256(25));
        
        // Try to vote before delay
        vm.expectRevert("Voting not started");
        governance.castVote(PROPOSAL_1, suint256(25));
        
        // Wait for delay
        vm.warp(block.timestamp + governance.PROPOSAL_DELAY());
        
        // Should work now
        governance.castVote(PROPOSAL_1, suint256(25));
        vm.stopPrank();
    }
} 