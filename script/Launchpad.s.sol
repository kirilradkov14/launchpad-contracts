// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/Launchpad.sol";

contract LaunchpadScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY_1");

        vm.startBroadcast(privateKey);

        Launchpad launchpad = new Launchpad();

        console.log("Launchpad deployed at:", address(launchpad));

        vm.stopBroadcast();
    }
}
