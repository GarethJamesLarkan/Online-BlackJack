// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
interface IwEth {
    function deposit() external payable;
    function withdraw(uint256 _amount) external;
}