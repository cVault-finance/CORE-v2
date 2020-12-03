pragma solidity 0.6.12;


// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@@&%%%%%%@@@@@&%%%%%%@%%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@&@@@@@@@@@&%%*****#%%%%&&&&&&&&&&@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@&&&&&&&%%*******#%%%# /%&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@&&&&&&%%%********#*,,,*. %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&/******,.          %@@@@@@%%%%%@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@%%%&@@@@@%***%***             %%&@@&%%,**%@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@%,,(%@@@%%*(#***,              (%%@&%  (%@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@%    %%%%*,,**                   %%,   (%@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@%    %%%**,,                    %    %%%@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@%*                                  %@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@&%*                                %@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@&#%%                                %@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@%#****%*                             %@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@%%%/**%*                             %%@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@%%*                              %@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@%                                %@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@%                                %@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@&%                                %@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@%                                 %%%@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@%                                  (%@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@&*                                     %@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@%%/,                                    %@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@%*****                                   %@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@&%%*****                                   %@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@&/******                                   %@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@&/******                                   %@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@&/,****,                                 (%%@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@%,*****,                                  (&@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@%*,***.                                   (&@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@%                                        %%%@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@%                                        %@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@&#(                                ((((%////%%&@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@&%%,. . ./%&&&&&%*.............%%&&&&&&&&&&&&&@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
/// MUH FANNY

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import "hardhat/console.sol";

interface INBUNIERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface ICOREGlobals {
    function TransferHandler() external returns (address);
    function CoreBuyer() external returns (address);
}
interface ICOREBuyer {
    function ensureFee(uint256, uint256, uint256) external;  
}
interface ICORETransferHandler{
    function getVolumeOfTokenInCoreBottomUnits(address) external returns(uint256);
}

