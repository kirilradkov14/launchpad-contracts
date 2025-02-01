// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/Launchpad.sol";
import "../src/LaunchpadFactory.sol";
import "../helpers/ArtifactStorage.sol";

contract LaunchpadFuzzTest is Test, ArtifactStorage {
    address public weth;
    address public uniswapFactory;
    address public uniswapRouter;

    Launchpad public implementation;
    LaunchpadFactory public launchpadFactory;
    Launchpad public proxy;

    receive() external payable {}

    function setUp() public {
        // WETH9 deployment (still needed for Uniswap)
        weth = _deployBytecode(ArtifactStorage.wethBytecode);
        require(weth != address(0), "WETH deployment failed");

        // UniswapV2Factory deployment
        address feeToSetter = vm.addr(1);
        bytes memory uniswapFactoryBytecode =
            abi.encodePacked(ArtifactStorage.uniswapV2Factory, abi.encode(feeToSetter));
        uniswapFactory = _deployBytecode(uniswapFactoryBytecode);
        require(uniswapFactory != address(0), "UniswapV2Factory deployment failed");

        // UniswapV2Router deployment
        bytes memory routerBytecodeWithArgs =
            abi.encodePacked(ArtifactStorage.uniswapV2Router, abi.encode(uniswapFactory, weth));
        uniswapRouter = _deployBytecode(routerBytecodeWithArgs);
        require(uniswapRouter != address(0), "Uniswap Router deployment failed");

        // Launchpad deployment
        implementation = new Launchpad();
        require(address(implementation) != address(0), "Implementation deployment failed");

        // LaunchpadFactory deployment
        launchpadFactory = new LaunchpadFactory(address(implementation), uniswapRouter);
        require(address(launchpadFactory) != address(0), "LaunchpadFactory deployment failed");

        // Create a proxy instance for testing
        address launchpad = launchpadFactory.createLaunchpad("Test Token", "TTKN");
        proxy = Launchpad(payable(launchpad));
    }

    function testFuzz_BuyTokensInvariant(uint256 ethAmount) public {
        // Bound eth amount between 0.01 ether and 99 ether
        ethAmount = bound(ethAmount, 0.01 ether, 99 ether);

        uint256 initialEthSupply = proxy.ethSupply();
        uint256 initialTokenSupply = proxy.tokenSupply();

        uint256 expectedTokens = proxy.getTokensOutAtCurrentSupply(ethAmount);

        // Skip if the purchase would exceed available token supply
        vm.assume(expectedTokens <= initialTokenSupply);

        uint256 actualTokens = proxy.buyTokens{value: ethAmount}(0);

        // Verify invariants
        assertEq(actualTokens, expectedTokens, "Token output mismatch");
        assertEq(proxy.ethSupply(), initialEthSupply + ethAmount, "ETH supply not updated correctly");
        assertEq(proxy.tokenSupply(), initialTokenSupply - actualTokens, "Token supply not updated correctly");
    }

    function testFuzz_SellTokensInvariant(uint256 sellAmount) public {
        // First buy some tokens to sell
        uint256 buyAmount = 1 ether;
        uint256 boughtTokens = proxy.buyTokens{value: buyAmount}(0);

        // Bound sell amount between 0.01 tokens and the amount bought
        sellAmount = bound(sellAmount, boughtTokens / 100, boughtTokens);

        uint256 initialEthSupply = proxy.ethSupply();
        uint256 initialTokenSupply = proxy.tokenSupply();

        uint256 expectedEth = proxy.getEthersOutAtCurrentSupply(sellAmount);

        // Approve tokens for selling
        proxy.token().approve(address(proxy), sellAmount);

        uint256 actualEth = proxy.sellTokens(sellAmount, 0);

        // Verify invariants
        assertEq(actualEth, expectedEth, "ETH output mismatch");
        assertEq(proxy.ethSupply(), initialEthSupply - actualEth, "ETH supply not updated correctly");
        assertEq(proxy.tokenSupply(), initialTokenSupply + sellAmount, "Token supply not updated correctly");
    }

    function testFuzz_LiquidityMigrationThreshold(uint256 ethAmount) public {
        // Bound eth amount to be close to but not exceeding threshold
        ethAmount = bound(ethAmount, 98 ether, 99.9 ether);

        // Buy tokens first
        proxy.buyTokens{value: ethAmount}(0);
        assertFalse(proxy.isMigrated(), "Should not be migrated yet");

        // Calculate remaining amount to threshold
        uint256 remainingToThreshold = proxy.THRESHOLD() - proxy.ethSupply();
        vm.assume(remainingToThreshold > 0);

        // Buy more tokens to trigger migration
        proxy.buyTokens{value: remainingToThreshold + 1 ether}(0);

        // Verify migration occurred
        assertTrue(proxy.isMigrated(), "Should be migrated");

        // Verify Uniswap pair exists
        address pair = IUniswapV2Factory(uniswapFactory).getPair(address(proxy.token()), weth);
        assertTrue(pair != address(0), "Liquidity pair not created");

        // Verify LP tokens were sent to dead address
        uint256 pairBalance = IERC20(pair).balanceOf(address(0xdead));
        assertTrue(pairBalance > 0, "No LP tokens sent to dead address");
    }

    function _deployBytecode(bytes memory bytecode) internal returns (address addr) {
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        require(addr != address(0), "Deployment failed");
    }
}
