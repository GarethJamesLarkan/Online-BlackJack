// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {BurnMintERC677Helper, IERC20} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";

import {TokenTransfer} from "../src/TokenTransfer.sol";


contract ForkTestSetup is Test {
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    uint256 public sourceFork;
    uint256 public destinationFork;
    address public alice;
    address public bob;
    IRouterClient public sourceRouter;
    uint64 public destinationChainSelector;
    BurnMintERC677Helper public sourceCCIPBnMToken;
    BurnMintERC677Helper public destinationCCIPBnMToken;
    IERC20 public sourceLinkToken;

    TokenTransfer public tokenTransfer;

    function setUp() public {
        string memory DESTINATION_RPC_URL = vm.envString(
            "OPTIMISM_SEPOLIA_RPC_URL"
        );
        string memory SOURCE_RPC_URL = vm.envString("MAINNET_SEPOLIA_RPC_URL");
        destinationFork = vm.createSelectFork(DESTINATION_RPC_URL);
        sourceFork = vm.createFork(SOURCE_RPC_URL);

        bob = makeAddr("bob");
        alice = makeAddr("alice");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        Register.NetworkDetails
            memory destinationNetworkDetails = ccipLocalSimulatorFork
                .getNetworkDetails(block.chainid);
        destinationCCIPBnMToken = BurnMintERC677Helper(
            destinationNetworkDetails.ccipBnMAddress
        );
        destinationChainSelector = destinationNetworkDetails.chainSelector;

        vm.selectFork(sourceFork);
        Register.NetworkDetails
            memory sourceNetworkDetails = ccipLocalSimulatorFork
                .getNetworkDetails(block.chainid);
        sourceCCIPBnMToken = BurnMintERC677Helper(
            sourceNetworkDetails.ccipBnMAddress
        );
        sourceLinkToken = IERC20(sourceNetworkDetails.linkAddress);
        sourceRouter = IRouterClient(sourceNetworkDetails.routerAddress);

        tokenTransfer = new TokenTransfer(sourceNetworkDetails.routerAddress, sourceNetworkDetails.linkAddress);
    }

    function prepareScenario()
        public
        returns (
            Client.EVMTokenAmount[] memory tokensToSendDetails,
            uint256 amountToSend
        )
    {
        vm.selectFork(sourceFork);
        vm.startPrank(alice);
        sourceCCIPBnMToken.drip(alice);

        amountToSend = 100;
        sourceCCIPBnMToken.approve(address(sourceRouter), amountToSend);

        tokensToSendDetails = new Client.EVMTokenAmount[](1);
        tokensToSendDetails[0] = Client.EVMTokenAmount({
            token: address(sourceCCIPBnMToken),
            amount: amountToSend
        });

        vm.stopPrank();
    }

    function test_transferTokensFromEoaToEoaPayFeesInLink() external {
        (
            Client.EVMTokenAmount[] memory tokensToSendDetails,
            uint256 amountToSend
        ) = prepareScenario();
        vm.selectFork(destinationFork);
        uint256 balanceOfBobBefore = destinationCCIPBnMToken.balanceOf(bob);

        vm.selectFork(sourceFork);
        uint256 balanceOfAliceBefore = sourceCCIPBnMToken.balanceOf(alice);
        ccipLocalSimulatorFork.requestLinkFromFaucet(alice, 10 ether);

        vm.startPrank(alice);
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(bob),
            data: abi.encode(""),
            tokenAmounts: tokensToSendDetails,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 0})
            ),
            feeToken: address(sourceLinkToken)
        });

        uint256 fees = sourceRouter.getFee(destinationChainSelector, message);
        sourceLinkToken.approve(address(sourceRouter), fees);
        sourceRouter.ccipSend(destinationChainSelector, message);
        vm.stopPrank();

        uint256 balanceOfAliceAfter = sourceCCIPBnMToken.balanceOf(alice);
        assertEq(balanceOfAliceAfter, balanceOfAliceBefore - amountToSend);

        ccipLocalSimulatorFork.switchChainAndRouteMessage(destinationFork);
        uint256 balanceOfBobAfter = destinationCCIPBnMToken.balanceOf(bob);
        assertEq(balanceOfBobAfter, balanceOfBobBefore + amountToSend);
    }

    function test_Fork() public {
        console.log("sourceFork", sourceFork);
        console.log("destinationFork", destinationFork);
    }
    
}
