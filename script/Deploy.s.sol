// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SuccessPool} from "../src/SuccessPool.sol";
import {ExitContribution} from "../src/ExitContribution.sol";
import {DividendDistributor} from "../src/DividendDistributor.sol";
import {Governance} from "../src/Governance.sol";

contract DeployScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVKEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy supporting contracts first
        ExitContribution exitContribution = new ExitContribution();
        console.log("ExitContribution deployed at:", address(exitContribution));

        // Deploy DividendDistributor with a temporary pool address that will be updated
        DividendDistributor dividendDistributor = new DividendDistributor(address(this));
        console.log("DividendDistributor deployed at:", address(dividendDistributor));

        Governance governance = new Governance();
        console.log("Governance deployed at:", address(governance));

        // Deploy main pool contract with references to supporting contracts
        SuccessPool successPool = new SuccessPool(
            address(exitContribution),
            address(dividendDistributor),
            address(governance)
        );
        console.log("SuccessPool deployed at:", address(successPool));

        vm.stopBroadcast();
    }
} 