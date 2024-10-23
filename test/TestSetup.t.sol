// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import "../src/Swapper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "./MockERC20.sol";

import {IRouterClient, LinkToken, BurnMintERC677Helper} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {CCIPLocalSimulator} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";

contract TokenSwapTest is Test {
    CCIPLocalSimulator public ccipLocalSimulator;

    uint64 public chainSelector;
    IRouterClient public sourceRouter;
    IRouterClient public destinationRouter;
    // WETH9 public wrappedNative;
    LinkToken public linkToken;
    BurnMintERC677Helper public ccipBnM;
    BurnMintERC677Helper public ccipLnM;

    Swapper public tokenSwap;
    ISwapRouter public swapRouter;
    address public WETH9;
    address public tokenAddress;
    MockERC20 public mockERC20;

    // Mock tokens for testing
    ERC20 public mockToken;

    address public owner = address(0x1);
    address public user = address(0x2);

    function setUp() public {
        // Setup the addresses
        swapRouter = ISwapRouter(address(0x123)); // Mock router address
        WETH9 = address(0x456);                  // Mock WETH9 address
        // tokenAddress = address(0x789);            // Mock token address
        
        vm.startPrank(owner);
        // Deploy mock ERC20 token for testing
        mockERC20 = new MockERC20("Mock Token", "MTK");
        deal(address(mockERC20), user, 1000 ether); // Assign tokens to the user for testing
        
        

        ccipLocalSimulator = new CCIPLocalSimulator();

        vm.stopPrank();

        (
            chainSelector,
            sourceRouter,
            destinationRouter,,
            // wrappedNative,
            linkToken,
            ccipBnM,
            ccipLnM
        ) = ccipLocalSimulator.configuration();

        // Deploy the swap contract
        tokenSwap = new Swapper(swapRouter, WETH9, address(sourceRouter), address(linkToken));
    }

    function testSwapExactInputSingle() public {
        // Mock the swapRouter call
        vm.mockCall(
            address(swapRouter),
            abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector),
            abi.encode(1 ether) // Return 1 WETH for the swap
        );

        // Set the user as the sender
        vm.startPrank(user);

        // Approve the swap contract to spend user's tokens
        mockERC20.approve(address(tokenSwap), 100 ether);

        // Log initial balances
        console.log("Initial user balance:", mockERC20.balanceOf(user));
        console.log("Initial tokenSwap balance:", mockERC20.balanceOf(address(tokenSwap)));

        // Perform the swap
        uint256 amountOut = tokenSwap.swapExactInputSingle(address(mockERC20), 100 ether);

        // Log results
        console.log("Amount out:", amountOut);
        console.log("Final user balance:", mockERC20.balanceOf(address(tokenSwap)));
        console.log("Final tokenSwap balance:", mockERC20.balanceOf(address(tokenSwap)));

        // Assertions to validate results
        assertGt(amountOut, 0, "Amount out should be greater than zero");
        assertEq(mockERC20.balanceOf(user), 900 ether, "User's token balance should decrease by 100 MTK");

        vm.stopPrank();
    }
}
