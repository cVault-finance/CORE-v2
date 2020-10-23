const CoreToken = artifacts.require('CORE');
const CoreVault = artifacts.require('CoreVault');
const { expectRevert, time, BN, ether, balance } = require('@openzeppelin/test-helpers');
const { inTransaction } = require('@openzeppelin/test-helpers/src/expectEvent');
const { assertion } = require('@openzeppelin/test-helpers/src/expectRevert');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');
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


const WBTC_ETH_PAIR_ADDRESS = "0xbb2b8038a1640196fbe3e38816f3e67cba72d940"
const CORE_ETH_PAIR_ADDRESS = "0x32ce7e48debdccbfe0cd037cc89526e4382cb81b"
const CORE_VAULT_ADDRESS = "0xc5cacb708425961594b63ec171f4df27a9c0d8c9";
const LGE_2_PROXY_ADDRESS = "0xf7cA8F55c54CbB6d0965BC6D65C43aDC500Bc591";
const proxyAdmin_ADDRESS = "0x9cb1eeccd165090a4a091209e8c3a353954b1f0f";
const CORE_GLOBALS_ADDRESS = "0x255ca4596a963883afe0ef9c85ea071cc050128b";
const CORE_MULTISIG = "0x5A16552f59ea34E44ec81E58b3817833E9fD5436"
const ProxyAdminContract = artifacts.require('ProxyAdmin');
const { advanceBlock, advanceTime, advanceTimeAndBlock } = require('./timeHelpers');

const advanceByHours = async (hours) => {
    await advanceTimeAndBlock(60 * 60 * hours);
}
const MAX_53_BIT = 4503599627370495;
const GAS_LIMIT = 0x1fffffffffffff;

