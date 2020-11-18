pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/lib/contracts/libraries/SafeERC20Namer.sol';
import "hardhat/console.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import './ICOREGlobals.sol';

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

// import "@openzeppelin/contracts/access/Ownable.sol";

interface ICOREVault {
    function addPendingRewards(uint256 _) external; 
}

interface IUNICORE {
    function viewGovernanceLevel(address) external returns (uint8);
    function setVault(address) external;
    function burnFromUni(uint256) external;
    function viewUNIv2() external returns (address);
    function viewUniBurnRatio() external returns (uint256);
    function setGovernanceLevel(address, uint8) external;
    function balanceOf(address) external returns (uint256);
    function setUniBurnRatio(uint256) external;
    function viewwWrappedUNIv2() external returns (address);
    function burnToken(uint256) external;
    function totalSupply() external returns (uint256);
}

interface IUNICOREVault {
    function userInfo(uint,address) external view returns (uint256, uint256);
}

interface IProxyAdmin {
    function owner() external returns (address);
    function transferOwnership(address) external;
    function upgrade(address, address) external;
}


interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}
interface ILGE {
    function claimLP() external;
}

interface ITransferContract {
    function run(address) external;
}

interface ICORE {
    function setShouldTransferChecker(address) external;
}

interface ITimelockVault {
    function LPContributed(address) external view returns (uint256);
}

contract TENSFeeApproverPermanent {
    address public tokenETHPair;
    constructor() public {
            tokenETHPair = 0xB1b537B7272BA1EDa0086e2f480AdCA72c0B511C;
    }

    function calculateAmountsAfterFee(
        address sender,
        address recipient,
        uint256 amount
        ) public  returns (uint256 transferToAmount, uint256 transferToFeeDistributorAmount)
        {

            // Will block all buys and liquidity removals
            if(sender == tokenETHPair || recipient == tokenETHPair) {
                // This is how a legend dies
                require(false, "TENS is depricated.");
            }

            // No fees 
            // school is out
            transferToAmount = amount;
        
        }
}


