// SPDX-License-Identifier: MIT
// COPYRIGHT cVault.finance TEAM
// NO COPY
// COPY = BAD
// This code is provided with no assurances or guarantees of any kind. Use at your own responsibility.
//
//  _____ ___________ _____  
// /  __ \  _  | ___ \  ___| 
// | /  \/ | | | |_/ / |__   
// | |   | | | |    /|  __|  
// | \__/\ \_/ / |\ \| |___  
//  \____/\___/\_| \_\____/  
//  _____                    __            _   _                 _ _           
// |_   _|                  / _|          | | | |               | | |          
//   | |_ __ __ _ _ __  ___| |_ ___ _ __  | |_| | __ _ _ __   __| | | ___ _ __ 
//   | | '__/ _` | '_ \/ __|  _/ _ \ '__| |  _  |/ _` | '_ \ / _` | |/ _ \ '__|
//   | | | | (_| | | | \__ \ ||  __/ |    | | | | (_| | | | | (_| | |  __/ |   
//   \_/_|  \__,_|_| |_|___/_| \___|_|    \_| |_/\__,_|_| |_|\__,_|_|\___|_|   
//                                                                                             
// This contract handles all fees and transfers, previously fee approver.
//                                   .
//      .              .   .'.     \   /
//    \   /      .'. .' '.'   '  -=  o  =-
//  -=  o  =-  .'   '              / | \
//    / | \                          |
//      |                            |
//      |                            |
//      |                      .=====|
//      |=====.                |.---.|
//      |.---.|                ||=o=||
//      ||=o=||                ||   ||
//      ||   ||                ||   ||
//      ||   ||                ||___||
//      ||___||                |[:::]|
//      |[:::]|                '-----'
//      '-----'              jiMXK9eDrMY
//             

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@nomiclabs/buidler/console.sol";
import "./ICOREGlobals.sol";

