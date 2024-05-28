// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract AttackTrusterLenderPool {
    address tokenAddress;
    address trusterLenderPool;
    uint256 amountToBorrow;

    constructor(address _tokenAddress, address _trusterLenderPool, uint256 _amountToBorrow) {
        tokenAddress = _tokenAddress;
        trusterLenderPool = _trusterLenderPool;
        amountToBorrow = _amountToBorrow;
    }

    function emptyPool() external {
        IERC20(tokenAddress).transfer(trusterLenderPool, amountToBorrow);
    }
}

interface IERC20 {
    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);
}
