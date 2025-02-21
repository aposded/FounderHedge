// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {SuccessPool} from "../src/SuccessPool.sol";
import {ExitContribution} from "../src/ExitContribution.sol";
import {DividendDistributor} from "../src/DividendDistributor.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVKEY");
        address wethAddress = vm.envAddress("WETH_ADDRESS");
        
        require(wethAddress != address(0), "WETH_ADDRESS not set");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts
        ExitContribution exitContribution = new ExitContribution();
        
        SuccessPool pool = new SuccessPool(
            address(exitContribution),
            address(0), // Temporary DividendDistributor address
            wethAddress
        );

        DividendDistributor dividendDistributor = new DividendDistributor(address(pool));
        
        // Set up contract references
        pool.setDividendDistributor(address(dividendDistributor));
        exitContribution.setPoolContract(address(pool));

        vm.stopBroadcast();

        // Log addresses using console2
        console2.log("ExitContribution deployed to:", address(exitContribution));
        console2.log("SuccessPool deployed to:", address(pool));
        console2.log("DividendDistributor deployed to:", address(dividendDistributor));
        console2.log("Using WETH at:", wethAddress);
    }
} 