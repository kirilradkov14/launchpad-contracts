// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ILaunchpad {
    function initialize(address _tokenAddress, address _wethAddress, address _uniswapRouter) external;

    function buyTokens(uint256 amountOutMin) external payable returns (uint256 amountOut);

    function sellTokens(uint256 amountIn, uint256 amountOutMin) external returns (uint256 amountOut);

    function getEthersOutAtCurrentSupply(uint256 amountIn) external view returns (uint256 amountOut);

    function getTokensOutAtCurrentSupply(uint256 amountIn) external view returns (uint256 amountOut);
}
