pragma solidity 0.8.22;

import "../TestSetup.sol";

contract BettingSystemTests is TestSetup {

    function setUp() public {
        setUpTests();
        vm.prank(owner);
        testUSDCContract.mint();

        vm.prank(alice);
        testUSDCContract.mint();
    }

    function test_Constructor_Works() public {
        assertEq(address(bettingSystemContract.treasury()), address(treasuryContract));
        assertEq(address(bettingSystemContract.rewardsModule()), address(rewardModuleContract));
        assertEq(address(bettingSystemContract.nftContract()), address(rewardNftContract));
    }

    function test_Create_Offer_Fails_If_Invalid_Odds() public {
        BettingSystem.EventStructure memory _eventDetails = BettingSystem.EventStructure({
            timestampOfStartDate: block.timestamp + 4 days,
            eventDescription: "Liverpool will beat Manchester United"
        });

        vm.startPrank(owner); 
        testUSDCContract.approve(address(bettingSystemContract), 20 ether);  
        vm.expectRevert("Invalid odds");
        bettingSystemContract.createOffer(99, 20 ether, 0.01 ether, address(testUSDCContract), _eventDetails);
    }

    function test_Create_Offer_Fails_If_Invalid_Max_Liquidity_Allowed() public {
        BettingSystem.EventStructure memory _eventDetails = BettingSystem.EventStructure({
            timestampOfStartDate: block.timestamp + 4 days,
            eventDescription: "Liverpool will beat Manchester United"
        });

        vm.startPrank(owner); 
        testUSDCContract.approve(address(bettingSystemContract), 0);  
        vm.expectRevert("Invalid max liquidity allowed");
        bettingSystemContract.createOffer(178, 0, 0.01 ether, address(testUSDCContract), _eventDetails);
    }

    function test_Create_Offer_Fails_If_Invalid_Minimum_Bet_Allowed() public {
        BettingSystem.EventStructure memory _eventDetails = BettingSystem.EventStructure({
            timestampOfStartDate: block.timestamp + 4 days,
            eventDescription: "Liverpool will beat Manchester United"
        });

        vm.startPrank(owner); 
        testUSDCContract.approve(address(bettingSystemContract), 20 ether);  
        vm.expectRevert("Invalid minimum bet allowed");
        bettingSystemContract.createOffer(178, 20 ether, 0, address(testUSDCContract), _eventDetails);
    }

    function test_Create_Offer_Fails_If_Invalid_Event_Date() public {
        BettingSystem.EventStructure memory _eventDetails = BettingSystem.EventStructure({
            timestampOfStartDate: block.timestamp,
            eventDescription: "Liverpool will beat Manchester United"
        });

        vm.startPrank(owner); 
        testUSDCContract.approve(address(bettingSystemContract), 20 ether);  
        vm.expectRevert("Invalid event date");
        bettingSystemContract.createOffer(178, 20 ether, 0.01 ether, address(testUSDCContract), _eventDetails);
    }

    function test_Create_Offer_Fails_If_Invalid_Event_Description() public {
        BettingSystem.EventStructure memory _eventDetails = BettingSystem.EventStructure({
            timestampOfStartDate: block.timestamp + 4 days,
            eventDescription: ""
        });

        vm.startPrank(owner); 
        testUSDCContract.approve(address(bettingSystemContract), 20 ether);  
        vm.expectRevert("Invalid event description");
        bettingSystemContract.createOffer(178, 20 ether, 0.01 ether, address(testUSDCContract), _eventDetails);
    }

    function test_Create_Offer_Works() public {
        BettingSystem.EventStructure memory _eventDetails = BettingSystem.EventStructure({
            timestampOfStartDate: block.timestamp + 4 days,
            eventDescription: "Liverpool will beat Manchester United"
        });

        assertEq(testUSDCContract.balanceOf(owner), 100_000_000 ether);
        assertEq(testUSDCContract.balanceOf(address(bettingSystemContract)), 0);
        assertEq(bettingSystemContract.totalsOffers(), 0);
    
        vm.startPrank(owner); 
        testUSDCContract.approve(address(bettingSystemContract), 20 ether);  
        bettingSystemContract.createOffer(178, 20 ether, 0.01 ether, address(testUSDCContract), _eventDetails);

        assertEq(testUSDCContract.balanceOf(owner), 100_000_000 ether - 20 ether);
        assertEq(testUSDCContract.balanceOf(address(bettingSystemContract)), 20 ether);
        assertEq(bettingSystemContract.totalsOffers(), 1);
    }

    function test_Place_Bet_Fails_If_Invalid_Offer_Id() public {
        createSingleOffer();

        vm.startPrank(alice);
        testUSDCContract.approve(address(bettingSystemContract), 5 ether);
        vm.expectRevert("Invalid offer id");
        bettingSystemContract.placeBet(0, 5 ether);
    }

    function test_Place_Bet_Fails_If_Invalid_Bet_Value() public {
        createSingleOffer();

        vm.startPrank(alice);
        testUSDCContract.approve(address(bettingSystemContract), 5 ether);
        vm.expectRevert("Invalid bet value");
        bettingSystemContract.placeBet(1, 0);
    }

    function test_Place_Bet_Fails_If_Bet_Value_Below_Minimum_Allowed() public {
        createSingleOffer();

        vm.startPrank(alice);
        testUSDCContract.approve(address(bettingSystemContract), 5 ether);
        vm.expectRevert("Bet value is below minimum allowed");
        bettingSystemContract.placeBet(1, 0.001 ether);
    }

    function test_Place_Bet_Fails_If_Event_Already_Started() public {
        createSingleOffer();

        vm.warp(block.timestamp + 5 days);
        vm.startPrank(alice);
        testUSDCContract.approve(address(bettingSystemContract), 5 ether);
        vm.expectRevert("Event already started");
        bettingSystemContract.placeBet(1, 5 ether);
    }

    function test_Place_Bet_Fails_If_Offer_Already_Resolved() public {
        createSingleOffer();

        vm.startPrank(owner);
        bettingSystemContract.resolveOffer(1, true);

        vm.startPrank(alice);
        testUSDCContract.approve(address(bettingSystemContract), 5 ether);
        vm.expectRevert("Offer not in betting state");
        bettingSystemContract.placeBet(1, 5 ether);
    }

    function test_Place_Bet_Fails_If_Bet_Value_Exceeds_Max_Betting_Value_Allowed() public {
        createSingleOffer();

        vm.startPrank(alice);
        testUSDCContract.approve(address(bettingSystemContract), 12 ether);
        vm.expectRevert("Bet value exceeds max betting value allowed");
        bettingSystemContract.placeBet(1, 12 ether);
    }

    function test_Place_Bet_Works() public {
        createSingleOffer();

        assertEq(testUSDCContract.balanceOf(alice), 100_000_000 ether);
        assertEq(testUSDCContract.balanceOf(address(bettingSystemContract)), 20 ether);
        assertEq(bettingSystemContract.totalsBets(), 0);

        (,,,, uint256 totalValueBetted,,,,,,) = bettingSystemContract.offers(1);
        assertEq(totalValueBetted, 0);

        vm.startPrank(alice);
        testUSDCContract.approve(address(bettingSystemContract), 5 ether);
        bettingSystemContract.placeBet(1, 5 ether);

        (uint256 betId, uint256 offerId, uint256 betValue, address bettor) = bettingSystemContract.bets(1);

        assertEq(betId, 1);
        assertEq(offerId, 1);
        assertEq(betValue, 5 ether);
        assertEq(bettor, alice);

        assertEq(testUSDCContract.balanceOf(alice), 100_000_000 ether - 5 ether);
        assertEq(testUSDCContract.balanceOf(address(bettingSystemContract)), 25 ether);
        assertEq(bettingSystemContract.totalsBets(), 1);

        (,,,, totalValueBetted,,,,,,) = bettingSystemContract.offers(1);
        assertEq(totalValueBetted, 5 ether);
    }

    function createSingleOffer() internal {
        BettingSystem.EventStructure memory _eventDetails = BettingSystem.EventStructure({
            timestampOfStartDate: block.timestamp + 4 days,
            eventDescription: "Liverpool will beat Manchester United"
        });

        vm.startPrank(owner); 
        testUSDCContract.approve(address(bettingSystemContract), 20 ether);  
        bettingSystemContract.createOffer(178, 20 ether, 0.01 ether, address(testUSDCContract), _eventDetails);
        vm.stopPrank();
    }
}