// Core Vault distributes fees equally amongst staked pools
// Have fun reading it. Hopefully it's bug-free. God bless.
contract FannyVault is OwnableUpgradeSafe {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event Deposit(address indexed by, address indexed forWho, uint256 indexed depositID, uint256 amount, uint256 multiplier);
    event Withdraw(address indexed user, uint256 indexed creditPenalty, uint256 amount);
    event COREBurned(address indexed from, uint256 value);

    // Eachu user has many deposits
    struct UserDeposit {
        uint256 amountCORE;
        uint256 startedLockedTime;
        uint256 amountTimeLocked;
        uint256 multiplier;
        bool withdrawed;
    }

    // Info of each user.
    struct UserInfo {
        uint256 amountCredit; // This is with locking multiplier
        uint256 rewardDebt; 
        UserDeposit[] deposits;
    }


    struct PoolInfo {
        uint256 accFannyPerShare; 
        bool withdrawable; 
        bool depositable;
    }

    IERC20 public CORE;
    IERC20 public FANNY;

    address public COREBurnPileNFT;

    // Info of each pool.
    PoolInfo public fannyPoolInfo;
    // Info of each user that stakes  tokens.
    mapping(address => UserInfo) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.

    //// pending rewards awaiting anyone to massUpdate
    uint256 public totalFarmableFannies;

    uint256 public blocksFarmingActive;
    uint256 public blockFarmingStarted;
    uint256 public blockFarmingEnds;
    uint256 public fannyPerBlock;
    uint256 public totalShares;
    uint256 public totalBlocksToCreditRemaining;
    uint256 private lastBlockUpdate;
    uint256 private coreBalance;
    bool private locked;

    // Reentrancy lock 
    modifier lock() {
        require(locked == false, 'FANNY Vault: LOCKED');
        locked = true;
        _;
        locked = false;
    }

    function initialize(address _fanny, uint256 farmableFanniesInWholeUnits, uint256 _blocksFarmingActive) public initializer {
        OwnableUpgradeSafe.__Ownable_init();
        CORE = IERC20(0x62359Ed7505Efc61FF1D56fEF82158CcaffA23D7);
        FANNY = IERC20(_fanny);

        totalFarmableFannies = farmableFanniesInWholeUnits*1e18;
        blocksFarmingActive = _blocksFarmingActive;
    }

    function startFarming() public onlyOwner {
        require(FANNY.balanceOf(address(this)) == totalFarmableFannies, "Not enough fannies in the contract - shameful");
        /// We start farming
        blockFarmingStarted = block.number + 300; // 300 is for deposits to roll in before rewards start
        // This is how rewards are calculated
        lastBlockUpdate = block.number + 300; // 300 is for deposits to roll in before rewards start
        // We get the last farming block
        blockFarmingEnds = blockFarmingStarted.add(blocksFarmingActive);
        // This is static so can be set here
        totalBlocksToCreditRemaining = blockFarmingEnds.sub(blockFarmingStarted);
        fannyPerBlock = totalFarmableFannies.div(totalBlocksToCreditRemaining);
        console.log("Fanny per block", fannyPerBlock);
        console.log("totalBlocksToCreditRemaining", totalBlocksToCreditRemaining);
        fannyPoolInfo.depositable = true;

        // We open deposits
        fannyPoolInfo.withdrawable = true;

    }

    function fanniesLeft() public view returns (uint256) {
        return totalBlocksToCreditRemaining * fannyPerBlock;
    }

    function _burn(uint256 _amount) internal {
        require(COREBurnPileNFT !=  address(0), "Burning NFT is not set");
        // We send the CORE to burn pile
        safeWithdrawCORE(COREBurnPileNFT, _amount) ;
        emit COREBurned(msg.sender, _amount);
    }

    // Sets the burn NFT once
    function setBurningNFT(address _burningNFTAddress) public onlyOwner {
        require(COREBurnPileNFT == address(0), "Already set");
        COREBurnPileNFT = _burningNFTAddress;
    }


    // Update the given pool's ability to withdraw tokens
    // Note contract owner is meant to be a governance contract allowing CORE governance consensus
    function toggleWithdrawals(bool _withdrawable) public onlyOwner {
        fannyPoolInfo.withdrawable = _withdrawable;
    }
    function toggleDepositable(bool _depositable) public onlyOwner {
        fannyPoolInfo.depositable = _depositable;
    }

    // View function to see pending COREs on frontend.
    function fannyReadyToClaim(address _user) public view returns (uint256) {
        PoolInfo memory pool = fannyPoolInfo;
        UserInfo memory user = userInfo[_user];
        uint256 accFannyPerShare = pool.accFannyPerShare;
        console.log("Pool fanny per share is", accFannyPerShare);
        console.log("User credit is", user.amountCredit);

        return user.amountCredit.mul(accFannyPerShare).div(1e12).sub(user.rewardDebt);
    }


    // Update reward variables of the given pool to be up-to-date.
    function updatePool() public  { // This is safe to be called publically caues its deterministic
        if(lastBlockUpdate == block.number) {  return; } // save gas on consecutive same block calls
        if(totalShares == 0) {  return; } // div0 error
        if(blockFarmingStarted > block.number ) { return; }
        PoolInfo storage pool = fannyPoolInfo;
        // We take number of blocks since last update
        uint256 deltaBlocks = block.number.sub(lastBlockUpdate);
        if(deltaBlocks > totalBlocksToCreditRemaining) {
            deltaBlocks = totalBlocksToCreditRemaining;
        }
        uint256 numFannyToCreditpool = deltaBlocks.mul(fannyPerBlock);
        totalBlocksToCreditRemaining = totalBlocksToCreditRemaining.sub(deltaBlocks);
        // Its stored as 1e12 for change
        // We divide it by total issued shares to get it per share
        uint256 fannyPerShare = numFannyToCreditpool.mul(1e12).div(totalShares);
        // This means we finished farming so noone gets anythign no more
        // We assign a value that its per each share
        pool.accFannyPerShare = pool.accFannyPerShare.add(fannyPerShare);
        lastBlockUpdate = block.number;
    }


    function totalWithdrawableCORE(address user) public view returns (uint256 withdrawableCORE) {
        UserInfo memory user = userInfo[user];
        uint256 lenghtUserDeposits = user.deposits.length;

        // Loop over all deposits
        for (uint256 i = 0; i < lenghtUserDeposits; i++) {
            UserDeposit memory currentDeposit = user.deposits[i]; // MEMORY BE CAREFUL

            if(currentDeposit.withdrawed == false  // If it has not yet been withdrawed
                        &&  // And
                        // the timestamp is higher than the lock time
                block.timestamp > currentDeposit.startedLockedTime.add(currentDeposit.amountTimeLocked)) 
                {
                    // It was not withdrawed.
                    // And its withdrawable, so we withdraw it
                    uint256 amountCOREInThisDeposit = currentDeposit.amountCORE; //gas savings we use it twice
                    withdrawableCORE = withdrawableCORE.add(amountCOREInThisDeposit);
                }
        }
    }


    function totalDepositedCOREAndNotWithdrawed(address user) public view returns (uint256 totalDeposited) {
        UserInfo memory user = userInfo[user];
        uint256 lenghtUserDeposits = user.deposits.length;

        // Loop over all deposits
        for (uint256 i = 0; i < lenghtUserDeposits; i++) {
            UserDeposit memory currentDeposit = user.deposits[i]; 
            if(currentDeposit.withdrawed == false) {
                uint256 amountCOREInThisDeposit = currentDeposit.amountCORE; 
                totalDeposited = totalDeposited.add(amountCOREInThisDeposit);
            }
        }
    }



    function numberDepositsOfuser(address user) public view returns (uint256) {
        UserInfo memory user = userInfo[msg.sender];
        return user.deposits.length +1;
    }



    // Amount and multiplier already needs to be validated
    function _deposit(uint256 _amount, uint256 multiplier, address forWho) internal {
        // We multiply the amount by the.. multiplier
        console.log("Fanny Vault Internal _deposit");
        console.log("amount deposit", _amount);
        console.log("multiplier deposit", multiplier);
        require(block.number < blockFarmingEnds, "Farming has ended or not started");
        PoolInfo memory pool = fannyPoolInfo; // Just memory is fine we don't write to it.
        require(pool.depositable, "Pool Deposits are closed");
        UserInfo storage user = userInfo[forWho];

        require(multiplier <= 25, "Sanity check failure for multiplier");
        require(multiplier > 0, "Sanity check failure for multiplier");

        uint256 depositID = user.deposits.length;
        if(multiplier != 25) { // multiplier of 25 is a burn
            user.deposits.push(
                UserDeposit({
                    amountCORE : _amount,
                    startedLockedTime : block.timestamp,
                    amountTimeLocked : multiplier > 1 ? multiplier * 4 weeks : 0,
                    withdrawed : false,
                    multiplier : multiplier
                })
            );
        }

        _amount = _amount.mul(multiplier); // Safe math just in case
                                           // Because i hate the ethereum network
                                           // And want everyone to pay 200 gas
        // Update before giving credit
        // Stops attacks
        updatePool();
        
        // Transfer pending fanny tokens to the user
        updateAndPayOutPending(forWho);

        console.log("Crediting for", _amount);
        //Transfer in the amounts from user
        if(_amount > 0) {
            user.amountCredit = user.amountCredit.add(_amount);
        }

        // We paid out so have to remember to update the user debt
        user.rewardDebt = user.amountCredit.mul(pool.accFannyPerShare).div(1e12);
        totalShares = totalShares.add(_amount);
    
        emit Deposit(msg.sender, forWho, depositID, _amount, multiplier);
    }


    // Function that burns from a person fro 25 multiplier
    function burnFor25XCredit(uint256 _amount) lock public {
        safeTransferCOREFromPersonToThisContract(_amount, msg.sender);
        _burn(_amount);
        _deposit(_amount, 25, msg.sender);
    }


    function deposit(uint256 _amount, uint256 lockTimeWeeks) lock public {
        console.log("Fanny Vault Deposit");
        // Safely transfer CORE out, make sure it got there in all pieces
        safeTransferCOREFromPersonToThisContract(_amount, msg.sender);
       _deposit(_amount, getMultiplier(lockTimeWeeks), msg.sender);
    }

    function depositFor(uint256 _amount, uint256 lockTimeWeeks, address forWho) lock public {
        safeTransferCOREFromPersonToThisContract(_amount, msg.sender);
       _deposit(_amount, getMultiplier(lockTimeWeeks), forWho);

    }

    function getMultiplier(uint256 lockTimeWeeks) internal pure returns (uint256 multiplier) {
        // We check for input errors
        require(lockTimeWeeks <= 48, "Lock time is too large.");
        // We establish the deposit multiplier
        if(lockTimeWeeks >= 8) { // Multiplier starts now
            multiplier = lockTimeWeeks/4; // max 12 min 2 in this branch
        } else {
            multiplier = 1; // else multiplier is 1 and is non-locked
        }
    }

    // Helper function that validates the deposit
    // And checks if FoT is on the deposit, which it should not be.
    function safeTransferCOREFromPersonToThisContract(uint256 _amount, address person) internal {
        uint256 beforeBalance = CORE.balanceOf(address(this));
        safeTransferFrom(address(CORE), person, address(this), _amount);
        uint256 afterBalance = CORE.balanceOf(address(this));
        require(afterBalance.sub(beforeBalance) == _amount, "Didn't get enough CORE, most likely FOT is ON");
    }


    function withdrawAllWithdrawableCORE() lock public {
        UserInfo memory user = userInfo[msg.sender];// MEMORY BE CAREFUL
        uint256 lenghtUserDeposits = user.deposits.length;
        require(user.amountCredit > 0, "Nothing to withdraw 1");
        // struct Deposit {
        //     uint256 amountCORE;
        //     uint256 startedLockedTime;
        //     uint256 amountTimeLocked;
        //     bool withdrawed;
        // }
        uint256 withdrawableCORE;
        uint256 creditPenalty;

        // Loop over all deposits
        for (uint256 i = 0; i < lenghtUserDeposits; i++) {
            UserDeposit memory currentDeposit = user.deposits[i]; // MEMORY BE CAREFUL
            console.log("Current deposit withdrawed", currentDeposit.withdrawed);
            if(currentDeposit.withdrawed == false  // If it has not yet been withdrawed
                        &&  // And
                        // the timestamp is higher than the lock time
                block.timestamp > currentDeposit.startedLockedTime.add(currentDeposit.amountTimeLocked)) 
                {
                    // It was not withdrawed.
                    // And its withdrawable, so we withdraw it
                    console.log("Setting withrawed to true");

                    userInfo[msg.sender].deposits[i].withdrawed = true; // this writes to storage
                    uint256 amountCOREInThisDeposit = currentDeposit.amountCORE; //gas savings we use it twice

                    creditPenalty = creditPenalty.add(amountCOREInThisDeposit.mul(currentDeposit.multiplier));
                    withdrawableCORE = withdrawableCORE.add(amountCOREInThisDeposit);
                }
        }

        // We check if there is anything to witdraw
        require(withdrawableCORE > 0, "Nothing to withdraw 2");
        //Sanity checks
        require(creditPenalty >= withdrawableCORE, "Sanity check failure. Penalty should be bigger or equal to withdrawable");
        require(creditPenalty > 0, "Sanity fail, withdrawing CORE and inccuring no credit penalty");
        console.log("Withdrawing amt core", withdrawableCORE);
        console.log("Withdrawing credit penalty", creditPenalty);

        // We conduct the withdrawal
        _withdraw(msg.sender, msg.sender, withdrawableCORE, creditPenalty);

    }


    function _withdraw(address from, address to, uint256 amountToWithdraw, uint256 creditPenalty) internal {
        PoolInfo memory pool = fannyPoolInfo; 
        require(pool.withdrawable, "Withdrawals are closed.");
        UserInfo storage user = userInfo[from];

        // We update the pool
        updatePool();
        // And pay out rewards to this person
        updateAndPayOutPending(from);
        // Adjust their reward debt and balances
        user.amountCredit = user.amountCredit.sub(creditPenalty, "Coudn't validate user credit amounts");
        user.rewardDebt = user.amountCredit.mul(pool.accFannyPerShare).div(1e12); // divide out the change buffer
        totalShares = totalShares.sub(creditPenalty, "Coudn't validate total shares");
        safeWithdrawCORE(to, amountToWithdraw);
        emit Withdraw(from, creditPenalty, amountToWithdraw);
    }

    function claimFanny(address forWho) public lock {
        UserInfo storage user = userInfo[forWho];
        PoolInfo memory pool = fannyPoolInfo; // Just memory is fine we don't write to it.
        updatePool();
        // And pay out rewards to this person
        updateAndPayOutPending(forWho);
        user.rewardDebt = user.amountCredit.mul(pool.accFannyPerShare).div(1e12); 
    } 

    function claimFanny() public lock {
        claimFanny(msg.sender);
    }
    
    // Public locked function, validates via msg.sender
    function withdrawDeposit(uint256 depositID) public lock {
        _withdrawDeposit(depositID, msg.sender, msg.sender);
    }
    

    // We withdraw a specific deposit id
    // Important to validate from
    // Internal function
    function _withdrawDeposit(uint256 depositID, address from, address to)  internal   {
        UserDeposit memory currentDeposit = userInfo[from].deposits[depositID]; // MEMORY BE CAREFUL

        uint256 creditPenalty;
        uint256 withdrawableCORE;

        if(
            currentDeposit.withdrawed == false && 
            block.timestamp > currentDeposit.startedLockedTime.add(currentDeposit.amountTimeLocked)) 
        {
            // It was not withdrawed.
            // And its withdrawable, so we withdraw it
            console.log("Setting withrawed to true");
            userInfo[from].deposits[depositID].withdrawed = true; // this writes to storage
            uint256 amountCOREInThisDeposit = currentDeposit.amountCORE; //gas savings we use it twice

            creditPenalty = creditPenalty.add(amountCOREInThisDeposit.mul(currentDeposit.multiplier));
            withdrawableCORE = withdrawableCORE.add(amountCOREInThisDeposit);
        }

        require(withdrawableCORE > 0, "Nothing to withdraw");
        require(creditPenalty >= withdrawableCORE, "Sanity check failure. Penalty should be bigger or equal to withdrawable");
        require(creditPenalty > 0, "Sanity fail, withdrawing CORE and inccuring no credit penalty");
        // _withdraw(address from, address to, uint256 amountToWithdraw, uint256 creditPenalty)
        _withdraw(from, to, withdrawableCORE, creditPenalty);

    }


    function updateAndPayOutPending(address from) internal {
        uint256 pending = fannyReadyToClaim(from);
        console.log("Paying out pending", pending);
        if(pending > 0) {
            safeFannyTransfer(from, pending);
        }
    }


    // Safe core transfer function, just in case if rounding error causes pool to not have enough COREs.
    function safeFannyTransfer(address _to, uint256 _amount) internal {
        
        uint256 _fannyBalance = FANNY.balanceOf(address(this));

        if (_amount > _fannyBalance) {
            safeTransfer(address(FANNY), _to, _fannyBalance);
        } else {
            safeTransfer(address(FANNY), _to, _amount);
        }
    }

    function safeWithdrawCORE(address _to, uint256 _amount) internal {
        uint256 balanceBefore = CORE.balanceOf(_to);
        safeTransfer(address(CORE), _to, _amount);
        uint256 balanceAfter = CORE.balanceOf(_to);
        require(balanceAfter.sub(balanceBefore) == _amount, "Failed to withdraw CORE tokens successfully, make sure FOT is off");
    }


    function safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'MUH FANNY: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'MUH FANNY: TRANSFER_FROM_FAILED');
    }

}
