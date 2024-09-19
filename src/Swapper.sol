// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IUniversalRouter} from "lib/universal-router/contracts/interfaces/IUniversalRouter.sol";
import {IUniswapV3Factory} from "lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {Commands} from "lib/universal-router/contracts/libraries/Commands.sol";
import {Constants} from "lib/universal-router/contracts/libraries/Constants.sol";
import {Permit2} from 'lib/permit2/src/Permit2.sol';
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Swapper {
    error PoolDoesNotExist();
    error AddressIsZero();
    error AmountIsZero();

    IUniversalRouter public immutable universalRouter;
    IUniswapV3Factory public immutable uniswapV3Factory;
    Permit2 public immutable permit2;

    constructor(address _universalRouter, address _uniswapV3Factory, address _permit2) {
        universalRouter = IUniversalRouter(_universalRouter);
        uniswapV3Factory = IUniswapV3Factory(_uniswapV3Factory);
        permit2 = Permit2(_permit2);
    }

    function swap(address _tokenIn, address _tokenOut, uint256 _amountIn) external checkAddress(_tokenIn) checkAddress(_tokenOut) {
        if (_amountIn == 0) {
            revert AmountIsZero();
        }

        ERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);

        address pool = uniswapV3Factory.getPool(_tokenIn, _tokenOut, 3000);
        if (pool == address(0)) {
            revert PoolDoesNotExist();
        }

        permit2.approve(_tokenIn, address(universalRouter), type(uint160).max, type(uint48).max);
        permit2.approve(_tokenOut, address(universalRouter), type(uint160).max, type(uint48).max);

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        address[] memory path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(msg.sender, _amountIn, _amountIn, path, false);

        universalRouter.execute(commands, inputs, block.timestamp + 1000);
    }

    modifier checkAddress(address _address) {
        if (_address == address(0)) {
            revert AddressIsZero();
        }
        _;
    }
}