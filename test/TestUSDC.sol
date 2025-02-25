pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestUSDC is ERC20 {

    constructor() ERC20("USDC", "USDC") {
    } 

    function mint() public {
        _mint(msg.sender, 100_000_000 ether);
    }
}