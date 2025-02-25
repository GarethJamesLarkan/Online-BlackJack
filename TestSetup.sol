// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "./src/BettingSystem.sol";
import "./src/Treasury.sol";
import "./src/RewardModule.sol";
import "./src/RewardNft.sol";
import "./test/TestUSDC.sol";

contract TestSetup is Test {

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);
    address robyn = vm.addr(4);
    address frank = vm.addr(5);
    address lucy = vm.addr(6);

    BettingSystem public bettingSystemContract;
    Treasury public treasuryContract;
    RewardModule public rewardModuleContract;
    RewardNft public rewardNftContract;
    TestUSDC public testUSDCContract;

    function setUpTests() public {
        treasuryContract = new Treasury();
        rewardModuleContract = new RewardModule();
        rewardNftContract = new RewardNft();
        testUSDCContract = new TestUSDC();

        bettingSystemContract = new BettingSystem(address(treasuryContract), address(rewardModuleContract), address(rewardNftContract));
    }
}