contract('LGE Live Tests', ([x3, pervert, rando, joe, john, trashcan]) => {

    beforeEach(async () => {
        this.owner = "0x5A16552f59ea34E44ec81E58b3817833E9fD5436";
        this.OxRevertMainnetAddress = '0xd5b47B80668840e7164C1D1d81aF8a9d9727B421';
    });

    it("Tests should fork from mainnet at a block number after the LGE is started and deployed", async () => {
        // Sanity tests to assure ganache restarts for each test trial
        this.mainnet_deployment_address = "0x5A16552f59ea34E44ec81E58b3817833E9fD5436";
        let block = await web3.eth.getBlock("latest")
        block_number = block.number;
        // Lge upgrading test
        this.LGEUpgrade = await LGE.new({ from: pervert, gasLimit: 50000000 });
        // proxy admin for upgrades
        let proxyAdmin = await ProxyAdminContract.at(proxyAdmin_ADDRESS);
        // We get new transfer handler
        this.CORETransferHandler = await COREDelegator.new({ from: pervert });
        // we upgrade LGE
        let iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);

        // We check units of someone here
        const preUpgradeUnitsOfRandomPerson = await iLGE.unitsContributed('0xf015aad0d3d0c7468f5abeac1c50043de3e5cdda');
        const preUpgradeTimestampStart = await iLGE.contractStartTimestamp();

        // We upgrade
        await proxyAdmin.upgrade(LGE_2_PROXY_ADDRESS, this.LGEUpgrade.address, { from: this.owner })

        // We sanity check units again after upgrade in case of a memory error
        const postUpgradeUnitsOfRandomPerson = await iLGE.unitsContributed('0xf015aad0d3d0c7468f5abeac1c50043de3e5cdda');
        const postUpgradeTimestampStart = await iLGE.contractStartTimestamp();
        assert(parseInt(preUpgradeUnitsOfRandomPerson) == parseInt(postUpgradeUnitsOfRandomPerson), "Mismatch units after upgrade mem error");
        assert(parseInt(preUpgradeTimestampStart) == parseInt(postUpgradeTimestampStart), "Mismatch units after upgrade mem error");

        //This is now upgraded
        let globalsLive = await COREGlobals.at(CORE_GLOBALS_ADDRESS);
        // we setnew transfer handler to transfer handler
        await globalsLive.setTransferHandler(this.CORETransferHandler.address, { from: this.owner });

        assert(block_number > 11088005, "Run ganache using the script /src/startTestEnvironment.sh before running these tests");
        let x3bal = await web3.eth.getBalance(x3);
        assert(x3bal == ether('100'), "If this was the first test run then we should expect 100 ETH for the first wallet. You should restart ganache.")
        // Send 1 eth to the x3 address to deliberately break tests if they're run twice without restarting ganache
        await web3.eth.sendTransaction({
            from: pervert,
            to: x3,
            value: ether('1')
        });
        x3bal = await web3.eth.getBalance(x3);
        assert(x3bal == ether('101'), "ETH balance error on wallet 0");
    });
    it("Should have a core vault showing the correct token address on mainnet", async () => {
        let cv = await CoreVault.at(CORE_VAULT_ADDRESS);
        let coreTokenFromMainnet = await cv.core();
        assert(coreTokenFromMainnet == "0x62359Ed7505Efc61FF1D56fEF82158CcaffA23D7", "Sanity check for core token address failed on Core Vault")
    });

    it("Should not let others extend LGE", async () => {
        let iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);
        await expectRevert(iLGE.extendLGE(1, { from: trashcan }), "LGE: Requires admin");
        await iLGE.extendLGE(1, { from: this.OxRevertMainnetAddress });
    });

    it("Should handle LGE ending properly", async function () {
        this.timeout(60000)

        let block = await web3.eth.getBlock("latest")
        block_number = block.number;
        block_timestamp = block.timestamp;
        console.log(`timestamp: ${block_timestamp}`);
        let iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);
        let lgeOver = await iLGE.isLGEOver();

        this.ETH_CORE_PAIR = await UniV2Pair.at(CORE_ETH_PAIR_ADDRESS);
        this.ETH_WBTC_PAIR = await UniV2Pair.at(WBTC_ETH_PAIR_ADDRESS);
        const { _reserve0: coreReserve, _reserve1: wethReserveInCorePair } = await this.ETH_CORE_PAIR.getReserves();
        const { _reserve0: wbtcReserve, _reserve1: wethReserveInWbtcPair } = await this.ETH_WBTC_PAIR.getReserves();
        const ETHperCORE = (wethReserveInCorePair / 1e18) / (coreReserve / 1e18);
        const ETHperWBTC = (wethReserveInWbtcPair / 1e18) / (wbtcReserve / 1e8);

        //Contribute 1 ETH

        await iLGE.addLiquidityETH({ from: joe, value: 1e18 });
        const shouldHaveGottenCOREUnits = 1e18 / ETHperCORE;



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
        if (lgeOVER) {
            console.log("OKAY. LGE OVER.")
        }

        // Now the fun begins, extending the mainnet data set and avancing us past the point of LGE completion means we can now test with mainnet numbers

        // First, let's try to claim the LP without actually ending the LGE, and make sure that fails
        console.log("First, let's try to claim the LP without actually ending the LGE, and make sure that fails");
        await expectRevert(iLGE.claimLP({ from: rando }), "LGE : Liquidity generation not finished")

        // get the wrappedToken value (cBTC in this case.)
        let wrappedTokenAddress = await iLGE.wrappedToken();
        let wrappedToken = await cBTC.at(wrappedTokenAddress);
        console.log(`Got wrapped cBTC (presumably) from ${wrappedTokenAddress}.`);

        // Before ending the LGE, you have to set the LGEAddress on cBTC...
        await wrappedToken.setLGEAddress(LGE_2_PROXY_ADDRESS, { from: CORE_MULTISIG });

        // Ok, end the LGE now
        console.log("Ok, end the LGE now");
        // Advance another 3 hours to make sure the grace period passed
        await advanceByHours(3);




        let addLPE = await iLGE.addLiquidityToPairPublic({ from: rando }); // Why is this reverting?
        let totalLPCreated = await iLGE.totalLPCreated();
        console.log(`We created total of ${totalLPCreated} LP units thats is ${totalLPCreated / 1e18} LP tokens`);
        // unitsContributed[msg.sender].sub(getCORERefundForPerson(msg.sender)).mul(LPPerUnitContributed).div(1e18));
        // Lets say we contributed 1 unit so we shoul dget
        const getFor1CORE = 1e18 * (await iLGE.LPPerUnitContributed()) / 1e18
        console.log(`Total per unit contribute (1CORE) is ${getFor1CORE}LP Units so ${getFor1CORE / 1e18} LP token`)
        console.log(`So if we divide it by 820 which is about the value in core contributed rn =
         ${getFor1CORE / 1e18 * 820} LP`)
        console.log(`We are refunding total of ${await iLGE.totalCOREToRefund() / 1e18} CORE`)
        const CORE_CBTC_PAIR_ADDRESS = await iLGE.wrappedTokenUniswapPair();

        const CORE_CBTC_PAIR = await UniV2Pair.at(CORE_CBTC_PAIR_ADDRESS);
        console.log(`cBTC/CORE pair is  at ${CORE_CBTC_PAIR_ADDRESS}`);
        const { _reserve0: coreReserveCBTCPair, _reserve1: cBTCReserve } = await CORE_CBTC_PAIR.getReserves();
        console.log(`Reserves of CORE  in new pair ${coreReserveCBTCPair / 1e18} and reserve of cBTC ${cBTCReserve / 1e8}`);
        const valueOFCOREINNEWPAIR = coreReserveCBTCPair / 1e18 * ETHperCORE;
        const valueofWBTCINHTENEWPAIR = cBTCReserve / 1e8 * ETHperWBTC;

        console.log(`LIVE ETH per CORE ${ETHperCORE} ETH per WBTC ${ETHperWBTC}`);
        console.log(`Price of cBTC reserves in pair  ${valueOFCOREINNEWPAIR}ETH value of all  CORE in the pair ${valueofWBTCINHTENEWPAIR}ETH`)
        console.log(`Price delta ${((valueOFCOREINNEWPAIR < valueofWBTCINHTENEWPAIR ? valueofWBTCINHTENEWPAIR / valueOFCOREINNEWPAIR : valueOFCOREINNEWPAIR / valueofWBTCINHTENEWPAIR) * 100) - 100}%`)
        // Next, let's claim some LP from rando, who didn't actually contribute to the LGE
        console.log("Next, let's claim some LP from rando, who didn't actually contribute to the LGE");
        await expectRevert(iLGE.claimLP({ from: rando }), "LEG : Nothing to claim.")
        console.log("It reverts as expected")

        const joeGotCoreUnits = await iLGE.unitsContributed(joe)
        assert((shouldHaveGottenCOREUnits * 1.1) > joeGotCoreUnits && (shouldHaveGottenCOREUnits * 0.9) < joeGotCoreUnits, "Joe got a mismatched 10% from actual")
        console.log("Eth contribution from joe test pass (10% max deviation form current)")
        await iLGE.claimLP({ from: joe });

        console.log("Joe can claim LP")
    });


});