// SPDX-License-Identifier: MIT



/// Transfer handler v0.1
// The basic needed for double coins to work
// While we wait for TransferHandler 1.0 to be properly tested.

pragma solidity ^0.6.0;
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol"; // for WETH
import "@nomiclabs/buidler/console.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "./ICOREGlobals.sol";

contract TransferHandler01 is OwnableUpgradeSafe {

    using SafeMath for uint256;
    ICOREGlobals coreGlobals;
    address tokenUniswapPairCORE;
    address[] public trackedPairs;

    uint8 public feePercentX100;  // max 255 = 25.5% artificial clamp
    bool public transfersPaused;
    mapping (address => bool) public noFeeList;
    mapping (address =>bool) public isPair;


    function initialize(
        address _coreGlobals
    ) public initializer {
        OwnableUpgradeSafe.__Ownable_init();
        coreGlobals = ICOREGlobals(_coreGlobals);

        feePercentX100 = 10; //1%

        tokenUniswapPairCORE = coreGlobals.COREWETHUniPair();
        _editNoFeeList(coreGlobals.COREVaultAddress(), true); // corevault proxy needs to have no sender fee
        _addPairToTrack(coreGlobals.COREWETHUniPair());

        // minFinney = 5000;
    }

    // No need to remove pairs
    function addPairToTrack(address pair) onlyOwner public {
        _addPairToTrack(pair);
    }

    function _addPairToTrack(address pair) internal {

        uint256 length = trackedPairs.length;
        for (uint256 i = 0; i < length; i++) {
            require(trackedPairs[i] != pair, "Pair already tracked");
        }
        // we sync
        sync(pair);
        // we add to array so we can loop over it
        trackedPairs.push(pair);
        // we add pair to no fee sender list
        _editNoFeeList(pair, true);
        // we add it to pair mapping to lookups
        isPair[pair] = true;

    }


    // CORE token is pausable 
    function setPaused(bool _pause) public onlyOwner {

        transfersPaused = _pause;

        // Sync all tracked pairs
        uint256 length = trackedPairs.length;
        for (uint256 i = 0; i < length; i++) {
            sync(trackedPairs[i]);
        }
    
    }

    function setFeeMultiplier(uint8 _feeMultiplier) public onlyOwner {
        feePercentX100 = _feeMultiplier;
    }

    function editNoFeeList(address _address, bool noFee) public onlyOwner {
        _editNoFeeList(_address,noFee);
    }
    function _editNoFeeList(address _address, bool noFee) internal{
        noFeeList[_address] = noFee;
    }

    // uint minFinney; // 2x for $ liq amount

    // function setMinimumLiquidityToTriggerStop(uint finneyAmnt) public onlyOwner{ // 1000 = 1eth
    //     minFinney = finneyAmnt;
    // }


    // Old sync for backwards compatibility - syncs COREtokenEthPair
    function sync() public returns (bool lastIsMint, bool lpTokenBurn) {

        (lastIsMint,  lpTokenBurn) = sync(tokenUniswapPairCORE);

        // This will update the state of lastIsMint, when called publically
        // So we have to sync it before to the last LP token value.

        // uint256 _balanceWETH = IERC20(WETHAddress).balanceOf(tokenUniswapPair);
        // uint256 _balanceCORE = IERC20(coreTokenAddress).balanceOf(tokenUniswapPair);

        // Do not block after small liq additions
        // you can only withdraw 350$ now with front running
        // And cant front run buys with liq add ( adversary drain )

        // lastIsMint = _balanceCORE > lastSupplyOfCoreInPair && _balanceWETH > lastSupplyOfWETHInPair.add(minFinney.mul(1 finney));


        // lastSupplyOfCoreInPair = _balanceCORE;
        // lastSupplyOfWETHInPair = _balanceWETH;
    }

    mapping(address => uint256) private lpSupplyOfPair;

    function sync(address pair) public returns (bool lastIsMint, bool lpTokenBurn) {

        // This will update the state of lastIsMint, when called publically
        // So we have to sync it before to the last LP token value.
        uint256 _LPSupplyOfPairNow = IERC20(pair).totalSupply();
        lpTokenBurn = lpSupplyOfPair[pair] > _LPSupplyOfPairNow;
        lpSupplyOfPair[pair] = _LPSupplyOfPairNow;

        lastIsMint = false;
    }


    // Called by ERC95
    // They are not pausable
    //  or have a fee
    // at least right now
    // Note ERC95 will make it impossible to withdraw liq at all
    // Because CORE will sync, or it will sync while the transfer is happening
    // and revert
    // Note 2 : it would be cool to have own WETH but that woudnt be supported by uniswap 
    function handleTransfer
        (address sender, 
        address recipient, 
        uint256 amount
        ) public {
            
            // If the pair is sender it might be a burn
            // So we sync and then check
        
            if(isPair[sender]) {
                (bool lastIsMint, bool lpTokenBurn) = sync(sender);
                require(lastIsMint == false, "CORE TransferHandler v0.1 : Liquidity withdrawals forbidden");
                require(lpTokenBurn == false, "CORE TransferHandler v0.1 : Liquidity withdrawals forbidden");
            }
            // If recipent is pair we just sync
            else if(isPair[recipient]) {
               sync(recipient);
            }

        }


    function calculateAmountsAfterFee(        
        address sender, 
        address recipient, 
        uint256 amount
        ) public  returns (uint256 transferToAmount, uint256 transferToFeeDistributorAmount) 
        {
            require(transfersPaused == false, "CORE TransferHandler v0.1 : Transfers Paused");

            // If the sender is pair
            // We sync and check for a burn happening
            if(isPair[sender]) {
                (bool lastIsMint, bool lpTokenBurn) = sync(sender);
                require(lastIsMint == false, "CORE TransferHandler v0.1 : Liquidity withdrawals forbidden");
                require(lpTokenBurn == false, "CORE TransferHandler v0.1 : Liquidity withdrawals forbidden");
            }
            // If recipient is pair we just sync
            else if(isPair[recipient]) {
               sync(recipient);
            }

            if(noFeeList[sender]) { // Dont have a fee when corevault is sending, or infinite loop
                console.log("Sending without fee");  // And when pair is sending ( buys are happening, no tax on it)
                transferToFeeDistributorAmount = 0;
                transferToAmount = amount;
            } 
            else {
                console.log("Normal fee transfer");
                transferToFeeDistributorAmount = amount.mul(feePercentX100).div(1000);
                transferToAmount = amount.sub(transferToFeeDistributorAmount);
            }

        }


}
