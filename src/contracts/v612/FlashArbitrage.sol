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
/// This contract checks for opportunities to gain profit for the CORE ecosystem
/// By arbitraging all existing pools, and transfering profits to FeeSplitter
/// That will add rewards to specific pools to keep them at X% APY
/// And add liquidity and subsequently burn the liquidity tokens after all pools reach this threashold
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
contract FlashAbitrage is Ownable {


address public distributor;
address internal WETH = 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2;

Strategy[] public strategies;

constructor (address _distributor) {
    distributor = _distributor; // we dont hard set it because its not live yet
                                // So can't easily mock it in tests
}

fallback () external payable {
    if(msg.sender != WETH) require(false, "Unsupported call");
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
    string name; // Name of the stregy for easy front end display
    Step[] steps; // Steps in the strategy eg WETH -> CORE is a step definied by the swap struct
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
function addStrategy(string memory _name, Step[] _steps) public onlyOwner {
    strategies.push({
        name : _name,
        steps : _steps
    });
}

// view the strategy
function strategyInfo(uint246 strategyPID) public view returns (Strategy){

}

// returns possible profit for front end display
function possibleStrategyProfit(uint256 strategyPID) public view returns (uint256 profitETH) {

}

// Public function that executes a strategy
// since its all a flash swap
// the strategies can't lose money only gain
function executeStrategy(uint256 strategyPID) public {

}

// A function that lets owner remove any tokens from this addrss
// note this address shoudn't hold any tokens
// And if it does that means someting already went wrong or someone send them to this address
function rescueTokens(address token, uint256 amt) public onlyOwner {
    IERC20(token).transfer(owner, amt);
}


}
