// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SourceERC20 is ERC20 {
    constructor() ERC20("SourceERC20", "SRC") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
