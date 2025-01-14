// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/LaunchpadFactory.sol";
import "../src/Launchpad.sol";
import "../src/token/TokenDeployer.sol";

contract LaunchpadDeployerScript is Script {
    address constant WETH_ADDRESS = 0x131bfbd0607968B5a730CeCeCB0488D5D2EcA7ba;
    address constant UNISWAP_ROUTER_ADDRESS = 0xE3b0AEA5df8225cF404894306E8a26d7Cb9118F8;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY_1");

        vm.startBroadcast(privateKey);

        TokenDeployer deployer = new TokenDeployer();
        Launchpad launchpad = new Launchpad();
        LaunchpadFactory factory =
            new LaunchpadFactory(address(launchpad), WETH_ADDRESS, UNISWAP_ROUTER_ADDRESS, address(deployer));

        console.log("LaunchpadFactory deployed at:", address(factory));

        vm.stopBroadcast();
    }
}
