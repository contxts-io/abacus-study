// File contracts/libraries/PostSessionLibrary.sol
pragma solidity ^0.8.0;

import "./sqrtLibrary.sol";

library PostSessionLibrary {

    using sqrtLibrary for *;

    function collusionCheck(uint correct, uint incorrect, uint spread) pure internal returns (bool) {
        if(correct * 100 / (correct + incorrect) >= (95-spread)) {
            return true;
        }
        else {
            return false;
        }
    }

    /////////////////////
    /// Session Bound ///
    /////////////////////

    function calculateTotalValue(
        uint values,
        uint[] memory appraisals,
        uint finalAppraisal
    ) pure internal returns (uint totalValue) {
        for(uint j = 0; j < 30; j++) {
            if (j == values) {
                break;
            }
            if(appraisals[j] > finalAppraisal) {
                totalValue += (appraisals[j] - finalAppraisal) ** 2;
            }
            else {
                totalValue += (finalAppraisal - appraisals[j]) ** 2;
            }
        }
    }

    function calculateBound(uint finalAppraisalValue, uint stdev, uint defender) pure internal returns (uint upperBound) {
        upperBound = finalAppraisalValue + (3 * (stdev + 20e18/finalAppraisalValue) / (defender + 1) * 2);
    }

    /////////////////////
    ///      Base     ///
    /////////////////////

    function calculateBase(uint finalAppraisalValue, uint userAppraisalValue, uint spread) pure internal returns(uint){
        uint base = 1;
        uint userVal = 100 * userAppraisalValue;
        for(uint i=spread; i >= 1; i--) {
            uint lowerOver = (100 + (i - 1)) * finalAppraisalValue;
            uint upperOver = (100 + i) * finalAppraisalValue;
            uint lowerUnder = (100 - i) * finalAppraisalValue;
            uint upperUnder = (100 - i + 1) * finalAppraisalValue;
            if (lowerOver < userVal && userVal <= upperOver) {
                return base;
            }
            if (lowerUnder < userVal && userVal <= upperUnder) {
                return base;
            }
            base += 1;
        }
        if(userVal == 100*finalAppraisalValue) {
            return spread + 1;
        }
        return 0;
    }

    /////////////////////
    ///    Harvest    ///
    /////////////////////

    // function harvestUserOver(uint _stake, uint _userAppraisal, uint _finalAppraisal) pure internal returns(uint) {
    //     return _stake * (_userAppraisal*100 - 105*_finalAppraisal)/(_finalAppraisal*100);
    // }

    // function harvestUserUnder(uint _stake, uint _userAppraisal, uint _finalAppraisal) pure internal returns(uint) {
    //     return _stake * (95*_finalAppraisal - 100*_userAppraisal)/(_finalAppraisal*100);
    // }

    function harvest(uint _stake, uint _userAppraisal, uint _finalAppraisal, uint riskFactor, uint spread) pure internal returns(uint) {
        if(
            (_userAppraisal*100 > (100 + spread)*_finalAppraisal
            && (_userAppraisal*100 - (100 + spread)*_finalAppraisal)/(_finalAppraisal) > (100 + spread))
            || _userAppraisal == 0
        ) {
            return _stake;
        }
        else if(_userAppraisal*100 > (100 + spread)*_finalAppraisal) {
            if (_stake * (_userAppraisal*100 - (100 + spread)*_finalAppraisal)/(_finalAppraisal*100) * riskFactor > _stake) {
                return _stake;
            }
            else {
                return _stake * (_userAppraisal*100 - (100 + spread)*_finalAppraisal)/(_finalAppraisal*100) * riskFactor;
            }
        }
        else if(_userAppraisal*100 < (100 - spread)*_finalAppraisal) {
            if (_stake * ((100 - spread)*_finalAppraisal - 100*_userAppraisal)/(_finalAppraisal*100) * riskFactor > _stake) {
                return _stake;
            }
            else {
                return _stake * ((100 - spread)*_finalAppraisal - 100*_userAppraisal)/(_finalAppraisal*100) * riskFactor;
            }
        }
        else {
            return 0;
        }
    }

    /////////////////////
    ///   Commission  ///
    /////////////////////
    function setCommission(uint _treasurySize) pure internal returns(uint) {
        if (_treasurySize < 25000 ether) {
            return 500;
        }
        else if(_treasurySize >= 25000 ether && _treasurySize < 50000 ether) {
            return 400;
        }
        else if(_treasurySize >= 50000 ether && _treasurySize < 100000 ether) {
            return 300;
        }
        else if(_treasurySize >= 100000 ether && _treasurySize < 2000000 ether) {
            return 200;
        }
        else if(_treasurySize >= 200000 ether && _treasurySize < 400000 ether) {
            return 100;
        }
        else if(_treasurySize >= 400000 ether && _treasurySize < 700000 ether) {
            return 50;
        }
        else {
            return 25;
        }
    }


}