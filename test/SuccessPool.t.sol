// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SuccessPool} from "../src/SuccessPool.sol";
import {ExitContribution} from "../src/ExitContribution.sol";
import {DividendDistributor} from "../src/DividendDistributor.sol";
import {USDY} from "../src/USDY.sol";

contract SuccessPoolTest is Test {
    SuccessPool public pool;
    ExitContribution public exitContribution;
    DividendDistributor public dividendDistributor;
    USDY public usdy;
    address public alice;
    address public bob;

    address public founder1 = address(0x1);
    address public founder2 = address(0x2);
    address public founder3 = address(0x3);
    address public attacker = address(0x666);
    address public admin;

    // Events for testing
    event MemberJoined(address indexed member);
    event MemberLeft(address indexed member);
    event ContributionReceived(address indexed member);
    event DividendsDistributed();
    event DividendDistributorUpdated(address indexed newDistributor);
    event EmergencyPaused();
    event EmergencyUnpaused();
    event AdminChanged(address indexed newAdmin);
    event JoinWindowClosed();

    function setUp() public {
        // Deploy contracts
        exitContribution = new ExitContribution();
        usdy = new USDY(address(this));
        
        // Deploy SuccessPool with temporary DividendDistributor address
        pool = new SuccessPool(
            address(exitContribution),
            address(0), // Temporary DividendDistributor address
            address(usdy)
        );
        
        // Deploy DividendDistributor with pool address
        dividendDistributor = new DividendDistributor(address(pool));
        
        // Set up contract references
        pool.setDividendDistributor(address(dividendDistributor));
        exitContribution.setPoolContract(address(pool));

        // Set up test accounts
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        // Label addresses for better trace output
        vm.label(founder1, "Founder1");
        vm.label(founder2, "Founder2");
        vm.label(founder3, "Founder3");
        vm.label(attacker, "Attacker");
        vm.label(admin, "Admin");

        // Store initial timestamp
        uint256 startTime = block.timestamp;
        
        // Move forward just enough to allow first commitment but not expire join window
        vm.warp(startTime + 1); // Just move forward 1 second to avoid any timing issues
    }

    function test_JoinPool() public {
        vm.startPrank(founder1);
        pool.joinPool(suint256(5)); // 5% commitment
        assertEq(pool.memberCount(), 1);
        assertEq(pool.getCommitmentPercentage(), 5);
        vm.stopPrank();
    }

    function test_JoinPool_InvalidPercentage() public {
        vm.startPrank(founder1);
        vm.expectRevert("Invalid commitment percentage");
        pool.joinPool(suint256(0));

        vm.expectRevert("Invalid commitment percentage");
        pool.joinPool(suint256(11));
        vm.stopPrank();
    }

    function test_JoinPool_AlreadyMember() public {
        vm.startPrank(founder1);
        pool.joinPool(suint256(5));
        vm.expectRevert("Already a member");
        pool.joinPool(suint256(5));
        vm.stopPrank();
    }

    function test_ContributeExit() public {
        // Setup: Join pool with 5% commitment
        vm.startPrank(founder1);
        pool.joinPool(suint256(5));
        vm.stopPrank();

        // Contribute exit worth 1000 units (should contribute 50 units to pool)
        vm.startPrank(founder1);
        pool.contributeExit(suint256(1000));
        
        // Check contribution was recorded
        assertEq(pool.getTotalContributed(), 50);
        vm.stopPrank();
    }

    function test_ContributeExit_NotMember() public {
        vm.startPrank(founder1);
        vm.expectRevert("Not a member");
        pool.contributeExit(suint256(1000));
        vm.stopPrank();
    }

    function test_LeavePool() public {
        // Setup: Join and contribute
        vm.startPrank(founder1);
        pool.joinPool(suint256(5));
        pool.contributeExit(suint256(1000));
        
        // Wait for minimum membership period
        vm.warp(block.timestamp + pool.MIN_MEMBERSHIP_PERIOD());
        
        uint256 initialMemberCount = pool.memberCount();
        pool.leavePool();
        
        assertEq(pool.memberCount(), initialMemberCount - 1);
        vm.stopPrank();
    }

    function test_LeavePool_BeforeMinPeriod() public {
        // Setup: Join and contribute
        vm.startPrank(founder1);
        pool.joinPool(suint256(5));
        pool.contributeExit(suint256(1000));
        
        vm.expectRevert("Minimum membership period not met");
        pool.leavePool();
        vm.stopPrank();
    }

    function test_LeavePool_NotMember() public {
        // Move past minimum period
        vm.warp(block.timestamp + pool.MIN_MEMBERSHIP_PERIOD());

        vm.startPrank(founder1);
        vm.expectRevert("Not a member");
        pool.leavePool();
        vm.stopPrank();
    }

    function test_LeavePool_NoContribution() public {
        vm.startPrank(founder1);
        pool.joinPool(suint256(5));

        // Move past minimum period
        vm.warp(block.timestamp + pool.MIN_MEMBERSHIP_PERIOD());

        vm.expectRevert("Must contribute before leaving");
        pool.leavePool();
        vm.stopPrank();
    }

    function test_MultipleFounders() public {
        // Founder 1 joins
        vm.startPrank(founder1);
        pool.joinPool(suint256(5));
        vm.stopPrank();

        // Founder 2 joins
        vm.startPrank(founder2);
        pool.joinPool(suint256(10));
        vm.stopPrank();

        // Founder 1 contributes
        vm.startPrank(founder1);
        pool.contributeExit(suint256(1000));
        vm.stopPrank();

        // Founder 2 contributes
        vm.startPrank(founder2);
        pool.contributeExit(suint256(500));
        vm.stopPrank();

        // Verify member count
        assertEq(pool.memberCount(), 2);

        // Verify individual contributions
        vm.startPrank(founder1);
        assertEq(pool.getTotalContributed(), 50); // 5% of 1000
        vm.stopPrank();

        vm.startPrank(founder2);
        assertEq(pool.getTotalContributed(), 50); // 10% of 500
        vm.stopPrank();
    }

    function test_GetCommitmentPercentage_NotMember() public {
        vm.startPrank(founder1);
        vm.expectRevert("Not a member");
        pool.getCommitmentPercentage();
        vm.stopPrank();
    }

    function test_GetTotalContributed_NotMember() public {
        vm.startPrank(founder1);
        vm.expectRevert("Not a member");
        pool.getTotalContributed();
        vm.stopPrank();
    }
} 