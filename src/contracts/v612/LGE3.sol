// SPDX-License-Identifier: MIT
// COPYRIGHT cVault.finance TEAM
// NO COPY
// COPY = BAD
// This code is provided with no assurances or guarantees of any kind. Use at your own responsibility.
//
//  _     _             _     _ _ _           
// | |   (_)           (_)   | (_) |         
// | |    _  __ _ _   _ _  __| |_| |_ _   _  
// | |   | |/ _` | | | | |/ _` | | __| | | | 
// | |___| | (_| | |_| | | (_| | | |_| |_| | 
// \_____/_|\__, |\__,_|_|\__,_|_|\__|\__, |  
//             | |                     __/ |                                                                               
//             |_|                    |___/               
//  _____                           _   _               _____                _                                                                    
// |  __ \                         | | (_)             |  ___|              | |  
// | |  \/ ___ _ __   ___ _ __ __ _| |_ _  ___  _ __   | |____   _____ _ __ | |_ 
// | | __ / _ \ '_ \ / _ \ '__/ _` | __| |/ _ \| '_ \  |  __\ \ / / _ \ '_ \| __|
// | |_\ \  __/ | | |  __/ | | (_| | |_| | (_) | | | | | |___\ V /  __/ | | | |_ 
//  \____/\___|_| |_|\___|_|  \__,_|\__|_|\___/|_| |_| \____/ \_/ \___|_| |_|\__|
//
// \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\                      
//    \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\                        
//       \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\                        
//          \\\\\\\\\\\\\\\\\\\\\\\\\\\\\                          
//            \\\\\\\\\\\\\\\\\\\\\\\\\\                           
//               \\\\\\\\\\\\\\\\\\\\\                             
//                  \\\\\\\\\\\\\\\\\                              
//                    \\\\\\\\\\\\\\                               
//                    \\\\\\\\\\\\\                                
//                    \\\\\\\\\\\\                                 
//                   \\\\\\\\\\\\                                  
//                  \\\\\\\\\\\\                                   
//                 \\\\\\\\\\\\                                    
//                \\\\\\\\\\\\                                     
//               \\\\\\\\\\\\                                      
//               \\\\\\\\\\\\                                      
//          `     \\\\\\\\\\\\      `    `                         
//             *    \\\\\\\\\\\\  *   *                            
//      `    *    *   \\\\\\\\\\\\   *  *   `                      
//              *   *   \\\\\\\\\\  *                              
//           `    *   * \\\\\\\\\ *   *   `                        
//        `    `     *  \\\\\\\\   *   `_____                      
//              \ \ \ * \\\\\\\  * /  /\`````\                    
//            \ \ \ \  \\\\\\  / / / /  \`````\                    
//          \ \ \ \ \ \\\\\\ / / / / |[] | [] |
//                                  EqPtz5qN7HM
//
// This contract lets people kickstart pair liquidity on uniswap together
// By pooling tokens together for a period of time
// A bundle of sticks makes one mighty liquidity pool
//
pragma solidity 0.6.12;


import './ICOREGlobals.sol';

import '@uniswap/v2-periphery/contracts/interfaces/IWETH.sol';

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol"; 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import './COREv1/ICoreVault.sol';

interface ICOREVault {
    function depositFor(address, uint256 , uint256 ) external;
}


interface IERC95 {
    function wrapAtomic(address) external;
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function skim(address to) external;
    function unpauseTransfers() external;

}


interface ICORETransferHandler {
    function sync(address) external returns(bool,bool);
    function feePercentX100() external returns (uint8); 

}

