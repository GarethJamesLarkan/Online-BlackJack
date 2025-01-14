// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";

contract BlackJack is Ownable {

    uint256 public minimumBet = 0.0001 ether;

    event MinimumBetUpdated(uint256 newMinimumBet);

    constructor() Ownable(msg.sender) public {

    }

    // ------------- Public Game Functions -------------------

    function startGame() external payable {
        require(msg.value >= minimumBet, "Bet too small");
        _dealInitialCards();
    }

    // ---------- Internal Game Helper Functions -------------
    function _dealInitialCards() internal {
    }


    // --------------- Only Owner Functions ------------------
    function updateMinimumBet(uint256 _newMinimumBet) external onlyOwner {
        minimumBet = _newMinimumBet;

        emit MinimumBetUpdated(_newMinimumBet);
    }
}