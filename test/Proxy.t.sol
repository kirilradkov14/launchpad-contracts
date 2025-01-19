// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Launchpad.sol";
import "../src/LaunchpadFactory.sol";
import "../helpers/ArtifactStorage.sol";

contract ProxyTest is Test, ArtifactStorage {
    address public weth;
    address public uniswapFactory;
    address public uniswapRouter;

    Launchpad public proxy;
    Launchpad public implementation;
    LaunchpadFactory public launchpadFactory;

    // Test accounts
    address public alice = address(0x1);
    address public bob = address(0x2);

    // Initial balances
    uint256 constant INITIAL_ETH_BALANCE = 1000 ether;
    uint256 constant INITIAL_TOKEN_SUPPLY = 800_000_000 ether;
    uint256 constant INITIAL_LIQUIDITY_TOKENS = 200_000_000 ether;

    receive() external payable {}

    function setUp() public {
        string memory tokenName = "TestToken";
        string memory tokenSymbol = "TT";

        // WETH9 deployment
        weth = _deployBytecode(ArtifactStorage.wethBytecode);
        require(weth != address(0), "WETH deployment failed");

        // UniswapV2Factory deployment
        address feeToSetter = vm.addr(1);
        // Encode constructor arguments with the bytecode
        bytes memory uniswapFactoryBytecode =
            abi.encodePacked(ArtifactStorage.uniswapV2Factory, abi.encode(feeToSetter));
        uniswapFactory = _deployBytecode(uniswapFactoryBytecode);
        require(uniswapFactory != address(0), "UniswapV2Factory deployment failed");

        // UniswapV2Router deployment
        bytes memory routerBytecodeWithArgs =
            abi.encodePacked(ArtifactStorage.uniswapV2Router, abi.encode(uniswapFactory, weth));
        uniswapRouter = _deployBytecode(routerBytecodeWithArgs);
        require(uniswapRouter != address(0), "Uniswap Router deployment failed");

        // Launchpad deployment (implementation)
        implementation = new Launchpad();
        require(address(implementation) != address(0), "Implementation deployment failed");

        // LaunchpadFactory deployment
        launchpadFactory = new LaunchpadFactory(address(implementation), weth, uniswapRouter);
        require(address(launchpadFactory) != address(0), "LaunchpadFactory deployment failed");

        address proxyAddress = launchpadFactory.createLaunchpad(tokenName, tokenSymbol);
        proxy = Launchpad(payable(proxyAddress));
        assertEq(address(proxy.weth()), weth, "WETH address mismatch");
        assertEq(address(proxy.uniswapRouter()), uniswapRouter, "Uniswap Router address mismatch");

        // Setup test accounts
        vm.deal(alice, INITIAL_ETH_BALANCE);
        vm.deal(bob, INITIAL_ETH_BALANCE);
    }

    function testInitialState() public view {
        assertEq(proxy.ethSupply(), 0, "Initial ETH supply should be 0");
        assertEq(proxy.tokenSupply(), INITIAL_TOKEN_SUPPLY, "Initial token supply mismatch");
        assertEq(proxy.tokensLiquidity(), INITIAL_LIQUIDITY_TOKENS, "Initial liquidity tokens mismatch");
        assertFalse(proxy.isMigrated(), "Should not be migrated initially");
    }

    function testSingleBuyTokens() public {
        uint256 buyAmount = 1 ether;
        uint256 initialTokenBalance = proxy.token().balanceOf(alice);
        uint256 initialEthSupply = proxy.ethSupply();

        vm.startPrank(alice);
        uint256 expectedTokens = proxy.getTokensOutAtCurrentSupply(buyAmount);
        uint256 tokensReceived = proxy.buyTokens{value: buyAmount}(0);
        vm.stopPrank();

        // Check balance changes
        assertEq(tokensReceived, expectedTokens, "Received tokens should match expected");
        assertEq(proxy.token().balanceOf(alice), initialTokenBalance + tokensReceived, "Token balance mismatch");
        assertEq(proxy.ethSupply(), initialEthSupply + buyAmount, "ETH supply not updated correctly");
        assertEq(IERC20(address(proxy.weth())).balanceOf(address(proxy)), buyAmount, "WETH balance incorrect");
    }

    function testMultipleBuysIncreasePrices() public {
        uint256 buyAmount = 1 ether;

        // First buy
        vm.startPrank(alice);
        uint256 firstBuyTokens = proxy.getTokensOutAtCurrentSupply(buyAmount);
        proxy.buyTokens{value: buyAmount}(0);
        vm.stopPrank();

        // Second buy with same ETH amount should yield fewer tokens
        vm.startPrank(bob);
        uint256 secondBuyTokens = proxy.getTokensOutAtCurrentSupply(buyAmount);
        proxy.buyTokens{value: buyAmount}(0);
        vm.stopPrank();

        assertTrue(secondBuyTokens < firstBuyTokens, "Price should increase after buys");
    }

    function testSellTokens() public {
        // First buy tokens
        uint256 buyAmount = 1 ether;
        vm.startPrank(alice);
        uint256 tokensBought = proxy.buyTokens{value: buyAmount}(0);

        // Approve tokens for selling
        proxy.token().approve(address(proxy), tokensBought);

        // Get expected ETH return
        uint256 expectedEthReturn = proxy.getEthersOutAtCurrentSupply(tokensBought);
        uint256 initialWethBalance = IERC20(address(proxy.weth())).balanceOf(address(proxy));
        uint256 initialAliceEthBalance = address(alice).balance;

        // Sell tokens
        uint256 ethReceived = proxy.sellTokens(tokensBought, 0);
        vm.stopPrank();

        assertEq(ethReceived, expectedEthReturn, "ETH received should match expected");
        assertEq(address(alice).balance, initialAliceEthBalance + ethReceived, "ETH balance not updated correctly");
        assertEq(
            IERC20(address(proxy.weth())).balanceOf(address(proxy)),
            initialWethBalance - ethReceived,
            "WETH balance not updated correctly"
        );
        assertEq(proxy.token().balanceOf(alice), 0, "Should have no tokens left");
    }

    function testPriceDecreasesAfterSell() public {
        // Initial buy
        uint256 buyAmount = 2 ether;
        vm.startPrank(alice);
        uint256 tokensBought = proxy.buyTokens{value: buyAmount}(0);

        // Record price before sell
        uint256 priceBeforeSell = proxy.getEthersOutAtCurrentSupply(1 ether);

        // Sell half the tokens
        proxy.token().approve(address(proxy), tokensBought / 2);
        proxy.sellTokens(tokensBought / 2, 0);

        // Check price after sell
        uint256 priceAfterSell = proxy.getEthersOutAtCurrentSupply(1 ether);
        vm.stopPrank();

        assertTrue(priceAfterSell < priceBeforeSell, "Price should decrease after sell");
    }

    function testThresholdMigration() public {
        vm.startPrank(alice);
        uint256 thresholdAmount = proxy.THRESHOLD();

        // Buy tokens with amount exceeding threshold
        uint256 exceedingAmount = thresholdAmount + 1 ether;
        proxy.buyTokens{value: exceedingAmount}(0);

        assertTrue(proxy.isMigrated(), "Should be migrated after threshold");
        assertEq(address(alice).balance, INITIAL_ETH_BALANCE - thresholdAmount, "Excess ETH should be refunded");
        assertEq(IERC20(address(proxy.weth())).balanceOf(address(proxy)), 0, "WETH balance incorrect after migration");
        vm.stopPrank();
    }

    function testFailBuyAfterMigration() public {
        // First reach threshold
        vm.startPrank(alice);
        proxy.buyTokens{value: proxy.THRESHOLD()}(0);

        // Try to buy after migration
        vm.expectRevert(abi.encodeWithSignature("LaunchpadInvalidState()"));
        proxy.buyTokens{value: 1 ether}(0);
        vm.stopPrank();
    }

    function testMinimumOutputAmount() public {
        uint256 buyAmount = 1 ether;
        uint256 expectedTokens = proxy.getTokensOutAtCurrentSupply(buyAmount);

        vm.startPrank(alice);
        // Should revert when minimum output is higher than actual output
        vm.expectRevert(abi.encodeWithSignature("LaunchpadInsufficientOutputAmount()"));
        proxy.buyTokens{value: buyAmount}(expectedTokens + 1);
        vm.stopPrank();
    }

    function testFailSellMinimumOutputTooHigh() public {
        uint256 buyAmount = 1 ether;
        uint256 expectedTokens = proxy.getTokensOutAtCurrentSupply(buyAmount);

        // Record initial balances
        uint256 initialAliceEthBalance = address(alice).balance;
        uint256 initialTokenBalance = proxy.token().balanceOf(alice);
        uint256 initialWethBalance = IERC20(address(proxy.weth())).balanceOf(address(proxy));

        // Try to buy with minimum output higher than possible
        vm.startPrank(alice);
        proxy.buyTokens{value: buyAmount}(expectedTokens + 1);
        vm.stopPrank();

        // Verify balances remained unchanged
        assertEq(address(alice).balance, initialAliceEthBalance, "Alice ETH balance should be unchanged");
        assertEq(proxy.token().balanceOf(alice), initialTokenBalance, "Token balance should be unchanged");
        assertEq(
            IERC20(address(proxy.weth())).balanceOf(address(proxy)),
            initialWethBalance,
            "WETH balance should be unchanged"
        );
    }

    function _deployBytecode(bytes memory bytecode) internal returns (address addr) {
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        require(addr != address(0), "Deployment failed");
    }
}