contract COREForkMigrator is OwnableUpgradeSafe {
    using SafeMath for uint256;
    /// EVENTS
    event ETHSendToLGE(uint256);

    ///Variables
    bool public LPClaimedFromLGE;
    bool private locked;
    IERC20 public  CORE;
    ICOREVault public  coreVault;
    IUniswapV2Factory public  uniswapFactory;
    IWETH wETH;
    address public  CORExWETHPair;
    address payable public CORE_MULTISIG;
    address public postLGELPTokenAddress;
    address public Fee_Approver_Permanent;
    address public Vault_Permanent;
    uint256 public totalLPClaimed;
    uint256 public totalETHSent;
    uint256 contractStartTimestamp;

    mapping (address => bool) LPClaimed;

    //// UNICORE Specific Variables
    bool public UNICORE_Migrated;
    bool public UNICORE_Liquidity_Transfered;
    address public UNICORE_Vault;
    address public UNICORE_Token;
    address public UNICORE_Reactor_Token; // Slit token for liquidity
    uint256 public UNICORE_Snapshot_Block;
    uint256 public Ether_Total_For_UNICORE_LP;
    uint256 public UNICORE_Total_LP_Supply;

    mapping (address => uint256) balanceUNICOREReactor;
    mapping (address => uint256) balanceUNICOREReactorInVaultOnSnapshot;


    // ENCORE Specific variables
    bool public ENCORE_Liquidity_Transfered;
    bool public ENCORE_Transfers_Closed;
    address public ENCORE_Vault;
    address public ENCORE_Vault_Timelock;
    address public ENCORE_Fee_Approver;
    address public ENCORE_Token;
    address public ENCORE_Timelock_Vault;
    address public ENCORE_Proxy_Admin;
    address public ENCORE_LP_Token;
    address public ENCORE_Migrator;
    uint256 public Ether_Credit_Per_ENCORE_LP;
    uint256 public Ether_Total_For_Encore_LP;
    uint256 public ENCORE_Total_LP_Supply;

    mapping (address => uint256) balanceENCORELP;
    // No need for snapshot


    /// TENS Specific functions and variables
    bool public TENS_Liquidity_Transfered;
    address public TENS_Vault;
    address public TENS_Token;
    address public TENS_Proxy_Admin;
    address public TENS_LP_Token;
    address public TENS_Fee_Approver_Permanent;
    uint256 public Ether_Total_For_TENS_LP;
    uint256 public TENS_Total_LP_Supply;

    mapping (address => uint256) balanceTENSLP;
    // No need for snapshot

    /// Reentrancy modifier
    modifier lock() {
        require(locked == false, 'CORE Migrator: Execution Locked');
        locked = true;
        _;
        locked = false;
    }


    // Constructor
    function initialize() initializer public{
        require(tx.origin == 0x5A16552f59ea34E44ec81E58b3817833E9fD5436);
        require(msg.sender == 0x5A16552f59ea34E44ec81E58b3817833E9fD5436);

        OwnableUpgradeSafe.__Ownable_init();
        CORE_MULTISIG = 0x62359Ed7505Efc61FF1D56fEF82158CcaffA23D7;
        contractStartTimestamp = block.timestamp;

        // Permanent vault and fee approver
        Vault_Permanent = 0xfeD4Ec1348a4068d4934E09492428FD92E399e5c;
        Fee_Approver_Permanent = 0x43Dd7026284Ac8f95Eb02bB1bd68D0699B0Ae9cA;

        //UNICORE
        UNICORE_Vault = 0x6F31ECD8110bcBc679AEfb74c7608241D1B78949;
        UNICORE_Token = 0x5506861bbb104Baa8d8575e88E22084627B192D8;

        //TENS
        TENS_Vault = 0xf983EcF91195bD63DE8445997082680E688749BC;
        TENS_Token = 0x776CA7dEd9474829ea20AD4a5Ab7a6fFdB64C796;
        TENS_Proxy_Admin = 0x2d0C48C5BF930A09F8CD6fae5aC5A16b24e1723a;
        TENS_LP_Token = 0xB1b537B7272BA1EDa0086e2f480AdCA72c0B511C;
        TENS_Fee_Approver_Permanent = 0x22C91cDd1E00cD4d7D029f0dB94020Fce3C486e3;
        
        ENCORE_Proxy_Admin = 0x1964784ba40c9fD5EED1070c1C38cd5D1d5F9f55;
        ENCORE_Token = 0xe0E4839E0c7b2773c58764F9Ec3B9622d01A0428;
        ENCORE_LP_Token = 0x2e0721E6C951710725997928DcAAa05DaaFa031B;
        ENCORE_Fee_Approver = 0xF3c3ff0ea59d15e82b9620Ed7406fa3f6A261f98;
        ENCORE_Vault = 0xdeF7BdF8eCb450c1D93C5dB7C8DBcE5894CCDaa9;
        ENCORE_Vault_Timelock = 0xC2Cb86437355f36d42Fb8D979ab28b9816ac0545;
        Ether_Credit_Per_ENCORE_LP = uint256(1 ether).div(2).mul(10724).div(10000); // Account for 7.24% fee on LGE

        ICOREGlobals globals = ICOREGlobals(0x255CA4596A963883Afe0eF9c85EA071Cc050128B);
        CORE = IERC20(globals.CORETokenAddress());
        uniswapFactory = IUniswapV2Factory(globals.UniswapFactory());
        coreVault = ICOREVault(globals.COREVaultAddress());
        CORExWETHPair = globals.COREWETHUniPair();
        wETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    }
    
    //Enables recieving eth
    receive() external payable{}

    function setLPTokenAddress(address _token) onlyOwner public {
        postLGELPTokenAddress = _token;
    }

    function claimLPForForLP() lock public {
        require(getOwedLP(msg.sender) > 0, "nothing to claim");
        LPClaimed[msg.sender] = true;

        IERC20(postLGELPTokenAddress).transfer(msg.sender, getOwedLP(msg.sender));
    }

    function getOwedLP(address user) public view returns (uint256 LPDebtForUser) {
        if(postLGELPTokenAddress == address (0)) return 0;
        if(LPClaimedFromLGE == false) return 0;
        if(LPClaimed[msg.sender] == true) return 0;

        uint256 balanceUNICORE = viewCreditedUNICOREReactors(user);
        uint256 balanceENCORE = viewCreditedENCORETokens(user);
        uint256 balanceTENS = viewCreditedTENSTokens(user);

        if(balanceUNICORE == 0 && balanceENCORE == 0 && balanceTENS == 0) return 0;

        uint256 totalETH = Ether_Total_For_TENS_LP.add(Ether_Total_For_UNICORE_LP).add(Ether_Total_For_Encore_LP);
        uint256 totalETHEquivalent;

        if(balanceUNICORE > 0){
            totalETHEquivalent = Ether_Total_For_TENS_LP.div(UNICORE_Total_LP_Supply).mul(balanceUNICORE);
        }

        if(balanceENCORE > 0){
            totalETHEquivalent = totalETHEquivalent.add(Ether_Total_For_Encore_LP).div(ENCORE_Total_LP_Supply).mul(balanceENCORE);

        }

        if(balanceTENS > 0){
            totalETHEquivalent = totalETHEquivalent.add(Ether_Total_For_TENS_LP).div(TENS_Total_LP_Supply).mul(balanceTENS);
        }

        LPDebtForUser = totalETHEquivalent.mul(totalLPClaimed).div(totalETH).div(1e18);
    }

    ////////////
    /// Unicore specific functions
    //////////

    function snapshotUNICORE(address[] memory _addresses, uint256[] memory balances) onlyOwner public {
        require(UNICORE_Migrated == true, "UNICORE Deposits are still not closed");

        uint256 length = _addresses.length;
        require(length == balances.length, "Wrong input");

        for (uint256 i = 0; i < length; i++) {
            balanceUNICOREReactorInVaultOnSnapshot[_addresses[i]] = balances[i];
        }
    }

    function notAfterUnicoreLiquidityMigration() internal view {
        require(UNICORE_Migrated == false, "UNICORE Deposits closed");
    }

    function viewCreditedUNICOREReactors(address person) public view returns (uint256) {

        if(UNICORE_Migrated) {
            return balanceUNICOREReactorInVaultOnSnapshot[person].add(balanceUNICOREReactor[person]);
        }

        else {
            (uint256 userAmount, ) = IUNICOREVault(UNICORE_Vault).userInfo(0, person);
            return balanceUNICOREReactor[person].add(userAmount);

        }

    }

    function addUNICOREReactors() lock public {
        notAfterUnicoreLiquidityMigration();
        uint256 amtAdded = transferTokenHereSupportingFeeOnTransferTokens(UNICORE_Reactor_Token, IERC20(UNICORE_Reactor_Token).balanceOf(msg.sender));
        balanceUNICOREReactor[msg.sender] = balanceUNICOREReactor[msg.sender].add(amtAdded);
    }

    // Unicore migraiton is special and a-typical
    // Because of the extensive changes to the code-base.
    function transferUNICORELiquidity() onlyOwner public {
        console.log("Tranfering Unicore liquidity");
        require(ENCORE_Liquidity_Transfered == true, "ENCORE has to go first");
        require(UNICORE_Liquidity_Transfered == false, "UNICORE already transfered");

        // Make sure we have the proper permissions.
        require(IUNICORE(UNICORE_Token).viewGovernanceLevel(address(this)) == 2, "Incorrectly set governance level, can't proceed");
        require(IUNICORE(UNICORE_Token).viewGovernanceLevel(0x5A16552f59ea34E44ec81E58b3817833E9fD5436) == 2, "Incorrectly set governance level, can't proceed");
        require(IUNICORE(UNICORE_Token).viewGovernanceLevel(0x05957F3344255fDC9fE172E30016ee148D684313) == 0, "Incorrectly set governance level, can't proceed");
        require(IUNICORE(UNICORE_Token).viewGovernanceLevel(0xE6f32f17BE3Bf031B4B6150689C1f17cEcA375C8) == 0, "Incorrectly set governance level, can't proceed");
        require(IUNICORE(UNICORE_Token).viewGovernanceLevel(0xF4D7a0E8a68345442172F45cAbD272c25320AA96) == 0, "Incorrectly set governance level, can't proceed");
        require(address(this).balance >= 1e18, " Feed me eth");

        IUNICORE unicore = IUNICORE(UNICORE_Token);

        wETH.deposit{value: 1e18}();
        IUniswapV2Pair pair = IUniswapV2Pair(unicore.viewUNIv2());
        
        bool token0IsWETH = pair.token0() == address(wETH);
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        wETH.transfer(address(pair), 1e18);
        uint256 amtUnicore;

        if(token0IsWETH){
            amtUnicore = getAmountOut(1e18, reserve0, reserve1);
            pair.swap(0, amtUnicore, address(this), "");
        }
        else{
            amtUnicore = getAmountOut(1e18, reserve1, reserve0);

            pair.swap(amtUnicore, 0, address(this), "");
        }

        unicore.setVault(address(this));
        unicore.setUniBurnRatio(100);
    
        uint256 balUnicoreOfUniPair = unicore.balanceOf(unicore.viewUNIv2());
        uint256 totalSupplywraps = IERC20(unicore.viewwWrappedUNIv2()).totalSupply();
        UNICORE_Total_LP_Supply = totalSupplywraps;

        uint256 input = (balUnicoreOfUniPair-1).mul(totalSupplywraps).div(balUnicoreOfUniPair);

        unicore.burnFromUni(input);

        {

        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        uint256 amtWETH;
        uint256 previousPairBalance = unicore.balanceOf(address(pair));
        IERC20(address(unicore)).transfer(address(pair),  unicore.balanceOf(address(this)));
        uint256 nowPairBalance = unicore.balanceOf(address(pair));

        if(token0IsWETH){
            amtWETH = getAmountOut(nowPairBalance- previousPairBalance, reserve1, reserve0);

            pair.swap(amtWETH, 0, address(this), "");
            ( reserve0,  reserve1, ) = pair.getReserves();
            require(reserve0 < 1e18, " Burn not sufficient");
        }
        else{
            amtWETH = getAmountOut(nowPairBalance- previousPairBalance, reserve0, reserve1);

            pair.swap(0, amtWETH, address(this), "");
            ( reserve0,  reserve1, ) = pair.getReserves();
            require(reserve1 < 1e18, " Burn not sufficient");
        }

        uint256 UNICORETotalSupply = unicore.totalSupply();
        // 0.6 eth per is the floor we should get more here
        require(amtWETH > UNICORETotalSupply.mul(60).div(100), " Didn't get enough ETH ");
        require(amtWETH > 500 ether, " Didn't get enough ETH"); // sanity
        
        Ether_Total_For_UNICORE_LP = amtWETH;
        wETH.withdraw(amtWETH);

        unicore.setGovernanceLevel(address(this), 1);
        UNICORE_Liquidity_Transfered = true;
        uint256 totalETH = Ether_Total_For_TENS_LP.add(Ether_Total_For_UNICORE_LP).add(Ether_Total_For_Encore_LP);
        console.log("Balance of ETH in contract : ", address(this).balance / 1e18);
        }

    }

    ////////////
    /// ENCORE specific functions
    //////////
    function viewCreditedENCORETokens(address person) public view returns (uint256) {
            (uint256 userAmount, ) = IUNICOREVault(ENCORE_Vault).userInfo(0, person);
            uint256 userAmountTimelock = ITimelockVault(ENCORE_Vault_Timelock).LPContributed(person);
            return balanceENCORELP[person].add(userAmount).add(userAmountTimelock);
    }

    // Add LP to balance here
    function addENCORELPTokens() lock public {
        require(ENCORE_Transfers_Closed == false, "ENCORE LP transfers still ongoing");
        uint256 amtAdded = transferTokenHereSupportingFeeOnTransferTokens(ENCORE_LP_Token, IERC20(ENCORE_LP_Token).balanceOf(msg.sender));
        balanceENCORELP[msg.sender] = balanceENCORELP[msg.sender].add(amtAdded);
    }

    function closeENCORETransfers() onlyOwner public  {
        require(block.timestamp >= contractStartTimestamp.add(2 days), "2 day grace ongoing");
        ENCORE_Transfers_Closed = true;
    }

    function transferENCORELiquidity(address privateTransferContract) onlyOwner public {
        console.log("Tranfering encore liquidity");

        require(ENCORE_Transfers_Closed == true, "ENCORE LP transfers still ongoing");
        require(ENCORE_Liquidity_Transfered == false, "Already transfered liquidity");
        require(IProxyAdmin(ENCORE_Proxy_Admin).owner() == address(this), "Set me as the proxy owner for ENCORE");

        require(privateTransferContract != address(0));
        IProxyAdmin(ENCORE_Proxy_Admin).transferOwnership(privateTransferContract);

        // We check 2 contracts with burned LP
        uint256 burnedLPTokens = IERC20(ENCORE_LP_Token).balanceOf(ENCORE_Token)
                .add(IERC20(ENCORE_LP_Token).balanceOf(0x2a997EaD7478885a66e6961ac0837800A07492Fc));

        ENCORE_Total_LP_Supply = IERC20(ENCORE_LP_Token).totalSupply() - burnedLPTokens;
    
        // We calculate total owed to ENCORE LPs
        Ether_Total_For_Encore_LP = ENCORE_Total_LP_Supply // burned ~100
                .mul(Ether_Credit_Per_ENCORE_LP)
                .div(1e18);

        // We send out all LP tokens we have 
        IERC20(ENCORE_LP_Token)
            .transfer(ENCORE_LP_Token, IERC20(ENCORE_LP_Token).balanceOf(address(this)));

        uint256 ethBalBefore = address(this).balance;
        ITransferContract(privateTransferContract).run(ENCORE_LP_Token);
        uint256 newETH = address(this).balance.sub(ethBalBefore);

        console.log("Balance of ETH in contract : ", (address(this).balance / 1e18));

        // Make sure we got eth
        require(newETH > 9200 ether, "Did not recieve enough ether");  
        console.log("Ether total for encore LP", Ether_Total_For_Encore_LP);
                
                //60% max
        require(newETH.mul(60).div(100) > Ether_Total_For_Encore_LP, "Too much for encore LP"); 
                
        require(ENCORE_Proxy_Admin != address(0) 
                &&  Fee_Approver_Permanent != address(0) 
                && Vault_Permanent != address(0), "Sanity check failue");

        IProxyAdmin(ENCORE_Proxy_Admin).upgrade(ENCORE_Fee_Approver, Fee_Approver_Permanent);
        IProxyAdmin(ENCORE_Proxy_Admin).upgrade(ENCORE_Vault, Vault_Permanent);
        _sendENCOREProxyAdminBackToMultisig();
        ENCORE_Liquidity_Transfered = true;
    }

    function sendENCOREProxyAdminBackToMultisig() onlyOwner public {
        return _sendENCOREProxyAdminBackToMultisig();
    }

    function _sendENCOREProxyAdminBackToMultisig() internal {
        IProxyAdmin(ENCORE_Proxy_Admin).transferOwnership(CORE_MULTISIG);
        require(IProxyAdmin(ENCORE_Proxy_Admin).owner() == CORE_MULTISIG, "Proxy Ownership Transfer Not Successfull");
    }

    ////////////
    /// TENS specific functions
    //////////

    function addTENSLPTokens() lock public {
        require(ENCORE_Transfers_Closed == false, "ENCORE LP transfers still ongoing");
        uint256 amtAdded = transferTokenHereSupportingFeeOnTransferTokens(TENS_LP_Token, IERC20(TENS_LP_Token).balanceOf(msg.sender));
        balanceTENSLP[msg.sender] = balanceTENSLP[msg.sender].add(amtAdded);
    }

    function viewCreditedTENSTokens(address person) public view returns (uint256) {

        (uint256 userAmount, ) = IUNICOREVault(TENS_Vault).userInfo(0, person);
        return balanceTENSLP[person].add(userAmount);
    }

    function transferTENSLiquidity(address privateTransferContract) onlyOwner public {
        console.log("Tranfering tens liquidity");

        require(TENS_Liquidity_Transfered == false, "Already transfered");
        require(ENCORE_Liquidity_Transfered == true, "ENCORE has to go first");

        require(IProxyAdmin(TENS_Proxy_Admin).owner() == address(this), "Set me as the proxy owner for TENS");
        require(IProxyAdmin(TENS_Token).owner() == address(this), "Set me as the owner for TENS"); // same interface
        require(privateTransferContract != address(0));

        IProxyAdmin(TENS_Proxy_Admin).transferOwnership(privateTransferContract);
        IProxyAdmin(TENS_Token).transferOwnership(privateTransferContract);
        TENS_Total_LP_Supply = IERC20(TENS_LP_Token).totalSupply();

        // We send out all LP tokens we have 
        IERC20(TENS_LP_Token)
            .transfer(TENS_LP_Token, IERC20(TENS_LP_Token).balanceOf(address(this)));

        uint256 ethBalBefore = address(this).balance;
        ITransferContract(privateTransferContract).run(TENS_LP_Token);
        uint256 newETH = address(this).balance.sub(ethBalBefore);

        console.log("Balance of ETH in contract : ", (address(this).balance / 1e18));
        require(newETH > 130 ether, "Did not recieve enough ether");

        require(TENS_Fee_Approver_Permanent != address(0) &&
            Vault_Permanent != address(0), "Sanity check failue");

        IProxyAdmin(TENS_Proxy_Admin).upgrade(TENS_Vault, Vault_Permanent);
        TENS_Fee_Approver_Permanent = address ( new TENSFeeApproverPermanent() );
        ICORE(TENS_Token).setShouldTransferChecker(TENS_Fee_Approver_Permanent);
        Ether_Total_For_TENS_LP = newETH;

        _sendOwnershipOfTENSBackToMultisig();

        TENS_Liquidity_Transfered = true;
  
    }

    function sendOwnershipOfTENSBackToMultisig() onlyOwner public {
        return _sendOwnershipOfTENSBackToMultisig();
    }

    function _sendOwnershipOfTENSBackToMultisig() internal {
        IProxyAdmin(TENS_Token).transferOwnership(CORE_MULTISIG);
        require(IProxyAdmin(TENS_Token).owner() == CORE_MULTISIG, "Multisig not owner of token"); // same interface
        IProxyAdmin(TENS_Proxy_Admin).transferOwnership(CORE_MULTISIG);
        require(IProxyAdmin(TENS_Proxy_Admin).owner() == CORE_MULTISIG, "Multisig not owner of proxyadmin");
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


    function transferTokenHereSupportingFeeOnTransferTokens(address token,uint256 amountTransfer) internal returns (uint256 amtAdded) {
        uint256 balBefore = IERC20(token).balanceOf(address(this));
        require(IERC20(token).transferFrom(msg.sender, address(this), amountTransfer));
        amtAdded = IERC20(token).balanceOf(address(this)).sub(balBefore);
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
    function rescueUnsupportedTokens(address token, uint256 amt) public onlyOwner {
        IERC20(token).transfer(CORE_MULTISIG, amt);
    }

    function sendETHToLGE(uint256 amt, address payable lgeContract) onlyOwner public {
        uint256 totalETH = Ether_Total_For_TENS_LP.add(Ether_Total_For_UNICORE_LP).add(Ether_Total_For_Encore_LP);
        require(totalETHSent <= totalETH, "Too much sent");
        totalETHSent = totalETHSent.add(amt);
        require(lgeContract != address(0)," no ");
        sendETH(lgeContract, amt);
        emit ETHSendToLGE(amt);
    }

    function sendETHToTreasury(uint256 amt, address payable to) onlyOwner public {
        uint256 totalETH = Ether_Total_For_TENS_LP.add(Ether_Total_For_UNICORE_LP).add(Ether_Total_For_Encore_LP);
        require(totalETHSent == totalETH, "Still money to send to LGE");
        require(to != address(0)," no ");
        sendETH(to, amt);
    }

    function claimLPFromLGE(address lgeContract) onlyOwner public {
        require(postLGELPTokenAddress != address(0), "LP token address not set.");
        ILGE(lgeContract).claimLP();
        
        LPClaimedFromLGE = true;
        totalLPClaimed = IERC20(postLGELPTokenAddress).balanceOf(address(this));
    }

}
