// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {USDY} from "../src/USDY.sol";

contract DeployUSDY is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVKEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy USDY contract with deployer as admin
        USDY usdy = new USDY(msg.sender);
        
        vm.stopBroadcast();

        // Log the address
        console2.log("USDY deployed to:", address(usdy));
    }
} 