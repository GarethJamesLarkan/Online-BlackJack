// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IUniversalRouter} from "lib/universal-router/contracts/interfaces/IUniversalRouter.sol";
import "lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {Commands} from "lib/universal-router/contracts/libraries/Commands.sol";
import {Constants} from "lib/universal-router/contracts/libraries/Constants.sol";
import 'lib/permit2/src/interfaces/IPermit2.sol';
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Swapper {
    error PoolDoesNotExist();
    error AddressIsZero();
    error AmountIsZero();

    IUniversalRouter public immutable universalRouter;
    IUniswapV2Factory public immutable uniswapV2Factory;
    IPermit2 public permit2;

    constructor(address _universalRouter, address _uniswapV2Factory, address _permit2) {
        universalRouter = IUniversalRouter(_universalRouter);
        uniswapV2Factory = IUniswapV2Factory(_uniswapV2Factory);
        permit2 = IPermit2(_permit2);
    }

    function swap(address _tokenIn, address _tokenOut, uint256 _amountIn) external checkAddress(_tokenIn) checkAddress(_tokenOut) {
        if (_amountIn == 0) {
            revert AmountIsZero();
        }

        ERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);

        // address pool = uniswapV3Factory.getPool(_tokenIn, _tokenOut, 3000);
        // if (pool == address(0)) {
        //     revert PoolDoesNotExist();
        // }

        address pair = uniswapV2Factory.getPair(_tokenIn, _tokenOut);
        if (pair == address(0)) {
            revert PoolDoesNotExist();
        }

        ERC20(_tokenIn).approve(address(permit2), type(uint160).max);
        permit2.approve(_tokenIn, address(universalRouter), type(uint160).max, type(uint48).max);

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        address[] memory path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.MSG_SENDER, _amountIn, 0, path, true);

        universalRouter.execute(commands, inputs, block.timestamp + 1000);
    }

    modifier checkAddress(address _address) {
        if (_address == address(0)) {
            revert AddressIsZero();
        }
        _;
    }
}