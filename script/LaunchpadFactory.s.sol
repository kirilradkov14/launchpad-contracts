// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/LaunchpadFactory.sol";
import "../src/Launchpad.sol";
import "../src/mocks/WETH.sol";
import "../src/token/TokenDeployer.sol";

contract TokenDeployerScript is Script {
    function run() external {
        vm.startBroadcast();

        WETH weth = new WETH();
        TokenDeployer deployer = new TokenDeployer();
        Launchpad launchpad = new Launchpad();
        LaunchpadFactory factory =
            new LaunchpadFactory(address(launchpad), address(weth), address(deployer), address(deployer));

        console.log("LaunchpadFactory deployed at:", address(factory));

        vm.stopBroadcast();
    }
}
