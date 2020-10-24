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
import "hardhat/console.sol";

import "./ICOREGlobals.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

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
        // require(false, "got to handleTransfer");
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
        require(ICOREGlobals(coreGlobalsAddress).isStateChangeApprovedContract(msg.sender), "CORE DELEGATOR: only CORE contracts are allowed to call this function");
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


        // This function is just calculating FoT amounts for CORE
    // Flow of this
    // msg.sender is token check
    // sender is what calls CORE token
    // So we check who is sender here
    // If sender is one of the pairs
    // We sync that pair
    // recipent is the recipent of CORE otken
    // We check that for pair too

    ////////////
    /// recipent is any of the CORE pairs IF
    // Its a SELL or a MINT
    // sender is PAIR if its a BUY or BURN
    ////////////

    // If sender or recipent is pir we can update volume in CORE bottom units
    // we upgrade core bottom units eveyr lets say 500 blocks which is about 1.5hr

    mapping (address => address) isPairForThisToken;


    struct Pair {
        address token0;
        address token1;
        uint256[25] volumeInHour;
        uint256 cumulativeVolumeLast24hInCOREBottomUnits;
        bool volumeArrayFilled;
        uint8 currentArrayPosition;
    }

    mapping(address => bool) public isDoubleControlledPair;
    mapping(address => Pair) public _pair;

    // by blocking all token withdrawals we have to keep state of a token about previous pair
    // what doe shtis mena
    function handleToken0OutFromDoubleControlledPair() internal{
        // update state for this token (lp)
        // set state to update next check
    }
    function handleToken1OutFromDoubleControlledPair() internal {
        // check for previous state update being burn

    }

    function getVolumeOfTokenInCoreBottomUnits(address pairAddress) public view returns(uint256) {
        Pair memory currentPair = _pair[pairAddress]; // memory this is  a view
    
        return currentPair.volumeArrayFilled ? 
            currentPair.cumulativeVolumeLast24hInCOREBottomUnits.div(currentPair.currentArrayPosition == 0 ? 1: currentPair.currentArrayPosition) :
            currentPair.cumulativeVolumeLast24hInCOREBottomUnits.sub(currentPair.volumeInHour[currentPair.currentArrayPosition]).div(24); 
            // If the array is not filled we just divide it by current array position note it has -1 already applied because its 0
            // indexed - and note the special case for first hour ever which will just return that hours volume so far
            // We shoudnt extrapolate volume to 24h here or it can be manipulated
            // For the case its already filled we substract the current one which is getting filled
    }

    function addVolumeToToken(uint256 paidFees, address pairAddress) internal {

        Pair storage currentPair = _pair[pairAddress]; // storage because we edit it
        uint256 valueOfPaidFees = paidFees.mul(coreBottomPriceFromETHPair);
        currentPair.volumeInHour[currentPair.currentArrayPosition] = currentPair.volumeInHour[currentPair.currentArrayPosition].add(valueOfPaidFees);
        updateRunningAveragesArray(pairAddress, valueOfPaidFees);


    }

    function updateRunningAveragesArray(address pairAddress, uint256 valueOfPaidFees) internal {


    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal view returns (uint256 amountOut) {
        // fix revert on pairs with no volume
        if(amountIn == 0) return 0;
        if(reserveIn == 0 && reserveOut == 0) return 0;

        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }


    uint256 public coreBottomPriceFromETHPair; // Real bottom price is higher but this good enough to aproximate vol
                                            // In something thats not possible to manipulate
                                            // Or is it

    function getCOREBottomPrice() public view returns (uint256 COREBottomInWETH) {
        (uint256 COREReserves, uint256 WETHReserves,) = IUniswapV2Pair(ICOREGlobals(coreGlobalsAddress).COREWETHUniPair()).getReserves();
        // 1e22 is 10k of 1e18
        //1e22.sub(COREReserves) is total out
        uint256 totalSellOfAllCORE = getAmountOut(uint256(1e22).sub(COREReserves) , COREReserves, WETHReserves);
        COREBottomInWETH = WETHReserves.sub(totalSellOfAllCORE).div(1e4); //1e4 is 10k
    }

    uint private lastBlockCOREBottomUpdate;
    function updateCOREBottomPrice(bool forceUpdate) internal {
        uint256 _coreBottomPriceFromETHPair = getCOREBottomPrice();
        // Note its intended that it just doesnt update it and goes for old price
        // To not block transfers
        if(block.number > lastBlockCOREBottomUpdate.add(500) 
                && forceUpdate ? true : _coreBottomPriceFromETHPair < coreBottomPriceFromETHPair.mul(13).div(10))
                // We check here for bottom price change in case of manipulation
                // I dont see a scenario this is legimate
                // forceUpdate bypasses this check
                {
            coreBottomPriceFromETHPair = _coreBottomPriceFromETHPair;
            lastBlockCOREBottomUpdate = block.number;
        }
    }

    // Admin function
    // its possible core bottom price gets stuck at old version
    // In case someone puts in 30% of total liquidity into liquidity at once
    // This applies only to CORE/WETH pool - not new LGES
    function forceUpdateBottomPrice() public onlyOwner {
        updateCOREBottomPrice(true); 
    }

    
    function sync(address token) public returns (bool isMint, bool isBurn) {
        // require(false,"Got to sync");
        // TokenInfo memory currentToken = _tokens[token];
        return(false, false);
        // // This will update the state of lastIsMint, when called publically
        // // So we have to sync it before to the last LP token value.
        // uint256 _LPSupplyOfPairTotal = IERC20(currentToken.uniswapPair).totalSupply();
        // isBurn = currentToken.lastTotalSupplyOfLPTokens > _LPSupplyOfPairTotal;

        // // TODO: what sets isMint?

        // if(isBurn == false) { // further more indepth checks

        // }

        // _tokens[token].lastTotalSupplyOfLPTokens = _LPSupplyOfPairTotal;

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