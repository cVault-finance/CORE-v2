const CoreToken = artifacts.require('CORE');
const CoreVault = artifacts.require('CoreVault');
const { expectRevert, time, BN, ether, balance } = require('@openzeppelin/test-helpers');
const { inTransaction } = require('@openzeppelin/test-helpers/src/expectEvent');
const { assertion } = require('@openzeppelin/test-helpers/src/expectRevert');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');
const ganache = require("ganache-core");
const { assert } = require('hardhat');
const hre = require("hardhat");

const WETH9 = artifacts.require('WETH9');
const UniV2Pair = artifacts.require("UniswapV2Pair");
const UniswapV2Factory = artifacts.require('UniswapV2Factory');
const FeeApprover = artifacts.require('FeeApprover');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');

const ERC95 = artifacts.require('ERC95');
const WBTC = artifacts.require('WBTC');
const ERC20DetailedToken = artifacts.require('ERC20DetailedToken');
const LGE = artifacts.require('cLGE');
const COREGlobals = artifacts.require('COREGlobals');
const COREDelegator = artifacts.require('COREDelegator');
const cBTC = artifacts.require('cBTC');
const TransferHandler01 = artifacts.require('TransferHandler01');

const TRANSFER_HANDLER_ADDRESS = "0x2e2a33ceca9aef101d679ed058368ac994118e7a"
const WBTC_ETH_PAIR_ADDRESS = "0xbb2b8038a1640196fbe3e38816f3e67cba72d940"
const CORE_ETH_PAIR_ADDRESS = "0x32ce7e48debdccbfe0cd037cc89526e4382cb81b"
const CORE_VAULT_ADDRESS = "0xc5cacb708425961594b63ec171f4df27a9c0d8c9";
const LGE_2_PROXY_ADDRESS = "0xf7cA8F55c54CbB6d0965BC6D65C43aDC500Bc591";
const proxyAdmin_ADDRESS = "0x9cb1eeccd165090a4a091209e8c3a353954b1f0f";
const CORE_GLOBALS_ADDRESS = "0x255ca4596a963883afe0ef9c85ea071cc050128b";
const CORE_MULTISIG = "0x5A16552f59ea34E44ec81E58b3817833E9fD5436"
const UNISWAP_ROUTER_ADDRESS = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
const WBTC_ADDRESS = "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599"
const MAINNET_WBTC_MINTER = "0xca06411bd7a7296d7dbdd0050dfc846e95febeb7";
const DEAD_ADDRESS = "0x000000000000000000000000000000000000dEaD";
const CORE_ADDRESS = "0x62359Ed7505Efc61FF1D56fEF82158CcaffA23D7";
const CBTC_PROXY = "0x7b5982dcAB054C377517759d0D2a3a5D02615AB8";
const UNISWAP_FACTORY_ADDRESS = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f";
const snapshot = require('./snapshot');

const ProxyAdminContract = artifacts.require('ProxyAdmin');
const { advanceBlock, advanceTime, advanceTimeAndBlock } = require('./timeHelpers');

const advanceByHours = async (hours) => {
    await advanceTimeAndBlock(60 * 60 * hours);
}
const MAX_53_BIT = 4503599627370495;
const GAS_LIMIT = 0x1fffffffffffff;

const impersonate = async (address) => {
    console.log(`Impersonating ${address}`)
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [address]
    })
}

const upgrade = async (owner, proxy_address, toContractImplementationAddress /* normally is CONTRACT.new() */ ) => {
    let adminProxy = await ProxyAdminContract.at(proxyAdmin_ADDRESS);
    await impersonate(owner);
    console.log(`adminProxy.upgrade: ${adminProxy.address}, ${proxy_address}, ${toContractImplementationAddress}`);
    return await adminProxy.upgrade(proxy_address, toContractImplementationAddress, {from: owner});
}

