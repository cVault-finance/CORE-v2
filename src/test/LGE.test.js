const CoreToken = artifacts.require('CORE');
const CoreVault = artifacts.require('CoreVault');
const { expectRevert, time, BN } = require('@openzeppelin/test-helpers');
const { inTransaction } = require('@openzeppelin/test-helpers/src/expectEvent');
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

contract('ERC95 tests', ([x3, revert, james, joe, john, trashcan]) => {

    beforeEach(async () => {
        this.testCount = 0;
        this.weth = await WETH9.new({ from: john });


        this.WBTC = await WBTC.new({ from: x3 });
        this.WBTC.mint(x3, 6e8);
        this.WBTC.mint(revert, 6e8); // Mint 6 BTC equivalent
        this.DORE = await ERC20DetailedToken.new("Dumbledore Token", "DORE", "18", ((new BN(10000)).mul((new BN(10)).pow(new BN(18)))).toString(), { from: x3 });
        const c95WBTCargs = [
            "cVault.finance/cBTC",
            "cBTC",
            [
                this.WBTC.address
            ],
            [
                100
            ],
            [
                8
            ]
        ]
        this.c95WBTC = await ERC95.new(...c95WBTCargs, { from: x3 });



        this.factory = await UniswapV2Factory.new(revert, { from: revert });
        this.router = await UniswapV2Router02.new(this.factory.address, this.weth.address, { from: revert });
        console.log('weth address', this.weth.address);
        console.log('his.c95WBTC.address', this.c95WBTC.address);
        console.log('this.DORE.address', this.DORE.address);
        console.log('this.factory.address', this.factory.address);
        console.log('this.WBBTC.address', this.WBTC.address);


        this.router = await UniswapV2Router02.new(this.factory.address, this.weth.address, { from: revert });

        this.WBTCETHPair = await UniV2Pair.at((await this.factory.createPair(this.weth.address, this.WBTC.address)).receipt.logs[0].args.pair);
        this.COREETHpair = await UniV2Pair.at((await this.factory.createPair(this.weth.address, this.DORE.address)).receipt.logs[0].args.pair);

        console.log("WEBTCETH address", this.WBTCETHPair.address);
        /// Add liquidity to pairs

        //wtbc
        await this.WBTC.mint(this.WBTCETHPair.address, 6e8); // Mint 6 BTC equivalent
        await this.weth.deposit({ value: 6e8, from: revert })
        await this.weth.transfer(this.WBTCETHPair.address, 6e8, { from: revert });
        await this.WBTCETHPair.mint(trashcan);


        //CORE/DORE
        await this.DORE.transfer(this.COREETHpair.address, 6e8, { from: x3 });
        await this.weth.deposit({ value: 6e8, from: revert })
        await this.weth.transfer(this.COREETHpair.address, 6e8, { from: revert });
        await this.COREETHpair.mint(trashcan);
        ////


        this.COREGlobals = await COREGlobals.new(
            this.COREETHpair.address, this.DORE.address,
            revert, revert, this.factory.address, revert,
            { from: revert })
        // constructor(address _COREWETHUniPair, address _COREToken, address _COREDelegator, address _COREVault, address _uniFactory, address _transferHandler) public {

        // constructor(uint256 daysLong, address _wrappedToken, address _coreGlobals, address _preWrapEthPair) public {
        this.lge = await LGE.new(7, this.c95WBTC.address, this.COREGlobals.address, this.WBTCETHPair.address, { from: revert })
    });

    it("Should not allow contributions when its not started", async () => {
        // ETH contribution
        await expectRevert(this.lge.send(99, { from: revert, value: 99 }), "LGE Didn't start");
        // WETH contribution
        await this.weth.approve(this.lge.address, 999999999999, { from: revert });
        await this.weth.deposit({ value: '100000000000000', from: revert })

        await expectRevert(this.lge.addLiquidityWithTokenWithAllowance(this.weth.address, 9999, { from: revert }), "LGE Didn't start");

        await this.weth.transfer(this.lge.address, 9999, { from: revert });
        await expectRevert(this.lge.addLiquidityAtomic({ from: revert }), "LGE Didn't start");


        // LP contribution
        await this.WBTC.mint(this.WBTCETHPair.address, 6e8); // Mint 6 BTC equivalent
        await this.weth.deposit({ value: 6e8, from: revert })

        await this.weth.transfer(this.WBTCETHPair.address, 6e8, { from: revert });
        await this.WBTCETHPair.mint(revert);
        await this.WBTCETHPair.approve(this.lge.address, 999999999999, { from: revert });
        await expectRevert(this.lge.addLiquidityWithTokenWithAllowance(this.WBTCETHPair.address, 9999, { from: revert }), "LGE Didn't start");
        await this.WBTCETHPair.transfer(this.lge.address, 9999, { from: revert });

        await expectRevert(this.lge.addLiquidityWithTokenWithAllowance(this.WBTCETHPair.address, 9999, { from: revert }), "LGE Didn't start");
        await expectRevert(this.lge.addLiquidityAtomic({ from: revert }), "LGE Didn't start");
    })
    it("Shouldn't let non admin start it", async () => {
        //admin is revert
        await expectRevert(this.lge.startLGE({ from: joe }), "Ownable: caller is not the owner");

        this.lge.startLGE({ from: revert })
    })

    it("Should let people deposit after start", async () => {
        await this.WBTC.mint(this.WBTCETHPair.address, 100e8); // Mint 6 BTC equivalent
        await this.weth.deposit({ value: 100e18, from: revert }) // Wrap in WETH
        await this.weth.deposit({ value: 300e18, from: revert })

        await this.weth.transfer(this.WBTCETHPair.address, ((new BN(100)).mul((new BN(10)).pow(new BN(18)))).toString(), { from: revert }); // Send to the pair
        await this.WBTCETHPair.mint(revert); // Mint new LP to revert


        // ETH contribution
        this.lge.startLGE({ from: revert })

        await this.lge.send(99, { from: revert, value: 99 })
        // WETH contribution
        await this.weth.approve(this.lge.address, ((new BN(1000)).mul((new BN(10)).pow(new BN(18)))).toString(), { from: revert });

        await this.lge.addLiquidityWithTokenWithAllowance(this.weth.address, 9999, { from: revert })

        await this.weth.transfer(this.lge.address, 9999, { from: revert });
        await this.lge.addLiquidityAtomic({ from: revert })


        // LP contribution

        let wbtcEthPairBalanceStr = (await this.WBTCETHPair.balanceOf(revert)).toString();
        await this.WBTCETHPair.approve(this.lge.address, 999999999999, { from: revert });
        console.log(`revert's LP balance: ${wbtcEthPairBalanceStr}`);
        await this.lge.addLiquidityWithTokenWithAllowance(this.WBTCETHPair.address, 9999, { from: revert })
        await this.WBTCETHPair.transfer(this.lge.address, 9999, { from: revert });

        await this.lge.addLiquidityWithTokenWithAllowance(this.WBTCETHPair.address, 9999, { from: revert })
        await this.lge.addLiquidityAtomic({ from: revert })
    })




});