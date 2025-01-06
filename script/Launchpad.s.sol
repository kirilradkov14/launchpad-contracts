// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/Launchpad.sol";

contract TokenDeployerScript is Script {
    function run() external {
        vm.startBroadcast();

        Launchpad launchpad = new Launchpad();

        console.log("Launchpad deployed at:", address(launchpad));

        vm.stopBroadcast();
    }
}