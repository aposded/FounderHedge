// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC, modified for shielded types.
 */
interface ISRC20 {
    /**
     * @dev Function to emit when tokens are moved from one account to another.
     * Must be overridden by implementing contracts to define event emission behavior.
     * Default implementation is no-op for privacy.
     * 
     * @param from The sender address
     * @param to The recipient address
     * @param value The transfer amount
     */
    function emitTransfer(address from, address to, uint256 value) external;

    /**
     * @dev Function to emit when allowance is modified.
     * Must be overridden by implementing contracts to define event emission behavior.
     * Default implementation is no-op for privacy.
     * 
     * @param owner The token owner
     * @param spender The approved spender
     * @param value The approved amount
     */
    function emitApproval(address owner, address spender, uint256 value) external;

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     * For privacy reasons, returns actual balance only if caller is the account owner,
     * otherwise reverts.
     */
    function balanceOf(saddress account) external view returns (uint256);

    /**
     * @dev Moves a shielded `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded,
     * otherwise reverts.
     *
     * Expected that implementation calls emitTransfer.
     */
    function transfer(saddress to, suint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     * For privacy reasons, returns actual allowance only if caller is either owner or spender,
     * otherwise reverts.
     */
    function allowance(saddress owner, saddress spender) external view returns (uint256);

    /**
     * @dev Sets a shielded `value` amount of tokens as the allowance of a shielded `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Expected that implementation calls emitApproval.
     */
    function approve(saddress spender, suint256 value) external returns (bool);

    /**
     * @dev Moves a shielded `value` amount of tokens from a shielded `from` address to a shielded `to` address using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Expected that implementation calls emitTransfer.
     */
    function transferFrom(saddress from, saddress to, suint256 value) external returns (bool);
}