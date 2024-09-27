// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "lib/forge-std/src/Test.sol";
import {console} from "lib/forge-std/src/console.sol";
import 'lib/permit2/src/interfaces/IPermit2.sol';
import {ERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import {IUniswapV2Factory} from 'lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import {IUniswapV2Pair} from 'lib/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import {IUniversalRouter} from "lib/universal-router/contracts/interfaces/IUniversalRouter.sol";
import {Constants} from 'lib/universal-router/contracts/libraries/Constants.sol';
import {Commands} from 'lib/universal-router/contracts/libraries/Commands.sol';

import "lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import {Swapper} from "../src/Swapper.sol";

import 'lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol';
import 'lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol';

contract UniswapV2Test is Test {
    uint256 constant AMOUNT = 1e6;
    uint256 constant BALANCE = 100000 ether;
    IUniswapV2Factory constant FACTORY = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    ERC20 constant WETH9 = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ERC20 constant USDC = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    IUniversalRouter router = IUniversalRouter(0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD);

    Swapper public swapper;

    address alice = vm.addr(1001);

    function setUp() public virtual {
        vm.createSelectFork(vm.envString('MAINNET_RPC_URL'));

        swapper = new Swapper(address(router), address(FACTORY), address(PERMIT2));

        vm.startPrank(alice);
        deal(alice, BALANCE);
        deal(address(USDC), alice, BALANCE);
        deal(address(WETH9), alice, BALANCE);

        ERC20(USDC).approve(address(swapper), type(uint256).max);
        ERC20(WETH9).approve(address(swapper), type(uint256).max);
        ERC20(USDC).approve(address(PERMIT2), type(uint256).max);
        ERC20(WETH9).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(address(USDC), address(router), type(uint160).max, type(uint48).max);
        PERMIT2.approve(address(WETH9), address(router), type(uint160).max, type(uint48).max);

        ERC20(USDC).approve(address(PERMIT2), type(uint160).max);
        vm.stopPrank();
    }

    function test_ExactInput0For1() public {

        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(USDC),
                tokenOut: address(WETH9),
                fee: 3000,
                recipient: msg.sender,
                deadline: block.timestamp + 10000,
                amountIn: AMOUNT,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        console.log(ERC20(address(USDC)).balanceOf(alice));
        console.log(ERC20(address(WETH9)).balanceOf(address(swapper)));
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH9);
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(params);
        // inputs[0] = abi.encode(Constants.MSG_SENDER, AMOUNT, 0, path, true);

        vm.prank(alice);
        router.execute(commands, inputs, block.timestamp + 10000);
        // swapper.swap(address(USDC), address(WETH9), AMOUNT);

        console.log(ERC20(address(USDC)).balanceOf(alice));
        console.log(ERC20(address(WETH9)).balanceOf(address(swapper)));
        //router.execute(commands, inputs, block.timestamp + 10000);
        //assertEq(ERC20(address(USDC)).balanceOf(alice), BALANCE - AMOUNT);
        // assertGt(ERC20(address(WETH9)).balanceOf(alice), BALANCE);

    //     ISwapRouter.ExactInputSingleParams memory params =
    //         ISwapRouter.ExactInputSingleParams({
    //             tokenIn: DAI,
    //             tokenOut: WETH9,
    //             fee: poolFee,
    //             recipient: msg.sender,
    //             deadline: block.timestamp,
    //             amountIn: amountIn,
    //             amountOutMinimum: 0,
    //             sqrtPriceLimitX96: 0
    //         });
    }
}

// import {Test, console} from "forge-std/Test.sol";
// import {Swapper} from "../src/Swapper.sol";
// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import {IPermit2} from 'lib/permit2/src/interfaces/IPermit2.sol';

// import {IUniswapV3Factory} from "lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
// import {IUniswapV2Factory} from "lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

// contract TestSetup is Test {
//     uint256 mainnetFork;

//     IUniswapV3Factory public uniswapV3Factory;
//     IUniswapV2Factory public uniswapV2Factory;
//     Swapper public swapper;
//     IPermit2 public PERMIT2;

//     address public universalRouter = 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD;
//     address public uniswapV3FactoryAddress = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
//     address public uniswapV2FactoryAddress = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
//     address public permit2Address = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

//     address public weth9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
//     address public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
//     address public uni = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;

//     address public alice = makeAddr("alice");
//     address public bob = makeAddr("bob");

//     function setUp() public {
//         vm.selectFork(vm.createFork(vm.envString("MAINNET_RPC_URL")));

//         deal(alice, 10 ether);

//         PERMIT2 = IPermit2(permit2Address);

//         swapper = new Swapper(universalRouter, uniswapV2FactoryAddress, uniswapV3FactoryAddress, permit2Address);
//         uniswapV3Factory = IUniswapV3Factory(uniswapV3FactoryAddress);
//         uniswapV2Factory = IUniswapV2Factory(uniswapV2FactoryAddress);

//         vm.startPrank(alice);
//         ERC20(weth9).approve(address(swapper), type(uint256).max);
//         ERC20(usdc).approve(address(swapper), type(uint256).max);
//         ERC20(weth9).approve(address(PERMIT2), type(uint256).max);
//         ERC20(usdc).approve(address(PERMIT2), type(uint256).max);
//         PERMIT2.approve(weth9, address(universalRouter), type(uint160).max, type(uint48).max);
//         PERMIT2.approve(usdc, address(universalRouter), type(uint160).max, type(uint48).max);
//     }