contract('LGE Live Tests', ([x3, pervert, rando, joe, john, trashcan]) => {
    // console.log(x3);

    // it("Sanity test for Ganache", async function () {
    //     let actual_test_block = (await web3.eth.getBlock("latest")).number;
    //     console.log(actual_test_block);
    //     console.log(`BLOCK NUMBER: ${this.test_block_num}\nACTUAL BLCOK NUMBER: ${actual_test_block}`);
    //     assert(actual_test_block > 11088005, "Test environment problem 1");
    // });
    afterEach(async function () {
        console.log(`Reverting to snapshot ${this.snapshotId}`);
        await snapshot.revertToSnapshot(this.snapshotId);
    });

    beforeEach(async function () {
        this.timeout(120000)
        impersonate("0x5a16552f59ea34e44ec81e58b3817833e9fd5436");
        this.snapshotId = await snapshot.takeSnapshot();
        console.log(`Took snapshot ${this.snapshotId}`);
        this.owner = "0x5A16552f59ea34E44ec81E58b3817833E9fD5436";
        this.OxRevertMainnetAddress = '0xd5b47B80668840e7164C1D1d81aF8a9d9727B421';
        this.iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);

        // We check units of someone here
        // const preUpgradeUnitsOfRandomPerson = await this.iLGE.unitsContributed('0xf015aad0d3d0c7468f5abeac1c50043de3e5cdda');
        // const preUpgradeTimestampStart = await this.iLGE.contractStartTimestamp();

        // We upgrade
        // this.iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);

        // We sanity check units again after upgrade in case of a memory error
        // const postUpgradeUnitsOfRandomPerson = await this.iLGE.unitsContributed('0xf015aad0d3d0c7468f5abeac1c50043de3e5cdda');
        // const postUpgradeTimestampStart = await this.iLGE.contractStartTimestamp();
        // assert(parseInt(preUpgradeUnitsOfRandomPerson) == parseInt(postUpgradeUnitsOfRandomPerson), "Mismatch units after upgrade mem error");
        // assert(parseInt(preUpgradeTimestampStart) == parseInt(postUpgradeTimestampStart), "Mismatch units after upgrade mem error");

        // get the wrappedToken value (cBTC in this case.)
        // this.wrappedTokenAddress = await this.iLGE.wrappedToken();
        // let wrappedToken = await cBTC.at(this.wrappedTokenAddress);

        // Before ending the LGE, you have to set the LGEAddress on cBTC...
        // await wrappedToken.setLGEAddress(LGE_2_PROXY_ADDRESS, { from: CORE_MULTISIG });

        // let adminProxy = await ProxyAdminContract.at(proxyAdmin_ADDRESS);
        // Upgrade cBTC
        // let newCBTCImpl = await cBTC.new();
        // impersonate(this.owner);
        // console.log(`adminProxy.upgrade: ${adminProxy.address}, ${CBTC_PROXY}, ${newCBTCImpl.address}`);
        // await adminProxy.upgrade(CBTC_PROXY, newCBTCImpl.address, {from: this.owner});


        // this.router = await UniswapV2Router02.new(this.factory.address, this.weth.address, { from: x3 });
    });

    it("Recreates removal of liquidity circumstances successfully", async function () {
        impersonate(x3);
        this.weth = await WETH9.at("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2");
        this.factory = await UniswapV2Factory.at(UNISWAP_FACTORY_ADDRESS);
        let uniRouter = await UniswapV2Router02.new(this.factory.address, this.weth.address, { from: x3 });
        console.log('weth address', this.weth.address);
        console.log('this.factory.address', this.factory.address);

        let latest_block_data = (await web3.eth.getBlock("latest"));
        let actual_test_block = latest_block_data.number;
        let latest_block_timestamp = latest_block_data.timestamp;
        const mrLiquidityRemover = "0x1f4d088464a0175c8ddb90bc7a510b1d5a0da1a6";
        await impersonate(mrLiquidityRemover);

        // let newCBTC = await cBTC.new();
        // await upgrade(this.owner, CBTC_PROXY, newCBTC.address);

        let cbtcCorePair = await UniV2Pair.at("0x6fad7d44640c5cd0120deec0301e8cf850becb68");
        await cbtcCorePair.approve(uniRouter.address, "9999999999999999999999", {from: mrLiquidityRemover});

        const newTHandler = await TransferHandler01.new();
        let adminProxy = await ProxyAdminContract.at(proxyAdmin_ADDRESS);
        await impersonate(this.owner);
        console.log(`adminProxy.upgrade: ${adminProxy.address}, ${TRANSFER_HANDLER_ADDRESS}, ${newTHandler.address}`);
        await adminProxy.upgrade(TRANSFER_HANDLER_ADDRESS, newTHandler.address, {from: this.owner});

        // Try to remove liquidity
        await impersonate(mrLiquidityRemover);
        let liquidity = new BN("891954058369");
        let amountAMin = new BN("144059597049542987");
        let amountBMin = new BN("5469633");
        let deadline = new BN("9999999999999999"); //(new BN(latest_block_timestamp)).add(new BN(1200)); // 120 seconds from this latest block
        let liqRemoval = await uniRouter.removeLiquidity(
            CORE_ADDRESS,
            CBTC_PROXY,
            liquidity.toString(),
            amountAMin.toString(),
            amountBMin.toString(),
            mrLiquidityRemover,
            deadline.toString(),
            {from: mrLiquidityRemover}
        )
    })

    /*
    it("Test cBTC wrap of wBTC", async function () {
        let gibbs = "0xe27953E859203598387968F04F55fD130a234C67";
        impersonate(gibbs);

        let wbtcInstance = await WBTC.at("0x2260fac5e5542a773aa44fbcfedf7c193bc2c599");
        let cBTCInstance = await cBTC.at(this.wrappedTokenAddress);
        let allowance = await wbtcInstance.allowance(gibbs, cBTCInstance.address, {from: gibbs})
        console.log(`# initial WBTC allowance for spender, cBTC: ${allowance}`);
        await wbtcInstance.approve(cBTCInstance.address, 100000000, {from: gibbs});
        console.log(`# new WBTC allowance for spender, cBTC: ${allowance}`);
        let r = await cBTCInstance.wrap(gibbs, 1, {from: gibbs});
        
        // console.log(r);
    })*/

    // it("Adds LP", async function () {
    //     this.timeout(120000)
    //     let iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);
    //     await endLGEAdmin(iLGE);
    // })

/*
    it("Doesn't give out LP to people who didn't contribute", async function () {
        this.timeout(120000)
        let iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);
        await advanceByHours(999); // we make it finished but not call end
        await endLGEAdmin(iLGE);
        await expectRevert(iLGE.claimLP({ from: rando }), "LEG : Nothing to claim")
    })


    it("Should have a core vault showing the correct token address on mainnet", async () => {
        let cv = await CoreVault.at(CORE_VAULT_ADDRESS);
        let coreTokenFromMainnet = await cv.core();
        assert(coreTokenFromMainnet == "0x62359Ed7505Efc61FF1D56fEF82158CcaffA23D7", "Sanity check for core token address failed on Core Vault")
    });

    it("Should not let others extend LGE", async function () {
        let iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);
        await expectRevert(iLGE.extendLGE(1, { from: trashcan }), "LGE: Requires admin");
        impersonate(this.OxRevertMainnetAddress);
        await iLGE.extendLGE(1, { from: this.OxRevertMainnetAddress });
    });

    it("LGE Ends on timestamp expected", async function () {
        this.timeout(60000)
        let iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);

        let block = await web3.eth.getBlock("latest")
        block_number = block.number;
        block_timestamp = block.timestamp;
        let lgeOver = await iLGE.isLGEOver();

        // Sanity test, LGE shouldn't be over when performing this test from the most recent block.
        // If this fails then the LGE already ended and everyone is cheering, rah rah!
        assert(lgeOver == false, `LGE ended prematurely at ${block_timestamp}`);

        // Loop through advancing time 6 hours at a time until lgeOVER is true
        const second = 1;
        const minute = 60 * second;
        const hour = 60 * minute
        const day = 24 * hour
        const lgeEndTimestamp = parseInt(await iLGE.contractStartTimestamp()) + day * 7 + 30 * minute;
        console.log(`LGE should end at ${lgeEndTimestamp}`)
        let dayNum = 0;
        const hoursPerBlockToSkip = 6;
        while (dayNum <= 8 * 24 / hoursPerBlockToSkip) {
            await advanceByHours(hoursPerBlockToSkip);

            const blockTimestamp = (await web3.eth.getBlock("latest")).timestamp;
            let lgeOVER = await iLGE.isLGEOver();
            if (blockTimestamp > lgeEndTimestamp) {

                // Reached beyond the end point of the LGE
                assert(lgeOVER, `LGE should have ended by ${blockTimestamp}`)
                dayNum = 1e20; // early exit
                console.log(`lgeOVER at ${blockTimestamp}`);
            }
            else {
                assert(lgeOVER == false, `LGE should NOT have ended by ${blockTimestamp}`)
            }
            dayNum++;
            if (dayNum == 8 * 24 / hoursPerBlockToSkip) {
                assert(false, "8 days should be long enough for the LGE to end");
            }
        }

        // Mine a few more blocks without timestamp override and make sure the LGE is still in the ended state based on the timestamp incrementing
        await advanceBlock();
        let lgeOVER = await iLGE.isLGEOver();
        assert(lgeOVER, `LGE should have ended after artificially moving timestamp forward`)
        await advanceBlock();
        lgeOVER = await iLGE.isLGEOver();
        assert(lgeOVER, `LGE should have ended after artificially moving timestamp forward`)

        // let addLPE = await iLGE.addLiquidityToPairPublic({ from: rando }); // Why is this reverting?
        // let totalLPCreated = await iLGE.totalLPCreated();
        // console.log(`We created total of ${totalLPCreated} LP units thats is ${totalLPCreated / 1e18} LP tokens`);
        // // unitsContributed[msg.sender].sub(getCORERefundForPerson(msg.sender)).mul(LPPerUnitContributed).div(1e18));
        // // Lets say we contributed 1 unit so we shoul dget
        // const getFor1CORE = 1e18 * (await iLGE.LPPerUnitContributed()) / 1e18
        // console.log(`Total per unit contribute (1CORE) is ${getFor1CORE}LP Units so ${getFor1CORE / 1e18} LP token`)
        // console.log(`So if we divide it by 820 which is about the value in core contributed rn =
        //  ${getFor1CORE / 1e18 * 820} LP`)
        // console.log(`We are refunding total of ${await iLGE.totalCOREToRefund() / 1e18} CORE`)
        // const CORE_CBTC_PAIR_ADDRESS = await iLGE.wrappedTokenUniswapPair();

        // const CORE_CBTC_PAIR = await UniV2Pair.at(CORE_CBTC_PAIR_ADDRESS);
        // console.log(`cBTC/CORE pair is  at ${CORE_CBTC_PAIR_ADDRESS}`);
        // const { _reserve0: coreReserveCBTCPair, _reserve1: cBTCReserve } = await CORE_CBTC_PAIR.getReserves();
        // console.log(`Reserves of CORE  in new pair ${coreReserveCBTCPair / 1e18} and reserve of cBTC ${cBTCReserve / 1e8}`);
        // const valueOFCOREINNEWPAIR = coreReserveCBTCPair / 1e18 * ETHperCORE;
        // const valueofWBTCINHTENEWPAIR = cBTCReserve / 1e8 * ETHperWBTC;

        // console.log(`LIVE ETH per CORE ${ETHperCORE} ETH per WBTC ${ETHperWBTC}`);
        // console.log(`Price of cBTC reserves in pair  ${valueOFCOREINNEWPAIR}ETH value of all  CORE in the pair ${valueofWBTCINHTENEWPAIR}ETH`)
        // console.log(`Price delta ${((valueOFCOREINNEWPAIR < valueofWBTCINHTENEWPAIR ? valueofWBTCINHTENEWPAIR / valueOFCOREINNEWPAIR : valueOFCOREINNEWPAIR / valueofWBTCINHTENEWPAIR) * 100) - 100}%`)
        // // Next, let's claim some LP from rando, who didn't actually contribute to the LGE
        // console.log("Next, let's claim some LP from rando, who didn't actually contribute to the LGE");
    });

    it("Doesn't give out LP to people who didn't contributeAnd doesn't allow for several contributions", async function () {
        this.timeout(120000)

        let iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);
        await iLGE.addLiquidityETH({ from: joe, value: 1e18 });
        await advanceByHours(999); // we make it finished but not call end
        await endLGEAdmin(iLGE);
        await expectRevert(iLGE.claimLP({ from: rando }), "LEG : Nothing to claim")
        await iLGE.claimLP({ from: joe });
        await expectRevert(iLGE.claimLP({ from: joe }), "LEG : Nothing to claim")
        await expectRevert(iLGE.claimAndStakeLP({ from: joe }), "LEG : Nothing to claim")

    })



    it("It gives units as expected putting in 1 ETH and can claim lp", async function () {

        this.timeout(60000)
        let iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);

        //Contribute 1 ETH
        await iLGE.addLiquidityETH({ from: joe, value: 1e18 });

        await advanceByHours(999); // we make it finished but not call end
        this.ETH_CORE_PAIR = await UniV2Pair.at(CORE_ETH_PAIR_ADDRESS);
        this.ETH_WBTC_PAIR = await UniV2Pair.at(WBTC_ETH_PAIR_ADDRESS);

        const { _reserve0: coreReserve, _reserve1: wethReserveInCorePair } = await this.ETH_CORE_PAIR.getReserves();
        const ETHperCORE = (wethReserveInCorePair / 1e18) / (coreReserve / 1e18);

        const shouldHaveGottenCOREUnits = 1e18 / ETHperCORE;


        const joeGotCoreUnits = await this.iLGE.unitsContributed(joe)
        assert((shouldHaveGottenCOREUnits * 1.1) > joeGotCoreUnits && (shouldHaveGottenCOREUnits * 0.9) < joeGotCoreUnits, "Joe got a mismatched 10% from actual")

        // function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns(uint amountOut);
        await endLGEAdmin(this.iLGE);

        this.CBTC_CORE_PAIR = await UniV2Pair.at(await this.iLGE.wrappedTokenUniswapPair());

        // Joe can claim LP
        await this.iLGE.claimLP({ from: joe });
        assert((await this.CBTC_CORE_PAIR.balanceOf(joe)) > 0, "Joe didn't claim more than 0 LP tokens even tho he gave 1eth");


    });

    it("LGE Reverts claiming LP and Refunds before its over, And before liq is added", async function () {
        this.timeout(60000)
        let iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);

        await expectRevert(iLGE.claimLP({ from: rando }), "LGE : Liquidity generation not finished")
        await expectRevert(iLGE.getCOREREfund({ from: rando }), "LGE not finished")
        await advanceByHours(999); // we make it finished but not call end
        await expectRevert(iLGE.claimLP({ from: rando }), "LGE : Liquidity generation not finished")
        await expectRevert(iLGE.getCOREREfund({ from: rando }), "LGE not finished")

    });


    it("LGE Finish is publically callable", async function () {
        this.timeout(60000)
        let iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);
        await advanceByHours(999); // we make it finished but not call end
        await iLGE.addLiquidityToPairPublic({ from: rando });
    });

    it("LGE Finish is admin callable with ratios from mainnet", async function () {
        this.timeout(60000)
        let iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);
        await advanceByHours(999); // we make it finished but not call end
        //function addLiquidityToPairAdmin(uint256 ratio1ETHWholeBuysXCOREUnits, uint256 ratio1ETHWholeBuysXWrappedTokenUnits)
        // function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns(uint amountOut);
        await endLGEAdmin(iLGE);

    });

    it("Can unlock cBTC", async function () {
        await unlockCBTC();
    });


    it("Vault handles multiple pools", async function () {
        this.timeout(120000)

        let vault = await CoreVault.at(CORE_VAULT_ADDRESS);
        await vault.massUpdatePools();
        assert((await vault.pendingRewards()) == 0, " Pending rewards is not 0 restart test pls");
        const CORE = await CoreToken.at(CORE_ADDRESS);
        // test token for stake
        this.DORE = await ERC20DetailedToken.new("Dumbledore Token", "DORE", "18", ((new BN(10000)).mul((new BN(10)).pow(new BN(18)))).toString(), { from: x3 });

        let accCorePerSharePool0 = new BN((await vault.poolInfo(0)).accCorePerShare); // Old pool has 100 alloc
        console.log(`Share for pool 0 before doing anything - ${accCorePerSharePool0}`)
        console.log(`Adding new pool for test token`);
        // function add(
        //     uint256 _allocPoint,
        //     IERC20 _token,
        //     bool _withUpdate,
        //     bool _withdrawable
        // ) public onlyOwner {
        await vault.add(0, this.DORE.address, true, true, { from: CORE_MULTISIG });
        await this.DORE.approve(CORE_VAULT_ADDRESS,
            ((new BN(10000)).mul((new BN(10)).pow(new BN(18)))).toString()
            , { from: x3 });
        vault.deposit(1, ((new BN(9708)).mul((new BN(10)).pow(new BN(18)))).toString(), { from: x3 })
        let accCorePerSharePool1 = new BN((await vault.poolInfo(1)).accCorePerShare); // Old pool has 100 alloc
        console.log(`Share for pool 1 just after adding- ${accCorePerSharePool1}`)
        console.log(`Balance of vault  before burn transfer ${await CORE.balanceOf(CORE_VAULT_ADDRESS)}`)
        await CORE.transfer(DEAD_ADDRESS, 1e17.toString(), { from: CORE_MULTISIG }) //10 tax
        console.log(`Balance of vault  after burn transfer${await CORE.balanceOf(CORE_VAULT_ADDRESS)}`)
        console.log(`Pending rewards after transfer${await vault.pendingRewards()}`)

        await vault.massUpdatePools();

        let accCorePerSharePool0After = new BN((await vault.poolInfo(0)).accCorePerShare); // Old pool has 100 alloc
        let accCorePerSharePool1After = new BN((await vault.poolInfo(1)).accCorePerShare); // Old pool has 100 alloc
        console.log(`Pool0 added- ${accCorePerSharePool0After.sub(accCorePerSharePool0)}`)
        console.log(`Pool1 added- ${accCorePerSharePool1After.sub(accCorePerSharePool1)}`)

        // /////   function set(
        // uint256 _pid,
        //     uint256 _allocPoint,
        //         bool _withUpdate

        console.log("-----")
        console.log(`After a addition of 1e15 and mass update (50/50 split)`)
        await vault.set(1, 100, true, { from: CORE_MULTISIG }); //100 and 100 so 50/50
        accCorePerSharePool0 = new BN((await vault.poolInfo(0)).accCorePerShare);
        accCorePerSharePool1 = new BN((await vault.poolInfo(1)).accCorePerShare);
        await CORE.transfer(DEAD_ADDRESS, 1e17.toString(), { from: CORE_MULTISIG }) //10 tax

        await vault.massUpdatePools();
        accCorePerSharePool0After = new BN((await vault.poolInfo(0)).accCorePerShare);
        accCorePerSharePool1After = new BN((await vault.poolInfo(1)).accCorePerShare);
        console.log(`Pool0 added- ${accCorePerSharePool0After.sub(accCorePerSharePool0)}`)
        console.log(`Pool1 added- ${accCorePerSharePool1After.sub(accCorePerSharePool1)}`)

        //////
        console.log("-----")
        console.log(`After a addition of 1e15 and mass update (10/90 split)`)
        await vault.set(0, 900, true, { from: CORE_MULTISIG }); //900 and 100 so 90/10
        accCorePerSharePool0 = new BN((await vault.poolInfo(0)).accCorePerShare);
        accCorePerSharePool1 = new BN((await vault.poolInfo(1)).accCorePerShare);
        await CORE.transfer(DEAD_ADDRESS, 1e17.toString(), { from: CORE_MULTISIG }) //10 tax
        await vault.massUpdatePools();
        accCorePerSharePool0After = new BN((await vault.poolInfo(0)).accCorePerShare);
        accCorePerSharePool1After = new BN((await vault.poolInfo(1)).accCorePerShare);
        console.log(`Pool0 added- ${accCorePerSharePool0After.sub(accCorePerSharePool0)}`)
        console.log(`Pool1 added- ${accCorePerSharePool1After.sub(accCorePerSharePool1)}`)
    });

    it("LGE refunds work and are callable", async function () {
        this.timeout(120000)
        let iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);

        //Contribute 1 ETH
        const previousBalance = await iLGE.unitsContributed('0x4523b791292da89A9194B61bA4CD9d98f2af68E0');

        await iLGE.matchCreditFromLPContributionBug({ from: CORE_MULTISIG });
        const nowBalannce = await iLGE.unitsContributed('0x4523b791292da89A9194B61bA4CD9d98f2af68E0');
        console.log(`
        Prevoious balance for refund ${previousBalance}
        Balance now ${nowBalannce}
        expected refund is 7831928571428571000
        now - prev = ${nowBalannce - previousBalance}`)
        assert(parseInt(nowBalannce) == parseInt(previousBalance) + 7831928571428571000, "Incorrectly refunded(maybe change check previosu log)")

    });


    it("Deposit for person after LGE is over works", async function () {
        this.timeout(60000)
        let iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);

        //Contribute 1 ETH
        await iLGE.addLiquidityETH({ from: joe, value: 1e18 });

        await advanceByHours(999); // we make it finished but not call end

        await endLGEAdmin(this.iLGE);
        console.log(`We created this much LP token units ${await this.iLGE.totalLPCreated()}`)
        let vault = await CoreVault.at(CORE_VAULT_ADDRESS);

        await vault.add(0, await iLGE.wrappedTokenUniswapPair(), true, true, { from: CORE_MULTISIG });

        await this.iLGE.claimAndStakeLP({ from: joe });
        // mapping(uint256 => mapping(address => UserInfo)) public userInfo;
        // This might be gotten diffrently i dont know cant check rn
        console.log("Amount that user has in vault")
        console.log(parseInt(((await vault.userInfo(1, joe)).amount).toString()))
        assert(parseInt(((await vault.userInfo(1, joe)).amount).toString()) > 0, "User wasn't credited for deposit in the vault");

    });


    it("Can't burn new LP tokens immidietly after LGE cuse of SYNC on feeApprover", async function () {
        this.timeout(60000)
        let iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);

        //Contribute 1 ETH
        await iLGE.addLiquidityETH({ from: joe, value: 1e18 });

        await advanceByHours(999); // we make it finished but not call end

        const tHandler = await TransferHandler01.at(TRANSFER_HANDLER_ADDRESS);
        await endLGEAdmin(this.iLGE);
        const newPairAddress = await this.iLGE.wrappedTokenUniswapPair();
        console.log(`New Pair address is ${newPairAddress}`)
        await tHandler.addPairToTrack(newPairAddress, { from: CORE_MULTISIG })
        await tHandler.sync(newPairAddress)

        await this.iLGE.claimLP({ from: joe });
        const newPair = await UniV2Pair.at(await iLGE.wrappedTokenUniswapPair());
        await newPair.transfer(newPair.address, (await newPair.balanceOf(joe)).valueOf().toString(), { from: joe });
        await expectRevert(newPair.burn(joe), "UniswapV2: TRANSFER_FAILED")
        // mapping(uint256 => mapping(address => UserInfo)) public userInfo;
        // This might be gotten diffrently i dont know cant check rn

    });


    it("cBTC handles deposits and withdrawals correctly including 0 ", async function () {
        this.timeout(120000)

        await unlockCBTC();
        const WBTCContract = await WBTC.at(WBTC_ADDRESS);
        let iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);


        let wrappedTokenAddress = await iLGE.wrappedToken();
        mintwBTCTo(pervert, 6e8.toString());// 6btc
        mintwBTCTo(x3, 12e8.toString());// 12btc

        let cBTCContract = await cBTC.at(wrappedTokenAddress);
        const totalSupplyOfcBTCBEfore = await cBTCContract.totalSupply();
        console.log(`Total supply before  cbtc mint ${totalSupplyOfcBTCBEfore}`)
        await WBTCContract.approve(cBTCContract.address, 1e8.toString(), { from: pervert });
        await WBTCContract.approve(cBTCContract.address, 100e8.toString(), { from: x3 });

        await cBTCContract.wrap(pervert, 1e8, { from: pervert });
        console.log(`Total supply after cbtc mint ${await cBTCContract.totalSupply()}`)

        assert((await cBTCContract.totalSupply()) == (parseInt(totalSupplyOfcBTCBEfore) + 1e8), "Wrong balance before mint");
        console.log(`Balance after mint for revert ${(await cBTCContract.balanceOf(pervert))}`)
        assert((await cBTCContract.balanceOf(pervert)) == 1e8.toString(), "Wrong balance after mint");
        console.log(`Total supply after 1e8 mint ${(await cBTCContract.totalSupply())}`)


        await cBTCContract.unwrap(1e8, { from: pervert }); // wrap 1WBTC to cBTC
        await expectRevert(cBTCContract.unwrap(1, { from: pervert }), "ERC20: burn amount exceeds balance"); // wrap 1WBTC to cBTC
        console.log(`Total supply after 1e8 unwrap ${(await cBTCContract.totalSupply())}`)

        assert((await cBTCContract.balanceOf(pervert)) == 0, "Wrong balance after unwrap");
        assert((await WBTCContract.balanceOf(pervert)) == 6e8.toString(), "Wrong balance underlying after unwrap"); // 6 -1 +1 =6
        assert((await cBTCContract.totalSupply()) == totalSupplyOfcBTCBEfore.toString(), "Wrong balance after mint");
        await cBTCContract.wrapAtomic(pervert, { from: pervert });
        await cBTCContract.unwrapAll({ from: pervert })
        await cBTCContract.wrap(pervert, 0, { from: pervert });
        await cBTCContract.wrap(pervert, 0, { from: pervert });
        await cBTCContract.wrap(x3, 1e8.toString(), { from: x3 }); //1
        assert((await cBTCContract.balanceOf(x3)) == 1e8.toString(), "Wrong balance underlying after unwrap"); // 6 -1 +1 =6

        await cBTCContract.wrap(pervert, 0, { from: pervert });
        assert((await WBTCContract.balanceOf(pervert)) == 6e8.toString(), "Wrong balance underlying after unwrap"); // 6 -1 +1 =6
        await cBTCContract.wrap(pervert, 0, { from: pervert });
        await cBTCContract.wrap(pervert, 0, { from: pervert });
        await cBTCContract.skim(pervert, { from: pervert })
        await cBTCContract.unwrap(0, { from: pervert });
        await cBTCContract.wrap(x3, 1e8.toString(), { from: x3 }); //2
        await WBTCContract.transfer(cBTCContract.address, 1e8, { from: x3 });
        await cBTCContract.wrapAtomic(x3, { from: x3 }); //3
        await cBTCContract.wrapAtomic(pervert, { from: pervert });
        await cBTCContract.unwrapAll({ from: pervert })
        await cBTCContract.skim(pervert, { from: pervert })
        await cBTCContract.wrap(x3, 1e8.toString(), { from: x3 }); //4

        await cBTCContract.wrap(pervert, 0, { from: pervert });
        assert((await cBTCContract.balanceOf(pervert)) == 0, "Wrong balance after unwrap");
        await cBTCContract.wrap(pervert, 0, { from: pervert });
        await WBTCContract.transfer(cBTCContract.address, 1e8, { from: x3 }); //5
        await cBTCContract.wrapAtomic(x3, { from: x3 });

        await cBTCContract.wrapAtomic(pervert, { from: pervert });
        await cBTCContract.unwrapAll({ from: pervert })
        await cBTCContract.wrap(pervert, 0, { from: pervert });
        assert((await cBTCContract.balanceOf(pervert)) == 0, "Wrong balance underlying after unwrap"); // 6 -1 +1 =6
        await cBTCContract.unwrap(0, { from: pervert });
        await cBTCContract.wrap(x3, 1e8.toString(), { from: x3 }); //6

        assert((await cBTCContract.balanceOf(pervert)) == 0, "Wrong balance after unwrap");
        await cBTCContract.wrap(pervert, 0, { from: pervert });
        await cBTCContract.wrap(pervert, 0, { from: pervert });
        assert((await cBTCContract.balanceOf(pervert)) == 0, "Wrong balance after unwrap");
        await cBTCContract.wrap(pervert, 0, { from: pervert });
        await cBTCContract.unwrap(0, { from: pervert });
        await cBTCContract.wrap(x3, 1e8.toString(), { from: x3 }); //7
        await WBTCContract.transfer(cBTCContract.address, 1e8, { from: x3 });
        await cBTCContract.wrapAtomic(x3, { from: x3 }); //8
        assert((await cBTCContract.balanceOf(x3)) == 8e8.toString(), "Wrong balance after unwrap");
        await cBTCContract.unwrapAll({ from: x3 });
        assert((await cBTCContract.balanceOf(x3)) == 0, "Wrong balance after unwrap");
        await cBTCContract.unwrap(0, { from: pervert });
        await cBTCContract.unwrap(0, { from: pervert });
        await cBTCContract.skim(pervert, { from: pervert })
        assert((await WBTCContract.balanceOf(cBTCContract.address)) == 0, "Wrong balance underlying after unwrap"); // 6 -1 +1 =6
        assert((await WBTCContract.balanceOf(x3)) == 12e8, "Wrong balance underlying after unwrap"); // 6 -1 +1 =6

        assert((await cBTCContract.balanceOf(pervert)) == 0, "Wrong balance after unwrap");
        assert((await WBTCContract.balanceOf(pervert)) == 6e8.toString(), "Wrong balance underlying after unwrap"); // 6 -1 +1 =6

    });

*/

});

