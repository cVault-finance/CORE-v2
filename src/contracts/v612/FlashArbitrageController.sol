pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/lib/contracts/libraries/SafeERC20Namer.sol';
// import "hardhat/console.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";


// _________  ________ _____________________                                             
// \_   ___ \ \_____  \\______   \_   _____/                                             
// /    \  \/  /   |   \|       _/|    __)_                                              
// \     \____/    |    \    |   \|        \                                             
//  \______  /\_______  /____|_  /_______  /                                             
//         \/         \/       \/        \/                                              
// ___________.____       _____    _________ ___ ___                                     
// \_   _____/|    |     /  _  \  /   _____//   |   \                                    
//  |    __)  |    |    /  /_\  \ \_____  \/    ~    \                                   
//  |     \   |    |___/    |    \/        \    Y    /                                   
//  \___  /   |_______ \____|__  /_______  /\___|_  /                                    
//      \/            \/       \/        \/       \/                                     
//    _____ ____________________.________________________    _____    ___________________
//   /  _  \\______   \______   \   \__    ___/\______   \  /  _  \  /  _____/\_   _____/
//  /  /_\  \|       _/|    |  _/   | |    |    |       _/ /  /_\  \/   \  ___ |    __)_ 
// /    |    \    |   \|    |   \   | |    |    |    |   \/    |    \    \_\  \|        \
// \____|__  /____|_  /|______  /___| |____|    |____|_  /\____|__  /\______  /_______  /
//         \/       \/        \/                       \/         \/        \/        \/ 
//  Controller
//
// This contract checks for opportunities to gain profit for all of DEXs out there
// But especially the CORE ecosystem because this contract can tell another contrac to turn feeOff for the duration of its trades
// By arbitraging all existing pools, and transfering profits to FeeSplitter
// That will add rewards to specific pools to keep them at X% APY
// And add liquidity and subsequently burn the liquidity tokens after all pools reach this threashold
//
//      .edee...      .....       .eeec.   ..eee..
//    .d*"  """"*e..d*"""""**e..e*""  "*c.d""  ""*e.
//   z"           "$          $""       *F         **e.
//  z"             "c        d"          *.           "$.
// .F                        "            "            'F
// d                                                   J%
// 3         .                                        e"
// 4r       e"              .                        d"
//  $     .d"     .        .F             z ..zeeeeed"
//  "*beeeP"      P        d      e.      $**""    "
//      "*b.     Jbc.     z*%e.. .$**eeeeP"
//         "*beee* "$$eeed"  ^$$$""    "
//                  '$$.     .$$$c
//                   "$$.   e$$*$$c
//                    "$$..$$P" '$$r
//                     "$$$$"    "$$.           .d
//         z.          .$$$"      "$$.        .dP"
//         ^*e        e$$"         "$$.     .e$"
//           *b.    .$$P"           "$$.   z$"
//            "$c  e$$"              "$$.z$*"
//             ^*e$$P"                "$$$"
//               *$$                   "$$r
//               '$$F                 .$$P
//                $$$                z$$"
//                4$$               d$$b.
//                .$$%            .$$*"*$$e.
//             e$$$*"            z$$"    "*$$e.
//            4$$"              d$P"        "*$$e.
//            $P              .d$$$c           "*$$e..
//           d$"             z$$" *$b.            "*$L
//          4$"             e$P"   "*$c            ^$$
//          $"            .d$"       "$$.           ^$r
//         dP            z$$"         ^*$e.          "b
//        4$            e$P             "$$           "
//                     J$F               $$
//                     $$               .$F
//                    4$"               $P"
//                    $"               dP    kjRWG0tKD4A
//
// I'll have you know...
interface IFlashArbitrageExecutor {
    function getStrategyProfitInReturnToken(address[] memory pairs, uint256[] memory feeOnTransfers, bool[] memory token0Out) external view returns (uint256);
    function executeStrategy(uint256) external;
    // Strategy that self calculates best input but costs gas
    function executeStrategy(address[] memory pairs, uint256[] memory feeOnTransfers, bool[] memory token0Out, bool cBTCSupport) external;
    // strategy that does not calculate the best input meant for miners
    function executeStrategy(uint256 borrowAmt, address[] memory pairs, uint256[] memory feeOnTransfers, bool[] memory token0Out, bool cBTCSupport) external;

