// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {WETH} from "../src/WETH.sol";

contract DeployWETH is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVKEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy WETH contract
        WETH weth = new WETH();
        
        vm.stopBroadcast();

        // Log the address
        console2.log("WETH deployed to:", address(weth));
    }
} 