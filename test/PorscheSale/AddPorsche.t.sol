pragma solidity 0.8.22;

import "../TestSetup.sol";

contract AddPorscheTests is TestSetup {

    function setUp() public {
        setUpTests();
    }

    function test_FailsIfInvalidOwner() public {
        PorscheSale.Porsche memory porscheCaymanIncorrectOwner = PorscheSale.Porsche({
            model: "718 Cayman",
            ipfsHash: "0xmd03ndn03jmf4004f03n40rfbkndnn04ndnlk",
            price: 30 ether,
            year: 2006,
            mileage: 73405,
            owner: alice,
            purchaser: address(0),
            sold: false
        });

        vm.prank(bob);
        vm.expectRevert("Invalid owner address");
        porscheSale.addPorsche(porscheCaymanIncorrectOwner);
    }

    function test_FailsIfInvalidPurchaser() public {
        PorscheSale.Porsche memory porscheCaymanIncorrectPurchaser = PorscheSale.Porsche({
            model: "718 Cayman",
            ipfsHash: "0xmd03ndn03jmf4004f03n40rfbkndnn04ndnlk",
            price: 30 ether,
            year: 2006,
            mileage: 73405,
            owner: bob,
            purchaser: alice,
            sold: false
        });

        vm.prank(bob);
        vm.expectRevert("Invalid purchaser address");
        porscheSale.addPorsche(porscheCaymanIncorrectPurchaser);
    }

    function test_FailsIfSetToSold() public {
        PorscheSale.Porsche memory porscheCaymanSold = PorscheSale.Porsche({
            model: "718 Cayman",
            ipfsHash: "0xmd03ndn03jmf4004f03n40rfbkndnn04ndnlk",
            price: 30 ether,
            year: 2006,
            mileage: 73405,
            owner: bob,
            purchaser: address(0),
            sold: true
        });

        vm.prank(bob);
        vm.expectRevert("Porsche must not be sold");
        porscheSale.addPorsche(porscheCaymanSold);
    }

    function test_AddPorsche() public {
        assertEq(porscheSale.porscheId(), 0);
        (,,,,, address currentOwner,,) = porscheSale.porsches(0);
        assertEq(currentOwner, address(0));

        vm.prank(alice);
        vm.expectEmit(true, false, false, false);
        emit PorscheAdded(0);
        porscheSale.addPorsche(porscheCayman);

        assertEq(porscheSale.porscheId(), 1);
        (
            string memory model,
            string memory ipfsHash,
            uint256 price,
            uint256 year,
            uint256 mileage, 
            address newOwner,
            address purchaser,
            bool sold
        ) = porscheSale.porsches(0);
        assertEq(model, "718 Cayman");
        assertEq(ipfsHash, "0xmd03ndn03jmf4004f03n40rfbkndnn04ndnlk");
        assertEq(price, 30 ether);
        assertEq(year, 2006);
        assertEq(mileage, 73405);
        assertEq(newOwner, alice);
        assertEq(purchaser, address(0));
        assertEq(sold, false);
    }
}