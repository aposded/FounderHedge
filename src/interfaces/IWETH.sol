// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title IWETH - Interface for Privacy-Preserving Wrapped Ether
 */
interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function approve(saddress spender, suint256 amount) external returns (bool);
    function transfer(saddress to, suint256 amount) external returns (bool);
    function transferFrom(saddress from, saddress to, suint256 amount) external returns (bool);
    function balanceOf(saddress owner) external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
} 