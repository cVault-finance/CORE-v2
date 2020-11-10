pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/lib/contracts/libraries/SafeERC20Namer.sol';

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
    function getStrategyProfitInBorrowToken(address[] memory pairs, uint256[] memory feeOnTransfers, bool[] memory token0Out) external view returns (uint256);
    function executeStrategy(uint256) external;
    // Strategy that self calculates best input but costs gas
    function executeStrategy(address[] memory pairs, uint256[] memory feeOnTransfers, bool[] memory token0Out, bool cBTCSupport) external;
    // strategy that does not calculate the best input meant for miners
    function executeStrategy(uint256 borrowAmt, address[] memory pairs, uint256[] memory feeOnTransfers, bool[] memory token0Out, bool cBTCSupport) external;
}

interface ICOREGlobals {
    function ArbitrageProfitDistributor() external returns (address payable);
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
    function balanceOf(address) external returns (uint256);
}

contract FlashAbitrageController is OwnableUpgradeSafe {
using SafeMath for uint256;

uint256 public revenueSplitFeeOffStrategy;
uint256 public revenueSplitFeeOnStrategy;
uint8 MAX_STEPS_LEN; // This variable is responsible to minimsing risk of gas limit strategies being added
                     // Which would always have 0 gas cost because they could never complete

address payable public  distributor;
IWETH public WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
IFlashArbitrageExecutor public executor;
address public cBTC = 0x7b5982dcAB054C377517759d0D2a3a5D02615AB8;
address public CORE = 0x62359Ed7505Efc61FF1D56fEF82158CcaffA23D7;

Strategy[] public strategies;

function initialize (address _coreGlobals, address _executor)  initializer public  {

    distributor = ICOREGlobals(_coreGlobals).ArbitrageProfitDistributor(); // we dont hard set it because its not live yet
                                // So can't easily mock it in tests
    executor = IFlashArbitrageExecutor(_executor);
    revenueSplitFeeOffStrategy = 10; // 1%
    revenueSplitFeeOnStrategy = 500; // 50%
    MAX_STEPS_LEN = 20;
}


struct Strategy {
    string strategyName;
    bool[] token0Out; // An array saying if token 0 should be out in this step
    address[] pairs; // Array of pair addresses
    uint256[] feeOnTransfers; //Array of fee on transfers 1% = 10
    bool cBTCSupport; // Should the algorithm check for cBTC and wrap/unwrap it
                      // Note not checking saves gas
    uint256 highestRecordedGasCost; // As soon as a strategy is successfully run once
                                    // We know its gas
    bool feeOff; // Allows for adding CORE strategies - where there is no fee on the executor
}



function addNewStrategy(bool borrowToken0, address[] memory pairs) public returns (uint256 strategyID) {
    require(pairs.length <= MAX_STEPS_LEN, "FA Controller - too many steps");
    bool[] memory token0Out = new bool[](pairs.length);
    //We create an empty 0 array for fee on transfers
    bool[] memory feeOnTransfers = new bool[](pairs.length);

    // First token out is the same as borrowTokenOut
    token0Out[0] = borrowToken0;

    address token0 = IUniswapV2Pair(pairs[0]).token0();
    address token1 = IUniswapV2Pair(pairs[0]).token1();
    require(token0 != CORE && token1 != CORE, "FA Controller: CORE strategies can be only added by an admin");
    bool cBTCSupport;

    // We turn on cbtc support if any of the borrow token pair has cbtc
    if(token0 == cBTC || token1 == cBTC) cBTCSupport = true;

    // Establish the first token out
    address lastToken = borrowToken0 ? token0 : token1;

     
    string memory strategyName = concat(SafeERC20Namer.tokenSymbol(lastToken), string(" too low."));

    // Loop over all other pairs
    for (uint256 i = 1; i < token0Out.length; i++) {

        address token0 = IUniswapV2Pair(pairs[i]).token0();
        address token1 = IUniswapV2Pair(pairs[i]).token1();
        require(token0 != CORE && token1 != CORE, "FA Controller: CORE strategies can be only added by an admin");

        // We turn on cbtc support if any of the pairs have cbts
        if(token0 == cBTC || token1 == cBTC) cBTCSupport = true;

        // We check if the token is in the next pair
        // If its not then its a wrong input
        require(token0 == lastToken || token1 == lastToken, "FA Controller: Malformed Input - pair does not contain previous token");
        
        // We take the opposite
        // So if we input token1
        // Then token0 is out
        token0Out[i] = token1 == lastToken;

        // If token 0 is the token we are inputting, the last one
        // Then we take the opposite here
        lastToken = token0 == lastToken ? token1 : token0;
    }
    
    // address[] memory pairs, uint256[] memory feeOnTransfers, bool[] memory token0Out, bool cBTCSupport
    strategies.push(
        Strategy({
            strategyName : strategyName,
            token0Out : token0Out,
            pairs : pairs,
            feeOnTransfers : feeOnTransfers,
            cBTCSupport : cBTCSupport,
            highestRecordedGasCost : 0,
            feeOff : false
        })
    );

    strategyID = strategies.length;
}

function addNewStrategyWithFeeOnTransferTokens(bool borrowToken0, address[] memory pairs, uint256[] memory feeOnTransfers) public returns (uint256 strategyID) {
    require(pairs.length <= MAX_STEPS_LEN, "FA Controller - too many steps");
    require(pairs.length == feeOnTransfers.length, "FA Controller: Malformed Input -  pairs and feeontransfers should equal");
    bool[] memory token0Out = new bool[](pairs.length);
    // First token out is the same as borrowTokenOut
    token0Out[0] = borrowToken0;

    address token0 = IUniswapV2Pair(pairs[0]).token0();
    address token1 = IUniswapV2Pair(pairs[0]).token1();
    require(token0 != CORE && token1 != CORE, "FA Controller: CORE strategies can be only added by an admin");
    bool cBTCSupport;

    // We turn on cbtc support if any of the borrow token pair has cbtc
    if(token0 == cBTC || token1 == cBTC) cBTCSupport = true;

    // Establish the first token out
    address lastToken = borrowToken0 ? token0 : token1;

     
    string memory strategyName = concat(SafeERC20Namer.tokenSymbol(lastToken), string(" too low."));

    // Loop over all other pairs
    for (uint256 i = 1; i < token0Out.length; i++) {

        address token0 = IUniswapV2Pair(pairs[i]).token0();
        address token1 = IUniswapV2Pair(pairs[i]).token1();
        require(token0 != CORE && token1 != CORE, "FA Controller: CORE strategies can be only added by an admin");

        // We turn on cbtc support if any of the pairs have cbts
        if(token0 == cBTC || token1 == cBTC) cBTCSupport = true;

        // We check if the token is in the next pair
        // If its not then its a wrong input
        require(token0 == lastToken || token1 == lastToken, "FA Controller: Malformed Input - pair does not contain previous token");
        
        // We take the opposite
        // So if we input token1
        // Then token0 is out
        token0Out[i] = token1 == lastToken;

        // If token 0 is the token we are inputting, the last one
        // Then we take the opposite here
        lastToken = token0 == lastToken ? token1 : token0;
    }
    
    // address[] memory pairs, uint256[] memory feeOnTransfers, bool[] memory token0Out, bool cBTCSupport
    strategies.push(
        Strategy({
            strategyName : strategyName,
            token0Out : token0Out,
            pairs : pairs,
            feeOnTransfers : feeOnTransfers,
            cBTCSupport : cBTCSupport,
            highestRecordedGasCost : 0,
            feeOff : false
        })
    );

    strategyID = strategies.length;
}

// Does not limit core being in the pairs
function addNewStrategyAdmin(bool borrowToken0, address[] memory pairs, uint256[] memory feeOnTransfers) onlyOwner public returns (uint256 strategyID) {
    require(pairs.length <= MAX_STEPS_LEN, "FA Controller - too many steps");
    require(pairs.length == feeOnTransfers.length, "FA Controller: Malformed Input -  pairs and feeontransfers should equal");
    bool[] memory token0Out = new bool[](pairs.length);
    // First token out is the same as borrowTokenOut
    token0Out[0] = borrowToken0;

    address token0 = IUniswapV2Pair(pairs[0]).token0();
    address token1 = IUniswapV2Pair(pairs[0]).token1();
    bool cBTCSupport;

    // We turn on cbtc support if any of the borrow token pair has cbtc
    if(token0 == cBTC || token1 == cBTC) cBTCSupport = true;

    // Establish the first token out
    address lastToken = borrowToken0 ? token0 : token1;

     
    string memory strategyName = concat(SafeERC20Namer.tokenSymbol(lastToken), string(" too low."));

    // Loop over all other pairs
    for (uint256 i = 1; i < token0Out.length; i++) {

        address token0 = IUniswapV2Pair(pairs[i]).token0();
        address token1 = IUniswapV2Pair(pairs[i]).token1();

        // We turn on cbtc support if any of the pairs have cbts
        if(token0 == cBTC || token1 == cBTC) cBTCSupport = true;

        // We check if the token is in the next pair
        // If its not then its a wrong input
        require(token0 == lastToken || token1 == lastToken, "FA Controller: Malformed Input - pair does not contain previous token");
        
        // We take the opposite
        // So if we input token1
        // Then token0 is out
        token0Out[i] = token1 == lastToken;

        // If token 0 is the token we are inputting, the last one
        // Then we take the opposite here
        lastToken = token0 == lastToken ? token1 : token0;
    }
    
    // address[] memory pairs, uint256[] memory feeOnTransfers, bool[] memory token0Out, bool cBTCSupport
    strategies.push(
        Strategy({
            strategyName : strategyName,
            token0Out : token0Out,
            pairs : pairs,
            feeOnTransfers : feeOnTransfers,
            cBTCSupport : cBTCSupport,
            highestRecordedGasCost : 0,
            feeOff : false
        })
    );

    strategyID = strategies.length;
}


fallback () external payable {
    // We dont accept eth
    revert("FA Controller: Contract doesn't accept ETH");
}

    /////////////////
    //// ADMIN SETTERS
    //////////////////
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


    function strategyProfitInBorrowToken(uint256 strategyID) public view returns (uint256 profit) {
        Strategy memory currentStrategy = strategies[strategyID];
        return executor.getStrategyProfitInBorrowToken(currentStrategy.pairs, currentStrategy.feeOnTransfers, currentStrategy.token0Out);
    }


    // view the strategy
    function strategyInfo(uint256 strategyPID) public view returns (Strategy memory){
        return strategies[strategyPID];
    }

    function sendETH(address payable to, uint256 amt) internal {
        // console.log("I'm transfering ETH", amt/1e18, to);
        // throw exception on failure
        to.transfer(amt);
    }


    // Public function that executes a strategy
    // since its all a flash swap
    // the strategies can't lose money only gain
    // so its appropriate that they are public here
    // I don't think its possible that one of the strategies that is less profitable
    // takes away money from the more profitable one
    // Otherwise people would be able to do it anyway with their own contracts
    function executeStrategy(uint256 strategyPID) public {
        // function executeStrategy(address[] memory pairs, uint256[] memory feeOnTransfers, bool[] memory token0Out, bool cBTCSupport) external;

        Strategy memory currentStrategy = strategies[strategyPID];
        executor.executeStrategy(currentStrategy.pairs, currentStrategy.feeOnTransfers, currentStrategy.token0Out, currentStrategy.cBTCSupport);

        // Eg. Token 0 was out so profit token is token 1
        address profitToken = currentStrategy.token0Out[0] ? 
            IUniswapV2Pair(currentStrategy.pairs[0]).token1() 
                : 
            IUniswapV2Pair(currentStrategy.pairs[0]).token0();

        uint256 profit = IERC20(profitToken).balanceOf(address(this));

        // We split the profit based on the strategy
        if(currentStrategy.feeOff) safeTransfer(profitToken, msg.sender, profit.mul(revenueSplitFeeOffStrategy).div(100));
        else safeTransfer(profitToken, msg.sender,profit.mul(revenueSplitFeeOnStrategy).div(100));

        safeTransfer(profitToken, distributor, IERC20(profitToken).balanceOf(address(this)));

    }


    // This function is for people who do not want to reveal their strategies
    // skips gas checks
    // Note we can do this function because executor requires this contract to be a caller when doing feeoff stratgies
    function skimToken(address _token) public {
    
        IERC20 token = IERC20(_token);
        uint256 balToken = token.balanceOf(address(this));


        safeTransfer(_token, msg.sender, balToken.mul(revenueSplitFeeOffStrategy).div(100));
        safeTransfer(_token, distributor, token.balanceOf(address(this)));

    }


    function safeTransfer(address token, address to, uint256 value) internal {
            // bytes4(keccak256(bytes('transfer(address,uint256)')));
            (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
            require(success && (data.length == 0 || abi.decode(data, (bool))), 'FA Executor: TRANSFER_FAILED');
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

    function concat(string memory _base, string memory _value) internal returns (string memory) {
        bytes memory _baseBytes = bytes(_base);
        bytes memory _valueBytes = bytes(_value);

        string memory _tmpValue = new string(_baseBytes.length + _valueBytes.length);
        bytes memory _newValue = bytes(_tmpValue);

        uint i;
        uint j;

        for(i=0; i<_baseBytes.length; i++) {
            _newValue[j++] = _baseBytes[i];
        }

        for(i=0; i<_valueBytes.length; i++) {
            _newValue[j++] = _valueBytes[i++];
        }

        return string(_newValue);
    }
}
