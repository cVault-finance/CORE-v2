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
//                    $"               dP    kjRWG0tKDA4A
//
// I'll have you know...
contract FlashAbitrage {


address public distributor;
constructor (address _distributor) {
    distributor = _distributor;
}

struct Strategy {

}

struct Swap {

}

Strategy[] public strategies;


// returns possible profit for front end display
function possibleStrategyProfit(uint256 strategyPID) public view returns (uint256 profitETH) {

}

// Public function that executes a strategy
// since its all a flash swap
// the strategies can't lose money only gain
function executeStrategy(uint256 strategyPID) public {

}


}