//     function test_Deploy() public {
//         assertEq(address(swapper.universalRouter()), universalRouter);
//         assertEq(address(swapper.uniswapV3Factory()), address(uniswapV3Factory));
//     }

//     function test_Swap() public {
        
//         assertEq(vm.activeFork(), mainnetFork);

//         console.log(uniswapV2Factory.getPair(usdc, weth9));
        
//         // console.log(uniswapV3Factory.getPool(weth9, usdc, 3000));
//         deal(alice, 10 ether);
//         deal(weth9, alice, 10 ether);
//         deal(usdc, alice, 10 ether);
//         // assertEq(ERC20(weth9).balanceOf(alice), 10 ether);
//         // assertEq(ERC20(usdc).balanceOf(alice), 0);

//         vm.startPrank(alice);
//         swapper.swap(weth9, usdc, 1 ether);
//     }
// }





// contract ForkTestSetup is Test {
    // CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    // uint256 public sourceFork;
    // uint256 public destinationFork;
    // address public alice;
    // address public bob;
    // IRouterClient public sourceRouter;
    // uint64 public destinationChainSelector;
    // BurnMintERC677Helper public sourceCCIPBnMToken;
    // BurnMintERC677Helper public destinationCCIPBnMToken;
    // IERC20 public sourceLinkToken;

    // TokenTransfer public tokenTransfer;

    // function setUp() public {
    //     string memory DESTINATION_RPC_URL = vm.envString(
    //         "OPTIMISM_SEPOLIA_RPC_URL"
    //     );
    //     string memory SOURCE_RPC_URL = vm.envString("MAINNET_SEPOLIA_RPC_URL");
    //     destinationFork = vm.createSelectFork(DESTINATION_RPC_URL);
    //     sourceFork = vm.createFork(SOURCE_RPC_URL);

    //     bob = makeAddr("bob");
    //     alice = makeAddr("alice");

    //     ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
    //     vm.makePersistent(address(ccipLocalSimulatorFork));

    //     Register.NetworkDetails
    //         memory destinationNetworkDetails = ccipLocalSimulatorFork
    //             .getNetworkDetails(block.chainid);
    //     destinationCCIPBnMToken = BurnMintERC677Helper(
    //         destinationNetworkDetails.ccipBnMAddress
    //     );
    //     destinationChainSelector = destinationNetworkDetails.chainSelector;

    //     vm.selectFork(sourceFork);
    //     Register.NetworkDetails
    //         memory sourceNetworkDetails = ccipLocalSimulatorFork
    //             .getNetworkDetails(block.chainid);
    //     sourceCCIPBnMToken = BurnMintERC677Helper(
    //         sourceNetworkDetails.ccipBnMAddress
    //     );
    //     sourceLinkToken = IERC20(sourceNetworkDetails.linkAddress);
    //     sourceRouter = IRouterClient(sourceNetworkDetails.routerAddress);

    //     tokenTransfer = new TokenTransfer(sourceNetworkDetails.routerAddress, sourceNetworkDetails.linkAddress);
    // }

    // function prepareScenario()
    //     public
    //     returns (
    //         Client.EVMTokenAmount[] memory tokensToSendDetails,
    //         uint256 amountToSend
    //     )
    // {
    //     vm.selectFork(sourceFork);
    //     vm.startPrank(alice);
    //     sourceCCIPBnMToken.drip(alice);

    //     amountToSend = 100;
    //     sourceCCIPBnMToken.approve(address(sourceRouter), amountToSend);

    //     tokensToSendDetails = new Client.EVMTokenAmount[](1);
    //     tokensToSendDetails[0] = Client.EVMTokenAmount({
    //         token: address(sourceCCIPBnMToken),
    //         amount: amountToSend
    //     });

    //     vm.stopPrank();
    // }

    // function test_transferTokensFromEoaToEoaPayFeesInLink() external {
    //     (
    //         Client.EVMTokenAmount[] memory tokensToSendDetails,
    //         uint256 amountToSend
    //     ) = prepareScenario();
    //     vm.selectFork(destinationFork);
    //     uint256 balanceOfBobBefore = destinationCCIPBnMToken.balanceOf(bob);

    //     vm.selectFork(sourceFork);
    //     uint256 balanceOfAliceBefore = sourceCCIPBnMToken.balanceOf(alice);
    //     ccipLocalSimulatorFork.requestLinkFromFaucet(alice, 10 ether);

    //     vm.startPrank(alice);
    //     Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
    //         receiver: abi.encode(bob),
    //         data: abi.encode(""),
    //         tokenAmounts: tokensToSendDetails,
    //         extraArgs: Client._argsToBytes(
    //             Client.EVMExtraArgsV1({gasLimit: 0})
    //         ),
    //         feeToken: address(sourceLinkToken)
    //     });

    //     uint256 fees = sourceRouter.getFee(destinationChainSelector, message);
    //     sourceLinkToken.approve(address(sourceRouter), fees);
    //     sourceRouter.ccipSend(destinationChainSelector, message);
    //     vm.stopPrank();

    //     uint256 balanceOfAliceAfter = sourceCCIPBnMToken.balanceOf(alice);
    //     assertEq(balanceOfAliceAfter, balanceOfAliceBefore - amountToSend);

    //     ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);
    //     uint256 balanceOfBobAfter = destinationCCIPBnMToken.balanceOf(bob);
    //     assertEq(balanceOfBobAfter, balanceOfBobBefore + amountToSend);
    // }

    // function test_Fork() public {
    //     console.log("sourceFork", sourceFork);
    //     console.log("destinationFork", destinationFork);
    // }
    
// }