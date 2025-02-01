// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../helpers/ArtifactStorage.sol";

contract UniswapV2DeploymentScript is Script, ArtifactStorage {
    address public weth;
    address public uniswapFactory;
    address public uniswapRouter;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY_1");
        vm.startBroadcast(privateKey);

        weth = _deployBytecode(ArtifactStorage.wethBytecode);
        require(weth != address(0), "Deployment failed");
        console.log("WETH deployed at:", weth);

        bytes memory factoryConstructorArgs = abi.encode(address(this));
        bytes memory factoryBytecodeWithArgs =
            abi.encodePacked(ArtifactStorage.uniswapV2Factory, factoryConstructorArgs);

        uniswapFactory = _deployBytecode(factoryBytecodeWithArgs);
        require(uniswapFactory != address(0), "Deployment failed");
        console.log("UniswapFactory deployed at:", uniswapFactory);

        bytes memory routerConstructorArgs = abi.encode(uniswapFactory, weth);
        bytes memory routerBytecodeWithArgs = abi.encodePacked(ArtifactStorage.uniswapV2Router, routerConstructorArgs);

        uniswapRouter = _deployBytecode(routerBytecodeWithArgs);
        require(uniswapRouter != address(0), "Deployment failed");
        console.log("UniswapRouter deployed at:", uniswapRouter);

        vm.stopBroadcast();
    }

    function _deployBytecode(bytes memory bytecode) internal returns (address addr) {
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        require(addr != address(0), "Deployment failed");
    }
}
