// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/token/TokenDeployer.sol";

contract TokenDeployerScript is Script {
    function run() external {
        vm.startBroadcast();

        TokenDeployer deployer = new TokenDeployer();

        console.log("TokenDeployer deployed at:", address(deployer));

        vm.stopBroadcast();
    }
}
