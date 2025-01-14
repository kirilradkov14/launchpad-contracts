// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/token/TokenDeployer.sol";

contract TokenDeployerScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY_1");

        vm.startBroadcast(privateKey);

        TokenDeployer deployer = new TokenDeployer();

        console.log("TokenDeployer deployed at:", address(deployer));

        vm.stopBroadcast();
    }
}
