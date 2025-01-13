// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

import "./helpers/ArtifactStorage.sol";

interface IWETH9 {
    function totalSupply() external view returns (uint256);
    function deposit() external payable;
    function withdraw(uint256) external;
    function balanceOf(address) external view returns (uint256);
}

interface IUniswapV2Factory {
    function feeToSetter() external view returns (address);
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Router {
    function factory() external view returns (address);
    function WETH() external view returns (address);
}

contract UniswapV2 is Test, ArtifactStorage {
    address public weth;
    address public uniswapFactory;
    address public uniswapRouter;

    receive() external payable {}

    function setUp() public {}

    function testWethDeployment() public {
        weth = _deployBytecode(ArtifactStorage.wethBytecode);

        // Assert deployment succeeded
        assertTrue(weth != address(0), "Deployment failed");

        // Cast to WETH9 interface
        IWETH9 wethContract = IWETH9(weth);

        // Interact with the contract
        wethContract.deposit{value: 1 ether}(); // Deposit 1 Ether into the contract

        uint256 balance = wethContract.balanceOf(address(this)); // Get balance of the test contract
        assertEq(balance, 1 ether, "Balance should be 1 Ether");

        // Test withdraw function
        wethContract.withdraw(0.5 ether); // Withdraw 0.5 Ether
        uint256 newBalance = wethContract.balanceOf(address(this));
        assertEq(newBalance, 0.5 ether, "Balance should be 0.5 Ether");
    }

    function testFactoryDeployment() public {
        address feeToSetter = vm.addr(1);
        bytes memory constructorArgs = abi.encode(feeToSetter);
        bytes memory bytecodeWithArgs = abi.encodePacked(ArtifactStorage.uniswapV2Factory, constructorArgs);

        uniswapFactory = _deployBytecode(bytecodeWithArgs);
        // Assert the deployment succeeded
        assertTrue(uniswapFactory != address(0), "Uniswap Factory deployment failed");

        // Cast the deployed address to the factory interface
        IUniswapV2Factory factory = IUniswapV2Factory(uniswapFactory);

        // Verify feeToSetter
        address feeToSetterFromFactory = factory.feeToSetter();
        assertEq(feeToSetterFromFactory, feeToSetter, "FeeToSetter does not match expected value");

        // Create a pair
        address tokenA = vm.addr(2); // Example token A
        address tokenB = vm.addr(3); // Example token B
        address pair = factory.createPair(tokenA, tokenB);

        // Assert pair creation succeeded
        assertTrue(pair != address(0), "Pair creation failed");

        // Validate the pair address is retrievable
        address retrievedPair = factory.getPair(tokenA, tokenB);
        assertEq(pair, retrievedPair, "Retrieved pair address does not match created pair");
    }

    function testRouterDeployment() public {
        // Deploy WETH
        weth = _deployBytecode(ArtifactStorage.wethBytecode);
        assertTrue(weth != address(0), "WETH deployment failed");

        // Deploy Factory
        address feeToSetter = vm.addr(1);
        bytes memory factoryConstructorArgs = abi.encode(feeToSetter);
        bytes memory factoryBytecodeWithArgs =
            abi.encodePacked(ArtifactStorage.uniswapV2Factory, factoryConstructorArgs);
        uniswapFactory = _deployBytecode(factoryBytecodeWithArgs);
        assertTrue(uniswapFactory != address(0), "Uniswap Factory deployment failed");

        // Deploy Router
        bytes memory routerConstructorArgs = abi.encode(uniswapFactory, weth);
        bytes memory routerBytecodeWithArgs = abi.encodePacked(ArtifactStorage.uniswapV2Router, routerConstructorArgs);
        uniswapRouter = _deployBytecode(routerBytecodeWithArgs);
        assertTrue(uniswapRouter != address(0), "Uniswap Router deployment failed");

        // Interact with Router
        IUniswapV2Router router = IUniswapV2Router(uniswapRouter);

        // Verify factory and WETH addresses
        assertEq(router.factory(), uniswapFactory, "Router factory address mismatch");
        assertEq(router.WETH(), weth, "Router WETH address mismatch");
    }

    function _deployBytecode(bytes memory bytecode) internal returns (address addr) {
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        require(addr != address(0), "Deployment failed");
    }
}
