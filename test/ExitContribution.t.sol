// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ExitContribution} from "../src/ExitContribution.sol";
import {SuccessPool} from "../src/SuccessPool.sol";
import {DividendDistributor} from "../src/DividendDistributor.sol";
import {USDY} from "../src/USDY.sol";

contract ExitContributionTest is Test {
    ExitContribution public exitContribution;
    SuccessPool public successPool;
    DividendDistributor public dividendDistributor;
    USDY public usdy;
    address public member1 = address(0x1);
    address public member2 = address(0x2);
    address public member3 = address(0x3);
    address public attacker = address(0x666);
    address public admin;

    // Events for testing
    event ContributionProcessed(address indexed member, uint256 amount);
    event EmergencyPaused();
    event EmergencyUnpaused();
    event AdminChanged(address indexed newAdmin);
    event PoolContractUpdated(address indexed newPool);

    function setUp() public {
        // Deploy contracts
        exitContribution = new ExitContribution();
        usdy = new USDY(address(this));
        
        // Deploy SuccessPool with temporary DividendDistributor address
        successPool = new SuccessPool(
            address(exitContribution),
            address(0), // Temporary DividendDistributor address
            address(usdy)
        );
        
        // Deploy DividendDistributor with pool address
        dividendDistributor = new DividendDistributor(address(successPool));
        
        // Set up contract references
        successPool.setDividendDistributor(address(dividendDistributor));
        exitContribution.setPoolContract(address(successPool));

        // Set up test accounts
        admin = address(this);
        vm.deal(admin, 100 ether);

        vm.label(member1, "Member1");
        vm.label(member2, "Member2");
        vm.label(member3, "Member3");
        vm.label(attacker, "Attacker");
        vm.label(admin, "Admin");

        // Wait for initial process interval
        vm.warp(block.timestamp + exitContribution.MIN_PROCESS_INTERVAL());
    }

    // ======== Emergency Control Tests ========

    function test_EmergencyPause() public {
        // Pause the contract
        exitContribution.pause();
        assertTrue(exitContribution.paused());

        // Try operations while paused
        vm.startPrank(address(successPool));
        vm.expectRevert(ExitContribution.ContractPaused.selector);
        exitContribution.processContribution(member1, suint256(100));
        vm.stopPrank();
    }

    function test_EmergencyUnpause() public {
        // Pause and then unpause
        exitContribution.pause();
        
        // Wait for process interval to ensure we're not too frequent
        vm.warp(block.timestamp + exitContribution.MIN_PROCESS_INTERVAL());
        
        exitContribution.unpause();
        assertFalse(exitContribution.paused());

        // Operations should work after unpause
        vm.startPrank(address(successPool));
        
        // Process a contribution
        exitContribution.processContribution(member1, suint256(100));
        
        // Wait for process interval before next contribution
        vm.warp(block.timestamp + exitContribution.MIN_PROCESS_INTERVAL());
        
        // Process another contribution - should work
        exitContribution.processContribution(member1, suint256(100));
        vm.stopPrank();
    }

    function test_OnlyAdminCanPause() public {
        vm.startPrank(attacker);
        vm.expectRevert(ExitContribution.Unauthorized.selector);
        exitContribution.pause();
        vm.stopPrank();
    }

    function test_AdminChange() public {
        address newAdmin = address(0x123);
        exitContribution.changeAdmin(newAdmin);
        assertEq(exitContribution.admin(), newAdmin);

        // Old admin should no longer have access
        vm.expectRevert(ExitContribution.Unauthorized.selector);
        exitContribution.pause();
    }

    // ======== Contribution Limit Tests ========

    function test_MaxContributionLimit() public {
        vm.startPrank(address(successPool));
        
        // Try to contribute more than max
        uint256 maxContribution = exitContribution.MAX_CONTRIBUTION();
        vm.expectRevert("Contribution too large");
        exitContribution.processContribution(member1, suint256(maxContribution + 1));
        
        // Should work with max amount
        exitContribution.processContribution(member1, suint256(maxContribution));
        
        // Wait for process interval before next contribution
        vm.warp(block.timestamp + exitContribution.MIN_PROCESS_INTERVAL());
        
        // Process another max contribution - should work
        exitContribution.processContribution(member1, suint256(maxContribution));
        vm.stopPrank();
    }

    function test_ProcessInterval() public {
        vm.startPrank(address(successPool));
        exitContribution.processContribution(member1, suint256(100));
        
        // Try to process again immediately
        vm.expectRevert(ExitContribution.ProcessTooFrequent.selector);
        exitContribution.processContribution(member1, suint256(100));
        
        // Wait for interval
        vm.warp(block.timestamp + exitContribution.MIN_PROCESS_INTERVAL());
        
        // Should work now
        exitContribution.processContribution(member1, suint256(100));
        vm.stopPrank();
    }

    function test_TotalProcessedValue() public {
        vm.startPrank(address(successPool));
        exitContribution.processContribution(member1, suint256(100));
        
        vm.startPrank(member1);
        assertEq(exitContribution.getTotalProcessedValue(), 100);
        vm.stopPrank();
        
        // Wait for process interval
        vm.warp(block.timestamp + exitContribution.MIN_PROCESS_INTERVAL());
        
        vm.startPrank(address(successPool));
        exitContribution.processContribution(member1, suint256(150));
        
        vm.startPrank(member1);
        assertEq(exitContribution.getTotalProcessedValue(), 250);
        vm.stopPrank();
    }

    function test_LastProcessTime() public {
        uint256 currentTime = block.timestamp;
        
        vm.startPrank(address(successPool));
        exitContribution.processContribution(member1, suint256(100));
        
        vm.startPrank(member1);
        assertEq(exitContribution.getLastProcessTime(), currentTime);
        vm.stopPrank();
        
        // Wait for process interval
        uint256 newTime = currentTime + exitContribution.MIN_PROCESS_INTERVAL();
        vm.warp(newTime);
        
        vm.startPrank(address(successPool));
        exitContribution.processContribution(member1, suint256(100));
        
        vm.startPrank(member1);
        assertEq(exitContribution.getLastProcessTime(), newTime);
        vm.stopPrank();
    }

    function test_PoolContractUpdate() public {
        // Deploy a new ExitContribution contract for this test
        ExitContribution newExitContribution = new ExitContribution();
        
        address newPool = address(0x123);
        newExitContribution.setPoolContract(newPool);
        assertEq(address(newExitContribution.poolContract()), newPool);

        // Try to update again
        vm.expectRevert("Pool already set");
        newExitContribution.setPoolContract(address(0x456));

        // Only admin should be able to update
        vm.startPrank(attacker);
        vm.expectRevert(ExitContribution.Unauthorized.selector);
        newExitContribution.setPoolContract(address(0x456));
        vm.stopPrank();
    }

    // Include all previous tests...
}