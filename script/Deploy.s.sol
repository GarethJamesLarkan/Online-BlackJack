// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../CatalystTest.sol";
import "../src/UUPSProxy.sol";

contract DeployRewardNftScript is Script {

    /*---- Storage variables ----*/

    UUPSProxy public catalystTestProxy;

    CatalystTest public catalystTestImplementation;
    CatalystTest public catalystTest;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy RewardNft
        catalystTestImplementation = new CatalystTest();
        catalystTestProxy = new UUPSProxy(address(catalystTestImplementation), "");
        catalystTest = CatalystTest(address(catalystTestProxy));
        catalystTest.initialize("Test");

        console.log("Address: ", address(catalystTest));
    }
}
