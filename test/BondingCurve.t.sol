// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/libraries/BondingCurve.sol";

contract BondingCurveTest is Test {
    // Constants from the BondingCurve library
    uint256 constant BASE_PRICE = 30_677_636_300;
    uint256 constant EXP_FACTOR = 4_000_000;
    uint256 constant SCALING_FACTOR = 1e18;

    function setUp() public {}

    function testPurchaseBaseCases() public pure {
        // Test purchase with 0 ETH supply and 1 ETH input
        // Should return some tokens
        uint256 tokensOut = BondingCurve.calculatePurchaseReturn(0, 1 ether);
        assert(tokensOut > 0);

        // Test purchase with 0 ETH input
        // Should return 0
        uint256 zeroOut = BondingCurve.calculatePurchaseReturn(1 ether, 0);
        assert(zeroOut == 0);
    }

    function testPurchasePriceIncrease() public {
        // Test that token price increases with ETH supply
        uint256 ethIn = 1 ether;
        uint256 supply1 = 10 ether;
        uint256 supply2 = 20 ether;

        uint256 tokens1 = BondingCurve.calculatePurchaseReturn(supply1, ethIn);
        uint256 tokens2 = BondingCurve.calculatePurchaseReturn(supply2, ethIn);

        assertTrue(tokens2 < tokens1, "Price should increase with supply");

        // Calculate price difference to verify curve steepness
        // Percentage difference
        uint256 priceDiff = (tokens1 - tokens2) * 100 / tokens1;
        assertTrue(priceDiff > 0 && priceDiff < 50, "Price increase should be reasonable");
    }

    function testSellBaseCases() public {
        // Test sell with 0 token input
        uint256 ethOut = BondingCurve.calculateSellReturn(1 ether, 0);
        assertEq(ethOut, 0, "Should return 0 ETH for 0 tokens");
    }

    function testSellPriceDecrease() public {
        // Setup initial state
        uint256 initialEthSupply = 50 ether;

        // Test selling different amounts
        uint256 sellAmount1 = 1000 ether;

        uint256 ethOut1 = BondingCurve.calculateSellReturn(initialEthSupply, sellAmount1);
        uint256 ethOut2 = BondingCurve.calculateSellReturn(initialEthSupply - ethOut1, sellAmount1);

        assertTrue(ethOut2 < ethOut1, "Price should decrease after selling");
    }

    function testCurveSymmetry() public {
        uint256 ethSupply = 10 ether;
        uint256 ethIn = 1 ether;

        // Buy tokens
        uint256 tokensReceived = BondingCurve.calculatePurchaseReturn(ethSupply, ethIn);

        // Sell the same amount of tokens
        uint256 ethOut = BondingCurve.calculateSellReturn(ethSupply + ethIn, tokensReceived);

        // Should get slightly less ETH due to the curve mechanics
        assertTrue(ethOut < ethIn, "Should have some slippage");
        assertTrue(ethOut > ethIn * 99 / 100, "Slippage should be reasonable");
    }

    function testExtremeValues() public {
        // Test with very small amounts
        uint256 tinyEth = 1 wei;
        uint256 tokensForTiny = BondingCurve.calculatePurchaseReturn(0, tinyEth);
        // Due to precision limitations with fixed-point math, very small amounts might return 0
        assertEq(tokensForTiny, 0, "Tiny amounts should return 0 due to precision limits");

        // Test with more reasonable minimum amount (0.0001 ether)
        uint256 smallEth = 1e14; // 0.0001 ether
        uint256 tokensForSmall = BondingCurve.calculatePurchaseReturn(0, smallEth);
        assertTrue(tokensForSmall > 0, "Should handle small amounts");

        // Test with large amounts
        uint256 largeEth = 1000000 ether;
        uint256 tokensForLarge = BondingCurve.calculatePurchaseReturn(0, largeEth);
        assertTrue(tokensForLarge > 0, "Should handle large amounts");

        // Test progression of amounts
        assertTrue(tokensForSmall < tokensForLarge, "Larger ETH input should yield more tokens");
    }

    function testSellRevertOnInvalidAmount() public {
        uint256 ethSupply = 10 ether;

        // Try to sell more tokens than possible
        uint256 maxTokens = BondingCurve.calculatePurchaseReturn(0, ethSupply);
        vm.expectRevert(abi.encodeWithSignature("FormulaInvalidTokenAmount()"));
        BondingCurve.calculateSellReturn(ethSupply, maxTokens * 2);
    }

    function testPriceProgression() public {
        uint256 ethSupply = 0;
        uint256 ethIncrement = 1 ether;
        uint256 lastTokenAmount = type(uint256).max;

        // Test price progression over multiple purchases
        for (uint256 i = 0; i < 10; i++) {
            uint256 tokenAmount = BondingCurve.calculatePurchaseReturn(ethSupply, ethIncrement);
            assertTrue(tokenAmount < lastTokenAmount, "Price must increase monotonically");
            assertTrue(tokenAmount > 0, "Should always return some tokens");

            ethSupply += ethIncrement;
            lastTokenAmount = tokenAmount;
        }
    }

    function testCurveParameters() public {
        // Test that the curve parameters produce expected behavior
        uint256 initialPurchase = BondingCurve.calculatePurchaseReturn(0, 1 ether);

        // Log values for analysis
        console.log("Initial purchase tokens:", initialPurchase);
        console.log("Base price (P0):", BASE_PRICE);
        console.log("Expected linear tokens:", 1 ether * SCALING_FACTOR / BASE_PRICE);

        // For exponential bonding curve, we should verify that:
        // 1. Initial purchase gives reasonable amount of tokens
        assertTrue(initialPurchase > 0, "Should return tokens");

        // 2. Verify curve steepness
        uint256 laterPurchase = BondingCurve.calculatePurchaseReturn(50 ether, 1 ether);
        assertTrue(laterPurchase < initialPurchase / 2, "Curve should be sufficiently steep");

        // 3. Verify the exponential nature
        uint256 purchase1 = BondingCurve.calculatePurchaseReturn(0, 1 ether);
        uint256 purchase2 = BondingCurve.calculatePurchaseReturn(1 ether, 1 ether);
        uint256 purchase3 = BondingCurve.calculatePurchaseReturn(2 ether, 1 ether);

        assertTrue(purchase1 > purchase2, "Price should increase");
        assertTrue(purchase2 > purchase3, "Price should increase");

        // Verify exponential decrease
        uint256 diff1 = purchase1 - purchase2;
        uint256 diff2 = purchase2 - purchase3;
        assertTrue(diff2 < diff1, "Price change should be exponential");
    }
}
