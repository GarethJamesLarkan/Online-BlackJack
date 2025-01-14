// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

contract BlackJack is Ownable, VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface coordinator;

    uint64 subscriptionId;
    bytes32 keyHash;

    uint256 public minimumBet = 0.0001 ether;

    event MinimumBetUpdated(uint256 newMinimumBet);

    constructor(address _coordinator, uint64 _subscriptionId, bytes32 _keyHash) Ownable(msg.sender) VRFConsumerBaseV2(_coordinator) public {
        require(_coordinator != address(0), "Cannot be zero address");
        coordinator = VRFCoordinatorV2Interface(_coordinator);
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
    }

    // ------------- Public Game Functions -------------------

    function startGame() external payable {
        require(msg.value >= minimumBet, "Bet too small");
        _dealInitialCards();
    }

    // ---------- Internal Game Helper Functions -------------
    function _dealInitialCards() internal {
        
    }

    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
    
    }


    // --------------- Only Owner Functions ------------------
    function updateMinimumBet(uint256 _newMinimumBet) external onlyOwner {
        minimumBet = _newMinimumBet;

        emit MinimumBetUpdated(_newMinimumBet);
    }
}