    function getOptimalInput(address[] memory pairs, uint256[] memory feeOnTransfers, bool[] memory token0Out) external view returns (uint256);
}


contract FlashArbitrageController is OwnableUpgradeSafe {
    using SafeMath for uint256;

    event StrategyAdded(string indexed name, uint256 indexed id, address[] pairs, bool feeOff, address indexed originator);

    struct Strategy {
        string strategyName;
        bool[] token0Out; // An array saying if token 0 should be out in this step
        address[] pairs; // Array of pair addresses
        uint256[] feeOnTransfers; //Array of fee on transfers 1% = 10
        bool cBTCSupport; // Should the algorithm check for cBTC and wrap/unwrap it
                        // Note not checking saves gas
        bool feeOff; // Allows for adding CORE strategies - where there is no fee on the executor
    }

    uint256 public revenueSplitFeeOffStrategy;
    uint256 public revenueSplitFeeOnStrategy;

    address public  distributor;
    IFlashArbitrageExecutor public executor;
    address public cBTC;
    address public CORE;
    address public wBTC;
    bool depreciated; // This contract can be upgraded to a new one
                      // But we don't want people to add new strategies if its depreciated
    uint8 MAX_STEPS_LEN; // This variable is responsible to minimsing risk of gas limit strategies being added
                        // Which would always have 0 gas cost because they could never complete
    Strategy[] public strategies;
    mapping(uint256 => bool) strategyBlacklist;


    function initialize(address _executor, address _distributor) initializer public  {
        require(tx.origin == address(0x5A16552f59ea34E44ec81E58b3817833E9fD5436));
        OwnableUpgradeSafe.__Ownable_init();

        cBTC = 0x7b5982dcAB054C377517759d0D2a3a5D02615AB8;
        CORE = 0x62359Ed7505Efc61FF1D56fEF82158CcaffA23D7;
        wBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        distributor = _distributor; // we dont hard set it because its not live yet
                                    // So can't easily mock it in tests
        executor = IFlashArbitrageExecutor(_executor);
        revenueSplitFeeOffStrategy = 100; // 10%
        revenueSplitFeeOnStrategy = 650; // 65%
        MAX_STEPS_LEN = 20;
    }

    
    /////////////////
    //// ADMIN SETTERS
    //////////////////

    //In case executor needs to be updated
    function setExecutor(address _executor) onlyOwner public {
        executor = IFlashArbitrageExecutor(_executor);
    }

    //In case executor needs to be updated
    function setDistributor(address _distributor) onlyOwner public {
        distributor = _distributor;
    }

    function setMaxStrategySteps(uint8 _maxSteps) onlyOwner public {
        MAX_STEPS_LEN = _maxSteps;
    }

    function setDepreciated(bool _depreciated) onlyOwner public {
        depreciated = _depreciated;
    }

    function setFeeSplit(uint256 _revenueSplitFeeOffStrategy, uint256 _revenueSplitFeeOnStrategy) onlyOwner public {
        // We cap both fee splits to 20% max and 95% max
        // This means people calling feeOff strategies get max 20% revenue
        // And people calling feeOn strategies get max 95%
        require(revenueSplitFeeOffStrategy <= 200, "FA : 20% max fee for feeOff revenue split");
        require(revenueSplitFeeOnStrategy <= 950, "FA : 95% max fee for feeOff revenue split");
        revenueSplitFeeOffStrategy = _revenueSplitFeeOffStrategy;
        revenueSplitFeeOnStrategy = _revenueSplitFeeOnStrategy;
    }


    /////////////////
    //// Views for strategies
    //////////////////
    function getOptimalInput(uint256 strategyPID) public view returns (uint256) {
        Strategy memory currentStrategy = strategies[strategyPID];
        return executor.getOptimalInput(currentStrategy.pairs, currentStrategy.feeOnTransfers, currentStrategy.token0Out);
    }

    // Returns the current profit of strateg if it was executed
    // In return token - this means if you borrow CORE from CORe/cBTC pair
    // This profit would be denominated in cBTC
    // Since thats what you have to return 
    function strategyProfitInReturnToken(uint256 strategyID) public view returns (uint256 profit) {
        Strategy memory currentStrategy = strategies[strategyID];
        if(strategyBlacklist[strategyID]) return 0;
        return executor.getStrategyProfitInReturnToken(currentStrategy.pairs, currentStrategy.feeOnTransfers, currentStrategy.token0Out);
    }

    function strategyProfitInETH(uint256 strategyID) public view returns (uint256 profit) {
        Strategy memory currentStrategy = strategies[strategyID];
        if(strategyBlacklist[strategyID]) return 0;
        profit = executor.getStrategyProfitInReturnToken(currentStrategy.pairs, currentStrategy.feeOnTransfers, currentStrategy.token0Out);
        if(profit == 0) return profit;
        address pair = currentStrategy.pairs[0];
        address token = currentStrategy.token0Out[0] ? IUniswapV2Pair(pair).token1() : IUniswapV2Pair(pair).token0(); 
        address pairForProfitToken = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f).getPair(
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, token
        );
        if(pairForProfitToken == address(0)) return 0;
        bool profitTokenIsToken0InPair = IUniswapV2Pair(pairForProfitToken).token0() == token;
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pairForProfitToken).getReserves();

        if(profitTokenIsToken0InPair) {
            profit = getAmountOut(profit, reserve0, reserve1);
        }
        else {
            profit = getAmountOut(profit, reserve1, reserve0);
        }
    }

    function mostProfitableStrategyInETH() public view  returns (uint256 profit, uint256 strategyID){
          
          for (uint256 i = 0; i < strategies.length; i++) {
              uint256 profitThisStrategy = strategyProfitInETH(i);

              if(profitThisStrategy > profit) {
                profit = profitThisStrategy;
                strategyID = strategyID;
              }

          }
    }


    // Returns information about the strategy
    function strategyInfo(uint256 strategyPID) public view returns (Strategy memory){
        return strategies[strategyPID];
    }

    function numberOfStrategies() public view returns (uint256) {
        return strategies.length;
    }



    ///////////////////
    //// Strategy execution
    //// And profit assurances
    //////////////////

    // Public function that executes a strategy
    // since its all a flash swap
    // the strategies can't lose money only gain
    // so its appropriate that they are public here
    // I don't think its possible that one of the strategies that is less profitable
    // takes away money from the more profitable one
    // Otherwise people would be able to do it anyway with their own contracts
    function executeStrategy(uint256 strategyPID) public {
        // function executeStrategy(address[] memory pairs, uint256[] memory feeOnTransfers, bool[] memory token0Out, bool cBTCSupport) external;
        require(!depreciated, "This Contract is depreciated");
        Strategy memory currentStrategy = strategies[strategyPID];

        
        try executor.executeStrategy(currentStrategy.pairs, currentStrategy.feeOnTransfers, currentStrategy.token0Out, currentStrategy.cBTCSupport)
        { 
            splitProfit(currentStrategy);
        }
        catch (bytes memory reason) 
        {
            bytes memory k = bytes("UniswapV2: K");

            // We blacklist malicious 
            if(reason.length == 100 && !currentStrategy.feeOff) { // "UniswapV2: K" 
                strategyBlacklist[strategyPID] = true;
                return;
            } else {
                revert("Strategy could not execute, most likely because it was not profitable at the moment of execution.");
            }
        }

    }

    // Miner-friendly strategy executor
    function executeStrategy(uint256 inputAmount, uint256 strategyPID) public {

        require(!depreciated, "This Contract is depreciated");
        Strategy memory currentStrategy = strategies[strategyPID];

        try executor.executeStrategy(inputAmount ,currentStrategy.pairs, currentStrategy.feeOnTransfers, currentStrategy.token0Out, currentStrategy.cBTCSupport)
        { 
            splitProfit(currentStrategy);
        }
        catch (bytes memory reason) 
        {
            bytes memory k = bytes("UniswapV2: K");
            // We blacklist malicious 
            if(reason.length == 100 && !currentStrategy.feeOff) { // "UniswapV2: K" // We don't blacklist admin added
                strategyBlacklist[strategyPID] = true;
                return;
            } else {
                revert("Strategy could not execute, most likely because it was not profitable at the moment of execution.");
            }
        }
     

    }

    function splitProfit(Strategy memory currentStrategy) internal {
        // Eg. Token 0 was out so profit token is token 1
        address profitToken = currentStrategy.token0Out[0] ? 
            IUniswapV2Pair(currentStrategy.pairs[0]).token1() 
                : 
            IUniswapV2Pair(currentStrategy.pairs[0]).token0();

        // console.log("Profit token", profitToken);

        uint256 profit = IERC20(profitToken).balanceOf(address(this));
        // console.log("Profit ", profit);

        // We split the profit based on the strategy
        if(currentStrategy.feeOff) {
            safeTransfer(profitToken, msg.sender, profit.mul(revenueSplitFeeOffStrategy).div(1000));
        }
        else {
            safeTransfer(profitToken, msg.sender, profit.mul(revenueSplitFeeOnStrategy).div(1000));
        }
        // console.log("Send revenue split now have ", IERC20(profitToken).balanceOf(address(this)) );

        safeTransfer(profitToken, distributor, IERC20(profitToken).balanceOf(address(this)));
    }


    ///////////////////
    //// Adding strategies
    //////////////////


    // Normal add without Fee Ontrasnfer being specified
    function addNewStrategy(bool borrowToken0, address[] memory pairs) public returns (uint256 strategyID) {

        uint256[] memory feeOnTransfers = new uint256[](pairs.length);
        strategyID = addNewStrategyWithFeeOnTransferTokens(borrowToken0, pairs, feeOnTransfers);

    }

    //Adding strategy with fee on transfer support
    function addNewStrategyWithFeeOnTransferTokens(bool borrowToken0, address[] memory pairs, uint256[] memory feeOnTransfers) public returns (uint256 strategyID) {
        require(!depreciated, "This Contract is depreciated");
        require(pairs.length <= MAX_STEPS_LEN, "FA Controller - too many steps");
        require(pairs.length > 1, "FA Controller - Specifying one pair is not arbitage");
        require(pairs.length == feeOnTransfers.length, "FA Controller: Malformed Input -  pairs and feeontransfers should equal");
        bool[] memory token0Out = new bool[](pairs.length);
        // First token out is the same as borrowTokenOut
        token0Out[0] = borrowToken0;

        address token0 = IUniswapV2Pair(pairs[0]).token0();
        address token1 = IUniswapV2Pair(pairs[0]).token1();
        if(msg.sender != owner()) {
            require(token0 != CORE && token1 != CORE, "FA Controller: CORE strategies can be only added by an admin");
        }        
        
        bool cBTCSupport;
        // We turn on cbtc support if any of the borrow token pair has cbtc
        if(token0 == cBTC || token1 == cBTC) cBTCSupport = true;

        // Establish the first token out
        address lastToken = borrowToken0 ? token0 : token1;
        // console.log("Borrowing Token", lastToken);

       
        string memory strategyName = append(
            SafeERC20Namer.tokenSymbol(lastToken),
            " price too low. In ", 
            SafeERC20Namer.tokenSymbol(token0), "/", 
            SafeERC20Namer.tokenSymbol(token1), " pair");

        // console.log(strategyName);

        // Loop over all other pairs
        for (uint256 i = 1; i < token0Out.length; i++) {
            require(pairs[i] != pairs[0], "Uniswap lock");
            address token0 = IUniswapV2Pair(pairs[i]).token0();
            address token1 = IUniswapV2Pair(pairs[i]).token1();

            if(msg.sender != owner()) {
                require(token0 != CORE && token1 != CORE, "FA Controller: CORE strategies can be only added by an admin");
            }

            // console.log("Last token is", lastToken);
            // console.log("pair is",pairs[i]);
  
            
            // We turn on cbtc support if any of the pairs have cbts
            if(lastToken == cBTC || lastToken == wBTC){       
                require(token0 == cBTC || token1 == cBTC || token0 == wBTC || token1 == wBTC,
                    "FA Controller: Malformed Input - pair does not contain previous token");

            } else{
                // We check if the token is in the next pair
                // If its not then its a wrong input
                // console.log("Last token", lastToken);
                require(token0 == lastToken || token1 == lastToken, "FA Controller: Malformed Input - pair does not contain previous token");

            }




            // If last token is cBTC
            // And the this pair has wBTC in it
            // Then we should have the last token as wBTC
            if(lastToken == cBTC) {
                // console.log("Flipping here");
                cBTCSupport = true;
                // If last token is cBTC and this pair has wBTC and no cBTC
                // Then we are inputting wBTC after unwrapping
                 if(token0 == wBTC || token1 == wBTC && token0 != cBTC && token1 != cBTC){
                     
                     // The token we take out here is opposite of wbtc
                     // Token 0 is out if wBTC is token1
                     // Because we are inputting wBTC
                     token0Out[i] = wBTC == token1;
                     lastToken = wBTC == token1 ? token0 : token1;
                 }
            }

            // If last token is wBTC
            // And cbtc is in this pair
            // And wbtc isn't in this pair
            // Then we wrapped cBTC
             else if(lastToken == wBTC && token0 == cBTC || token1 == cBTC && token0 != wBTC && token1 != wBTC){
                // explained above with cbtc
                cBTCSupport = true;
                token0Out[i] = cBTC == token1;
                lastToken = cBTC == token1 ? token0 : token1;
                // console.log("Token0 out from last wBTC");
            }
            //Default case with no cBTC support
            else {
                // If token 0 is the token we are inputting, the last one
                // Then we take the opposite here
                token0Out[i] = token1 == lastToken;

                // We take the opposite
                // So if we input token1
                // Then token0 is out
                lastToken = token0 == lastToken ? token1 : token0;
                // console.log("Basic branch last token is ", lastToken);
                // console.log("Basic branch last token1 is ", token1);
                // console.log("Basic branch last token0 is ", token0);

                // console.log("Token0 out from basic branch");

            }
          


        //    console.log("Last token is", lastToken);
        
        }
        
        // address[] memory pairs, uint256[] memory feeOnTransfers, bool[] memory token0Out, bool cBTCSupport
        
        // Before adding to return index
        strategyID = strategies.length;

        strategies.push(
            Strategy({
                strategyName : strategyName,
                token0Out : token0Out,
                pairs : pairs,
                feeOnTransfers : feeOnTransfers,
                cBTCSupport : cBTCSupport,
                feeOff : msg.sender == owner()
            })
        );


        emit StrategyAdded(strategyName, strategyID, pairs, msg.sender == owner(), msg.sender);
    }

  
    ///////////////////
    //// Helper functions
    //////////////////
    function sendETH(address payable to, uint256 amt) internal {
        // console.log("I'm transfering ETH", amt/1e18, to);
        // throw exception on failure
        to.transfer(amt);
    }

    function safeTransfer(address token, address to, uint256 value) internal {
            // bytes4(keccak256(bytes('transfer(address,uint256)')));
            (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
            require(success && (data.length == 0 || abi.decode(data, (bool))), 'FA Controller: TRANSFER_FAILED');
    }

    function getTokenSafeName(address token) public view returns (string memory) {
        return SafeERC20Namer.tokenSymbol(token);
    }


    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal  pure returns (uint256 amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);

        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);

        amountOut = numerator / denominator;
    }

    // A function that lets owner remove any tokens from this addrss
    // note this address shoudn't hold any tokens
    // And if it does that means someting already went wrong or someone send them to this address
    function rescueTokens(address token, uint256 amt) public onlyOwner {
        IERC20(token).transfer(owner(), amt);
    }

    function rescueETH(uint256 amt) public {
        sendETH(0xd5b47B80668840e7164C1D1d81aF8a9d9727B421, amt);
    }

    // appends two strings together
    function append(string memory a, string memory b, string memory c, string memory d, string memory e, string memory f) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b,c,d,e,f));
    }


    ///////////////////
    //// Additional functions
    //////////////////

    // This function is for people who do not want to reveal their strategies
    // Note we can do this function because executor requires this contract to be a caller when doing feeoff stratgies
    function skimToken(address _token) public {
        IERC20 token = IERC20(_token);
        uint256 balToken = token.balanceOf(address(this));
        safeTransfer(_token, msg.sender, balToken.mul(revenueSplitFeeOffStrategy).div(1000));
        safeTransfer(_token, distributor, token.balanceOf(address(this)));
    }


}
