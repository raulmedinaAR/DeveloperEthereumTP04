// SPDX-License-Identifier: MIT

pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./RaulMedinaToken.sol";

/** 
 * @title SimpleSwap
 * @author Raúl Medina
 *
 * @notice Smart contract that lets users add and remove liquidity 
 *         (Implemented with ERC20 from Openzeppelin), swap tokens,
 *         fetch price quotes, and calculate expected output amounts—replicating
 *         Uniswap-style functionality without relying on the Uniswap protocol.
 */
contract SimpleSwap is ERC20 {
    /*
     * @dev Implements Openzeppelin's ERC20 for liquidity management.
     */
    constructor() ERC20("Liquidity", "LP") {
    }

    /**
     * @notice Verifies that the token pair is valid before proceeding.
     * @dev Guards against common configuration mistakes:
     *      - 'tokenA' and 'tokenB' must reference different contracts,
     *        otherwise the pool would be meaningless.
     *      - Neither address may be the zero address, which would break
     *        ERC20 calls and revert the transaction.
     *
     * @param tokenA Address of a test ERC20 token (must implement IMintableERC20).
     * @param tokenB Address of a test ERC20 token (must implement IMintableERC20).
     */
    modifier ValidTokens(address tokenA, address tokenB) {
        require(tokenA != tokenB, "Identical addresses");
        require(tokenA != address(0) && tokenB != address(0), "Zero addresses");
        _;
    }

    /**
     * @notice Function that lets users add liquidity for a pair of tokens in an ERC-20 pool.
     * @dev Transfers the user’s tokens to the contract, calculates the proper liquidity
     *      based on current reserves, and mints liquidity tokens back to the user.
     *
     * @param tokenA Address of a test ERC20 token (must implement IMintableERC20).
     * @param tokenB Address of a test ERC20 token (must implement IMintableERC20).
     * @param amountADesired Amount of token A the user wishes to supply.
     * @param amountBDesired Amount of token B the user wishes to supply.
     * @param amountAMin     Minimum acceptable amount of token A (slippage protection).
     * @param amountBMin     Minimum acceptable amount of token B (slippage protection).
     * @param to             Recipient address that will receive the liquidity tokens.
     * @param deadline       Unix timestamp after which the transaction will revert.
     *
     * @return amountA  Actual amount of token A added.
     * @return amountB  Actual amount of token B added.
     * @return liquidity Amount of liquidity tokens minted.
     */
    function addLiquidity
    (
        address tokenA, address tokenB, 
        uint amountADesired, uint amountBDesired, 
        uint amountAMin, uint amountBMin, 
        address to, 
        uint deadline
    ) ValidTokens(tokenA, tokenB) external returns (uint amountA, uint amountB, uint liquidity) 
    {
        require(block.timestamp <= deadline, "Expired");
        require(amountADesired > 0 && amountBDesired > 0, "Desired amount is zero");
        require(amountAMin > 0 && amountBMin > 0, "Min amount is zero");
        require(to != address(0), "The 'to' address is zero");

        // Get the reserves of both tokens
        uint256 reserveA = RaulMedinaToken(tokenA).balanceOf(address(this));
        uint256 reserveB = RaulMedinaToken(tokenB).balanceOf(address(this));
        if(reserveA == 0 && reserveB == 0) { //Check if there is no previous liquidity
            // If there is no previous liquidity, I take the desired amount
            amountA   = amountADesired;
            amountB   = amountBDesired;

            // Initial liquidity based on the constant product formula
            // Formula used in the review class.
            liquidity = Math.sqrt(amountA * amountB); 
        }
        else {
            // Calculate optimal amount of B according to reserves
            uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Insufficient B amount");
                amountA = amountADesired;
                amountB = amountBOptimal;
            } 
            else {
                // Calculate optimal amount of A according to reserves
                uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
                require(amountAOptimal >= amountAMin, "Insufficient A amount");
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
            // Calcula liquidez a emitir
            liquidity = min((amountA * liquidity) / reserveA, (amountB * liquidity) / reserveB);
        }
        require(liquidity > 0, "Insufficient liquidity minted");

        // Transfer tokens A and B to the contract
        RaulMedinaToken(tokenA).transferFrom(msg.sender, address(this), amountA);
        RaulMedinaToken(tokenB).transferFrom(msg.sender, address(this), amountB);
        // Mint liquidity tokens to the user
        _mint(to, liquidity);

        return (amountA, amountB, liquidity);
    }

    /**
     * @notice Allows users to withdraw liquidity from an ERC-20 pool.
     * @dev Burns the caller’s liquidity tokens, computes the correct amounts of
     *      token A and token B based on current reserves, and transfers them to
     *      the designated recipient.
     *
     * @param tokenA Address of a test ERC20 token (must implement IMintableERC20).
     * @param tokenB Address of a test ERC20 token (must implement IMintableERC20).
     * @param liquidity  Amount of liquidity tokens to burn.
     * @param amountAMin Minimum acceptable amount of token A (slippage protection).
     * @param amountBMin Minimum acceptable amount of token B (slippage protection).
     * @param to         Recipient address for the withdrawn tokens.
     * @param deadline   Unix timestamp after which the transaction will revert.
     *
     * @return amountA   Actual amount of token A received.
     * @return amountB   Actual amount of token B received.
     */
    function removeLiquidity
    (
        address tokenA, address tokenB, 
        uint liquidity, 
        uint amountAMin, uint amountBMin, 
        address to, 
        uint deadline
    ) ValidTokens(tokenA, tokenB) external returns (uint amountA, uint amountB) 
    {
        require(block.timestamp <= deadline, "Expired");
        require(liquidity > 0, "Liquidity is zero");
        require(to != address(0), "The 'to' address is zero");
        require(balanceOf(msg.sender) >= liquidity, "You are trying to withdraw more liquidity than you have");

        // Get the reserves of both tokens and the total amount of liquidity tokens issued
        uint256 reserveA = RaulMedinaToken(tokenA).balanceOf(address(this));
        uint256 reserveB = RaulMedinaToken(tokenB).balanceOf(address(this));
        uint256 totalSupply = totalSupply();
        // Calculate how many tokens A and B correspond to the percentage of liquidity withdrawn
        amountA = (liquidity * reserveA) / totalSupply;
        amountB = (liquidity * reserveB) / totalSupply;

        require(amountA >= amountAMin, "Insufficient amountA");
        require(amountB >= amountBMin, "Insufficient amountB");

        // Send tokens A and B to the recipient 'to'
        RaulMedinaToken(tokenA).transfer(to, amountA);
        RaulMedinaToken(tokenB).transfer(to, amountB);
        // Burns the issuer's liquidity tokens, reducing the total supply
        _burn(msg.sender, liquidity);

        return (amountA, amountB);
    }

    /**
     * @notice Swaps an exact amount of one ERC-20 token for another.
     * @dev Transfers the specified input tokens from the caller, performs the swap
     *      according to current pool reserves, and sends the output tokens to the
     *      designated recipient.
     *
     * @param amountIn      Exact amount of input tokens supplied by the caller.
     * @param amountOutMin  Minimum acceptable amount of output tokens (slippage protection).
     * @param path          Array of token addresses: [inputToken, outputToken].
     * @param to            Recipient address for the output tokens.
     * @param deadline      Unix timestamp after which the transaction will revert.
     *
     * @return amounts  Array containing the input amount and the actual output amount.
     */
    function swapExactTokensForTokens
    (
        uint amountIn, 
        uint amountOutMin, 
        address[] calldata path, 
        address to, 
        uint deadline
    ) external returns (uint[] memory amounts) 
    {
        require(block.timestamp <= deadline, "Expired");
        require(amountIn > 0 && amountOutMin > 0, "Amount is zero");
        require(path.length == 2 && path[0] != address(0) && path[1] != address(0), "Path is not valid");
        require(to != address(0), "The 'to' address is zero");

        // Gets the current reserves of input and output tokens
        uint256 reserveIn  = RaulMedinaToken(path[0]).balanceOf(address(this));
        uint256 reserveOut = RaulMedinaToken(path[1]).balanceOf(address(this));
        
        // Calculate how many output tokens would be obtained and 
        // verify that they are at least 'amountOutMin'
        uint256 amountOut  = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "Insufficient output amount");

        // Transfers the user's input tokens to the contract and 
        // then sends the calculated amount of output tokens to the recipient.
        RaulMedinaToken(path[0]).transferFrom(msg.sender, address(this), amountIn);
        RaulMedinaToken(path[1]).transfer(to, amountOut);

        // Builds the array with the input and output quantities and returns it
        amounts    = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
        return amounts;
    }

    /**
     * @notice Returns the price of one token in terms of another.
     * @dev Reads the pool’s reserves for both tokens, performs the calculation,
     *      and returns the current price of 'tokenA' denominated in 'tokenB'.
     *
     * @param tokenA Address of a test ERC20 token (must implement IMintableERC20).
     * @param tokenB Address of a test ERC20 token (must implement IMintableERC20).
     *
     * @return price of one unit of 'tokenA' expressed in units of 'tokenB'.
     */
    function getPrice(address tokenA, address tokenB) ValidTokens(tokenA, tokenB) external view returns (uint price) {      
        uint256 reserveA = RaulMedinaToken(tokenA).balanceOf(address(this));
        require(reserveA > 0, "Insufficient reserves A");

        uint256 reserveB = RaulMedinaToken(tokenB).balanceOf(address(this));
        require(reserveB > 0, "Insufficient reserves B");

        // 1e18 is equivalent to 10**18
        // Scaling factor we use in Ethereum to represent quantities with 18 decimal places.
        price = (reserveB * 1e18) / reserveA;
    }

    /**
     * @notice Calculates how many output tokens will be received for a given swap.
     * @dev Uses the input amount and the current reserves to compute the expected
     *      output amount, following the constant-product formula.
     *
     * @param amountIn   Amount of input tokens supplied.
     * @param reserveIn  Current reserve of the input  token in the pool.
     * @param reserveOut Current reserve of the output token in the pool.
     *
     * @return amountOut Amount of output tokens that will be received.
     */
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint amountOut) {
        require(amountIn  > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        // Calculate how many output tokens the user will receive using the formula proposed in the statement
        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
    }

    /*
     * @notice Returns the smaller of two values.
     */
    function min(uint256 x, uint256 y) private pure returns (uint256) {
        return x < y ? x : y;
    }
}
