// File contracts/ABCTreasury.sol

pragma solidity ^0.8.0;

import "./helpers/ReentrancyGuard.sol";
import "./interfaces/IERC20.sol";

/// @author Medici
/// @title Treasury contract for Abacus
contract ABCTreasury is  ReentrancyGuard {

    /* ======== UINT ======== */

    uint public nftsPriced;
    uint public profitGenerated;
    uint public tokensClaimed;
    uint public riskFactor;
    uint public spread;
    uint public defender;
    uint public commissionRate;
    uint public payoutMultiplier;

    /* ======== BOOL ======== */

    bool public tokenStatus;
    bool public auctionStatus;

    /* ======== ADDRESS ======== */

    address public auction;
    address public pricingSession;
    address public admin;
    address public ABCToken;
    address public multisig;
    address public creditStore;

    /* ======== EVENTS ======== */

    event ethClaimedByUser(address user_, uint ethClaimed);
    event ethToABCExchange(address user_, uint ethExchanged, uint ppSent);

    /* ======== CONSTRUCTOR ======== */

    constructor(address _creditStore) {
        admin = msg.sender;
        creditStore = _creditStore;
        auctionStatus = true;
        riskFactor = 2;
        spread = 10;
        defender = 2;
        commissionRate = 500;
        payoutMultiplier = 200;
    }

    /* ======== ADMIN FUNCTIONS ======== */

    /// @notice set the auction status based on the active/inactive status of the bounty auction
    /// @param status desired auction status to be stored and referenced in contract
    function setAuctionStatus(bool status) onlyAdmin external {
        auctionStatus = status;
    }

    /// @notice set the auction status based on the active/inactive status of the bounty auction
    /// @param _commissionRate desired commission percentage the protocol would like to take
    function setCommissionRate(uint _commissionRate) onlyAdmin external {
        commissionRate = _commissionRate;
    }

    function setPayoutMultiplier(uint _multiplier) onlyAdmin external {
        payoutMultiplier = _multiplier;
    }

    /// @notice set protocol risk factor
    /// @param _risk the protocol risk factor is a multiplier applied to any losses harvested
    function setRiskFactor(uint _risk) onlyAdmin external {
        riskFactor = _risk;
    }

    /// @notice set the protocol spread
    /// @param _spread the protocol spread is the margin of error that correctness is based on
    function setSpread(uint _spread) onlyAdmin external {
        spread = _spread;
    }

    /// @notice set the protocol defender level
    /** @dev the defender is used to determined the amount of
    recursive bound exclusions enforced per session.

    For example, in times of a high volume of extreme value attacks,
    the community can set the defender to level 3 in which case every session
    will have the _boundCheck happen 3 times. What this means is there will be
    one bound check, the final appraisal will be adjusted, then a second check,
    final appraisal will be re-adjusted, then a third, and final appraisal will
    be adjusted one final time.

    Any values that are removed result in removal from final appraisal affect
    AND their stake is completely lost.
    */
    /// @param _defender the defender is a value that determines the amount of recursive bound exclusions enforced per session
    function setDefender(uint _defender) onlyAdmin external {
        defender = _defender;
    }

    /// @notice set ABC token contract address
    /// @param _ABCToken desired ABC token to be stored and referenced in contract
    function setABCTokenAddress(address _ABCToken) onlyAdmin external {
        ABCToken = _ABCToken;
    }

    function setMultisig(address _multisig) onlyAdmin external {
        multisig = _multisig;
    }

    /// @notice allow admin to withdraw funds to multisig in the case of emergency (ONLY USED IN THE CASE OF EMERGENCY)
    /// @param _amountEth value of ETH to be withdrawn from the treasury to multisig (ONLY USED IN THE CASE OF EMERGENCY)
    function withdrawEth(uint _amountEth) onlyAdmin external {
        (bool sent, ) = payable(multisig).call{value: _amountEth}("");
        require(sent, "Failed to send Ether");
    }

    /// @notice allow admin to withdraw funds to multisig in the case of emergency (ONLY USED IN THE CASE OF EMERGENCY)
    /// @param _amountAbc value of ABC to be withdrawn from the treasury to multisig (ONLY USED IN THE CASE OF EMERGENCY)
    function withdrawAbc(uint _amountAbc) onlyAdmin external {
        bool sent = IERC20(ABCToken).transfer(multisig, _amountAbc);
        require(sent);
    }

    /// @notice set newAdmin (or burn admin when the time comes)
    /// @param _newAdmin desired admin address to be stored and referenced in contract
    function setAdmin(address _newAdmin) onlyAdmin external {
        admin = _newAdmin;
    }

    /// @notice set pricing factory address to allow for updates
    /// @param _pricingFactory desired pricing session principle address to be stored and referenced in contract
    function setPricingSession(address _pricingFactory) onlyAdmin external {
        pricingSession = _pricingFactory;
    }

    /// @notice set auction contract for bounty auction period
    /// @param _auction desired auction address to be stored and referenced in contract
    function setAuction(address _auction) onlyAdmin external {
        auction = _auction;
    }

    function setCreditStore(address _creditStore) onlyAdmin external {
        creditStore = _creditStore;
    }

    /* ======== CHILD FUNCTIONS ======== */

    /// @notice send ABC to users that earn
    /// @param recipient the user that will be receiving ABC
    /// @param _amount the amount of ABC to be transferred to the recipient
    function sendABCToken(address recipient, uint _amount) public {
        require(msg.sender == creditStore || msg.sender == admin);
        if(msg.sender == creditStore) {
            IERC20(ABCToken).transfer(recipient, payoutMultiplier * _amount / 100);
        }
        else {
            IERC20(ABCToken).transfer(recipient, _amount);
        }
    }

    /// @notice track amount of nfts priced
    function updateNftPriced() isFactory external {
        nftsPriced++;
    }

    /// @notice track total profits generated by the protocol through fees
    function updateTotalProfitsGenerated(uint _amount) isFactory external {
        profitGenerated += _amount;
    }

    /* ======== FALLBACKS ======== */

    receive() external payable {}
    fallback() external payable {}

    /* ======== MODIFIERS ======== */

    ///@notice check that msg.sender is admin
    modifier onlyAdmin() {
        require(admin == msg.sender, "not admin");
        _;
    }

    ///@notice check that msg.sender is factory
    modifier isFactory() {
        require(msg.sender == pricingSession, "not session contract");
        _;
    }

    ///@notice check that msg.sender is factory
    modifier isCreditStore() {
        require(msg.sender == creditStore, "not credit store contract");
        _;
    }
}