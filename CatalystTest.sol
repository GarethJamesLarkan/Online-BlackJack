// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC1155SupplyUpgradeable } from
  "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import { UUPSUpgradeable } from
  "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from
  "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from
  "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IIPSeedCurve, TradeType } from "./curves/IIPSeedCurve.sol";
import { IIPSeedMetadataRenderer } from "./IPSeedMetadataRenderer.sol";
import { IPSeedTrust } from "./IPSeedTrust.sol";

uint16 constant BASIS_POINTS = 10000;

enum MarketState {
  //waiting for contributions, users can buy tokens and exit at any time, only sourcer can transfer tokens
  OPEN,
  //either market has not reached the funding goal in time or negotiation period has passed, tokens are transferable, users can claim their collateral. Fees are claimable by the protocol owner.
  EXPIRED,
  //funding goal has been reached, negotiation period starts, collateral is locked, tokens transferable
  FUNDED,
  //collateral has been claimed by the beneficiary, there is no collateral on the market anymore, tokens are transferable, can be transitioned to EXPIRED by the beneficiary
  CLAIMED,
  //set manually by the beneficiary. the fundraise was ultimately successful and the project (externally) has been converted to an asset (eg an IPT). Fees become claimable by the sourcer.
  SUCCEEDED
}

/// the initial market parameters that are required to spawn a new market
struct MarketParameters {
  /// a precomputed token id (keccak(sourcer,projectId))
  uint256 tokenId;
  /// an external location to lookup project metadata (eg a ceramic stream, ipfs hash, url, should be prefixed with a resolveable schema, eg ipfs://, ceramic://, catalyst-mainnet://)
  string projectId;
  /// the account that manages the project. Must be signer on the beneficiary wallet
  address sourcer;
  /// a multisig between protocolTrustee & sourcer that will receive the collected funds
  address payable beneficiary;
  /// the market price curve that determines token prices at a given supply
  IIPSeedCurve priceCurve;
  /// depends on priceCurve implementation and must be precomputed by the client using the funding goal *including* fees
  bytes32 curveParameters;
  // funding goal in Eth, *including* lp provisioning margin
  uint128 fundingGoal;
  // the amount of tokens that are preminted for the beneficiary when the market is spawned
  uint128 premint;
  // block.timestamp for the market to close
  uint64 deadline;
}

/// the dynamic market state that's updated during the market's lifecycle
struct MarketData {
  MarketState state;
  // currently collected eth amount, *including* the fees
  uint256 collateral;
  // block.timestamp for the negotiation period after the funding deadline
  uint64 negotiationDeadline;
  // the amount of collateral that has accrued (including fees) during the funding period
  uint256 accruedCapital;
  // the `beneficiary` can decide to return not the funding goal when negotiation fails
  uint256 returnedCollateral;
  // 2[L-02] tracks the amount of the ratio of accrued capital that has been refunded
  uint256 refundedVsAccruedCapital;
  // tallies all fees that are collected during market trades. Will be claimable either by the sourcer or the protocol owner, depending on the market's outcome
  uint256 collectedFees;
  // once the market closes, this will indicate the final token supply that has been minted. Useful to calculate holders share ratios when others burn their tokens
  uint256 finalSupply;
}

error UnauthorizedAccess(); //0x344fd586
error TokenAlreadyExists(); //0xc991cbb1
error InvalidTokenId(); //0x3f6cc768
error TradeSizeOutOfRange(); //36a518e4
error InsufficientPayment(); //0xcd1c8867
error BalanceTooLow(); // 0xa3281672
error BadState(MarketState expected, MarketState actual); //0x39863a6a
error TransferRestricted(); //0x2b05a2f2
error PriceDriftTooHigh();
error DeadlineExpired();

/**
 * @title IPSeed V3.1
 * @author molecule.xyz
 * @notice IP seeds are ERC1155 tokens that are traded along a bonding curve and represent governance and interest signals for a preliminary piece of IP.
 * @dev this contract is upgradeable in order to be able to add new features in the future
 * @custom:security-contact info@molecule.to
 */
