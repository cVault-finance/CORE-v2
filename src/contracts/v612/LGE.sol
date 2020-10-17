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

// import '@uniswap/v2-periphery/contracts/libraries/IUniswapV2Library.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IWETH.sol';
// import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

import "@openzeppelin/contracts/access/Ownable.sol"; 
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol"; 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import './COREv1/ICoreVault.sol';
import "@nomiclabs/buidler/console.sol";

// import '@uniswap/v2-core/contracts/UniswapV2Pair.sol';

library COREIUniswapV2Library {
    
    using SafeMath for uint256;

    // Copied from https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/libraries/IUniswapV2Library.sol
    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'IUniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'IUniswapV2Library: ZERO_ADDRESS');
    }

        // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal  returns (uint256 amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        console.log("Inside getAmountOut from uniswap got amountIn of", amountIn);
        uint amountInWithFee = amountIn.mul(997);
        console.log("multiplied by 997 its",amountInWithFee);
        console.log("Reserve out is",reserveOut);

        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        console.log("Reserve in ",reserveIn);
        console.log( "So numerator is", numerator, "and denominator is", denominator);

        amountOut = numerator / denominator;
        console.log("So amount out is ", amountOut);
    }

}

interface IERC95 {
    function wrapAtomic(address) external;
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function skim(address to) external;
    function unpauseTransfers() external;

}

interface CERC95 {
    function wrapAtomic(address) external;
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function skim(address to) external;
    function name() external view returns (string memory);
}


interface ICORETransferHandler {
    function sync(address) external;
}