contract COREDelegator is OwnableUpgradeSafe {
    using SafeMath for uint256;
    // Core contracts can call fee approver with the state of the function they do
    // eg. flash loan which will allow withdrawal of liquidity for that transaction only
    // IMPORTANT to switch it back after transfer is complete to default

    enum PossibleStates {
        FEEOFF,
        FLASHLOAN,
        RESHUFFLEARBITRAGE,
        DEFAULT
    }

    /// dummy fortests 
    function handleTransfer(address from, address to, uint256 amount) public {

    }

    PossibleStates constant defaultState = PossibleStates.DEFAULT;
    PossibleStates public currentstate;
    address coreGlobalsAddress;
    bool paused;

    function initalize(address coreGlobalsAddress, bool paused) public initializer onlyOwner {
        coreGlobalsAddress = coreGlobalsAddress;
        paused = paused;
    }    

    function setCOREGlobalsAddress(address _coreGlobalsAddress) public onlyOwner {
        coreGlobalsAddress = _coreGlobalsAddress;
    }

    function changeState(PossibleStates toState) public onlyCOREcontracts {
        currentstate = toState;
    }


    modifier onlyCOREcontracts () {
        // all contracts will be in globals
        require(ICOREGlobals(coreGlobalsAddress).isStateChangeApprovedContract(msg.sender), "CORE DELEGATOR: Fuck off.");
        _;

    }


    struct FeeMultiplier {
        bool isSet; // Because 0 needs to be 0
        uint256 fee;
    }


    uint256 public DEFAULT_FEE;

    function setDefaultFee(uint256 fee) public onlyOwner {
        DEFAULT_FEE = fee;
    }


    mapping (address => TokenModifiers) private _tokenModifiers;

    struct TokenModifiers {
        bool isSet;
        mapping (address => FeeMultiplier) recieverFeeMultipliers;
        mapping (address => FeeMultiplier) senderFeeMultipliers;
        uint256 TOKEN_DEFAULT_FEE;
    }

    mapping (address => TokenInfo) private _tokens;

    struct TokenInfo {
        address liquidityWithdrawalSender;
        uint256 lastTotalSupplyOfLPTokens;
        address uniswapPair;
        // address[] pairs; // TODO: xRevert pls Confirm this should be added
        // uint16 numPairs; // TODO: xRevert pls Confirm this should be added
    }

    // TODO: Let's review the design of this for handling arbitrary LPs
    // function addPairForToken(address tokenAddress, address pair) external onlyOwner {
    //     TokenInfo currentToken = _tokens[tokenAddress];
    //     // TODO: Use a set to avoid  duplicate adds (just wastes gas but might as well)
    //     _tokens[tokenAddress].pairs[currentToken.numTokens++] = pair;
    // }

    function setUniswapPair(address ofToken, address uniswapPair) external onlyOwner {
        _tokens[ofToken].uniswapPair = uniswapPair;
    }

    function setFeeModifierOfAddress(address ofToken, address that, uint256 feeSender, uint256 feeReciever) public onlyOwner {
        _tokenModifiers[ofToken].isSet = true;

        _tokenModifiers[ofToken].senderFeeMultipliers[that].fee = feeSender;
        _tokenModifiers[ofToken].senderFeeMultipliers[that].isSet = true; // TODO: xRevert pls Confirm this should be added

        _tokenModifiers[ofToken].recieverFeeMultipliers[that].fee = feeReciever;
        _tokenModifiers[ofToken].recieverFeeMultipliers[that].isSet = true; // TODO: xRevert pls Confirm this should be added
    }

    function removeFeeModifiersOfAddress(address ofToken, address that) public onlyOwner {
        _tokenModifiers[ofToken].isSet = false;
    }



    // Should return 0 if nothing is set.
    // Or would this grab some garbage memory?
    function getFeeOfTransfer(address sender, address recipient) public view returns (uint256 fee){

        TokenModifiers storage currentToken = _tokenModifiers[msg.sender];
        if(currentToken.isSet == false) return DEFAULT_FEE;

        fee = currentToken.senderFeeMultipliers[sender].isSet ? currentToken.senderFeeMultipliers[sender].fee :
            currentToken.recieverFeeMultipliers[recipient].isSet ? currentToken.recieverFeeMultipliers[recipient].fee : 
                currentToken.TOKEN_DEFAULT_FEE;

    }
    
    function sync(address token) public returns (bool isMint, bool isBurn) {
        TokenInfo memory currentToken = _tokens[token];

        // This will update the state of lastIsMint, when called publically
        // So we have to sync it before to the last LP token value.
        uint256 _LPSupplyOfPairTotal = IERC20(currentToken.uniswapPair).totalSupply();
        isBurn = currentToken.lastTotalSupplyOfLPTokens > _LPSupplyOfPairTotal;

        // TODO: what sets isMint?

        if(isBurn == false) { // further more indepth checks

        }

        _tokens[token].lastTotalSupplyOfLPTokens = _LPSupplyOfPairTotal;

    }



    function calculateAmountsAfterFee(        
    address sender, 
    address recipient, // unusued maybe use din future
    uint256 amount,
    address tokenAddress
    ) public  returns (uint256 transferToAmount, uint256 transferToFeeDistributorAmount) 
    {
        require(paused == false, "CORE DELEGATOR: Transfers Paused");
        (bool lastIsMint, bool lpTokenBurn) = sync(tokenAddress);

        //sender takes precedence
        uint256 currentFee = getFeeOfTransfer(sender, recipient); 
  
        if(sender == _tokens[msg.sender].liquidityWithdrawalSender) {
            // This will block buys that are immidietly after a mint. Before sync is called/
            // Deployment of this should only happen after router deployment 
            // And addition of sync to all CoreVault transactions to remove 99.99% of the cases.
            require(lastIsMint == false, "CORE DELEGATOR: Liquidity withdrawals forbidden");
            require(lpTokenBurn == false, "CORE DELEGATOR: Liquidity withdrawals forbidden");
        }

        if(currentFee == 0) { 
            console.log("Sending without fee");                     
            transferToFeeDistributorAmount = 0;
            transferToAmount = amount;
        } 
        else {
            console.log("Normal fee transfer");
            transferToFeeDistributorAmount = amount.mul(currentFee).div(1000);
            transferToAmount = amount.sub(transferToFeeDistributorAmount);
        }

        // IMPORTANT
        currentstate = defaultState;
        // IMPORTANT
    }

}