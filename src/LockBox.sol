// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @notice Contract to account for erc20 tokens sent across bridge

contract LockBox is Ownable2Step {
    error TokenNotAllowed(address token);
    error AddressZero();
    error InvalidAmount();

    event TokenLocked(address token, uint256 amount);
    event TokenAllowed(address token);

    //mapping to hold locked ERC20 token balances
    mapping(address => uint256) public lockedBalances;

    //mapping to hold allowed ERC20's
    mapping(address => bool) public allowedTokens;

    constructor() Ownable(msg.sender) {}

    function allowToken(address _token) public onlyOwner verifyToken(_token) {
        allowedTokens[_token] = true;

        emit TokenAllowed(_token);
    }

    function lock(address _token, uint256 _amount) public verifyAmount(_amount) verifyToken(_token) {
        if(!allowedTokens[_token]) {
            revert TokenNotAllowed(_token);
        }

        lockedBalances[_token] += _amount;

        emit TokenLocked(_token, _amount);
    }
    
    modifier verifyToken(address _token) {
        if(_token == address(0)) {
            revert AddressZero();
        }
        _;
    }

    modifier verifyAmount(uint256 _amount) {
        if(_amount <= 0) {
            revert InvalidAmount();
        }
        _;
    }
}