contract CORE_LGE_3 is Initializable, OwnableUpgradeSafe {

    using SafeMath for uint256;

    uint256 private locked;
    // Reentrancy lock 
    modifier lock() {
        require(locked == 1, 'CORE LGE: LOCKED');
        locked = 0;
        _; // Can't re-eter until function is finished
        locked = 1;
    }

    /// Addresses of different tokens
    address public WETH;
    address public CORE;
    address public DAI;
    address public cDAIxcCOREUniswapPair;
    address public cDAI;
    address public cCORE;
    address payable public CORE_MULTISIG;

    // Uniswap factories for recognising LP tokens
    address public uniswapFactory;
    address public sushiswapFactory;


    ////////////////////////////////////////
    // Variables for calculating LP gotten per each user
    // Note all contributions get "flattened" to CORE 
    // This means we just calculate how much CORE it would buy with the running average
    // And use that as the counter
    uint256 public totalLPCreated;    
    uint256 private totalCOREUnitsContributed;
    uint256 public LPPerCOREUnitContributed; // stored as 1e18 more - this is done for change
    ////////////////////////////////////////


    event Contibution(uint256 COREvalue, address from);
    event COREBought(uint256 COREamt);

    mapping(address => PriceAverage) _averagePrices;
    struct PriceAverage{
       uint8 lastAddedHead;
       uint256[20] price;
       uint256 cumulativeLast20Blocks;
       bool arrayFull;
       uint lastBlockOfIncrement; // Just update once per block ( by buy token function )
    }
    mapping (address => bool) public claimed; 
    mapping (address => bool) public doNotSellList;
    mapping (address => uint256) public credit;
    mapping (address => uint256) public tokenReserves;

    ICOREGlobals public coreGlobals;
    bool public LGEStarted;
    bool public LGEFinished;
    uint256 public contractStartTimestamp;
    uint256 public LGEDurationDays;

    function initialize() public initializer {
        require(msg.sender == address(0x5A16552f59ea34E44ec81E58b3817833E9fD5436));
        OwnableUpgradeSafe.__Ownable_init();

        contractStartTimestamp = uint256(-1); // wet set it here to max so checks fail
        LGEDurationDays = 7 days;

        DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        CORE = 0x62359Ed7505Efc61FF1D56fEF82158CcaffA23D7;
        WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        uniswapFactory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        sushiswapFactory = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
        CORE_MULTISIG = 0x5A16552f59ea34E44ec81E58b3817833E9fD5436;
        coreGlobals = ICOREGlobals(0x255CA4596A963883Afe0eF9c85EA071Cc050128B);

        doNotSellList[DAI] = true;
        doNotSellList[CORE] = true;

    }
    
    /// Starts LGE by admin call
    function startLGE() public onlyOwner {
        require(LGEStarted == false, "Already started");

        contractStartTimestamp = block.timestamp;
        LGEStarted = true;

        updateRunningAverages();
    }
    
    // Note selling tokens doesn't need slippage protection usually
    // Because front run bots dont hold, usually
    // but maybe rekt
    function sellTokenForWETH(address _token) internal returns (uint256 amountOut) {
        
        // we just sell on uni cause fuck you
        address pairWithWETH = IUniswapV2Factory(uniswapFactory).getPair(_token, WETH);
        require(pairWithWETH != address(0), "Unsupported shitcoin"); 

        IERC20 shitcoin = IERC20(_token);
        IUniswapV2Pair pair = IUniswapV2Pair(pairWithWETH);
        // check how much pair has
        uint256 balanceBefore = shitcoin.balanceOf(pairWithWETH); // can pumpthis, but fails later
        // Send all token to pair
        safeTransfer(_token, pairWithWETH, shitcoin.balanceOf(address(this))); // re
        // check how much it got
        uint256 balanceAfter = shitcoin.balanceOf(pairWithWETH);
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        
        // Make a swaperoo                    
        if(pair.token0() == _token) {
                                       // in, reservein, reserveout
            amountOut = getAmountOut(balanceAfter.sub(balanceBefore, "Fuqq"), reserve0, reserve1);
            pair.swap(amountOut, 0, address(this), "");
        } else {
            amountOut = getAmountOut(balanceAfter.sub(balanceBefore, "Fuqq"), reserve1, reserve0);
            pair.swap(0, amountOut, address(this), "");
        }

    }


    function getDAIxCOREBuyAmounts (uint256 contributionValueETH)
                internal view returns (uint256 COREBuyinETH,uint256 DAIBuyInETH){

        /// This ratio is flashloanable which would throw the peg off
        /// But this is not a priority here. As its not a profitable attack to the attacker.
        (uint256 COREValueETH, uint256 DAIValueETH) = getDAIandCOREReservesValueInETH();

        if(COREValueETH == DAIValueETH) return (contributionValueETH.div(2), contributionValueETH.div(2));

        if(COREValueETH > DAIValueETH) {

            // To equalibrium
            uint256 DAIBuyToEquilibrium = COREValueETH - DAIValueETH;

            if(DAIBuyToEquilibrium + 1 >= contributionValueETH) { // If its nto 2 wei we cant split
                return (0 , contributionValueETH);
            }

            // We take the equalibrium and check how many percent of total contribution it is
            uint256 restETH = contributionValueETH - DAIBuyToEquilibrium;

            DAIBuyInETH = DAIBuyToEquilibrium.add(restETH).div(2);
            COREBuyinETH = restETH.div(2);
            
        } else { // DAIValueETH is bigger than COREValueETH

            uint256 COREuyToEquilibrium = DAIValueETH - COREValueETH;

            if(COREuyToEquilibrium + 1 >= contributionValueETH) { // If its nto 2 wei we cant split
                return (contributionValueETH, 0);
            }

            uint256 restETH = contributionValueETH - COREuyToEquilibrium;
            COREBuyinETH = COREuyToEquilibrium.add(restETH).div(2);
            DAIBuyInETH = restETH.div(2);

        }

    }

    function getWETHValueOf1e8TokenUnits(address _token) internal view returns (uint256) {
         address pairWithWETH = IUniswapV2Factory(uniswapFactory).getPair(_token, WETH);
         if(pairWithWETH == address(0)) return 0;
         IUniswapV2Pair pair = IUniswapV2Pair(pairWithWETH);
         (uint256 reserve0, uint256 reserve1 ,) = pair.getReserves();

         if(pair.token0() == WETH) {
             return getAmountOut(1e8,reserve1,reserve0);
         } else {
             return getAmountOut(1e8,reserve0,reserve1);
         }
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal  pure returns (uint256 amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }


    function isLGEOver() public view returns (bool) {
        return block.timestamp > contractStartTimestamp.add(LGEDurationDays);
    }
    
    //////////////////////////////////////////////
    //////////////////////////////////////////////
    //////////////////////////////////////////////
    /// CONTRIBUTIONS
    /// Contributions user functions

    // Fallback deposits to ETH
    fallback() external payable {
        if(msg.sender != WETH) {
             addLiquidityETH();
        }
    }

    // Handling weth deposits
    function addLiquidityETH() lock public payable {
        IWETH(WETH).deposit{value: msg.value}();
        uint256 valueInCOREUnits = getAveragePriceLast20BlocksIn1WETHPriceWorth(CORE).mul(msg.value).div(1e18);
        credit[msg.sender] = credit[msg.sender].add(valueInCOREUnits);
    }

    // Main function to contribute any token
    // Which will sell eveyr token we don't keep for WETH
    function contributeWithAllowance(address _token, uint256 _amountContribution) public lock {

        require(LGEStarted == true, "LGE Didn't start");
        require(LGEFinished == false, "LGE : Liquidity generation finished");
        require(isLGEOver() == false, "LGE is over.");

        // We get the token from person safely
        // We check against reserves
        // We update our reserves with amount that flew in
        address [] memory tokensToSell;

        address token0;
        address token1;
        try IUniswapV2Pair(_token).token0() { token0 = IUniswapV2Pair(_token).token0(); } catch {}
        bool isUniLP;
        bool isSushiLP;

        // We try to get it before if it was a normal token it would just not get written
        if(token0 != address(0)) {
           token1 = IUniswapV2Pair(_token).token1();
           isUniLP = IUniswapV2Factory(uniswapFactory).getPair(token1,token0) !=  address(0);
           isSushiLP = IUniswapV2Factory(sushiswapFactory).getPair(token0,token1) !=  address(0);
        }

        // If its a LP we sell it
        if(isUniLP || isSushiLP) {
            safeTransferFrom(_token, msg.sender, _token, _amountContribution);
            IUniswapV2Pair(_token).burn(address(this));
            tokensToSell[0] = token0;
            tokensToSell[1] = token1;
        } else {
            tokensToSell[0] = _token;
        }

        // We loop over each token
        for (uint256 i = 0; i < tokensToSell.length; i++) {

            if(doNotSellList[tokensToSell[i]]) { // We dont sell this token aka its CORE or DAI

                // We count it as higher even tho FoT
                if(tokensToSell[i] == CORE) {

                    credit[msg.sender] = credit[msg.sender].add(_amountContribution); // we can trust this cause
                                                                          // we know CORE
                    tokenReserves[CORE] = tokenReserves[CORE].add(_amountContribution);
                    uint256 FoT = ICORETransferHandler(coreGlobals.TransferHandler()).feePercentX100();
                    uint256 postFoTValue = _amountContribution.mul(FoT).div(1000);
                    tokenReserves[CORE] = tokenReserves[CORE].add(postFoTValue);
                    emit Contibution(postFoTValue, msg.sender);
                }

                if(tokensToSell[i] == DAI) {
                    uint256 valueInCOREUnits = getAveragePriceLast20BlocksIn1WETHPriceWorth(DAI)
                                                .mul(_amountContribution).div(1e18);

                    credit[msg.sender] = credit[msg.sender].add(valueInCOREUnits);
                                                                        // We can similiary trust this cause we know DAI
                    tokenReserves[DAI] = IERC20(DAI).balanceOf(address(this)); 
                    emit Contibution(valueInCOREUnits, msg.sender);
                }

            // If its DAI we sell if for WETH if we have too much dai
            } else {
                
                uint256 amountOut = sellTokenForWETH(tokensToSell[i]);
                uint256 balanceWETHNew = IERC20(WETH).balanceOf(address(this));
                uint256 reserveWETH = tokenReserves[WETH];
                require(balanceWETHNew > reserveWETH, "sir.");
                require(amountOut == balanceWETHNew.sub(reserveWETH, "ser."), "Ekhm");
                tokenReserves[WETH] = balanceWETHNew;
                uint256 valueInCOREUnits = getAveragePriceLast20BlocksIn1WETHPriceWorth(CORE).mul(amountOut).div(1e18);
                credit[msg.sender] = credit[msg.sender].add(valueInCOREUnits);
                emit Contibution(valueInCOREUnits, msg.sender);

            }

            updateRunningAverages(); // After transactions are done

        }
    }

    /// Claiming LP User functions
    function claimLP() lock public {
        safeTransfer(cDAIxcCOREUniswapPair, msg.sender, _claimLP());
    }

    function claimAndStakeLP() lock public {
        address vault = coreGlobals.COREVaultAddress();
        IUniswapV2Pair(cDAIxcCOREUniswapPair).approve(vault, uint(-1));
        ICOREVault(vault).depositFor(msg.sender, 3, _claimLP());
    }

    function _claimLP() internal returns (uint256 claimable){ 
        uint256 credit = credit[msg.sender]; // gas savings

        require(LGEFinished == true, "LGE : Liquidity generation not finished");
        require(claimed[msg.sender] == false, "LGE : Already claimed");
        require(credit > 0, "LGE : Nothing to be claimed");

        claimable = credit.mul(LPPerCOREUnitContributed).div(1e18);
            // LPPerUnitContributed is stored at 1e18 multiplied

        claimed[msg.sender] =  true;
    }


    //////////////////////////////////////////////
    //////////////////////////////////////////////
    //////////////////////////////////////////////
    /// VIEWS

    // returns WETH value of both reserves (dai and CORE for internal purposes)
    function getDAIandCOREReservesValueInETH() internal view returns (uint256 COREValueETH, uint256 DAIValueETH) {
        (uint256 reserveCORE, uint256 reserveDAI) = (tokenReserves[CORE], tokenReserves[DAI]);
        COREValueETH = reserveCORE.div(1e8).mul(getWETHValueOf1e8TokenUnits(CORE));
        DAIValueETH = reserveDAI.div(1e8).mul(getWETHValueOf1e8TokenUnits(DAI));
    }

   // returns WETH value of both reserves (dai and CORE + WETH)
    function getLGEContributionsValue() public view returns (uint256 COREValueETH, uint256 DAIValueETH, uint256 ETHValue) {
        (uint256 reserveCORE, uint256 reserveDAI) = (tokenReserves[CORE], tokenReserves[DAI]);
        COREValueETH = reserveCORE.div(1e8).mul(getWETHValueOf1e8TokenUnits(CORE));
        DAIValueETH = reserveDAI.div(1e8).mul(getWETHValueOf1e8TokenUnits(DAI));
        ETHValue =  IERC20(WETH).balanceOf(address(this));
    }


    //////////////////////////////////////////////
    //////////////////////////////////////////////
    //////////////////////////////////////////////
    /// Admin balancing functions
    function buyCOREforWETH(uint256 amountWETH, uint256 minAmountCOREOut) onlyOwner public {
        (uint256 COREValueETH, uint256 DAIValueETH) = getDAIandCOREReservesValueInETH();
        require(COREValueETH.add(amountWETH) <= DAIValueETH, "Buying too much CORE");
        IUniswapV2Pair pair = IUniswapV2Pair(0x62359Ed7505Efc61FF1D56fEF82158CcaffA23D7);// CORE/WETH pair
        safeTransfer(WETH, address(pair), amountWETH);
        // CORE is token0
        (uint256 reservesCORE, uint256 reservesWETH, ) = pair.getReserves();
        uint256 coreOUT = getAmountOut(amountWETH, reservesWETH, reservesCORE);
        pair.swap(coreOUT, 0, address(this), "");
        tokenReserves[CORE] = tokenReserves[CORE].add(coreOUT);
        require(coreOUT >= minAmountCOREOut, "Buy Slippage too high");
        emit COREBought(coreOUT);
    }


    function buyDAIforWETH(uint256 amountWETH, uint256 minAmountDAIOut) onlyOwner public {
        IUniswapV2Pair pair = IUniswapV2Pair(0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11);// DAI/WETH pair
        safeTransfer(WETH, address(pair), amountWETH);
        // DAI is token0
        (uint256 reservesDAI, uint256 reservesWETH, ) = pair.getReserves();
        uint256 daiOUT = getAmountOut(amountWETH, reservesWETH, reservesDAI);
        pair.swap(daiOUT, 0, address(this), "");
        tokenReserves[DAI] = IERC20(DAI).balanceOf(address(this)); 
        require(daiOUT >= minAmountDAIOut, "Buy Slippage too high");
    }

    function sellDAIforWETH(uint256 amountDAI, uint256 minAmountWETH) onlyOwner public {
        IUniswapV2Pair pair = IUniswapV2Pair(0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11);// DAI/WETH pair
        safeTransfer(DAI, address(pair), amountDAI);
        // DAI is token0
        (uint256 reservesDAI, uint256 reservesWETH, ) = pair.getReserves();
        uint256 wethOUT = getAmountOut(amountDAI, reservesDAI, reservesWETH);
        pair.swap(0, wethOUT, address(this), "");
        tokenReserves[DAI] = IERC20(DAI).balanceOf(address(this)); 
        require(wethOUT >= minAmountWETH, "Buy Slippage too high");
    }   



    //////////////////////////////////////////////
    //////////////////////////////////////////////
    //////////////////////////////////////////////
    /// Anti flash loan manipulation running averages
    function updateRunningAverages() internal {
         if(_averagePrices[DAI].lastBlockOfIncrement != block.number) {
            _averagePrices[DAI].lastBlockOfIncrement = block.number;
            updateRunningAveragePrice(DAI, false);
          }
         if(_averagePrices[CORE].lastBlockOfIncrement != block.number) {
            _averagePrices[CORE].lastBlockOfIncrement = block.number;
            updateRunningAveragePrice(CORE, false);
         }
    }

    // This is out tokens per 1WETH (1e18 units)
    function getAveragePriceLast20BlocksIn1WETHPriceWorth(address token) public view returns (uint256) {
       return _averagePrices[token].cumulativeLast20Blocks.div(_averagePrices[token].arrayFull ? 20 : _averagePrices[token].lastAddedHead);
       // We check if the "array is full" because 20 writes might not have happened yet
       // And therefor the average would be skewed by dividing it by 20
    }


    // NOTE outTokenFor1WETH < lastQuote.mul(150).div(100) check
    function updateRunningAveragePrice(address token, bool isRescue) internal returns (uint256) {

        PriceAverage storage currentAveragePrices =  _averagePrices[token];
        address pairWithWETH = IUniswapV2Factory(uniswapFactory).getPair(token, WETH);
        (uint256 wethReserves, uint256 tokenReserves,) = IUniswapV2Pair(pairWithWETH).getReserves();
        // Get amt you would get for 1eth
        uint256 outTokenFor1WETH = getAmountOut(1e18, wethReserves, tokenReserves);

        uint8 i = currentAveragePrices.lastAddedHead;
        
        ////////////////////
        /// flash loan safety
        //we check the last quote for comparing to this one
        uint256 lastQuote;
        if(i == 0) {
            lastQuote = currentAveragePrices.price[19];
        }
        else {
            lastQuote = currentAveragePrices.price[i - 1];
        }

        // Safety flash loan revert
        // If change is above 50%
        // This can be rescued by the bool "isRescue"
        if(lastQuote != 0 && isRescue == false){
            require(outTokenFor1WETH < lastQuote.mul(15000).div(10000), "Change too big from previous price");
        }
        ////////////////////
        
        currentAveragePrices.cumulativeLast20Blocks = currentAveragePrices.cumulativeLast20Blocks.sub(currentAveragePrices.price[i]);
        currentAveragePrices.price[i] = outTokenFor1WETH;
        currentAveragePrices.cumulativeLast20Blocks = currentAveragePrices.cumulativeLast20Blocks.add(outTokenFor1WETH);
        currentAveragePrices.lastAddedHead++;
        if(currentAveragePrices.lastAddedHead > 19) {
            currentAveragePrices.lastAddedHead = 0;
            currentAveragePrices.arrayFull = true;
        }
        return currentAveragePrices.cumulativeLast20Blocks;
    }

    // Because its possible that price of someting legitimately goes +50%
    // Then the updateRunningAveragePrice would be stuck until it goes down,
    // This allows the admin to "rescue" it by writing a new average
    // skiping the +50% check
    function rescueRatioLock(address token) public onlyOwner{
        updateRunningAveragePrice(token, true);
    }


    //////////////////////////////////////////////
    //////////////////////////////////////////////
    //////////////////////////////////////////////
    /// Ending the LGE
    function addLiquidityToPair() public onlyOwner {
        require(block.timestamp > contractStartTimestamp.add(LGEDurationDays), "LGE : Liquidity generation ongoing");
        require(LGEFinished == false, "LGE : Liquidity generation finished");
        require(IERC20(WETH).balanceOf(address(this)) < 1 ether, "Too much WETH still left over in the contract");
        
        (uint256 COREValueETH, uint256 DAIValueETH) = getDAIandCOREReservesValueInETH();

        //If there is too much CORE we just take it from the top, no refunds in LGE3
        if(COREValueETH > DAIValueETH) {
            uint256 DELTA = COREValueETH - DAIValueETH;
            uint256 percentOfCORETooMuch = DELTA.mul(1e18).div(COREValueETH); // carry 1e18
            // Skim too much
            safeTransfer(CORE, CORE_MULTISIG, COREValueETH.mul(percentOfCORETooMuch).div(1e18));
        }

        // Else DAI is bigger value, we just allow it to be 4% bigger max 
        // We set max deviation from price of 4%
        require(COREValueETH.mul(104).div(100) > DAIValueETH, "Deviation from current price is too high" );

        // !!!!!!!!!!!
        //unlock wrapping
        IERC95(cCORE).unpauseTransfers();
        IERC95(cDAI).unpauseTransfers();
        //!!!!!!!!!

        // Optimistically get pair
        cDAIxcCOREUniswapPair = IUniswapV2Factory(uniswapFactory).getPair(cCORE , cDAI);
        if(cDAIxcCOREUniswapPair == address(0)) { // Pair doesn't exist yet 
            // create pair returns address
            cDAIxcCOREUniswapPair = IUniswapV2Factory(uniswapFactory).createPair(
                cDAI,
                cCORE
            );
        }


        uint256 balanceCORE = IERC20(CORE).balanceOf(address(this));
        uint256 balanceDAI = IERC20(CORE).balanceOf(address(this));
        uint256 DEV_FEE = 1000; 
        address CORE_MULTISIG = ICoreVault(coreGlobals.COREVaultAddress()).devaddr();
        uint256 devFeeCORE = balanceCORE.mul(DEV_FEE).div(10000);
        uint256 devFeeDAI = balanceDAI.mul(DEV_FEE).div(10000);


        // transfer dev fee
        safeTransfer(CORE, CORE_MULTISIG, devFeeCORE);
        safeTransfer(DAI, CORE_MULTISIG, devFeeDAI);

        // Wrap and send to uniswap pair
        safeTransfer(CORE, cCORE, balanceCORE.sub(devFeeCORE));
        safeTransfer(DAI, cDAI, balanceDAI.sub(devFeeDAI));
        IERC95(cCORE).wrapAtomic(cDAIxcCOREUniswapPair);
        IERC95(cDAI).wrapAtomic(cDAIxcCOREUniswapPair);

        require(IERC95(cDAI).balanceOf(cDAIxcCOREUniswapPair) == balanceDAI.sub(devFeeDAI), "Pair did not recieve enough DAI");
        require(IERC95(cCORE).balanceOf(cDAIxcCOREUniswapPair) == balanceCORE.sub(devFeeCORE), "Pair did not recieve enough CORE");


        // Mint tokens from uniswap pair
        IUniswapV2Pair pair = IUniswapV2Pair(cDAIxcCOREUniswapPair); // cCORE/cDAI pair
        
        //we get lp tokens
        require(pair.totalSupply() == 0, "Somehow total supply is higher, sanity fail");
        pair.mint(address(this));
        require(pair.totalSupply() > 0, "We didn't create tokens!");

        totalLPCreated = pair.balanceOf(address(this));
        LPPerCOREUnitContributed = totalLPCreated.mul(1e18).div(totalCOREUnitsContributed); // Stored as 1e18 more for round erorrs and change
        require(LPPerCOREUnitContributed > 0, "LP Per Unit Contribute Must be above Zero");

        //Sync pair
        ICORETransferHandler(coreGlobals.TransferHandler()).sync(cDAIxcCOREUniswapPair);

        LGEFinished = true;

    }

    //////////////////////////////////////////////
    //////////////////////////////////////////////
    //////////////////////////////////////////////
    /// Helper functions


    // If LGE doesn't trigger in 24h after its complete its possible to withdraw tokens
    // Because then we can assume something went wrong since LGE is a publically callable function
    // And otherwise everything is stuck.
    function safetyTokenWithdraw(address token) onlyOwner public {
        require(block.timestamp > contractStartTimestamp.add(LGEDurationDays).add(1 days));
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }
    function safetyETHWithdraw() onlyOwner public {
        require(block.timestamp > contractStartTimestamp.add(LGEDurationDays).add(1 days));
        msg.sender.call.value(address(this).balance)("");
    }

    // Added safety function to extend LGE in case multisig #2 isn't avaiable from emergency life events
    // TODO x3 add your key here
    function extendLGE(uint256 numHours) public {
        require(msg.sender == 0x82810e81CAD10B8032D39758C8DBa3bA47Ad7092 || msg.sender == 0xC91FE1ee441402D854B8F22F94Ddf66618169636, "LGE: Requires admin");
        require(numHours <= 24);
        LGEDurationDays = LGEDurationDays.add(numHours.mul(1 hours));
    }

    
    function safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'LGE3: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'LGE3: TRANSFER_FROM_FAILED');
    }
   
    


    
}