const mintwBTCTo = async (to, amt) => {
    console.log(`minting btc for ${amt}`)
    const WBTCContract = await WBTC.at(WBTC_ADDRESS);
    const balanceBefore = await WBTCContract.balanceOf(to)
    impersonate(MAINNET_WBTC_MINTER);
    impersonate(DEAD_ADDRESS);
    await WBTCContract.mint(DEAD_ADDRESS, parseInt(amt) * 100, { from: MAINNET_WBTC_MINTER }); // its minting less ? so lets just mint a lot and trasnfer from trashan
    await WBTCContract.transfer(to, amt, { from: DEAD_ADDRESS });
    console.log(`Balance after mint wbtc ${await WBTCContract.balanceOf(to)}`)
}

const unlockCBTC = async () => {
    let iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);
    let wrappedTokenAddress = await iLGE.wrappedToken();

    let wrappedToken = await cBTC.at(wrappedTokenAddress);
    await wrappedToken.setLGEAddress(CORE_MULTISIG, { from: CORE_MULTISIG });
    //unlock
    wrappedToken.unpauseTransfers({ from: CORE_MULTISIG });
    // set it back
    await wrappedToken.setLGEAddress(LGE_2_PROXY_ADDRESS, { from: CORE_MULTISIG });
}

const endLGEAdmin = async (iLGE) => {
    this.ETH_CORE_PAIR = await UniV2Pair.at(CORE_ETH_PAIR_ADDRESS);
    this.ETH_WBTC_PAIR = await UniV2Pair.at(WBTC_ETH_PAIR_ADDRESS);
    const router = await UniswapV2Router02.at(UNISWAP_ROUTER_ADDRESS);

    const { _reserve0: coreReserve, _reserve1: wethReserveInCorePair } = await this.ETH_CORE_PAIR.getReserves();
    const { _reserve0: wbtcReserve, _reserve1: wethReserveInWbtcPair } = await this.ETH_WBTC_PAIR.getReserves();
    const ratio1ETHWholeBuysXCOREUnits = await router.getAmountOut(1e18.toString(), wethReserveInCorePair, coreReserve);
    let ratio1ETHWholeBuysXWrappedTokenUnits = await router.getAmountOut(1e18.toString(), wethReserveInWbtcPair, wbtcReserve);
    console.log(`pre: ${ratio1ETHWholeBuysXWrappedTokenUnits}`);
    ratio1ETHWholeBuysXWrappedTokenUnits = ratio1ETHWholeBuysXWrappedTokenUnits.mul(new BN(103)).div(new BN(100));
    console.log(`post: ${ratio1ETHWholeBuysXWrappedTokenUnits}`);
    console.log(`ratio1ETHWholeBuysXCOREUnits ${ratio1ETHWholeBuysXCOREUnits} ratio1ETHWholeBuysXWrappedTokenUnits ${ratio1ETHWholeBuysXWrappedTokenUnits}`)
    await iLGE.addLiquidityToPairAdmin(ratio1ETHWholeBuysXCOREUnits, ratio1ETHWholeBuysXWrappedTokenUnits, { from: CORE_MULTISIG });
    assert((await iLGE.LGEFinished()) == true, "LGE didn't actually finish");
}