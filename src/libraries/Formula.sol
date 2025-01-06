// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Math64x64.sol";

/**
 * @title Formula
 * @dev Implements an exponential bonding curve for token pricing using the Math64x64 library.
 */
library Formula {
    using Math64x64 for int128;
    
    /** To scale fixed point arithmetic  */
    uint256 public constant SCALING_FACTOR = 1e18;

    /** Base Price for a token in wei (P0) */
    uint256 public constant BASE_PRICE = 30_677_636_300;

    /** The exponential factor determines the steepness of the curve (K)  */
    uint256 public constant EXP_FACTOR = 4_000_000;

    error FormulaInvalidTokenAmount();

    /**
     * @dev Calculates the number of tokens that can be bought with a given amount of ETH.
     * @param ethSupply The total ETH raised in the pool so far (in wei).
     * @param ethAmountIn The amount of ETH sent for buying tokens (in wei).
     * @return tokensToBuy The number of tokens that can be bought with the given ETH amount.
     */
    function calculatePurchaseReturn(uint256 ethSupply, uint256 ethAmountIn)
        internal
        pure
        returns (uint256 tokensToBuy)
    {
        if (ethAmountIn == 0) return 0;

        int128 k = Math64x64.divu(EXP_FACTOR, 1e8); 
        int128 P0 = Math64x64.divu(BASE_PRICE, 1e18);
        int128 ethSupplyFixed = Math64x64.divu(ethSupply, 1e18);
        int128 ethAmountInFixed = Math64x64.divu(ethAmountIn, 1e18);
        int128 ethSupplyNewFixed = ethSupplyFixed.add(ethAmountInFixed);

        int128 exponent = k.mul(ethSupplyFixed).neg();
        int128 expNegkE = exponent.exp();

        int128 exponentNew = k.mul(ethSupplyNewFixed).neg();
        int128 expNegkENew = exponentNew.exp();

        int128 numerator = expNegkE.sub(expNegkENew);
        int128 denominator = k.mul(P0);

        int128 tokensToBuyFixed = numerator.div(denominator);

        tokensToBuy = tokensToBuyFixed.mulu(SCALING_FACTOR);
    }

    /**
     * @dev Calculates the amount of ETH returned when selling a given amount of tokens.
     * @param ethSupply The total ETH raised in the pool so far (in wei).
     * @param tokenAmountIn The number of tokens being sold (with 18 decimals).
     * @return ethAmount The amount of ETH to return based on the market cap (in wei).
     */
    function calculateSellReturn(uint256 ethSupply, uint256 tokenAmountIn)
        internal
        pure
        returns (uint256 ethAmount)
    {
        if (tokenAmountIn == 0) return 0;

        int128 k = Math64x64.divu(EXP_FACTOR, 1e8);
        int128 P0 = Math64x64.divu(BASE_PRICE, 1e18);
        int128 one = Math64x64.fromUInt(1);

        int128 ethSupplyFixed = Math64x64.divu(ethSupply, 1e18);

        int128 exponent = k.mul(ethSupplyFixed).neg();
        int128 expNegkE = exponent.exp();

        int128 totalTokensSoldFixed = (one.sub(expNegkE)).div(k.mul(P0));
        int128 tokenAmountInFixed = Math64x64.divu(tokenAmountIn, SCALING_FACTOR);
        int128 newTotalTokensSoldFixed = totalTokensSoldFixed.sub(tokenAmountInFixed);

        if(newTotalTokensSoldFixed < 0) revert FormulaInvalidTokenAmount();

        int128 expNegkENew = one.sub(k.mul(P0).mul(newTotalTokensSoldFixed));

        if(expNegkENew <= 0) revert FormulaInvalidTokenAmount();

        int128 ethSupplyNewFixed = (expNegkENew.ln().neg()).div(k);

        int128 ethAmountFixed = ethSupplyFixed.sub(ethSupplyNewFixed);
        ethAmount = ethAmountFixed.mulu(1e18);
    }
}