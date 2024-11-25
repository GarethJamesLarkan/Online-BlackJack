// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/PorscheSale.sol";

contract TestSetup is Test {

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);

    PorscheSale public porscheSale;
    PorscheSale.Porsche public porscheCayman;

    event PorscheAdded(uint256 id);
    event PorschePurchased(uint256 id);

    function setUpTests() public {
        porscheSale = new PorscheSale();
        porscheCayman = PorscheSale.Porsche({
            model: "718 Cayman",
            ipfsHash: "0xmd03ndn03jmf4004f03n40rfbkndnn04ndnlk",
            price: 30 ether,
            year: 2006,
            mileage: 73405,
            owner: alice,
            purchaser: address(0),
            sold: false
        });
    }
}
