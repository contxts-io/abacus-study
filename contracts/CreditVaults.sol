// File contracts/CreditVault.sol

pragma solidity ^0.8.0;

import './helpers/ReentrancyGuard.sol';
import './ABCTreasury.sol';


/// @author Medici
/// @title Treasury contract for Abacus
contract CreditVault is  ReentrancyGuard {

    /* ======== UINT ======== */

    uint public tokensClaimed;

    /* ======== BOOL ======== */

    bool public tokenStatus;

    /* ======== ADDRESS ======== */

    address public auction;
    address public pricingSession;
    address public admin;
    address public token;
    address public multisig;
    address public treasury;

    /* ======== MAPPING ======== */

    /// @notice maps each user to their total profit earned
    mapping(address => uint) public profitStored;

    /// @notice maps each user to their principal stored
    mapping(address => uint) public principalStored;

    /// @notice maps each user to their history of profits earned
    mapping(address => uint) public totalProfitEarned;

    /* ======== EVENTS ======== */

    event ethClaimedByUser(address user_, uint ethClaimed);
    event ethToABCExchange(address user_, uint ethExchanged, uint ppSent);

    /* ======== CONSTRUCTOR ======== */

    constructor() {
        admin = msg.sender;
    }

    /* ======== ADMIN FUNCTIONS ======== */

    function setTokenStatus(bool _status) onlyAdmin external {
        tokenStatus = _status;
    }

    /// @notice set ABC token contract address
    /// @param _ABCToken desired ABC token to be stored and referenced in contract
    function setABCTokenAddress(address _ABCToken) onlyAdmin external {
        token = _ABCToken;
    }

    function setMultisig(address _multisig) onlyAdmin external {
        multisig = _multisig;
    }

    function setTreasury(address _treasury) onlyAdmin external {
        treasury = _treasury;
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

    /* ======== USER FUNCTIONS ======== */

    /// @notice user deposits principal
    function depositPrincipal() nonReentrant payable external {
        principalStored[msg.sender] += msg.value;
    }

    /// @notice allows user to reclaim principalUsed in batches
    function claimPrincipalUsed(uint _amount) nonReentrant external {
        require(_amount <= principalStored[msg.sender]);
        principalStored[msg.sender] -= _amount;
        (bool sent, ) = msg.sender.call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }

    /// @notice allows user to claim batched earnings
    /// @param trigger denotes whether the user desires it in ETH (1) or ABC (2)
    function claimProfitsEarned(uint trigger, uint _amount) nonReentrant external {
        require(trigger == 1 || trigger == 2);
        require(profitStored[msg.sender] >= _amount);
        if(trigger == 1) {
            (bool sent, ) = msg.sender.call{value: _amount}("");
            require(sent, "Failed to send Ether");
            profitStored[msg.sender] -= _amount;
            emit ethClaimedByUser(msg.sender, _amount);
        }
        else if(trigger == 2) {
            require(tokenStatus);
            uint abcAmount = _amount * ethToAbc();
            tokensClaimed += abcAmount;
            profitStored[msg.sender] -= _amount;
            ABCTreasury(payable(treasury)).sendABCToken(msg.sender, abcAmount);
            emit ethToABCExchange(msg.sender, _amount, abcAmount);
        }
    }

    /* ======== CHILD FUNCTIONS ======== */

    /// @notice Allows Factory contract to update the profit generated value
    /// @param _amount the amount of profit to update profitGenerated count
    function increasePrincipalStored(address _user, uint _amount) isFactory external {
        principalStored[_user] += _amount;
    }

    /// @notice decrease credit stored
    function decreasePrincipalStored(address _user, uint _amount) isFactory external {
        require(principalStored[_user] >= _amount);
        principalStored[_user] -= _amount;
    }

    /// @notice track profits earned by a user
    function updateProfitStored(address _user, uint _amount) isFactory external {
        profitStored[_user] += _amount;
        totalProfitEarned[_user] += _amount;
    }

    function sendToTreasury(uint _amount) isFactory external {
        payable(treasury).transfer(_amount);
    }

    /* ======== VIEW FUNCTIONS ======== */

    /// @notice returns the current spot exchange rate of ETH to ABC
    function ethToAbc() view public returns(uint) {
        return 1e18 / (0.00005 ether + 0.000015 ether * ((ABCTreasury(payable(treasury)).tokensClaimed()/2) / (1000000*1e18)));
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
}