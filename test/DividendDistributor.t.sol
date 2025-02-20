// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DividendDistributor} from "../src/DividendDistributor.sol";

contract MockPool {
    DividendDistributor public distributor;
    
    constructor(DividendDistributor _distributor) {
        distributor = _distributor;
    }
    
    function updateCommitment(address member, suint256 percentage) external {
        distributor.updateCommitment(member, percentage);
    }
    
    function distributeDividends(address member, suint256 amount, uint256 memberCount) external {
        distributor.distributeDividends(member, amount, memberCount);
    }
    
    function claimDividends(address member, suint256 amount) external {
        distributor.claimDividends(member, amount);
    }

    function setDistributor(DividendDistributor _distributor) external {
        distributor = _distributor;
    }
}

contract DividendDistributorTest is Test {
    DividendDistributor public dividendDistributor;
    MockPool public pool;
    address public member1 = address(0x1);
    address public member2 = address(0x2);
    address public member3 = address(0x3);
    address public attacker = address(0x666);
    address public admin;

    // Events for testing
    event DividendsDistributed(uint256 amount);
    event DividendsClaimed(address indexed member, uint256 amount);
    event CommitmentUpdated(address indexed member, uint256 amount);
    event EmergencyPaused();
    event EmergencyUnpaused();
    event AdminChanged(address indexed newAdmin);

    function setUp() public {
        // Deploy contracts in correct order
        pool = new MockPool(DividendDistributor(address(0))); // Temporary address
        dividendDistributor = new DividendDistributor(address(pool));
        pool.setDistributor(dividendDistributor);
        
        admin = address(this);

        // Label addresses
        vm.label(member1, "Member1");
        vm.label(member2, "Member2");
        vm.label(member3, "Member3");
        vm.label(attacker, "Attacker");
        vm.label(admin, "Admin");
        vm.label(address(pool), "Pool");

        // Warp time forward to avoid commitment lock issues
        vm.warp(block.timestamp + 30 days + 1);
    }

    // ======== Access Control Tests ========

    function test_OnlyPoolCanUpdateCommitment() public {
        vm.startPrank(attacker);
        vm.expectRevert("Only pool can call");
        dividendDistributor.updateCommitment(member1, suint256(5));
        vm.stopPrank();
    }

    function test_OnlyPoolCanDistributeDividends() public {
        vm.startPrank(attacker);
        vm.expectRevert("Only pool can call");
        dividendDistributor.distributeDividends(member1, suint256(100), 2);
        vm.stopPrank();
    }

    function test_OnlyPoolCanClaimDividends() public {
        vm.startPrank(attacker);
        vm.expectRevert("Only pool can call");
        dividendDistributor.claimDividends(member1, suint256(50));
        vm.stopPrank();
    }

    // ======== Commitment Tests ========

    function test_CommitmentBounds() public {
        vm.startPrank(address(pool));
        
        // Test minimum bound
        vm.expectRevert("Commitment too low");
        dividendDistributor.updateCommitment(member1, suint256(0));
        
        // Test maximum bound
        vm.expectRevert("Commitment too high");
        dividendDistributor.updateCommitment(member1, suint256(11));
        
        // Test valid commitment
        dividendDistributor.updateCommitment(member1, suint256(5));

        // Wait for lock period
        vm.warp(block.timestamp + 30 days + 1);

        // Test another valid commitment
        dividendDistributor.updateCommitment(member1, suint256(6));
        vm.stopPrank();
    }

    function test_CommitmentLockPeriod() public {
        vm.startPrank(address(pool));
        
        // First commitment
        dividendDistributor.updateCommitment(member1, suint256(5));
        
        // Try to update before lock period ends
        vm.expectRevert("Commitment locked");
        dividendDistributor.updateCommitment(member1, suint256(6));
        
        // Move forward past lock period
        vm.warp(block.timestamp + 30 days + 1);
        
        // Should succeed now
        dividendDistributor.updateCommitment(member1, suint256(6));
        vm.stopPrank();
    }

    // ======== Distribution Tests ========

    function test_DistributionProportions() public {
        vm.startPrank(address(pool));
        
        // Set up commitments: member1 = 5%, member2 = 3%
        dividendDistributor.updateCommitment(member1, suint256(5));
        
        // Wait for lock period before setting member2's commitment
        vm.warp(block.timestamp + 30 days + 1);
        dividendDistributor.updateCommitment(member2, suint256(3));
        
        // Wait for lock period before distribution
        vm.warp(block.timestamp + 30 days + 1);
        
        uint256 distribution = 1000;
        
        // Distribute through pool for member1
        dividendDistributor.distributeDividends(member1, suint256(distribution), 2);
        
        // Calculate expected shares
        uint256 totalCommitment = 8; // 5 + 3
        uint256 member1Share = (distribution * 5) / totalCommitment;
        uint256 member2Share = (distribution * 3) / totalCommitment;
        
        // Check member1's share
        vm.startPrank(member1);
        assertEq(dividendDistributor.getPendingDividends(), member1Share);
        vm.stopPrank();
        
        // Wait for minimum distribution interval
        vm.warp(block.timestamp + 1 days + 1);
        
        // Distribute through pool for member2
        vm.startPrank(address(pool));
        dividendDistributor.distributeDividends(member2, suint256(distribution), 2);
        
        // Check member2's share
        vm.startPrank(member2);
        assertEq(dividendDistributor.getPendingDividends(), member2Share);
        vm.stopPrank();
    }

    // ======== Claim Tests ========

    function test_CannotClaimMoreThanAvailable() public {
        vm.startPrank(address(pool));
        
        // Setup some pending dividends
        dividendDistributor.updateCommitment(member1, suint256(5));
        
        // Wait for lock period
        vm.warp(block.timestamp + 30 days + 1);
        
        dividendDistributor.distributeDividends(member1, suint256(100), 1);
        
        // Try to claim more than available
        vm.expectRevert("Insufficient dividends");
        dividendDistributor.claimDividends(member1, suint256(101));
        vm.stopPrank();
    }

    function test_ClaimDeductsFromPending() public {
        vm.startPrank(address(pool));
        
        // Setup dividends
        dividendDistributor.updateCommitment(member1, suint256(5));
        
        // Wait for lock period
        vm.warp(block.timestamp + 30 days + 1);
        
        dividendDistributor.distributeDividends(member1, suint256(100), 1);
        
        // Calculate expected pending amount (100% since only member)
        uint256 pendingAmount = 100;
        
        // Claim half of pending dividends
        dividendDistributor.claimDividends(member1, suint256(pendingAmount / 2));
        
        // Check pending was reduced
        vm.startPrank(member1);
        assertEq(dividendDistributor.getPendingDividends(), pendingAmount / 2);
        vm.stopPrank();
    }

    // ======== Edge Cases ========

    function test_LargeNumberHandling() public {
        vm.startPrank(address(pool));
        
        // Use a large but safe number that won't overflow when multiplied by commitment percentage
        uint256 largeAmount = 1e27; // Same as MAX_CLAIM_AMOUNT
        
        // Setup dividends
        dividendDistributor.updateCommitment(member1, suint256(5));
        
        // Wait for lock period
        vm.warp(block.timestamp + 30 days + 1);
        
        dividendDistributor.distributeDividends(member1, suint256(largeAmount), 1);
        
        // Member1 gets 100% since they're the only member
        dividendDistributor.claimDividends(member1, suint256(largeAmount));
        
        vm.startPrank(member1);
        assertEq(dividendDistributor.getTotalDividendsReceived(), largeAmount);
        vm.stopPrank();
    }

    function test_ZeroAddressRejection() public {
        vm.expectRevert("Invalid pool address");
        new DividendDistributor(address(0));
    }

    // ======== Timing Attack Tests ========

    function test_CannotFrontRunDistribution() public {
        vm.startPrank(address(pool));
        
        // Initial commitment
        dividendDistributor.updateCommitment(member1, suint256(5));
        
        // Try to update just before distribution
        vm.expectRevert("Commitment locked");
        dividendDistributor.updateCommitment(member1, suint256(6));
        
        // Distribution should use original commitment
        dividendDistributor.distributeDividends(member1, suint256(100), 1);
        vm.stopPrank();
    }

    // ======== Invariant Tests ========

    function invariant_TotalReceivedNeverDecreases() public {
        vm.startPrank(address(pool));
        
        // Setup commitment if not already set
        uint256 currentCommitment = uint256(dividendDistributor.getCommitmentPercentage());
        if (currentCommitment == 0) {
            dividendDistributor.updateCommitment(member1, suint256(5));
            // Wait for lock period
            vm.warp(block.timestamp + 30 days + 1);
        }
        
        // Distribute dividends first
        dividendDistributor.distributeDividends(member1, suint256(100), 1);
        
        // Get initial total received
        vm.startPrank(member1);
        uint256 initialTotal = dividendDistributor.getTotalDividendsReceived();
        vm.stopPrank();
        
        // Claim dividends
        vm.startPrank(address(pool));
        dividendDistributor.claimDividends(member1, suint256(100));
        vm.stopPrank();

        // Verify total never decreased
        vm.startPrank(member1);
        uint256 newTotal = dividendDistributor.getTotalDividendsReceived();
        assertTrue(newTotal >= initialTotal, "Total received should never decrease");
        vm.stopPrank();
    }

    function invariant_CommitmentPercentageInBounds() public {
        vm.startPrank(address(pool));
        
        // Only update commitment if not already set
        uint256 currentCommitment = uint256(dividendDistributor.getCommitmentPercentage());
        if (currentCommitment == 0) {
            dividendDistributor.updateCommitment(member1, suint256(5));
            // Wait for lock period
            vm.warp(block.timestamp + 30 days + 1);
        }
        
        // Try to update commitment to ensure bounds
        vm.expectRevert("Commitment too high");
        dividendDistributor.updateCommitment(member1, suint256(11));
        
        vm.expectRevert("Commitment too low");
        dividendDistributor.updateCommitment(member1, suint256(0));
        vm.stopPrank();
        
        // Check commitment bounds
        vm.startPrank(member1);
        uint256 commitment = dividendDistributor.getCommitmentPercentage();
        assertTrue(commitment >= dividendDistributor.MIN_COMMITMENT_PERCENTAGE(), "Commitment below minimum");
        assertTrue(commitment <= dividendDistributor.MAX_COMMITMENT_PERCENTAGE(), "Commitment above maximum");
        vm.stopPrank();
    }

    // ======== Emergency Control Tests ========

    function test_EmergencyPause() public {
        // Pause the contract
        dividendDistributor.pause();
        assertTrue(dividendDistributor.paused());

        // Try operations while paused
        vm.startPrank(address(pool));
        vm.expectRevert(DividendDistributor.ContractPaused.selector);
        dividendDistributor.updateCommitment(member1, suint256(100));

        vm.expectRevert(DividendDistributor.ContractPaused.selector);
        dividendDistributor.claimDividends(member1, suint256(50));

        vm.expectRevert(DividendDistributor.ContractPaused.selector);
        dividendDistributor.distributeDividends(member1, suint256(1000), 1);
        vm.stopPrank();
    }

    function test_EmergencyUnpause() public {
        // Pause and then unpause
        dividendDistributor.pause();
        dividendDistributor.unpause();
        assertFalse(dividendDistributor.paused());

        // Operations should work after unpause
        vm.startPrank(address(pool));
        dividendDistributor.updateCommitment(member1, suint256(5));
        dividendDistributor.distributeDividends(member1, suint256(1000), 1);
        vm.stopPrank();
    }

    function test_OnlyAdminCanPause() public {
        vm.startPrank(attacker);
        vm.expectRevert(DividendDistributor.Unauthorized.selector);
        dividendDistributor.pause();
        vm.stopPrank();
    }

    function test_AdminChange() public {
        address newAdmin = address(0x123);
        dividendDistributor.changeAdmin(newAdmin);
        assertEq(dividendDistributor.admin(), newAdmin);

        // Old admin should no longer have access
        vm.expectRevert(DividendDistributor.Unauthorized.selector);
        dividendDistributor.pause();
    }

    // ======== Precision Handling Tests ========

    function test_PrecisionInDistribution() public {
        vm.startPrank(address(pool));
        
        // Setup commitments with valid percentages
        dividendDistributor.updateCommitment(member1, suint256(5));
        
        // Wait for lock period
        vm.warp(block.timestamp + 30 days + 1);
        dividendDistributor.updateCommitment(member2, suint256(3));

        // Distribute small amount
        uint256 distributionAmount = 8; // Use 8 for even division
        dividendDistributor.distributeDividends(member1, suint256(distributionAmount), 2);

        // Check precision in shares
        vm.startPrank(member1);
        uint256 member1Share = dividendDistributor.getPendingDividends();
        vm.stopPrank();

        vm.startPrank(address(pool));
        dividendDistributor.claimDividends(member1, suint256(member1Share));

        // Wait for minimum distribution interval
        vm.warp(block.timestamp + 1 days + 1);

        dividendDistributor.distributeDividends(member2, suint256(distributionAmount), 2);

        vm.startPrank(member2);
        uint256 member2Share = dividendDistributor.getPendingDividends();
        vm.stopPrank();

        vm.startPrank(address(pool));
        dividendDistributor.claimDividends(member2, suint256(member2Share));
        vm.stopPrank();

        // Verify total distributed equals sum of shares
        assertEq(member1Share + member2Share, distributionAmount);
    }

    function test_LargeNumberPrecision() public {
        vm.startPrank(address(pool));
        
        // Setup commitments with valid percentages
        dividendDistributor.updateCommitment(member1, suint256(5));
        
        // Wait for lock period
        vm.warp(block.timestamp + 30 days + 1);
        dividendDistributor.updateCommitment(member2, suint256(3));

        // Distribute large amount
        uint256 distributionAmount = 1e24;
        dividendDistributor.distributeDividends(member1, suint256(distributionAmount), 2);

        // Check precision in shares
        vm.startPrank(member1);
        uint256 member1Share = dividendDistributor.getPendingDividends();
        vm.stopPrank();

        vm.startPrank(address(pool));
        dividendDistributor.claimDividends(member1, suint256(member1Share));
        vm.stopPrank();

        // Wait for minimum distribution interval
        vm.warp(block.timestamp + 1 days + 1);

        vm.startPrank(address(pool));
        dividendDistributor.distributeDividends(member2, suint256(distributionAmount), 2);

        vm.startPrank(member2);
        uint256 member2Share = dividendDistributor.getPendingDividends();
        vm.stopPrank();

        vm.startPrank(address(pool));
        dividendDistributor.claimDividends(member2, suint256(member2Share));
        vm.stopPrank();

        // Verify shares are proportional within acceptable precision
        assertApproxEqRel(member1Share * 3, member2Share * 5, 1e15); // 0.1% tolerance
    }

    function test_RoundingBehavior() public {
        vm.startPrank(address(pool));
        
        // Setup uneven commitments within valid range
        dividendDistributor.updateCommitment(member1, suint256(5));
        
        // Wait for lock period
        vm.warp(block.timestamp + 30 days + 1);
        dividendDistributor.updateCommitment(member2, suint256(3));

        // Distribute amount that will cause rounding
        uint256 distributionAmount = 1000;
        dividendDistributor.distributeDividends(member1, suint256(distributionAmount), 2);

        // Check rounding behavior
        vm.startPrank(member1);
        uint256 member1Share = dividendDistributor.getPendingDividends();
        vm.stopPrank();

        vm.startPrank(address(pool));
        dividendDistributor.claimDividends(member1, suint256(member1Share));

        // Wait for minimum distribution interval
        vm.warp(block.timestamp + 1 days + 1);

        dividendDistributor.distributeDividends(member2, suint256(distributionAmount), 2);

        vm.startPrank(member2);
        uint256 member2Share = dividendDistributor.getPendingDividends();
        vm.stopPrank();

        vm.startPrank(address(pool));
        dividendDistributor.claimDividends(member2, suint256(member2Share));
        vm.stopPrank();

        // Verify no dust is left and shares sum to total
        assertEq(member1Share + member2Share, distributionAmount);
    }

    // ======== Value Validation Tests ========

    function test_MaxClaimAmount() public {
        vm.startPrank(address(pool));
        
        // Setup valid commitment
        dividendDistributor.updateCommitment(member1, suint256(5));
        
        // Wait for lock period
        vm.warp(block.timestamp + 30 days + 1);
        
        // Distribute max amount
        uint256 maxAmount = dividendDistributor.MAX_CLAIM_AMOUNT();
        dividendDistributor.distributeDividends(member1, suint256(maxAmount), 1);
        
        // Try to claim more than max
        vm.expectRevert("ClaimAmountTooLarge");
        dividendDistributor.claimDividends(member1, suint256(maxAmount + 1));
        
        // Should be able to claim max amount
        dividendDistributor.claimDividends(member1, suint256(maxAmount));
        vm.stopPrank();
    }

    function test_ShareCalculationBounds() public {
        vm.startPrank(address(pool));
        
        // Setup commitments
        dividendDistributor.updateCommitment(member1, suint256(5));
        
        // Wait for lock period
        vm.warp(block.timestamp + 30 days + 1);
        dividendDistributor.updateCommitment(member2, suint256(3));
        
        uint256 distribution = 1000;
        
        // Distribute dividends
        dividendDistributor.distributeDividends(member1, suint256(distribution), 2);
        
        // Check that share is not larger than total distribution
        vm.startPrank(member1);
        assertTrue(dividendDistributor.getPendingDividends() <= distribution);
        vm.stopPrank();
    }
}