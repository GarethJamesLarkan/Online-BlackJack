pragma solidity 0.8.22;

import "../TestSetup.sol";

contract PurchasePorscheInEth is TestSetup {

    function setUp() public {
        setUpTests();
        vm.deal(bob, 100 ether);
        vm.prank(alice);
        porscheSale.addPorsche(porscheCayman);
    }

    function test_FailsIfInvalidPorscheId() public {
        vm.prank(bob);
        vm.expectRevert("Invalid Porsche ID");
        porscheSale.purchasePorscheInETH{value: 30 ether}(1);
    }

    function test_FailsIfPorscheAlreadySold() public {
        vm.startPrank(bob);
        porscheSale.purchasePorscheInETH{value: 30 ether}(0);
        vm.expectRevert("Porsche already sold");
        porscheSale.purchasePorscheInETH{value: 30 ether}(0);
    }

    function test_FailsIfInsufficientFunds() public {
        vm.prank(bob);
        vm.expectRevert("Insufficient funds");
        porscheSale.purchasePorscheInETH{value: 29 ether}(0);
    }

    function test_SuccessfulPurchase() public {
        uint256 bobBalanceBefore = bob.balance;
        uint256 aliceBalanceBefore = alice.balance;

        vm.startPrank(bob);
        vm.expectEmit(true, false, false, false);
        emit PorschePurchased(0);
        porscheSale.purchasePorscheInETH{value: 30 ether}(0);
        
        (,,,,,, address purchaser, bool sold) = porscheSale.porsches(0); 

        assertEq(purchaser, bob);
        assertEq(sold, true);
        assertEq(bob.balance, bobBalanceBefore - 30 ether);
        assertEq(alice.balance, aliceBalanceBefore + 30 ether);


    }
}