// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenSwap {
    ISwapRouter public immutable swapRouter;
    address public immutable WETH9;
    address public tokenAddress;
    uint24 public constant poolFee = 3000; // 0.3% fee

    constructor(ISwapRouter _swapRouter, address _WETH9, address _tokenAddress) {
        swapRouter = _swapRouter;
        WETH9 = _WETH9;
        tokenAddress = _tokenAddress;
    }

    function swapExactInputSingle(uint256 tokenAmountIn) external returns (uint256 amountOut) {
        // Transfer tokens from user to this contract
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), tokenAmountIn);

        // Approve the Uniswap router to spend tokens
        IERC20(tokenAddress).approve(address(swapRouter), tokenAmountIn);

        // Setup swap parameters
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenAddress,
                tokenOut: WETH9,
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp + 15,
                amountIn: tokenAmountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // Perform the swap
        amountOut = swapRouter.exactInputSingle(params);
    }
}
// pragma solidity ^0.8.22;

// import {IUniversalRouter} from "lib/universal-router/contracts/interfaces/IUniversalRouter.sol";
// import "lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
// import {Commands} from "lib/universal-router/contracts/libraries/Commands.sol";
// import {Constants} from "lib/universal-router/contracts/libraries/Constants.sol";
// import 'lib/permit2/src/interfaces/IPermit2.sol';
// // import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// import "./TokenTransfer.sol";

// contract Swapper is TokenTransfer {
//     error PoolDoesNotExist();
//     error AddressIsZero();
//     error AmountIsZero();

//     IUniversalRouter public immutable universalRouter;
//     IUniswapV2Factory public immutable uniswapV2Factory;
//     IPermit2 public permit2;

//     constructor(
//         address _universalRouter, 
//         address _ccipRouter, 
//         address _link, 
//         address _uniswapV2Factory, 
//         address _permit2
//     ) TokenTransfer(_ccipRouter, _link) {
//         universalRouter = IUniversalRouter(_universalRouter);
//         uniswapV2Factory = IUniswapV2Factory(_uniswapV2Factory);
//         permit2 = IPermit2(_permit2);
//     }

//     function swap(address _tokenIn, address _tokenOut, uint256 _amountIn) external checkAddress(_tokenIn) checkAddress(_tokenOut) {
//         if (_amountIn == 0) {
//             revert AmountIsZero();
//         }

//         IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);

//         // address pool = uniswapV3Factory.getPool(_tokenIn, _tokenOut, 3000);
//         // if (pool == address(0)) {
//         //     revert PoolDoesNotExist();
//         // }

//         address pair = uniswapV2Factory.getPair(_tokenIn, _tokenOut);
//         if (pair == address(0)) {
//             revert PoolDoesNotExist();
//         }

//         IERC20(_tokenIn).approve(address(permit2), type(uint160).max);
//         permit2.approve(_tokenIn, address(universalRouter), type(uint160).max, type(uint48).max);

//         bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
//         address[] memory path = new address[](2);
//         path[0] = _tokenIn;
//         path[1] = _tokenOut;
//         bytes[] memory inputs = new bytes[](1);
//         inputs[0] = abi.encode(Constants.MSG_SENDER, _amountIn, 0, path, true);

//         universalRouter.execute(commands, inputs, block.timestamp + 1000);
//     }

//     modifier checkAddress(address _address) {
//         if (_address == address(0)) {
//             revert AddressIsZero();
//         }
//         _;
//     }
// }