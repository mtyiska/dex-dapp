// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

/**
 * @title
 * @notice Empty DEX.sol that just outlines what features could be part of the challenge (up to you!)
 * @dev We want to create an automatic market where our contract will hold reserves of both ETH and 🎈 Balloons. These reserves will provide liquidity that allows anyone to swap between the assets.
 */
contract DEX {
    /* ========== GLOBAL VARIABLES ========== */

    using SafeMath for uint256; //outlines use of SafeMath for uint256 variables
    IERC20 token; //instantiates the imported contract

    event EthToTokenSwap();
    event TokenToEthSwap();
    event LiquidityProvided();
    event LiquidityRemoved();

    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;

    constructor(address token_addr) {
        token = IERC20(token_addr); //specifies the token address that will hook into the interface and be used through the variable 'token'
    }

    /**
     * @notice initializes amount of tokens that will be transferred to the DEX itself from the erc20 contract mintee (and only them based on how Balloons.sol is written). Loads contract up with both ETH and Balloons.
     * @param tokens amount to be transferred to DEX
     * @return totalLiquidity is the balance of this DEX contract
     * NOTE: since ratio is 1:1, this is fine to initialize the totalLiquidity (wrt to balloons) as equal to eth balance of contract.
     */
    function init(uint256 tokens) public payable returns (uint256) {
        require(totalLiquidity == 0, "DEX already has liquidity");
        console.log("current balance for address is", address(this).balance);
        totalLiquidity = address(this).balance;
        liquidity[msg.sender] = totalLiquidity;
        // sender, recipient, amount
        require((token.transferFrom(msg.sender, address(this), tokens)));
        return totalLiquidity;
    }

    /**
     * @notice returns yOutput, or yDelta for xInput (or xDelta)
     * @dev Follow along with the [original tutorial](https://medium.com/@austin_48503/%EF%B8%8F-minimum-viable-exchange-d84f30bd0c90) Price section for an understanding of the DEX's pricing model and for a price function to add to your contract. You may need to update the Solidity syntax (e.g. use + instead of .add, \* instead of .mul, etc). Deploy when you are done.
     */
    function price(
        uint256 xInput,
        uint256 xReserves,
        uint256 yReserves
    ) public pure returns (uint256 yOutput) {
        uint256 input_amount_with_fee = xInput.mul(997);
        uint256 numerator = input_amount_with_fee.mul(yReserves);
        uint256 denominator = xReserves.mul(1000).add(input_amount_with_fee);
        yOutput = numerator / denominator;
        return yOutput;
    }

    /**
     * @notice sends Ether to DEX in exchange for $BAL
     */
    function ethToToken() public payable returns (uint256 tokenOutput) {
        uint256 token_reserve = token.balanceOf(address(this));
        uint256 tokens_bought = price(
            msg.value,
            address(this).balance.sub(msg.value),
            token_reserve
        );
        require(token.transfer(msg.sender, tokens_bought));
        return tokens_bought;
    }

    /**
     * @notice sends $BAL tokens to DEX in exchange for Ether
     */
    function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
        uint256 token_reserve = token.balanceOf(address(this));
        uint256 eth_bought = price(
            tokenInput,
            token_reserve,
            address(this).balance
        );
        payable(msg.sender).transfer(eth_bought);
        require(token.transferFrom(msg.sender, address(this), tokenInput));
        ethOutput = eth_bought;
        return ethOutput;
    }

    /**
     * @notice allows deposits of $BAL and $ETH to liquidity pool
     * NOTE: Ratio needs to be maintained.
     */
    function deposit() public payable returns (uint256 tokensDeposited) {
        uint256 eth_reserve = address(this).balance.sub(msg.value);
        uint256 token_reserve = token.balanceOf(address(this));
        uint256 token_amount = (msg.value.mul(token_reserve) / eth_reserve).add(
            1
        );
        uint256 liquidity_minted = msg.value.mul(totalLiquidity) / eth_reserve;
        liquidity[msg.sender] = liquidity[msg.sender].add(liquidity_minted);
        require(token.transferFrom(msg.sender, address(this), token_amount));
        tokensDeposited = liquidity_minted;
        return tokensDeposited;
    }

    /**
     * @notice allows withdrawal of $BAL and $ETH from liquidity pool
     */
    function withdraw(uint256 amount) public returns (uint256, uint256) {
        uint256 token_reserve = token.balanceOf(address(this));
        uint256 eth_amount = amount.mul(address(this).balance) / totalLiquidity;
        uint256 token_amount = amount.mul(token_reserve) / totalLiquidity;
        liquidity[msg.sender] = liquidity[msg.sender].sub(eth_amount);
        totalLiquidity = totalLiquidity.sub(eth_amount);
        payable(msg.sender).transfer(eth_amount);
        require(token.transfer(msg.sender, token_amount));
        return (eth_amount, token_amount);
    }
}
