pragma solidity 0.8.22;

import "../TestSetup.sol";
import "../../src/interfaces/IwEth.sol";

contract PurchasePorscheInWETH is TestSetup {

    IwEth public weth;

    function setUp() public {
        setUpTests();

        //FORK MAINNET
        vm.selectFork(vm.createFork(vm.envString("MAINNET_RPC_URL")));
        weth = IwEth(wethAddress);

        // GIVE BOB 100 ETHER
        vm.deal(bob, 100 ether);

        // SWAP AND GET 50 WETH FOR PURCHASING
        vm.prank(bob);
        weth.deposit{value: 50 ether}();

        vm.prank(alice);
        porscheSale.addPorsche(porscheCayman);
    }
}