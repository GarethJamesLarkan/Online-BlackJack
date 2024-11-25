// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PorscheSale {

    struct Porsche {
        string model;
        string ipfsHash;
        uint256 price;
        uint256 year;
        uint256 mileage;
        address owner;
        address purchaser;
        bool sold;
    }

    mapping(uint256 porscheId => Porsche porsche) public porsches;

    uint256 public porscheId;
    address public wethAddress;

    event PorscheAdded(uint256 id);
    event PorschePurchased(uint256 id);

    constructor(address weth) {
        require(weth != address(0), "Invalid WETH address");
        wethAddress = weth;
    }

    function addPorsche(Porsche memory _porsche) public {
        require(_porsche.owner == msg.sender, "Invalid owner address");
        require(_porsche.purchaser == address(0), "Invalid purchaser address");
        require(!_porsche.sold, "Porsche must not be sold");
        porsches[porscheId] = _porsche;
        emit PorscheAdded(porscheId);
        porscheId++;
    }

    function purchasePorscheInETH(uint256 _porscheId) public payable {
        _checkValidPorsche(_porscheId);
        require(msg.value == porsches[_porscheId].price, "Insufficient funds");
        porsches[_porscheId].sold = true;
        porsches[_porscheId].purchaser = msg.sender;

        (bool sent, ) = porsches[_porscheId].owner.call{value: msg.value}("");
        require(sent, "Failed to send Ether");

        emit PorschePurchased(_porscheId);
    }

    // TASK FOR CODE OFF
    // ADD FUNCTION TO ALLOW PURCHASES IN WETH
    // TEST FUNCTION IN test/PorscheSale/PurchasePorscheInWETH.t.sol
    function purchasePorscheInWETH(uint256 _porscheId) public {
        
    }

    function _checkValidPorsche(uint256 _porscheId) private view {
        require(_porscheId < porscheId, "Invalid Porsche ID");
        require(porsches[_porscheId].sold == false, "Porsche already sold");
    }

}