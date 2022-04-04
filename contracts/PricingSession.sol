/**
 *Submitted for verification at Arbiscan on 2021-12-29
*/

// Sources flattened with hardhat v2.6.7 https://hardhat.org

// File contracts/PricingSession.sol

pragma solidity ^0.8.0;

import "./helpers/ReentrancyGuard.sol";

import "./libraries/SafeMath.sol";
import "./libraries/SafeMath.sol";
import "./libraries/sqrtLibrary.sol";
import "./libraries/PostSessionLibrary.sol";

import "./ABCTreasury.sol";
import "./CreditVaults.sol";

/// @author Medici
/// @title Pricing session contract for Abacus
contract PricingSession is ReentrancyGuard {

    using SafeMath for uint;

    /* ======== ADDRESS ======== */

    address ABCToken;
    ABCTreasury Treasury;
    address admin;
    address auction;
    address creditStore;

    /* ======== MAPPINGS ======== */

    /// @notice maps each NFT to its current nonce value
    mapping(address => mapping (uint => uint)) public nftNonce;

    mapping(uint => mapping(address => mapping(uint => address[]))) NftSessionVoters;

    mapping(uint => mapping(address => mapping(uint => VotingSessionMapping))) NftSessionMap;

    /// @notice maps each NFT pricing session (nonce dependent) to its necessary session checks (i.e. checking session progression)
    /// @dev nonce => tokenAddress => tokenId => session metadata
    mapping(uint => mapping(address => mapping(uint => VotingSessionChecks))) public NftSessionCheck;

    /// @notice maps each NFT pricing session (nonce dependent) to its necessary session core values (i.e. total participants, total stake, etc...)
    mapping(uint => mapping(address => mapping(uint => VotingSessionCore))) public NftSessionCore;

    /// @notice maps each NFT pricing session (nonce dependent) to its final appraisal value output
    mapping(uint => mapping(address => mapping(uint => uint))) public finalAppraisalValue;

    /* ======== STRUCTS ======== */

    /// @notice tracks all of the mappings necessary to operate a session
    struct VotingSessionMapping {

        mapping (address => uint) voterCheck;
        mapping (address => uint) winnerPoints;
        mapping (address => uint) secondaryPoint;
        mapping (address => uint) amountHarvested;
        mapping (address => Voter) nftVotes;
    }

    /// @notice track necessary session checks (i.e. whether its time to weigh votes or harvest)
    struct VotingSessionChecks {

        uint revealedStake;
        uint sessionProgression;
        uint calls;
        uint correct;
        uint incorrect;
        uint defender;
        uint spread;
        uint riskFactor;
        uint finalStdev;
        uint secondaryPoints;
    }

    /// @notice track the core values of a session (max appraisal value, total session stake, etc...)
    struct VotingSessionCore {

        uint endTime;
        uint bounty;
        uint keeperReward;
        uint lowestStake;
        uint maxAppraisal;
        uint totalAppraisalValue;
        uint totalSessionStake;
        uint totalProfit;
        uint totalWinnerPoints;
        uint totalVotes;
        uint uniqueVoters;
        uint votingTime;
    }

    /// @notice track voter information
    struct Voter {

        bytes32 concealedAppraisal;
        uint base;
        uint appraisal;
        uint stake;
    }

    /* ======== EVENTS ======== */

    event PricingSessionCreated(address creator_, uint nonce, address nftAddress_, uint tokenid_, uint initialAppraisal_, uint bounty_);
    event newAppraisalAdded(address voter_, uint nonce, address nftAddress_, uint tokenid_, uint stake_, bytes32 userHash_);
    event voteWeighed(address user_, uint nonce, address nftAddress_, uint tokenid_, uint appraisal);
    event finalAppraisalDetermined(uint nonce, address nftAddress_, uint tokenid_, uint finalAppraisal, uint amountOfParticipants, uint totalStake);
    event sessionEnded(address nftAddress, uint tokenid, uint nonce);

    /* ======== CONSTRUCTOR ======== */

    constructor(address _treasury, address _auction, address _creditStore) {
        Treasury = ABCTreasury(payable(_treasury));
        auction = _auction;
        admin = msg.sender;
        creditStore = _creditStore;
    }

    /// @notice set the auction address to be referenced throughout the contract
    /// @param _auction desired auction address to be stored and referenced in contract
    function setAuction(address _auction) onlyAdmin external {
        auction = _auction;
    }

    /// @notice set the treasury address
    /// @param treasury desired treasury address to be stored and referenced in contract
    function setTreasury(address treasury) onlyAdmin external {
        Treasury = ABCTreasury(payable(treasury));
    }

    /// @notice set ABC token address
    function setABCToken(address _token) onlyAdmin external {
        ABCToken = _token;
    }

    /// @notice Allow user to create new session and attach initial bounty
    /**
    @dev NFT sessions are indexed using a nonce per specific nft.
    The mapping is done by mapping a nonce to an NFT address to the
    NFT token id.
    */
    /// @param nftAddress NFT contract address of desired NFT to be priced
    /// @param tokenid NFT token id of desired NFT to be priced
    /// @param _initialAppraisal appraisal value for max value to be instantiated against
    /// @param _votingTime voting window duration
    function createNewSession(
        address nftAddress,
        uint tokenid,
        uint _initialAppraisal,
        uint _votingTime
    ) stopOverwrite(nftAddress, tokenid) external payable {
        require(_votingTime <= 1 days && (!Treasury.auctionStatus() || msg.sender == auction));
        VotingSessionCore storage sessionCore = NftSessionCore[nftNonce[nftAddress][tokenid]][nftAddress][tokenid];
        if(msg.sender == auction) {}
        else {
            uint abcCost = 0.005 ether *(CreditVault(payable(creditStore)).ethToAbc());
            (bool abcSent) = IERC20(ABCToken).transferFrom(msg.sender, address(Treasury), abcCost);
            require(abcSent);
        }
        if(nftNonce[nftAddress][tokenid] == 0 || getStatus(nftAddress, tokenid) == 5) {}
        else if(block.timestamp > sessionCore.endTime + sessionCore.votingTime * 3) {
            CreditVault(payable(creditStore)).sendToTreasury(sessionCore.totalSessionStake);
            sessionCore.totalSessionStake = 0;
            emit sessionEnded(nftAddress, tokenid, nftNonce[nftAddress][tokenid]);
        }
        nftNonce[nftAddress][tokenid]++;
        VotingSessionCore storage sessionCoreNew = NftSessionCore[nftNonce[nftAddress][tokenid]][nftAddress][tokenid];
        VotingSessionChecks storage sessionCheck = NftSessionCheck[nftNonce[nftAddress][tokenid]][nftAddress][tokenid];
        sessionCoreNew.votingTime = _votingTime;
        sessionCoreNew.maxAppraisal = 69420 * _initialAppraisal / 1000;
        sessionCoreNew.lowestStake = 100000 ether;
        sessionCoreNew.endTime = block.timestamp + _votingTime;
        sessionCoreNew.bounty = msg.value;
        sessionCheck.defender = Treasury.defender();
        sessionCheck.spread = Treasury.spread();
        sessionCheck.riskFactor = Treasury.riskFactor();
        payable(creditStore).transfer(sessionCoreNew.bounty);
        emit PricingSessionCreated(msg.sender, nftNonce[nftAddress][tokenid], nftAddress, tokenid, _initialAppraisal, msg.value);
    }

    /* ======== USER VOTE FUNCTIONS ======== */

    /// @notice Allows user to set vote in party
    /**
    @dev Users appraisal is hashed so users can't track final appraisal and submit vote right before session ends.
    Therefore, users must remember their appraisal in order to reveal their appraisal in the next function.
    */
    /// @param nftAddress NFT contract address of NFT being appraised
    /// @param tokenid NFT tokenid of NFT being appraised
    /// @param concealedAppraisal concealed bid that is a hash of the appraisooooors appraisal value, wallet address, and seed number
    function setVote(
        address nftAddress,
        uint tokenid,
        uint stake,
        bytes32 concealedAppraisal
    ) properVote(nftAddress, tokenid, stake) external {
        uint nonce = nftNonce[nftAddress][tokenid];
        VotingSessionCore storage sessionCore = NftSessionCore[nonce][nftAddress][tokenid];
        VotingSessionMapping storage sessionMap = NftSessionMap[nonce][nftAddress][tokenid];
        require(sessionCore.endTime > block.timestamp && stake <= CreditVault(payable(creditStore)).principalStored(msg.sender));
        sessionMap.voterCheck[msg.sender] = 1;
        CreditVault(payable(creditStore)).decreasePrincipalStored(msg.sender, stake);
        stake -= 0.004 ether;
        sessionCore.keeperReward += 0.002 ether;
        sessionCore.bounty += 0.002 ether;
        if (stake < sessionCore.lowestStake) {
            sessionCore.lowestStake = stake;
        }
        sessionCore.uniqueVoters++;
        sessionCore.totalSessionStake = sessionCore.totalSessionStake.add(stake);
        sessionMap.nftVotes[msg.sender].concealedAppraisal = concealedAppraisal;
        sessionMap.nftVotes[msg.sender].stake = stake;
        emit newAppraisalAdded(msg.sender, nonce, nftAddress, tokenid, stake, concealedAppraisal);
    }

    /// @notice allow user to update value inputs of their vote while voting is still active
    /// @param nftAddress NFT contract address of NFT being appraised
    /// @param tokenid NFT tokenid of NFT being appraised
    /// @param concealedAppraisal concealed bid that is a hash of the appraisooooors new appraisal value, wallet address, and seed number
    function updateVote(
        address nftAddress,
        uint tokenid,
        bytes32 concealedAppraisal
    ) external {
        uint nonce = nftNonce[nftAddress][tokenid];
        VotingSessionCore storage sessionCore = NftSessionCore[nonce][nftAddress][tokenid];
        VotingSessionMapping storage sessionMap = NftSessionMap[nonce][nftAddress][tokenid];
        require(sessionMap.voterCheck[msg.sender] == 1);
        require(sessionCore.endTime > block.timestamp);
        sessionMap.nftVotes[msg.sender].concealedAppraisal = concealedAppraisal;
    }

    /// @notice Reveals user vote and weights based on the sessions lowest stake
    /**
    @dev calculation can be found in the weightVoteLibrary.sol file.
    Votes are weighted as sqrt(userStake/lowestStake). Depending on a votes weight
    it is then added as multiple votes of that appraisal (i.e. if someoneone has
    voting weight of 8, 8 votes are submitted using their appraisal).
    */
    /// @param nftAddress NFT contract address of NFT being appraised
    /// @param tokenid NFT tokenid of NFT being appraised
    /// @param appraisal appraisooooor appraisal value used to unlock concealed appraisal
    /// @param seedNum appraisooooor seed number used to unlock concealed appraisal
    function weightVote(address nftAddress, uint tokenid, uint appraisal, uint seedNum) checkParticipation(nftAddress, tokenid) nonReentrant external {
        uint nonce = nftNonce[nftAddress][tokenid];
        VotingSessionCore storage sessionCore = NftSessionCore[nonce][nftAddress][tokenid];
        VotingSessionMapping storage sessionMap = NftSessionMap[nonce][nftAddress][tokenid];
        VotingSessionChecks storage sessionCheck = NftSessionCheck[nonce][nftAddress][tokenid];
        address[] storage voters = NftSessionVoters[nonce][nftAddress][tokenid];
        require(sessionCheck.sessionProgression < 2
                && sessionCore.endTime < block.timestamp
                && sessionMap.voterCheck[msg.sender] == 1
                && sessionMap.nftVotes[msg.sender].concealedAppraisal == keccak256(abi.encodePacked(appraisal, msg.sender, seedNum))
                && sessionCore.maxAppraisal >= appraisal
        );
        sessionMap.voterCheck[msg.sender] = 2;
        if(sessionCheck.sessionProgression == 0) {
            sessionCheck.sessionProgression = 1;
        }
        sessionCheck.revealedStake += sessionMap.nftVotes[msg.sender].stake;
        voters.push(msg.sender);
        _weigh(nftAddress, tokenid, appraisal);
        emit voteWeighed(msg.sender, nonce, nftAddress, tokenid, appraisal);
        if(sessionCheck.calls == sessionCore.uniqueVoters || block.timestamp > sessionCore.endTime + sessionCore.votingTime) {
            sessionCheck.sessionProgression = 2;
            sessionCore.uniqueVoters = sessionCheck.calls;
            sessionCheck.calls = 0;
        }
    }


    /// @notice takes average of appraisals and outputs a final appraisal value.
    /// @param nftAddress NFT contract address of NFT being appraised
    /// @param tokenid NFT tokenid of NFT being appraised
    function setFinalAppraisal(address nftAddress, uint tokenid) public {
        uint nonce = nftNonce[nftAddress][tokenid];
        VotingSessionCore storage sessionCore = NftSessionCore[nonce][nftAddress][tokenid];
        VotingSessionChecks storage sessionCheck = NftSessionCheck[nonce][nftAddress][tokenid];
        require(
            (block.timestamp > sessionCore.endTime + sessionCore.votingTime || sessionCheck.sessionProgression == 2)
            && sessionCheck.sessionProgression <= 2
        );
        CreditVault(payable(creditStore)).updateProfitStored(msg.sender, sessionCore.keeperReward/2 ether);
        _boundCheck(nftAddress, tokenid);
        sessionCore.totalProfit += sessionCore.bounty + (sessionCore.totalSessionStake - sessionCheck.revealedStake);
        sessionCheck.calls = 0;
        finalAppraisalValue[nonce][nftAddress][tokenid] = (sessionCore.totalAppraisalValue)/(sessionCore.totalVotes);
        sessionCheck.sessionProgression = 3;
        emit finalAppraisalDetermined(nftNonce[nftAddress][tokenid], nftAddress, tokenid, finalAppraisalValue[nftNonce[nftAddress][tokenid]][nftAddress][tokenid], sessionCore.uniqueVoters, sessionCore.totalSessionStake);
    }

    /// @notice Calculates users base and harvests their loss before returning remaining stake
    /**
    @dev A couple notes:
    1. Base is calculated based on margin of error.
        > +/- 5% = 1
        > +/- 4% = 2
        > +/- 3% = 3
        > +/- 2% = 4
        > +/- 1% = 5
        > Exact = 6
    2. winnerPoints are calculated based on --> base * stake
    3. Losses are harvested based on --> (margin of error - 5%) * stake
    */
    /// @param nftAddress NFT contract address of NFT being appraised
    /// @param tokenid NFT tokenid of NFT being appraised
    function harvest(address nftAddress, uint tokenid) checkParticipation(nftAddress, tokenid) nonReentrant external returns(uint256){
        uint nonce = nftNonce[nftAddress][tokenid];
        VotingSessionCore storage sessionCore = NftSessionCore[nonce][nftAddress][tokenid];
        VotingSessionChecks storage sessionCheck = NftSessionCheck[nonce][nftAddress][tokenid];
        address[] storage voters = NftSessionVoters[nonce][nftAddress][tokenid];
        require(sessionCheck.sessionProgression == 3);
        address user;
        for(uint i = 0; i < 20; i++) {
            user = voters[sessionCheck.calls];
            CreditVault(payable(creditStore)).updateProfitStored(msg.sender, 0.0005 ether);
            sessionCheck.calls++;
            _harvest(user, nftAddress, tokenid);
            if(sessionCheck.calls == sessionCore.uniqueVoters) {
                sessionCheck.sessionProgression = 4;
                sessionCore.uniqueVoters = sessionCheck.calls;
                sessionCheck.calls = 0;
                return 1;
            }
        }
        return 1;
    }

    /// @notice User claims principal stake along with any earned profits in ETH or ABC form
    /**
    @dev
    1. Calculates user principal return value
    2. Enacts sybil defense mechanism
    3. Edits totalProfits and totalSessionStake to reflect claim
    5. Pays out principal
    6. Adds profit credit to profitStored
    */
    /// @param nftAddress NFT contract address of NFT being appraised
    /// @param tokenid NFT tokenid of NFT being appraised
    function claim(address nftAddress, uint tokenid) checkParticipation(nftAddress, tokenid) nonReentrant external returns(uint) {
        uint nonce = nftNonce[nftAddress][tokenid];
        VotingSessionCore storage sessionCore = NftSessionCore[nonce][nftAddress][tokenid];
        VotingSessionChecks storage sessionCheck = NftSessionCheck[nonce][nftAddress][tokenid];
        address[] storage voters = NftSessionVoters[nonce][nftAddress][tokenid];
        require(sessionCheck.sessionProgression == 4);
        address user;
        for(uint i = 0; i < 20; i++) {
            user = voters[sessionCheck.calls];
            CreditVault(payable(creditStore)).updateProfitStored(msg.sender, 0.0005 ether);
            sessionCheck.calls++;
            _claim(user, nftAddress, tokenid);
            if(sessionCheck.calls == sessionCore.uniqueVoters) {
                sessionCore.totalSessionStake = 0;
                sessionCheck.sessionProgression = 5;
                emit sessionEnded(nftAddress, tokenid, nonce);
                return 1;
            }
        }
        return 1;
    }

    /* ======== INTERNAL FUNCTIONS ======== */

    ///@notice user vote is weighed
    /**
    @dev a voters weight is determined by the following formula:
        sqrt(voterStake/lowestStake)
    this value is then used to
    */
    /// @param nftAddress NFT contract address of NFT being appraised
    /// @param tokenid NFT tokenid of NFT being appraised
    /// @param appraisal the voters appraisal value
    function _weigh(address nftAddress, uint tokenid, uint appraisal) internal {
        uint nonce = nftNonce[nftAddress][tokenid];
        VotingSessionCore storage sessionCore = NftSessionCore[nonce][nftAddress][tokenid];
        VotingSessionMapping storage sessionMap = NftSessionMap[nonce][nftAddress][tokenid];
        VotingSessionChecks storage sessionCheck = NftSessionCheck[nonce][nftAddress][tokenid];
        sessionMap.nftVotes[msg.sender].appraisal = appraisal;
        uint weight = sqrtLibrary.sqrt(sessionMap.nftVotes[msg.sender].stake/sessionCore.lowestStake);
        sessionCore.totalVotes += weight;
        sessionCheck.calls++;

        sessionCore.totalAppraisalValue += weight * appraisal;
    }

    /// @notice user vote is checked against the post-determined lower and upper bound
    /**
    @dev the upper bound for acceptable votes are set using the following equation:

    Calculate margin
        uint256 margin = 3 * stdev + 20e18 / final_appraisal;

    Calculate inclusion bound
        uint256 upper_bound = final_appraisal + margin;

    This function is used to root out extreme entries that may be malicious or accidental.
    */
    /// @param nftAddress NFT contract address of NFT being appraised
    /// @param tokenid NFT tokenid of NFT being appraised
    function _boundCheck(address nftAddress, uint tokenid) internal {
        uint nonce = nftNonce[nftAddress][tokenid];
        VotingSessionCore storage sessionCore = NftSessionCore[nonce][nftAddress][tokenid];
        VotingSessionChecks storage sessionCheck = NftSessionCheck[nonce][nftAddress][tokenid];
        VotingSessionMapping storage sessionMap = NftSessionMap[nonce][nftAddress][tokenid];
        address[] storage voters = NftSessionVoters[nonce][nftAddress][tokenid];
        if(sessionCheck.calls != 0) {
            sessionCore.uniqueVoters = sessionCheck.calls;
        }
        uint rounds = sessionCore.uniqueVoters / 20 + 1;
        uint totalValue;
        uint voterCount;
        uint invalidCount;
        for(uint a = 0; a <= sessionCheck.defender; a++) {
            uint finalAppraisal = (sessionCore.totalAppraisalValue)/(sessionCore.totalVotes);
            voterCount = 0;
            for(uint i = 0; i < rounds; i++) {
                for(uint j = 0; j < 20; j++) {
                    if (voterCount == sessionCore.uniqueVoters) {
                        break;
                    }
                    if(sessionMap.nftVotes[voters[voterCount]].appraisal == 0) {}
                    else if(sessionMap.nftVotes[voters[voterCount]].appraisal > finalAppraisal) {
                        totalValue += (sessionMap.nftVotes[voters[voterCount]].appraisal - finalAppraisal) ** 2;
                    }
                    else {
                        totalValue += (finalAppraisal - sessionMap.nftVotes[voters[voterCount]].appraisal) ** 2;
                    }
                    voterCount++;
                }
            }
            uint stdev = sqrtLibrary.sqrt(totalValue/(sessionCore.uniqueVoters - invalidCount));
            totalValue = 0;
            sessionCheck.finalStdev = stdev;
            if(a == sessionCheck.defender) {
                break;
            }
            voterCount = 0;
            uint upper = PostSessionLibrary.calculateBound(finalAppraisal, stdev, sessionCheck.defender);
            uint weight;
            for(uint i = 0; i < rounds; i++) {
                for(uint j = 0; j < 20; j++) {
                    if (voterCount == sessionCore.uniqueVoters) {
                        break;
                    }
                    weight = sqrtLibrary.sqrt(sessionMap.nftVotes[voters[voterCount]].stake/sessionCore.lowestStake);
                    if(sessionMap.nftVotes[voters[voterCount]].appraisal > upper) {
                        sessionCore.totalVotes -= weight * (sessionMap.nftVotes[voters[voterCount]].appraisal == 0? 0:1);
                        sessionCore.totalAppraisalValue -= weight * sessionMap.nftVotes[voters[voterCount]].appraisal;
                        sessionMap.nftVotes[voters[voterCount]].appraisal = 0;
                        invalidCount++;
                    }
                    voterCount++;
                }
            }
        }
    }

    /// @notice Calculates users base and harvests their loss before returning remaining stake
    /**
    @dev A couple notes:
    1. Base is calculated based on margin of error.
        > +/- 5% = 1
        > +/- 4% = 2
        > +/- 3% = 3
        > +/- 2% = 4
        > +/- 1% = 5
        > Exact = 6
    2. winnerPoints are calculated based on --> base * stake
    3. Losses are harvested based on --> (margin of error - 5%) * stake
    */
    /// @param nftAddress NFT contract address of NFT being appraised
    /// @param tokenid NFT tokenid of NFT being appraised
    /// @param _user the user that harvest is being called on
    function _harvest(address _user, address nftAddress, uint tokenid) internal {
        uint nonce = nftNonce[nftAddress][tokenid];
        VotingSessionCore storage sessionCore = NftSessionCore[nonce][nftAddress][tokenid];
        VotingSessionChecks storage sessionCheck = NftSessionCheck[nonce][nftAddress][tokenid];
        VotingSessionMapping storage sessionMap = NftSessionMap[nonce][nftAddress][tokenid];
        uint finalAppraisal = finalAppraisalValue[nftNonce[nftAddress][tokenid]][nftAddress][tokenid];
        sessionMap.nftVotes[_user].base =
            PostSessionLibrary.calculateBase(
                finalAppraisal,
                sessionMap.nftVotes[_user].appraisal,
                sessionCheck.spread
            );
        uint weight = sqrtLibrary.sqrt(sessionMap.nftVotes[_user].stake/sessionCore.lowestStake);
        if(sessionMap.nftVotes[_user].base > 0) {
            sessionCore.totalWinnerPoints += sessionMap.nftVotes[_user].base * weight;
            sessionMap.winnerPoints[_user] = sessionMap.nftVotes[_user].base * weight;
            sessionCheck.correct += weight;
        }
        else if(
            sessionMap.nftVotes[_user].appraisal < finalAppraisal + sessionCheck.finalStdev
            && sessionMap.nftVotes[_user].appraisal > finalAppraisal - sessionCheck.finalStdev
        ) {
            sessionMap.secondaryPoint[_user] += sessionMap.nftVotes[_user].stake;
            sessionCheck.secondaryPoints += sessionMap.nftVotes[_user].stake;
            sessionCheck.incorrect += weight;
        }
        else {
            sessionCheck.incorrect += weight;
        }

        sessionMap.amountHarvested[_user] = PostSessionLibrary.harvest(
            sessionMap.nftVotes[_user].stake,
            sessionMap.nftVotes[_user].appraisal,
            finalAppraisalValue[nftNonce[nftAddress][tokenid]][nftAddress][tokenid],
            sessionCheck.riskFactor,
            sessionCheck.spread
        );

        sessionMap.nftVotes[_user].stake -= sessionMap.amountHarvested[_user];
        uint commission = sessionMap.amountHarvested[_user] * 500 / 10000;
        sessionCore.totalSessionStake -= commission;
        sessionMap.amountHarvested[_user] -= commission;
        sessionCore.totalProfit += sessionMap.amountHarvested[_user];
        CreditVault(payable(creditStore)).sendToTreasury(commission);
    }


    /// @notice User claims principal stake along with any earned profits in ETH or ABC form
    /**
    @dev
    1. Calculates user principal return value
    2. Enacts sybil defense mechanism
    3. Edits totalProfits and totalSessionStake to reflect claim
    5. Pays out principal
    6. Adds profit credit to profitStored
    */
    /// @param nftAddress NFT contract address of NFT being appraised
    /// @param tokenid NFT tokenid of NFT being appraised
    /// @param _user the user that harvest is being called on
    function _claim(address _user, address nftAddress, uint tokenid) internal {
        uint nonce = nftNonce[nftAddress][tokenid];
        VotingSessionCore storage sessionCore = NftSessionCore[nonce][nftAddress][tokenid];
        VotingSessionChecks storage sessionCheck = NftSessionCheck[nonce][nftAddress][tokenid];
        VotingSessionMapping storage sessionMap = NftSessionMap[nonce][nftAddress][tokenid];
        uint principalReturn;
        if(sessionCheck.correct * 100 / (sessionCheck.correct + sessionCheck.incorrect) >= (95-sessionCheck.spread)) {
            principalReturn += sessionMap.nftVotes[_user].stake + sessionMap.amountHarvested[_user];
        }
        else {
            principalReturn += sessionMap.nftVotes[_user].stake;
        }
        uint payout;
        if(sessionCheck.correct * 100 / (sessionCheck.correct + sessionCheck.incorrect) >= (95-sessionCheck.spread)) {
            payout = sessionCore.bounty/sessionCore.uniqueVoters;
        }
        else if(sessionCheck.secondaryPoints + sessionCore.totalWinnerPoints == 0) {
            payout = 0;
        }
        else if (sessionCore.totalWinnerPoints == 0) {
            payout = sessionCore.totalProfit * sessionMap.secondaryPoint[_user] / sessionCheck.secondaryPoints;
            sessionCheck.secondaryPoints -= sessionMap.secondaryPoint[_user];
            sessionMap.secondaryPoint[_user] = 0;
        }
        else {
            payout = sessionCore.totalProfit * sessionMap.winnerPoints[_user] / sessionCore.totalWinnerPoints;
            sessionCore.totalWinnerPoints -= sessionMap.winnerPoints[_user];
            sessionMap.winnerPoints[_user] = 0;
        }
        sessionCore.totalProfit -= payout;
        Treasury.updateTotalProfitsGenerated(payout);
        CreditVault(payable(creditStore)).increasePrincipalStored(_user, principalReturn);
        CreditVault(payable(creditStore)).updateProfitStored(_user, payout);
    }

    /* ======== VIEW FUNCTIONS ======== */

    /// @notice returns the status of the session in question
    /// @param nftAddress NFT contract address of NFT being appraised
    /// @param tokenid NFT tokenid of NFT being appraised
    function getStatus(address nftAddress, uint tokenid) view public returns(uint) {
        return NftSessionCheck[nftNonce[nftAddress][tokenid]][nftAddress][tokenid].sessionProgression;
    }

    // /// @notice check the users status in terms of session interaction
    // /// @param nftAddress NFT contract address of NFT being appraised
    // /// @param tokenid NFT tokenid of NFT being appraised
    // /// @param _user appraisooooor who's session progress is of interest
    function getVoterCheck(address nftAddress, uint tokenid, address _user) view external returns(uint) {
        return NftSessionMap[nftNonce[nftAddress][tokenid]][nftAddress][tokenid].voterCheck[_user];
    }

    /* ======== FALLBACK FUNCTIONS ======== */

    receive() external payable {}
    fallback() external payable {}

    /* ======== MODIFIERS ======== */

    /// @notice stop users from being able to create multiple sessions for the same NFT at the same time
    modifier stopOverwrite(
        address nftAddress,
        uint tokenid
    ) {
        require(
            nftNonce[nftAddress][tokenid] == 0
            || getStatus(nftAddress, tokenid) == 5
            || block.timestamp > NftSessionCore[nftNonce[nftAddress][tokenid]][nftAddress][tokenid].endTime + 2 * NftSessionCore[nftNonce[nftAddress][tokenid]][nftAddress][tokenid].votingTime
        );
        _;
    }

    /// @notice makes sure that a user that submits a vote satisfies the proper voting parameters
    modifier properVote(
        address nftAddress,
        uint tokenid,
        uint stake
    ) {
        require(
            NftSessionMap[nftNonce[nftAddress][tokenid]][nftAddress][tokenid].voterCheck[msg.sender] == 0
            && stake >= 0.009 ether
        );
        _;
    }

    /// @notice checks the participation of the msg.sender
    modifier checkParticipation(
        address nftAddress,
        uint tokenid
    ) {
        require(NftSessionMap[nftNonce[nftAddress][tokenid]][nftAddress][tokenid].voterCheck[msg.sender] > 0);
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }
}