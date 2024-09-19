// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Swapper} from "../src/Swapper.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "lib/universal-router/permit2/src/Permit2.sol";

import {IUniswapV3Factory} from "lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract TestSetup is Test {
    uint256 mainnetFork;

    IUniswapV3Factory public uniswapV3Factory;

    Swapper public swapper;
    Permit2 constant PERMIT2;

    address public universalRouter = 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD;
    address public uniswapV3FactoryAddress = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address public permit2Address = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    address public weth9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public uni = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        vm.selectFork(vm.createFork(vm.envString("MAINNET_RPC_URL")));

        PERMIT2 = Permit2(permit2Address);

        swapper = new Swapper(universalRouter, uniswapV3FactoryAddress, permit2Address);
        uniswapV3Factory = IUniswapV3Factory(uniswapV3FactoryAddress);
    }

    function test_Deploy() public {
        assertEq(address(swapper.universalRouter()), universalRouter);
        assertEq(address(swapper.uniswapV3Factory()), address(uniswapV3Factory));
    }

    function test_Swap() public {
        
        assertEq(vm.activeFork(), mainnetFork);
        
        console.log(uniswapV3Factory.getPool(weth9, usdc, 3000));
        deal(weth9, alice, 10 ether);
        assertEq(ERC20(weth9).balanceOf(alice), 10 ether);
        assertEq(ERC20(usdc).balanceOf(alice), 0);

        vm.startPrank(alice);
        ERC20(weth9).approve(address(swapper), 1 ether);
        // swapper.swap(weth9, usdc, 1 ether);
    }
}





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