contract IPSeed is
  ERC1155SupplyUpgradeable,
  UUPSUpgradeable,
  OwnableUpgradeable,
  ReentrancyGuardUpgradeable
{
  IIPSeedMetadataRenderer internal metadataRenderer;

  /// @notice manages certain trust aspects of privileged accounts
  IPSeedTrust public trustContract;

  // tokenId => market configuration parameters
  mapping(uint256 => MarketParameters) internal marketParams;

  // tokenId => market data / state
  mapping(uint256 => MarketData) internal markets;

  // tokenId => user => contributed eth amount (including fees)
  mapping(uint256 => mapping(address => uint256)) public contributions;

  event Spawned(
    uint256 indexed tokenId,
    address indexed sourcer,
    uint256 netFundingGoal,
    MarketParameters marketParameters
  );

  event Traded(
    uint256 indexed tokenId,
    address indexed trader,
    TradeType indexed tradeType,
    uint256 tokenAmount,
    uint256 ethAmount,
    uint256 newSupply,
    uint256 tradingFee
  );

  event FundingGoalReached(uint256 indexed tokenId);
  event ClaimedCollateral(
    uint256 indexed tokenId, address indexed beneficiary, uint256 claimedAmount
  );
  event Expired(
    uint256 indexed tokenId,
    address indexed feeRecipient,
    uint256 claimableCapital,
    uint256 collectedFees
  );

  event Succeeded(
    uint256 indexed tokenId,
    address indexed feeRecipient,
    IERC20 indexed iptAddress,
    uint256 paidOutFees
  );

  event NegotiationDeadlineExtended(uint256 indexed tokenId, uint64 newDeadline);

  event ContributionTransferred(
    uint256 indexed tokenId, address indexed from, address indexed to, uint256 amount
  );

  event TrustContractUpdated(IPSeedTrust newTrustContract);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize()
    public
    initializer
  {
    __UUPSUpgradeable_init();
    __Ownable_init(_msgSender());
    __ReentrancyGuard_init();
    __ERC1155_init("");
  }

  modifier onlyBeneficiary(uint256 tokenId) {
    if (_msgSender() != marketParams[tokenId].beneficiary) {
      revert UnauthorizedAccess();
    }
    _;
  }

  function setIPSeedTrust(IPSeedTrust _trustContract) external onlyOwner {
    trustContract = _trustContract;
    emit TrustContractUpdated(_trustContract);
  }

  /**
   * @notice computes the token id for a given sourcer and project id (a ceramic stream)
   */
  function computeTokenId(address sourcer, string memory projectId) public pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(sourcer, projectId)));
  }

  /**
   * @notice returns the current market state and collateral
   */
  function getMarketData(uint256 tokenId) external view returns (MarketData memory) {
    return markets[tokenId];
  }

  /**
   * @notice returns the market's spawn parameters / metadata
   */
  function getMarketParams(uint256 tokenId) external view returns (MarketParameters memory) {
    return marketParams[tokenId];
  }

  /**
   * @notice anchors a new token id on the contract. Verifies curve parameters. Premints tokens
   * @param params MetadataParams
   */
    function spawn(
        uint256 _tokenId,
        string memory _projectId,
        address _sourcer,
        address payable _beneficiary,
        IIPSeedCurve _priceCurve,
        bytes32 _curveParameters,
        uint128 _fundingGoal,
        uint128 _premint,
        uint64 _deadline
    ) external nonReentrant {
    
    MarketParameters memory params = MarketParameters({
        tokenId: _tokenId,
        projectId: _projectId,
        sourcer: _sourcer,
        beneficiary: _beneficiary,
        priceCurve: _priceCurve,
        curveParameters: _curveParamters,
        fundingGoal: _fundingGoal,
        premint: _premint,
        deadline: _deadline
    });

    if (
      bytes(params.projectId).length < 10
        || params.tokenId != computeTokenId(_msgSender(), params.projectId)
    ) {
      revert InvalidTokenId();
    }

    // ERC1155's `exists` function checks for totalSupply > 0, which is not what we want here
    if (bytes(marketParams[params.tokenId].projectId).length > 0) {
      revert TokenAlreadyExists();
    }

    marketParams[params.tokenId] = params;

    markets[params.tokenId] = MarketData({
      state: MarketState.OPEN,
      collateral: 0,
      negotiationDeadline: 0,
      accruedCapital: 0,
      returnedCollateral: 0,
      refundedVsAccruedCapital: 0,
      collectedFees: 0,
      finalSupply: 0
    });

    emit Spawned(params.tokenId, params.sourcer, params.fundingGoal, params);
    _mint(params.beneficiary, params.tokenId, params.premint, "");
  }

  /**
   * @notice buy tokens on the token's bonding curve. To finalize the fundraise users can send more ETH than required, the surplus will be reimbursed
   * @param tokenId token id
   * @param minTokenAmount the minimum amount of tokens to buy. Don't rely on values quoted by `getBuyPrice`
   */
  function mint(uint256 tokenId, uint256 minTokenAmount)
    external
    payable
    nonReentrant
    returns (uint256 utilizedAmount, uint256 tokensToMint)
  {
    MarketData storage market = markets[tokenId];
    if (market.state != MarketState.OPEN) {
      revert BadState(MarketState.OPEN, market.state);
    }

    MarketParameters memory _marketParams = marketParams[tokenId];

    if (trySettle(tokenId) > MarketState.OPEN) {
      //this allows settling the market implicitly without reverting
      Address.sendValue(payable(_msgSender()), msg.value);
      return (0, 0);
    }

    uint256 reimburse = 0;

    (tokensToMint, utilizedAmount, reimburse) = quoteTokensForEth(tokenId, msg.value);

    if (utilizedAmount > msg.value) {
      revert InsufficientPayment();
    }

    if (tokensToMint == 0) {
      //it's okay to not yield any tokens when this is a terminal closing trade
      if (market.collateral + utilizedAmount < _marketParams.fundingGoal) {
        revert TradeSizeOutOfRange();
      }
    }

    if (tokensToMint < minTokenAmount) {
      revert PriceDriftTooHigh();
    }

    contributions[tokenId][_msgSender()] += utilizedAmount;
    market.collateral += utilizedAmount;

    //the > is actually not needed but puts us on the safe side.
    if (market.collateral >= _marketParams.fundingGoal) {
      market.state = MarketState.FUNDED;
      //the default negotiation deadline lasts 12 weeks and starts when the market funding goal is reached
      market.negotiationDeadline = uint64(block.timestamp + 12 weeks);
      market.accruedCapital = market.collateral;
      market.finalSupply = totalSupply(tokenId) + tokensToMint;
      emit FundingGoalReached(tokenId);
      emit NegotiationDeadlineExtended(tokenId, market.negotiationDeadline);
    }

    _mint(_msgSender(), tokenId, tokensToMint, "");
    //refund surplus; that might help against frontrunners blocking trades by pushing the price up only by a tiny bit
    //refunds the little overshoot when hitting the funding goal for the last contributor
    if (reimburse > 0) {
      Address.sendValue(payable(_msgSender()), reimburse);
    }
    emit Traded(
      tokenId, _msgSender(), TradeType.Buy, tokensToMint, utilizedAmount, totalSupply(tokenId), 0
    );
  }

  /**
   * @notice burns the user's tokens and refunds the collateral.
   * @notice taxes an exit fee on OPEN markets that's collected by the beneficiary or protocol owner
   *
   * @param tokenId the token id
   */
  function exit(uint256 tokenId) external nonReentrant {
    uint256 tokenBalance = balanceOf(_msgSender(), tokenId);
    uint256 payout;
    uint256 paidFee;

    MarketState marketState = trySettle(tokenId);
    if (marketState > MarketState.EXPIRED) {
      revert BadState(MarketState.OPEN, marketState);
    }

    if (tokenBalance > 0) {
      _burn(_msgSender(), tokenId, tokenBalance);
    }
    (payout, paidFee) = refund(tokenId, _msgSender());

    emit Traded(
      tokenId, _msgSender(), TradeType.Exit, tokenBalance, payout, totalSupply(tokenId), paidFee
    );
  }

  /**
   * @notice a soft governance decision may decide to postpone the decision making process' deadline at any time as often as they wish
   * @param tokenId token id
   * @param newDeadline the new deadline's unix timestamp
   */
  function extendNegotiationDeadline(uint256 tokenId, uint64 newDeadline)
    external
    onlyBeneficiary(tokenId)
  {
    MarketState state = markets[tokenId].state;
    if (state < MarketState.FUNDED) {
      revert BadState(MarketState.FUNDED, state);
    }
    markets[tokenId].negotiationDeadline = newDeadline;
    emit NegotiationDeadlineExtended(tokenId, newDeadline);
  }

  /**
   * @notice called by the market's beneficiary multisig to withdraw a funded market's collateral
   * @param tokenId token id
   */
  function claimCollateral(uint256 tokenId) public onlyBeneficiary(tokenId) {
    MarketData storage market = markets[tokenId];
    if (market.state != MarketState.FUNDED) {
      revert BadState(MarketState.FUNDED, market.state);
    }

    if (block.timestamp > market.negotiationDeadline) {
      revert DeadlineExpired();
    }

    //it'd be better to claim only the net funding goal now, but not the extra margin for lp, but right now we're sending everything to the beneficiary
    uint256 claimableCapital = market.collateral;

    market.state = MarketState.CLAIMED;
    market.collateral = 0;

    //@dev _msgSender() == beneficiary, see modifier but this allows us to detect unwanted behavior more easily
    emit ClaimedCollateral(tokenId, _msgSender(), claimableCapital);
    Address.sendValue(marketParams[tokenId].beneficiary, claimableCapital);
  }

  /**
   * @notice the beneficiary decided to claim market collateral before, eg to convert it into a non volatile asset.
   *         This function allows the beneficiary to return an arbitrary amount (ideally the original funding goal) so participants can exit their contribution prorata.
   *         This also sets the market state to EXPIRED so participants can exit their contribution.
   * @param tokenId token id
   */
  function negotiationFailed(uint256 tokenId)
    external
    payable
    nonReentrant
    onlyBeneficiary(tokenId)
  {
    MarketData storage market = markets[tokenId];
    if (market.state < MarketState.FUNDED || market.state == MarketState.SUCCEEDED) {
      revert BadState(MarketState.FUNDED, market.state);
    }

    //anything lower than the funding goal is bad, but 0 is certainly an error.
    if (msg.value == 0 && market.state == MarketState.CLAIMED) {
      revert InsufficientPayment();
    }

    //in case any collateral had been leftover earlier, this would add everyhing up
    expireMarket(tokenId, market.collateral + msg.value);
  }

  /**
   * @notice called by the beneficiary to signal that the project has been successfully converted into an asset.
   *         pays out the collected exit fees to the beneficiary
   * @param tokenId the token id
   * @param ipToken the token that's going to be distributed (airdropped) among seed holders
   */
  function projectSucceeded(uint256 tokenId, IERC20 ipToken)
    external
    nonReentrant
    onlyBeneficiary(tokenId)
  {
    if (markets[tokenId].state == MarketState.FUNDED) {
      //side effect: can expire the market when the negotiation deadline has passed
      //side effect: modifies the market state to CLAIMED when successful
      claimCollateral(tokenId);
    }

    if (markets[tokenId].state != MarketState.CLAIMED) {
      revert BadState(MarketState.CLAIMED, markets[tokenId].state);
    }

    //also send the collected exit fees to the beneficiary
    uint256 collectedFees = markets[tokenId].collectedFees;
    markets[tokenId].collectedFees = 0;
    markets[tokenId].state = MarketState.SUCCEEDED;

    emit Succeeded(tokenId, marketParams[tokenId].beneficiary, ipToken, collectedFees);
    Address.sendValue(payable(marketParams[tokenId].beneficiary), collectedFees);
  }

  /**
   * @notice allows anyone to transition the market to the next state without relying on implicitly calling it through mints or burns
   * @param tokenId the token id
   */
  function settle(uint256 tokenId) external nonReentrant returns (MarketState state) {
    return trySettle(tokenId);
  }

  /**
   * @notice computes how many tokens a user will receive for a given amount of ETH
   * @param tokenId the token id
   * @param ethValue the amount of ETH that's sent to the contract
   * @return tokenAmount the amount of tokens that will be minted
   * @return utilizedAmount the amount of ETH that's actually collateralized (lower than ethValue greater when adding ethValue would exceed funding goal)
   * @return reimburse the amount of unused ETH and would be returned to the sender
   */
  function quoteTokensForEth(uint256 tokenId, uint256 ethValue)
    public
    view
    returns (uint256 tokenAmount, uint256 utilizedAmount, uint256 reimburse)
  {
    MarketParameters memory _marketParams = marketParams[tokenId];
    uint256 currentCollateral = markets[tokenId].collateral;
    reimburse = 0;

    //check whether this mint can close the market. If so, surplus eth is reimbursed at the end.
    if (currentCollateral + ethValue > _marketParams.fundingGoal) {
      utilizedAmount = _marketParams.fundingGoal - currentCollateral;
      reimburse = ethValue - utilizedAmount;
    } else {
      utilizedAmount = ethValue;
    }

    //this will also "remint the premint" if necessary
    tokenAmount = _marketParams.priceCurve.getTokensNeededToAddEthValue(
      totalSupply(tokenId), utilizedAmount, _marketParams.curveParameters
    );
  }

  /**
   * @notice returns an approximate Eth price to buy `tokenAmount` of tokens.
   *         don't rely on this for exact calculations, use `quoteTokensForEth` instead
   *
   * @return ethValue the amount of ETH that's collateralized when tokens are bought
   */
  function getBuyPrice(uint256 tokenId, uint256 tokenAmount)
    external
    view
    returns (uint256 ethValue)
  {
    MarketParameters memory params = marketParams[tokenId];
    ethValue =
      params.priceCurve.getBuyPrice(totalSupply(tokenId), tokenAmount, params.curveParameters);
  }

  /**
   * @dev the total amount of collateral that's currently locked on token id's bonding curve
   *      this includes the fee on MarktParams.fundingGoal and can just be the the fee value if the beneficiary has claimed the net funding goal
   */
  function collateral(uint256 tokenId) external view returns (uint256) {
    return markets[tokenId].collateral;
  }

  /**
   * @dev the spawn function & curve params requires you to provide the funding goal *including* lp fees.
   *      you can use this function (or do this calculation offchain) to compute the funding goal including fees at the rate that's defined by the trustContract
   * @param netFundingGoal the funding goal you want to achieve *without* fees
   */
  function computeFundingGoalWithFees(uint256 netFundingGoal) external view returns (uint256) {
    return (netFundingGoal * (BASIS_POINTS + trustContract.protocolLPFee()) / BASIS_POINTS);
  }

  /**
   * @notice computes the remaining Eth required to reach the funding goal
   * @param tokenId the tokenid
   *
   * @return amount the total amount of Eth that's required to reach the funding goal including fees
   */
  function getRemainingCapital(uint256 tokenId) external view returns (uint256 amount) {
    return marketParams[tokenId].fundingGoal - markets[tokenId].collateral;
  }

  /**
   * @return the amount of exit fees that have been collected on this market
   */
  function depositedFees(uint256 tokenId) external view returns (uint256) {
    return markets[tokenId].collectedFees;
  }

  /**
   *  @notice expires the market after deadlines have been passed
   *          if the market is in CLAIMED state, the collateral has been withdrawn.
   *          In that case the beneficiary can transist back into EXPIRED by (partly) returning the collateral using `negotiationFailed`
   *          this is implicitly called by exit and mint calls
   *  @dev must be called from an reentrancy safe function since it transfers collected fees to the protocol beneficiary when expired
   *  @param tokenId the token id
   *  @return state the updated market state
   */
  function trySettle(uint256 tokenId) private returns (MarketState state) {
    MarketData storage market = markets[tokenId];
    if (
      market.state == MarketState.OPEN && block.timestamp > marketParams[tokenId].deadline
        || (
          market.state == MarketState.FUNDED && block.timestamp > markets[tokenId].negotiationDeadline
        )
    ) {
      // no one touched ("claimed") the capital, so it's immediately claimable
      market.accruedCapital = market.collateral;
      expireMarket(tokenId, market.collateral);
    }
    return market.state;
  }

  /**
   * @notice Reused for exits & refunds on expired markets.
   *
   * @param tokenId the tokenid
   * @param contributor the contributor
   */
  function refund(uint256 tokenId, address contributor)
    private
    returns (uint256 payout, uint256 tradingFee)
  {
    uint256 contribution = contributions[tokenId][contributor];
    if (contribution == 0) {
      return (0, 0);
    }

    MarketData storage market = markets[tokenId];
    if (market.state == MarketState.OPEN) {
      //on open markets users simply get their contribution back
      payout = contribution;
      tradingFee = Math.mulDiv(payout, trustContract.protocolExitFee(), BASIS_POINTS);
    } else {
      //2[L-02] the last exiter receives the remaining collateral to avoid leaving dust on the contract
      if (market.refundedVsAccruedCapital == contribution) {
        payout = market.collateral;
        market.refundedVsAccruedCapital = 0;
      } else {
        payout = Math.mulDiv(contribution, market.returnedCollateral, market.accruedCapital);
        market.refundedVsAccruedCapital -= contribution;
      }
      tradingFee = 0;
    }

    contributions[tokenId][contributor] = 0;
    market.collateral -= payout;

    if (tradingFee > 0) {
      escrowFees(tokenId, tradingFee);
    }
    payout = payout - tradingFee;
    Address.sendValue(payable(contributor), payout);
  }

  function escrowFees(uint256 tokenId, uint256 feeValue) private {
    markets[tokenId].collectedFees += feeValue;
  }

  //https://github.com/OpenZeppelin/openzeppelin-contracts/blob/8b12f83a702210cdeff862c837ffb338811c31a4/contracts/token/ERC1155/ERC1155.sol#L135
  /**
   * @inheritdoc ERC1155SupplyUpgradeable
   * @dev while a market is in funding state, tokens only transferable by the sourcer
   */
  function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
    internal
    virtual
    override
  {
    if (from != address(0) && to != address(0)) {
      uint256 transferLength = ids.length;
      for (uint256 i; i < transferLength; ++i) {
        MarketData memory market = markets[ids[i]];
        if ((market.state < MarketState.FUNDED) && from != marketParams[ids[i]].beneficiary) {
          revert TransferRestricted();
        }
        uint256 transferContribution =
          (values[i] * contributions[ids[i]][from]) / balanceOf(from, ids[i]);

        //2[M-02] revert when transfer amount is so little that the contribution would be left behind
        if (contributions[ids[i]][from] > 0 && transferContribution == 0) {
          revert TransferRestricted();
        }

        contributions[ids[i]][from] -= transferContribution;
        contributions[ids[i]][to] += transferContribution;
        emit ContributionTransferred(ids[i], from, to, transferContribution);
      }
    }
    super._update(from, to, ids, values);
  }

  /**
   * @notice expires the market (project failed) and immediately transfers the collected fees to the protocol beneficiary
   * @param tokenId token id
   * @param returnedCollateral the capital that can be claimed by the contributors (includes the implicit fees on the extended funding goal)
   */
  function expireMarket(uint256 tokenId, uint256 returnedCollateral) private {
    MarketData storage market = markets[tokenId];

    market.state = MarketState.EXPIRED;
    market.collateral = returnedCollateral;
    market.returnedCollateral = returnedCollateral;
    market.refundedVsAccruedCapital = market.accruedCapital;
    uint256 collectedFees = market.collectedFees;
    market.collectedFees = 0;

    // 2[L-02] setting the refundable capital to the originally raised amount allows calculating IPT distribution amounts

    emit Expired(tokenId, trustContract.protocolBeneficiary(), returnedCollateral, collectedFees);
    Address.sendValue(trustContract.protocolBeneficiary(), collectedFees);
  }

  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address /*newImplementation*/ )
    internal
    override
    onlyOwner // solhint-disable-next-line no-empty-blocks
  { }

  /**
   * @notice metadata of this token is stored on chain.
   * @return base64 encoded json metadata for tokenId
   */
  function uri(uint256 tokenId) public view override returns (string memory) {
    return metadataRenderer.uri(marketParams[tokenId]);
  }
}