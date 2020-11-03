pragma solidity 0.6.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "hardhat/console.sol";
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
    function currentStrategyProfitInETH(uint256) external view returns (uint256);
    function executeStrategy(Strategy memory) external;
}

interface ICOREGlobals {
    function ArbitrageProfitDistributor() returns (address);
}


contract FlashAbitrageController is OwnableUpgradableSafe {

uint256 public revenueSplitFeeOffStrategy;
uint256 public revenueSplitFeeOnStrategy;
uint8 MAX_STEPS_LEN; // This variable is responsible to minimsing risk of gas limit strategies being added
                     // Which would always have 0 gas cost because they could never complete

address payable public  distributor;
IWETH public WETH = IWETH(0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2);
IFlashArbitrageExecutor public executor;

Strategy[] public strategies;

function initialize (address _coreGlobals)  initializer public  {

    distributor = ICOREGlobals(_coreGlobals).ArbitrageProfitDistributor(); // we dont hard set it because its not live yet
                                // So can't easily mock it in tests
    executor = IFlashArbitrageExecutor(_executor);
    revenueSplitFeeOffStrategy = 10; // 1%
    revenueSplitFeeOnStrategy = 500; // 50%
    MAX_STEPS_LEN = 20; 

}

fallback () external payable {
    // We revert on all sends of ETH to this address unless they are coming from unwrapping WETH
    if(msg.value > 0 && msg.sender != address(WETH)) revert("FA Controller: Contract doesn't accept ETH");
}

function setMaxStrategySteps(uint8 _maxSteps) onlyOwner public {
    MAX_STEPS_LEN = _maxSteps;
}

function setFeeSplit(uint256 _revenueSplitFeeOffStrategy, uint256 _revenueSplitFeeOnStrategy) onlyOwner public {
    // We cap both fee splits to 10% max and 90% max
    // This means people calling feeOff strategies get max 10% revenue
    // And people calling feeOn strategies get max 90%
    require(revenueSplitFeeOffStrategy <= 100, "FA : 10% max fee for feeOff revenue split");
    require(revenueSplitFeeOnStrategy <= 900, "FA : 90% max fee for feeOff revenue split");
    revenueSplitFeeOffStrategy = _revenueSplitFeeOffStrategy;
    revenueSplitFeeOnStrategy = _revenueSplitFeeOnStrategy;
}

/// Example stategy
// name "CORE worth too much in cBTC pair"
// If we have 3 pools (which we do currently)
// To flash swap that strategy
// We borrow CORE from core pair
// token bought is ETH CORE pair CORE/WETH
// Second step is to sell CORE into cBTC/CORE pair with purchased token is cBTC
// Third step is unwrapping cBTC into wBTC
// Forth step is selling wBTC for ETH in wBTC pair with purchased token wBTC
// Fifth step is to put some of that ETH inside CORE pair for the borrow from step 1 to go through 
// and then tx can complete
// Fifth step is where profit is calculated
struct Strategy {
    bool active;
    bool feeOff; // Should the strategy have a fee
    string name; // Name of the stregy for easy front end display
    Step[] steps; // Steps in the strategy eg WETH -> CORE is a step definied by the swap struct
    uint256 maxRecordedGas; // We check the gas the strategy took
}

struct Step {
    uint8 stepType; // a type of step id
                    // Steps might be :
                    // initial borrow 0
                    // Swap 1
                    // wrap 2
                    // unwrap 3

    address token0; // Token0 and token1 are used to identify the pair without sorting
    address token1;
    address contractToInteractWith; // Depending on step - for a swap/borrow its pair, for a wrap its wrapper (cBTC eg.)
    address tokenBought;
}


// This might be public in the future
// once i can think of all the possible repercussions
function addStrategy(string memory _name, Step[] _steps) public  {

    require(_steps.lenght < MAX_STEPS_LEN, "FA Controller : Too many steps");
    //Only owner can set fee off, otherwise people could add strategies bypasisng CORE transfer fee == bad
    if(COREFeeOff) require(msg.sender == owner, "FA Controller: Only governance can add fee off strategies");
    // no need to check for duplicates here
    // Doesn't really matter if there are any
    strategies.push({
        feeOff : false,
        name : _name,
        steps : _steps
    });

}


// This might be public in the future
// once i can think of all the possible repercussions
function addStrategyWithoutCORETransferFee(string memory _name, Step[] _steps) onlyOwner public {

    require(_steps.lenght < MAX_STEPS_LEN, "FA Controller : Too many steps");
    //Only owner can set fee off, otherwise people could add strategies bypasisng CORE transfer fee == bad
    // no need to check for duplicates here
    // Doesn't really matter if there are any
    strategies.push({
        feeOff : true,
        name : _name,
        steps : _steps
    });

}


// view the strategy
function strategyInfo(uint246 strategyPID) public view returns (Strategy){
    return strategies[strategyPID];
}

// returns possible profit for front end display
// caution this will not be accurate for strategies that go above the gas limit
// Meaning they could ever be recorded
function possibleStrategyProfit(uint256 strategyPID) public view returns (uint256) {
    return executor.currentStrategyProfitInETH(strategies[strategyPID]).sub(strategies[strategyPID].maxRecordedGas); 
}

// Public function that executes a strategy
// since its all a flash swap
// the strategies can't lose money only gain
// so its appropriate that they are public here
// I don't think its possible that one of the strategies that is less profitable
// takes away money from the more profitable one
// Otherwise people would be able to do it anyway with their own contracts
function executeStrategy(uint256 strategyPID) public {
    
    Strategy memory currentStrategy = strategies[strategyPID];

    //We check the gas at start of execution
    uint256 gasStart = gasleft();

    executor.executeStrategy(currentStrategy); // Executor is a bytecoded obfuscated contract
                                               // With an aim to make it harder to copy.
    
    splitRevenue(strategyPID, gasStart);
                                            
}


// This function is for people who do not want to reveal their strategies
// skips gas checks
// Note we can do this function because executor requires this contract to be a caller when doing feeoff stratgies
function skimWETH(uint256 strategyPID) internal {

    // We unwrap all WETH we have
    WETH.withdraw(WETH.balanceOf(address(this)));

    // We send revenue share
    // if we is off
    sendETH(msg.sender, address(this).balance.mul(revenueSplitFeeOnStrategy).div(100));
    
    //We send rest to distributor
    sendETH(distributor, address(this).balance);

    require(address(this).balance == 0, "FA contract cannot carry balance");
}

// Note this most likely should jus tbe given out in WETH
// But then people would have to unwrap it themselves and most likely run out of ETH for call gas
function splitRevenue(uint256 strategyPID, uint256 gasStart) internal {

    // We unwrap all WETH we have
    WETH.withdraw(WETH.balanceOf(address(this)));

    uint256 profitShare;

    // We send revenue share
    // if we is off
    if(strategies[strategyPID].feeOff) {
        profitShare = address(this).balance.mul(revenueSplitFeeOffStrategy).div(100);
        sendETH(msg.sender, profitShare);
    }
    else {
        profitShare = address(this).balance.mul(revenueSplitFeeOnStrategy).div(100);
        sendETH(msg.sender, profitShare);
    }
    
    //We send rest to distributor
    sendETH(distributor, address(this).balance);

    // Sanity check
    // Likely just wasting money here
    require(address(this).balance == 0, "FA: contract cannot carry balance");

    //And we check it at the end of execution
    // To get the gas used number        
    uint256 gasUsed = gasStart.sub(gasleft());

    // Gurantee that we did in fact have profit
    // Note we don't need to have some sort of minimum profit input from the user
    // Because it really doesn't matter if its 1eth unit its always positive
    require(gasUsed < profitShare, "FA: Profit wasn't big enough to justify the trade");

    // If its bigger than the max recorded we use it as the max recorded.
    if(strategies[strategyPID].maxRecordedGas < gasUsed) 
        strategies[strategyPID].maxRecordedGas = gasUsed;   
}

// A function that lets owner remove any tokens from this addrss
// note this address shoudn't hold any tokens
// And if it does that means someting already went wrong or someone send them to this address
function rescueTokens(address token, uint256 amt) public onlyOwner {
    IERC20(token).transfer(owner, amt);
}


}
