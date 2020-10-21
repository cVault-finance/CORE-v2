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

const CORE_VAULT_ADDRESS = "0xc5cacb708425961594b63ec171f4df27a9c0d8c9";
const LGE_2_PROXY_ADDRESS = "0xf7cA8F55c54CbB6d0965BC6D65C43aDC500Bc591";
const proxyAdmin_ADDRESS = "0x9cb1eeccd165090a4a091209e8c3a353954b1f0f";
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
        this.LGEUpgrade = await LGE.new({ from: pervert, gasLimit: 50000000 });
        let proxyAdmin = await ProxyAdminContract.at(proxyAdmin_ADDRESS);
        await proxyAdmin.upgrade(LGE_2_PROXY_ADDRESS, this.LGEUpgrade.address, { from: this.owner })
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
        await expectRevert(iLGE.extendLGE(1, { from: trashcan }), "LGE: MSG SENDER NOT REVERT");
        await iLGE.extendLGE(1, { from: this.OxRevertMainnetAddress });
    });

    it("Should handle LGE ending properly", async () => {
        let block = await web3.eth.getBlock("latest")
        block_number = block.number;
        block_timestamp = block.timestamp;
        console.log(`timestamp: ${block_timestamp}`);
        let iLGE = await LGE.at(LGE_2_PROXY_ADDRESS);
        let lgeOver = await iLGE.isLGEOver();

        // Sanity test, LGE shouldn't be over when performing this test from the most recent block.
        // If this fails then the LGE already ended and everyone is cheering, rah rah!
        assert(lgeOver == false, `LGE ended prematurely at ${block_timestamp}`);

        // Loop through advancing time 6 hours at a time until lgeOVER is true
        const lgeEndTimestamp = 1603579592;
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
        await wrappedToken.setLGEAddress(LGE_2_PROXY_ADDRESS, { from: this.owner });

        // Ok, end the LGE now
        console.log("Ok, end the LGE now");
        // Advance another 3 hours to make sure the grace period passed
        await advanceByHours(3);

        let addLPE = await iLGE.addLiquidityToPairPublic({ from: rando }); // Why is this reverting?
        console.log(addLPE);

        // Next, let's claim some LP from rando, who didn't actually contribute to the LGE
        console.log("Next, let's claim some LP from rando, who didn't actually contribute to the LGE");
        let claimedLP = await iLGE.claimLP({ from: rando })
        console.log(claimedLP);

    });


});