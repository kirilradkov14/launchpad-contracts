// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/Launchpad.sol";
import "../src/LaunchpadFactory.sol";
import "../helpers/ArtifactStorage.sol";

contract LaunchpadTest is Test, ArtifactStorage {
    address public weth;
    address public uniswapFactory;
    address public uniswapRouter;

    Launchpad public implementation;
    LaunchpadFactory public launchpadFactory;

    receive() external payable {}

    function setUp() public {
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
    }

    function test_ProxyCreation() public {
        string memory tokenName = "Test Token";
        string memory tokenSymbol = "TTKN";

        address launchpad = launchpadFactory.createLaunchpad(tokenName, tokenSymbol);

        assertTrue(launchpad != address(0), "Launchpad creation failed");

        Launchpad proxy = Launchpad(payable(launchpad));
        assertEq(address(proxy.weth()), weth, "WETH address mismatch");
        assertEq(address(proxy.uniswapRouter()), uniswapRouter, "Uniswap Router address mismatch");

        uint256 ethAmount = 0.5 ether;
        uint256 minTokens = proxy.getTokensOutAtCurrentSupply(ethAmount);
        uint256 tokensBought = proxy.buyTokens{value: ethAmount}(minTokens);
        assertTrue(tokensBought > 0, "Failed to buy tokens");

        uint256 proxyEthSupply = proxy.ethSupply();
        assertEq(proxyEthSupply, ethAmount, "ETH supply mismatch after token purchase");

        require(proxy.token().approve(address(proxy), type(uint256).max), "Approval failed");

        uint256 userTokenBalance = proxy.token().balanceOf(address(this));
        assertEq(userTokenBalance, tokensBought, "User token balance mismatch after token purchase");

        uint256 tokensToSell = tokensBought / 2; // Sell half of the tokens
        uint256 minEth = proxy.getEthersOutAtCurrentSupply(tokensToSell);

        uint256 ethReceived = proxy.sellTokens(tokensToSell, minEth);
        assertTrue(ethReceived > 0, "Failed to sell tokens");

        uint256 proxyEthSupplyAfterSale = proxy.ethSupply();
        assertEq(proxyEthSupplyAfterSale, ethAmount - ethReceived, "ETH supply mismatch after token sale");

        uint256 userTokenBalanceAfterSale = proxy.token().balanceOf(address(this));
        assertEq(userTokenBalanceAfterSale, tokensBought - tokensToSell, "User token balance mismatch after token sale");

        uint256 userEthBalance = address(this).balance;
        assertTrue(userEthBalance >= ethReceived, "User ETH balance mismatch after token sale");
    }

    function test_LiquidityMigration() public {
        string memory tokenName = "Test Token";
        string memory tokenSymbol = "TTKN";

        address launchpad = launchpadFactory.createLaunchpad(tokenName, tokenSymbol);

        assertTrue(launchpad != address(0), "Launchpad creation failed");

        Launchpad proxy = Launchpad(payable(launchpad));

        assertEq(address(proxy.weth()), weth, "WETH address mismatch");
        assertEq(address(proxy.uniswapRouter()), uniswapRouter, "Uniswap Router address mismatch");

        // Buy 99 tokens
        proxy.buyTokens{value: 99 ether}(0);
        assertTrue(proxy.isMigrated() == false, "LP already migrated");
        assertTrue(proxy.ethSupply() <= proxy.THRESHOLD(), "ETH Supply Reached Threshold");

        // Buy 2 tokens, triggering LP migration
        proxy.buyTokens{value: 2 ether}(0);
        assertTrue(proxy.isMigrated() == true, "LP already migrated");
        assertTrue(proxy.ethSupply() <= proxy.THRESHOLD(), "ETH Supply Reached Threshold");

        address pair = IUniswapV2Factory(uniswapFactory).getPair(address(proxy.token()), weth);
        assertTrue(pair != address(0), "Liquidity pair not created");

        uint256 pairBalance = IERC20(pair).balanceOf(address(0xdead));
        assertTrue(pairBalance > 0, "Liquidity migration failed");
    }

    function _deployBytecode(bytes memory bytecode) internal returns (address addr) {
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        require(addr != address(0), "Deployment failed");
    }
}
