// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IUniversalRouter} from "lib/universal-router/contracts/interfaces/IUniversalRouter.sol";

contract Swapper {
    IUniversalRouter public immutable universalRouter;

    constructor(address _universalRouter) {
        universalRouter = IUniversalRouter(_universalRouter);
    }
    function swap(address _tokenIn, address _tokenOut, uint256 _amountIn) external {
        // TODO
    }
}