contract cLGE is Ownable, ReentrancyGuard {

    using SafeMath for uint256;


    /// CORE gets deposited straight never sold - refunded if balance is off at end
    // Others get sold if needed
    // ETH always gets sold into XXX from CORE/XXX
    
    IERC20 public tokenBeingWrapped;
    address public coreEthPair;
    address public wrappedToken;
    address public preWrapEthPair;
    address immutable public COREToken;
    address public _WETH;
    address public wrappedTokenUniswapPair;
    address public uniswapFactory;

    ///////////////////////////////////////
    // Note this 3 are not supposed to be actual contributed because of the internal swaps
    // But contributed by people, before internal swaps
    uint256 public totalETHContributed;
    uint256 public totalCOREContributed;
    uint256 public totalWrapTokenContributed;
    ////////////////////////////////////////



    ////////////////////////////////////////
    // Internal balances user to calculate canges
    // Note we dont have WETH here because it all goes out
    uint256 private wrappedTokenBalance;
    uint256 private COREBalance;
    ////////////////////////////////////////

    ////////////////////////////////////////
    // Variables for calculating LP gotten per each user
    // Note all contributions get "flattened" to CORE 
    // This means we just calculate how much CORE it would buy with the running average
    // And use that as the counter
    uint256 public totalCOREToRefund; // This is in case there is too much CORE in the contract we refund people who contributed CORE proportionally
                                      // Potential scenario where someone swapped too much ETH/WBTC into CORE causing too much CORE to be in the contract
                                      // and subsequently being not refunded because he didn't contribute CORE but bought CORE for his ETH/WETB
                                      // Was noted and decided that the impact of this is not-significant
    uint256 public totalLPCreated;    
    uint256 private totalUnitsContributed;
    uint256 public LPPerUnitContributed; // stored as 1e8 more - this is done for change
    ////////////////////////////////////////


    event Contibution(uint256 COREvalue, address from);
    event COREBought(uint256 COREamt, address from);

    mapping (address => uint256) public COREContributed; // We take each persons core contributed to calculate units and 
                                                        // to calculate refund later from totalCoreRefund + CORE total contributed
    mapping (address => uint256) public unitsContributed; // unit to keep track how much each person should get of LP
    mapping (address => uint256) public unitsClaimed; 
    mapping (address => bool) public CORERefundClaimed; 
    mapping (address => address) public pairWithWETHAddressForToken; 

    mapping (address => uint256) public wrappedTokenContributed; // To calculate units
                                                                 // Note eth contributed will turn into this and get counted
    ICOREGlobals public coreGlobals;
    bool public LGEStarted;
    uint256 public contractStartTimestamp;
    uint256 public LGEDurationDays;
    bool public LGEFinished;

    constructor(uint256 daysLong, address _wrappedToken, address _coreGlobals, address _preWrapEthPair) public {
        contractStartTimestamp = uint256(-1); // wet set it here to max so checks fail
        LGEDurationDays = daysLong.mul(1 days);
        coreGlobals = ICOREGlobals(_coreGlobals);
        coreEthPair = coreETHPairGetter();
        (COREToken, _WETH) = (IUniswapV2Pair(coreEthPair).token0(), IUniswapV2Pair(coreEthPair).token1()); // bb
        console.log("Address WETH= ", _WETH);
        address tokenBeingWrappedAddress = IUniswapV2Pair(_preWrapEthPair).token1(); // bb
        tokenBeingWrapped =  IERC20(tokenBeingWrappedAddress); 

        console.log("In constructor pair, prewrap eth pair pair is " , _preWrapEthPair, CERC95(_preWrapEthPair).name());
        console.log("tokenBeingWrapped (token0) is ", tokenBeingWrappedAddress, CERC95(tokenBeingWrappedAddress).name());

        pairWithWETHAddressForToken[address(tokenBeingWrapped)] = _preWrapEthPair;
        pairWithWETHAddressForToken[IUniswapV2Pair(coreEthPair).token0()] = coreEthPair;// bb 


        wrappedToken = _wrappedToken;
        preWrapEthPair = _preWrapEthPair;
        uniswapFactory = coreGlobals.UniswapFactory();
    }

    /// Starts LGE by admin call
    function startLGE() public onlyOwner {
        require(LGEStarted == false, "Already started");
        console.log("Starting LGE on block", block.number);
        contractStartTimestamp = block.number;
        LGEStarted = true;

        updateRunningAverages();
    }


    function claimLP() nonReentrant public { 
        require(LGEFinished == true, "LGE : Liquidity generation not finished");
        require(unitsContributed[msg.sender].sub(unitsClaimed[msg.sender]) > 0, "LEG : Nothing to claim");

        IUniswapV2Pair(wrappedTokenUniswapPair)
            .transfer(msg.sender, unitsContributed[msg.sender].mul(LPPerUnitContributed).div(1e8));
            // LPPerUnitContributed is stored at 1e8 multiplied

        unitsClaimed[msg.sender] = unitsContributed[msg.sender];
    }

    function buyToken(address tokenTarget, uint256 amtToken, address tokenSwapping, uint256 amtTokenSwappingInput, address pair) internal {
        console.log(" > LGE.sol::buyToken(address tokenTarget, uint256 amtToken, address tokenSwapping, uint256 amtTokenSwappingInput, address pair) internal");
        (address token0, address token1) = COREIUniswapV2Library.sortTokens(tokenSwapping, tokenTarget);


        console.log("Transfering token", CERC95(tokenSwapping).name(), "To Uniswap");
        console.log("For amount", amtTokenSwappingInput);
        console.log("And I have", IERC20(tokenSwapping).balanceOf(address(this)), CERC95(tokenSwapping).name());
        IERC20(tokenSwapping).transfer(pair, amtTokenSwappingInput);

        console.log("Performing Uniswap swap from", CERC95(tokenSwapping).name(), " to ", CERC95(tokenTarget).name());
        console.log("Buying ", amtToken, "of", CERC95(tokenSwapping).name()); 
        if(tokenTarget == token0) {
             IUniswapV2Pair(pair).swap(amtToken, 0, address(this), "");
        }
        else {
            IUniswapV2Pair(pair).swap(0, amtToken, address(this), "");
        }

        if(tokenTarget == COREToken){
            emit COREBought(amtToken, msg.sender);
        }
        
        updateRunningAverages();
    }

    function updateRunningAverages() internal{
         if(_averagePrices[address(tokenBeingWrapped)].lastBlockOfIncrement != block.number) {
            _averagePrices[address(tokenBeingWrapped)].lastBlockOfIncrement = block.number;
            updateRunningAveragePrice(address(tokenBeingWrapped), false);
          }
         if(_averagePrices[COREToken].lastBlockOfIncrement != block.number) {
            _averagePrices[COREToken].lastBlockOfIncrement = block.number;
            updateRunningAveragePrice(COREToken, false);
         }
    }


    function coreETHPairGetter() public view returns (address) {
        return coreGlobals.COREWETHUniPair();
    }


    function getPairReserves(address pair) internal view returns (uint256 wethReserves, uint256 tokenReserves) {
        console.log("calling pair pair is :", pair);
        address token0 = IUniswapV2Pair(pair).token0();
        (uint256 reserve0, uint reserve1,) = IUniswapV2Pair(pair).getReserves();
        (wethReserves, tokenReserves) = token0 == _WETH ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function finalizeTokenWrapAddress(address _wrappedToken) onlyOwner public {
        wrappedToken = _wrappedToken;
    }

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


    function addLiquidityAtomic() public {
        console.log(" > LGE.sol::addLiquidityAtomic()");
        require(LGEStarted == true, "LGE Didn't start");
        require(LGEFinished == false, "LGE : Liquidity generation finished");
        // require(token == _WETH || token == COREToken || token == address(tokenBeingWrapped) || token == preWrapEthPair, "Unsupported deposit token");

        if(IUniswapV2Pair(preWrapEthPair).balanceOf(address(this)) > 0) {
            // Special carveout because unwrap calls this funciton
            // Since unwrap will add both WETH and tokenwrapped
            unwrapLiquidityTokens();
        } else{
            ( uint256 tokenBeingWrappedPer1ETH, uint256 coreTokenPer1ETH) = getHowMuch1WETHBuysOfTokens();


             // Check WETH if there is swap for CORRE or WBTC depending
             // Check WBTC and swap for core or not depending on peg
            uint256 balWETH = IERC20(_WETH).balanceOf(address(this));
            // No need to upate it because we dont retain WETH

            uint256 totalCredit; // In core units

            // Handling weth
            if(balWETH > 0){
                totalETHContributed = totalETHContributed.add(balWETH);
                totalCredit = handleWETHLiquidityAddition(balWETH,tokenBeingWrappedPer1ETH,coreTokenPer1ETH);
                // No other number should be there since it just started a line above
            }

            // Handling core wrap deposits
            // we check change from reserves
            uint256 tokenBeingWrappedBalNow = IERC20(tokenBeingWrapped).balanceOf(address(this));
            uint256 tokenBeingWrappedBalChange = tokenBeingWrappedBalNow.sub(wrappedTokenBalance);
            // If its bigger than 0 we handle
            if(tokenBeingWrappedBalChange > 0) {
                totalWrapTokenContributed = totalWrapTokenContributed.add(tokenBeingWrappedBalChange);
                // We update reserves
                wrappedTokenBalance = tokenBeingWrappedBalNow;
                // We add wrapped token contributionsto the person this is for stats only
                wrappedTokenContributed[msg.sender] = wrappedTokenContributed[msg.sender].add(tokenBeingWrappedBalChange);
                // We check how much credit he got that returns from this function
                totalCredit = totalCredit.add(  handleTokenBeingWrappedLiquidityAddition(tokenBeingWrappedBalChange,tokenBeingWrappedPer1ETH,coreTokenPer1ETH) );
            }           

            // we check core balance against reserves
            // Note this is FoT token safe because we check balance of this 
            // And not accept user input
            uint256 COREBalNow = IERC20(COREToken).balanceOf(address(this));
            uint256 balCOREChange = COREBalNow.sub(COREBalance);
            if(balCOREChange > 0) {
                COREContributed[msg.sender] = COREContributed[msg.sender].add(balCOREChange);
                totalCOREContributed = totalCOREContributed.add(balCOREChange);
            }
            // Reset reserves
            COREBalance = COREBalNow;

            uint256 unitsChange = totalCredit.add(balCOREChange);
            // Gives people balances based on core units, if Core is contributed then we just append it to it without special logic
            unitsContributed[msg.sender] = unitsContributed[msg.sender].add(unitsChange);
            totalUnitsContributed = totalUnitsContributed.add(unitsChange);
            emit Contibution(totalCredit, msg.sender);
        
        }
    }

    function handleTokenBeingWrappedLiquidityAddition(uint256 amt,uint256 tokenBeingWrappedPer1ETH,uint256 coreTokenPer1ETH) internal  returns (uint256 coreUnitsCredit) {
        // VERY IMPRECISE TODO
        uint256 outWETH;
        (uint256 reserveWETHofWrappedTokenPair, uint256 reserveTokenofWrappedTokenPair) = getPairReserves(preWrapEthPair);

        if(COREBalance.div(coreTokenPer1ETH) <= wrappedTokenBalance.div(tokenBeingWrappedPer1ETH)) {
            // swap for eth
            outWETH = COREIUniswapV2Library.getAmountOut(amt, reserveTokenofWrappedTokenPair, reserveWETHofWrappedTokenPair);
            console.log("I got a wrapped token deposit, figuring out how much ETH i get for ",amt,"of it - its", outWETH);
            console.log("Pair reserves of wrapped token are : wrapped token - ",reserveTokenofWrappedTokenPair, "and weth -", reserveWETHofWrappedTokenPair);
            buyToken(_WETH, outWETH, address(tokenBeingWrapped) , amt, preWrapEthPair);
            // buy core
            (uint256 buyReserveWeth, uint256 reserveCore) = getPairReserves(coreEthPair);
            uint256 outCore = COREIUniswapV2Library.getAmountOut(outWETH, buyReserveWeth, reserveCore);
            buyToken(COREToken, outCore, _WETH ,outWETH,coreEthPair);
        } else {
            // Dont swap just calculate out and credit and leave as is
            outWETH = COREIUniswapV2Library.getAmountOut(amt, reserveTokenofWrappedTokenPair , reserveWETHofWrappedTokenPair);
        }

        // Out weth is in 2 branches
        // We give credit to user contributing
        coreUnitsCredit = outWETH.mul(coreTokenPer1ETH).div(1e18);
    }

    function handleWETHLiquidityAddition(uint256 amt,uint256 tokenBeingWrappedPer1ETH,uint256 coreTokenPer1ETH) internal returns (uint256 coreUnitsCredit) {
        // VERY IMPRECISE TODO

        // We check if corebalance in ETH is smaller than wrapped token balance in eth
        if(COREBalance.div(coreTokenPer1ETH) <= wrappedTokenBalance.div(tokenBeingWrappedPer1ETH)) {
            // If so we buy core
            (uint256 reserveWeth, uint256 reserveCore) = getPairReserves(coreEthPair);
            uint256 outCore = COREIUniswapV2Library.getAmountOut(amt, reserveWeth, reserveCore);
            //we buy core
            buyToken(COREToken, outCore,_WETH,amt, coreEthPair);

            // amt here is weth contributed
        } else {
            (uint256 reserveWeth, uint256 reserveToken) = getPairReserves(preWrapEthPair);
            uint256 outToken = COREIUniswapV2Library.getAmountOut(amt, reserveWeth, reserveToken);
            console.log("I'm trying to figure out hwo much of wrapped token to buy",outToken);
            // we buy wrappedtoken
            buyToken(address(tokenBeingWrapped), outToken,_WETH, amt,preWrapEthPair);

           //We buy outToken of the wrapped token and add it here
            wrappedTokenContributed[msg.sender] = wrappedTokenContributed[msg.sender].add(outToken);
        }
        // we credit user for ETH/ multiplied per core per 1 eth and then divided by 1 weth meaning we get exactly how much core it would be
        // in the running average
        coreUnitsCredit = amt.mul(coreTokenPer1ETH).div(1e18);

    }


    function getHowMuch1WETHBuysOfTokens() public view returns (uint256 tokenBeingWrappedPer1ETH, uint256 coreTokenPer1ETH) {
        return (getAveragePriceLast20Blocks(address(tokenBeingWrapped)), getAveragePriceLast20Blocks(COREToken));
    }


    //TEST TASK : Check if liquidity is added via just ending ETH to contract
    fallback() external payable {
        console.log("hit fallback");
        if(msg.sender != _WETH) {
             addLiquidityETH();
        }
    }

    //TEST TASK : Check if liquidity is added via calling this function
    function addLiquidityETH() nonReentrant public payable {
        console.log(" > LGE.sol::addLiquidityETH() nonReentrant public payable");
        // wrap weth
        console.log("Depositing ETH of value", msg.value);
        console.log("WETH address in liq addition", _WETH);
        IWETH(_WETH).deposit{value: msg.value}();
        console.log("Depsosited WETH");
        addLiquidityAtomic();
    }

    // TEST TASK : check if this function deposits tokens
    function addLiquidityWithTokenWithAllowance(address token, uint256 amount) public nonReentrant {
        console.log(" > LGE.sol::addLiquidityWithTokenWithAllowance(address token, uint256 amount) public nonReentrant");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        addLiquidityAtomic();
    }   

    // We burn liquiidyt from WBTC/ETH pair
    // And then send it to this ontract
    // Wrap atomic will handle both deposits of WETH and wrappedtoken
    function unwrapLiquidityTokens() internal {
        console.log(" > LGE.sol::unwrapLiquidityTokens() internal");
        IUniswapV2Pair pair = IUniswapV2Pair(preWrapEthPair);
        pair.transfer(preWrapEthPair, pair.balanceOf(address(this)));
        pair.burn(address(this));
        addLiquidityAtomic();
    }



    // TODO

    mapping(address => PriceAverage) _averagePrices;
    struct PriceAverage{
       uint8 lastAddedHead;
       uint256[20] price;
       uint256 cumulativeLast20Blocks;
       bool arrayFull;
       uint lastBlockOfIncrement; // Just update once per block ( by buy token function )
    }

    // This is out tokens per 1WETH (1e18 units)
    function getAveragePriceLast20Blocks(address token) public view returns (uint256){
        console.log("Inside view average price last head is ", _averagePrices[token].lastAddedHead);
        console.log("Inside view average price token is ", token, CERC95(token).name());
        console.log("Inside view average cumulative is ", _averagePrices[token].cumulativeLast20Blocks);
        console.log("Inside view average last block is is ", _averagePrices[token].lastBlockOfIncrement);

       return _averagePrices[token].cumulativeLast20Blocks.div(_averagePrices[token].arrayFull ? 20 : _averagePrices[token].lastAddedHead);
       // We check if the "array is full" because 20 writes might not have happened yet
       // And therefor the average would be skewed by dividing it by 20
    }


    // NOTE outTokenFor1WETH < lastQuote.mul(150).div(100) check
    function updateRunningAveragePrice(address token, bool isRescue) public returns (uint256) {
        console.log("Incrementing average of address", CERC95(token).name());
        PriceAverage storage currentAveragePrices =  _averagePrices[token];
        address pairWithWETH = pairWithWETHAddressForToken[token];
        (uint256 wethReserves, uint256 tokenReserves) = getPairReserves(address(pairWithWETH));
        // Get amt you would get for 1eth
        uint256 outTokenFor1WETH = COREIUniswapV2Library.getAmountOut(1e18, wethReserves, tokenReserves);

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
        console.log("Last average is ", lastQuote);
        console.log("Current Price is ", outTokenFor1WETH);

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



    // Protect form people atomically calling for LGE generation [x]
    // Price manipulation protections
    // use TWAP [x] custom 20 blocks
    // Set max diviation from last trade - not needed [ ]
    // re-entrancy protection [x]
    // dev tax [x]
    function addLiquidityToPairPublic() nonReentrant public{
        addLiquidityToPair(true);
    }

    // Safety function that can call public add liquidity before
    // This is in case someone manipulates the 20 liquidity addition blocks 
    // and screws up the ratio
    // Allows admins 2 hours to rescue the contract.
    function addLiquidityToPairAdmin() nonReentrant onlyOwner public{
        addLiquidityToPair(false);
    }

    function getCOREREfund() nonReentrant public {
        require(LGEFinished == true, "LGE not finished");
        require(totalCOREToRefund > 0 , "No refunds");
        require(COREContributed[msg.sender] > 0, "You didn't contribute anything");
        // refund happens just once
        require(CORERefundClaimed[msg.sender] == false , "You already claimed");
        
        // To get refund we get the core contributed of this user
        // divide it by total core to get the percentage of total this user contributed
        // And then multiply that by total core
        uint256 COREToRefundToThisPerson = COREContributed[msg.sender].mul(1e12).div(totalCOREContributed).
            mul(totalCOREContributed).div(1e12);

        CORERefundClaimed[msg.sender] = true;
        IERC20(COREToken).transfer(msg.sender,COREToRefundToThisPerson);

    }

    function addLiquidityToPair(bool publicCall)  internal {
        require(block.timestamp > contractStartTimestamp.add(LGEDurationDays).add(publicCall ? 2 hours : 0), "LGE : Liquidity generaiton ongoing");
        require(LGEFinished == false, "LGE : Liquidity generation finished");
        
        // !!!!!!!!!!!
        //unlock wrapping
        IERC95(wrappedToken).unpauseTransfers();
        //!!!!!!!!!


        // wrap token
        tokenBeingWrapped.transfer(wrappedToken, tokenBeingWrapped.balanceOf(address(this)));
        IERC95(wrappedToken).wrapAtomic(address(this));
        IERC95(wrappedToken).skim(address(this)); // In case

        // Optimistically get pair
        wrappedTokenUniswapPair = IUniswapV2Factory(coreGlobals.UniswapFactory()).getPair(COREToken , wrappedToken);
        if(wrappedTokenUniswapPair == address(0)) { // Pair doesn't exist yet 
            // create pair returns address
            wrappedTokenUniswapPair = IUniswapV2Factory(coreGlobals.UniswapFactory()).createPair(
                COREToken,
                wrappedToken
            );
        }

        //send dev fee
        // 7.24% 
        uint256 DEV_FEE = 724; // TODO: DEV_FEE isn't public //ICoreVault(coreGlobals.COREVault).DEV_FEE();
        address devaddress = ICoreVault(coreGlobals.COREVaultAddress()).devaddr();
        IERC95(wrappedToken).transfer(devaddress, IERC95(wrappedToken).balanceOf(address(this)).mul(DEV_FEE).div(10000));
        IERC20(COREToken).transfer(devaddress, IERC20(COREToken).balanceOf(address(this)).mul(DEV_FEE).div(10000));

        //calculate core refund
        uint256 balanceCORENow = IERC20(COREToken).balanceOf(address(this));
        uint256 balanceCOREWrappedTokenNow = IERC95(wrappedToken).balanceOf(address(this));

        ( uint256 tokenBeingWrappedPer1ETH, uint256 coreTokenPer1ETH)  = getHowMuch1WETHBuysOfTokens();

        uint256 totalValueOfWrapper = balanceCOREWrappedTokenNow.mul(tokenBeingWrappedPer1ETH).div(1e18);
        uint256 totalValueOfCORE =  balanceCORENow.mul(coreTokenPer1ETH).div(1e18);

        totalCOREToRefund = totalValueOfWrapper >= totalValueOfCORE ? 0: 
                    totalValueOfCORE.sub(totalValueOfWrapper).mul(coreTokenPer1ETH).div(1e18);


        // send tokenwrap
        IERC95(wrappedToken).transfer(wrappedTokenUniswapPair, IERC95(wrappedToken).balanceOf(address(this)));

        // send core without the refund
        IERC20(COREToken).transfer(wrappedTokenUniswapPair, balanceCORENow.sub(totalCOREToRefund));

        // mint LP to this adddress
        IUniswapV2Pair(wrappedTokenUniswapPair).mint(address(this));

        // check how much was minted
        totalLPCreated = IUniswapV2Pair(wrappedTokenUniswapPair).balanceOf(address(this));

        // calculate minted per contribution
        LPPerUnitContributed = totalLPCreated.mul(1e8).div(totalUnitsContributed); // Stored as 1e8 more for round erorrs and change

        // set LGE to complete
        LGEFinished = true;

        //sync the tokens
        ICORETransferHandler(coreGlobals.transferHandler()).sync(wrappedToken);
        ICORETransferHandler(coreGlobals.transferHandler()).sync(COREToken);

    }
    


    
}