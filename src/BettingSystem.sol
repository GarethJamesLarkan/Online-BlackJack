// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// TODO: Add penalties for recording incorrect results
contract BettingSystem is Ownable2Step {

    enum Offer_State {
        BETTING, 
        PENDING_RESOLVE,
        RESOLVED
    }

    enum Offer_Result {
        PENDING,
        SUCCESS,
        FAIL
    }

    address public treasury;
    address public rewardsModule;
    address public nftContract;

    uint256 public totalsOffers;
    uint256 public totalsBets;
    uint256 public constant SCALE = 10_000;
    uint256 public constant ODDS_MULITPLIER = 100;

    mapping(uint256 offerId => OfferDetails) public offers;
    mapping(uint256 betId => Bet) public bets;

    struct EventStructure {
        uint256 timestampOfStartDate;
        bytes eventDescription;
    }

    // Make sure creator can withdraw any liquidity that wasnt bet
    struct OfferDetails {
        uint256 offerId;
        uint256 odds;
        uint256 maxLiquidityAllowed;
        uint256 minimumBetAllowed;
        uint256 totalValueBetted;
        uint256 maxBetValueAllowed;
        address creator;
        IERC20 token;
        EventStructure eventDetails;
        Offer_State offerState;
        bool outcome;
    }

    struct Bet {
        uint256 betId;
        uint256 offerId;
        uint256 betValue;
        address bettor;
    }

    event OfferCreated(uint256 indexed offerId, uint256 odds, uint256 maxLiquidityAllowed, uint256 minimumBetAllowed, address creator, EventStructure eventDetails);
    event DisputedBet(uint256 indexed betId, uint256 indexed offerId);

    //constructor
    constructor (address _treasury, address _rewardsModule, address _nftContract) Ownable(msg.sender) {
        require(_treasury != address(0), "Invalid treasury address");
        require(_rewardsModule != address(0), "Invalid rewards module address");
        require(_nftContract != address(0), "Invalid NFT contract address");

        treasury = _treasury;
        rewardsModule = _rewardsModule;
        nftContract = _nftContract;
    }

    //create bet
    function createOffer(uint256 _odds, uint256 _maxLiquidityAllowed, uint256 _minimumBetAllowed, address _tokenAddress, EventStructure memory _eventDetails) external {
        require(_odds > 100, "Invalid odds");
        require(_maxLiquidityAllowed > 0, "Invalid max liquidity allowed");
        require(_minimumBetAllowed > 0, "Invalid minimum bet allowed");
        require(_eventDetails.timestampOfStartDate > block.timestamp, "Invalid event date");
        require(bytes(_eventDetails.eventDescription).length > 0, "Invalid event description");

        totalsOffers++;

        OfferDetails storage offer = offers[totalsOffers];
        offer.offerId = totalsOffers;
        offer.odds = _odds;
        offer.maxLiquidityAllowed = _maxLiquidityAllowed;
        offer.minimumBetAllowed = _minimumBetAllowed;
        offer.token = IERC20(_tokenAddress);
        offer.eventDetails = _eventDetails;
        offer.creator = msg.sender;
        offer.maxBetValueAllowed = _maxLiquidityAllowed * ODDS_MULITPLIER / _odds;

        offer.token.transferFrom(msg.sender, address(this), _maxLiquidityAllowed);

        emit OfferCreated(offer.offerId, offer.odds, offer.maxLiquidityAllowed, offer.minimumBetAllowed, offer.creator, offer.eventDetails);
    }

    //place bet
    function placeBet(uint256 _offerId, uint256 _betValue) external {
        require(_offerId > 0, "Invalid offer id");
        require(_betValue > 0, "Invalid bet value");

        OfferDetails storage offer = offers[_offerId];
        require(_betValue >= offer.minimumBetAllowed, "Bet value is below minimum allowed");
        require(offer.offerState == Offer_State.BETTING, "Offer not in betting state");
        require(block.timestamp < offer.eventDetails.timestampOfStartDate, "Event already started");
        require(offer.totalValueBetted + _betValue <= offer.maxBetValueAllowed, "Bet value exceeds max betting value allowed");
        require(msg.sender != offer.creator, "Cannot be offer creator");

        totalsBets++;
        bets[totalsBets] = Bet(totalsBets, _offerId, _betValue, msg.sender);

        offer.totalValueBetted += _betValue;
        offer.token.transferFrom(msg.sender, address(this), _betValue);
    }

    function resolveOffer(uint256 _offerId, bool _outcome) external onlyOwner {
        require()
        OfferDetails storage offer = offers[_offerId];
        //resolve bet
        offer.offerState = Offer_State.RESOLVED;
        offer.outcome = _outcome;

    }

    //withdraw winnings 
}