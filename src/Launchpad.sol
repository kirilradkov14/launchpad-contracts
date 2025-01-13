// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {Formula} from "./libraries/Formula.sol";
import {ILaunchpad} from "./interfaces/launchpad/ILaunchpad.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {IUniswapV2Router02} from "./interfaces/uniswap/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "./interfaces/uniswap/IUniswapV2Factory.sol";

/**
 * @title Launchpad
 * @dev Launchpad contract implementing an exponential bonding curve.
 */
contract Launchpad is Initializable, ReentrancyGuardTransient, ILaunchpad {
    using SafeERC20 for IERC20;
    using Address for address payable;

    // --- Constants ---
    uint256 public constant THRESHOLD = 100 ether;
    uint256 public constant TOTAL_TOKENS = 1_000_000_000 ether;
    uint256 public constant TOKENS_FOR_SALE = 800_000_000 ether;
    uint256 public constant TOKENS_FOR_LIQUIDITY = 200_000_000 ether;

    // --- State variables ---
    uint256 public tokenSupply;
    uint256 public ethSupply;

    address public tokenAddress;

    IWETH public weth;
    IUniswapV2Router02 public uniswapRouter;

    bool public isMigrated;

    // --- Errors ---
    error LaunchpadInvalidState();
    error LaunchpadInsufficientInputAmount();
    error LaunchpadInsufficientOutputAmount();
    error LaunchpadInsufficientLiquidity();
    error LaunchpadInvalidAddress();

    // --- Events ---
    event LiquidityMigration(address indexed pair, uint256 ethAmount, uint256 tokenAmount);
    event TokenPurchase(address indexed recipient, uint256 ethAmountSent, uint256 tokenAmountReceived);
    event TokenSale(address indexed recipient, uint256 tokenAmountSent, uint256 ethAmountReceived);

    /**
     * @dev Modifier to ensure the contract is not migrated.
     */
    modifier whenNotMigrated() {
        if (isMigrated) revert LaunchpadInvalidState();
        _;
    }

    constructor() {
        _disableInitializers(); // Prevents initialization hijack
    }

    receive() external payable {}

    /**
     * @dev Initializer function
     * @param _tokenAddress The address of the token being sold.
     * @param _wethAddress The address of the WETH contract.
     * @param _uniswapRouter The address of the Uniswap V2 router.
     */
    function initialize(address _tokenAddress, address _wethAddress, address _uniswapRouter) external initializer {
        isMigrated = false;
        tokenAddress = _tokenAddress;
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        weth = IWETH(_wethAddress);
        tokenSupply = TOKENS_FOR_SALE;

        IERC20(tokenAddress).approve(_uniswapRouter, type(uint256).max);
    }

    /**
     * @notice Swap exact amount of ETH for an amount of tokens.
     * @param amountOutMin The minimum amount of tokens to receive.
     * @return amountOut The actual amount of tokens received.
     */
    function buyTokens(uint256 amountOutMin)
        external
        payable
        nonReentrant
        whenNotMigrated
        returns (uint256 amountOut)
    {
        uint256 ethAmount = msg.value;
        if (ethAmount == 0) revert LaunchpadInsufficientInputAmount();

        uint256 totalSupplyAfterETH = ethSupply + ethAmount;
        if (totalSupplyAfterETH >= THRESHOLD) {
            isMigrated = true;
            amountOut = _fillOrder(ethAmount, totalSupplyAfterETH);
            return amountOut;
        }

        amountOut = Formula.calculatePurchaseReturn(ethSupply, ethAmount);
        if (amountOut > tokenSupply) revert LaunchpadInsufficientLiquidity();
        if (amountOut < amountOutMin) revert LaunchpadInsufficientOutputAmount();

        ethSupply += ethAmount;
        tokenSupply -= amountOut;

        weth.deposit{value: ethAmount}();
        IERC20(tokenAddress).safeTransfer(msg.sender, amountOut);

        emit TokenPurchase(msg.sender, ethAmount, amountOut);

        return amountOut;
    }

    /**
     * @dev Swaps an exact amount of tokens for ETH.
     * @param amountIn The amount of tokens being sold.
     * @param amountOutMin The minimum amount of ETH to receive.
     * @return amountOut The actual amount of ETH received.
     */
    function sellTokens(uint256 amountIn, uint256 amountOutMin)
        external
        nonReentrant
        whenNotMigrated
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert LaunchpadInsufficientInputAmount();

        uint256 ethReturn = Formula.calculateSellReturn(ethSupply, amountIn);
        if (ethReturn < amountOutMin) revert LaunchpadInsufficientOutputAmount();
        if (ethReturn > ethSupply) revert LaunchpadInsufficientLiquidity();

        ethSupply -= ethReturn;
        tokenSupply += amountIn;

        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amountIn);

        weth.withdraw(ethReturn);
        payable(msg.sender).sendValue(ethReturn);

        emit TokenSale(msg.sender, amountIn, ethReturn);

        return ethReturn;
    }

    /**
     * @dev Computes the amount of ETH you'd receive at the current supply for a given token amount.
     * @param amountIn Amount of tokens to sell.
     * @return amountOut The amount of ETH that would be received.
     */
    function getEthersOutAtCurrentSupply(uint256 amountIn) public view returns (uint256 amountOut) {
        amountOut = Formula.calculateSellReturn(ethSupply, amountIn);
    }

    /**
     * @dev Computes the amount of tokens you'd receive at the current supply for a given ETH amount.
     * @param amountIn Amount of ETH to spend.
     * @return amountOut The amount of tokens that would be received.
     */
    function getTokensOutAtCurrentSupply(uint256 amountIn) public view returns (uint256 amountOut) {
        amountOut = Formula.calculatePurchaseReturn(ethSupply, amountIn);
    }

    /**
     * @dev Fill order when contribution exceeds the threshold.
     *      Refunds any excess ETH above THRESHOLD back to the sender.
     */
    function _fillOrder(uint256 amountIn, uint256 totalSupply) internal returns (uint256 amountOut) {
        uint256 excess = totalSupply - THRESHOLD;
        uint256 contribution = amountIn - excess;

        if (excess > 0) {
            payable(msg.sender).sendValue(excess);
            amountOut = Formula.calculatePurchaseReturn(ethSupply, contribution);
            if (amountOut > tokenSupply) revert LaunchpadInsufficientLiquidity();
            ethSupply += contribution;
            tokenSupply -= amountOut;
            weth.deposit{value: contribution}();
        }

        _migrateLiquidity(THRESHOLD, TOKENS_FOR_LIQUIDITY);
        emit TokenPurchase(msg.sender, contribution, amountOut);
        return amountOut;
    }

    /**
     * @dev Migrate liquidity to Uniswap V2 when the threshold is reached.
     * @param ethAmount Amount of ETH to add to the liquidity pool.
     * @param tokenAmount Amount of tokens to add to the liquidity pool.
     */
    function _migrateLiquidity(uint256 ethAmount, uint256 tokenAmount) internal {
        if (ethAmount == 0 || tokenAmount == 0) revert LaunchpadInsufficientInputAmount();

        weth.withdraw(ethAmount);

        uniswapRouter.addLiquidityETH{value: ethAmount}(
            tokenAddress,
            tokenAmount,
            0, // Min tokens
            0, // Min ETH
            address(this),
            block.timestamp + 600
        );

        address tokenPairLP = IUniswapV2Factory(uniswapRouter.factory()).getPair(tokenAddress, uniswapRouter.WETH());
        if (tokenPairLP == address(0)) revert LaunchpadInvalidAddress();

        IERC20(tokenPairLP).safeTransfer(address(0xdead), IERC20(tokenPairLP).balanceOf(address(this)));
        emit LiquidityMigration(tokenPairLP, ethAmount, tokenAmount);
    }
}
