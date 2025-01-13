// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

contract BlackJack {

    uint8 public minimumBet = 0.0001 ether;

    constructor() public {

    }

    function startGame() external payable {
        require(msg.value >= minimumBet, "Bet too small");
    }
}