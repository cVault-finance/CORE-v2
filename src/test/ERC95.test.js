const CoreToken = artifacts.require('CORE');
const CoreVault = artifacts.require('CoreVault');
const { expectRevert, time, BN } = require('@openzeppelin/test-helpers');
const WETH9 = artifacts.require('WETH9');
const UniswapV2Pair = artifacts.require('UniswapV2Pair');
const UniswapV2Factory = artifacts.require('UniswapV2Factory');
const FeeApprover = artifacts.require('FeeApprover');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const COREDelegator = artifacts.require('COREDelegator');
const COREGlobals = artifacts.require('COREGlobals');

const ERC95 = artifacts.require('ERC95');
const WBTC = artifacts.require('WBTC');
const cBTC = artifacts.require('cBTC');

const ERC20DetailedToken = artifacts.require('ERC20DetailedToken');


contract('ERC95 tests', ([x3, revert]) => {

    beforeEach(async () => {
        this.testCount = 0;
        this.WBTC = await WBTC.new({ from: x3 });
        this.WBTC.mint(x3, 6e8); // Mint 6 BTC equivalent
        this.delegator = await COREDelegator.new();
        this.COREGlobals = await COREGlobals.new(
            revert, revert,
            this.delegator.address, revert, revert, revert,
            { from: revert });

        this.DORE = await ERC20DetailedToken.new("Dumbledore Token", "DORE", "18", ((new BN(10000)).mul((new BN(10)).pow(new BN(18)))).toString(), { from: x3 });
        const c95WBTCargs = [
            [
                this.WBTC.address
            ],
            [
                100
            ],
            [
                8
            ], this.COREGlobals.address

        ]
        this.c95WBTC = await cBTC.new(...c95WBTCargs, { from: x3 });
    });
    /*it("Should wrap WBTC and have correct balances reflected", async () => {
        // Start with 6 WBTC
        // WBTC: 6
        // c95WBTC: 0
        assert.equal((await this.WBTC.balanceOf(x3)).valueOf().toString(), "600000000");
        assert.equal((await this.c95WBTC.balanceOf(x3)).valueOf().toString(), "0");
        // Send 2 WBTC on to the c95WBTC contract
        // WBTC: 4
        // c95WBTC: 0 (2 pending)
        await this.WBTC.transfer(this.c95WBTC.address, (2e8).toString());
        assert.equal((await this.WBTC.balanceOf(x3)).valueOf().toString(), "400000000");
        // Wrap it
        // WBTC: 4
        // c95WBTC: 2
        await this.c95WBTC.wrapAtomic(x3);
        assert.equal((await this.c95WBTC.balanceOf(x3)).valueOf().toString(), "200000000");
        // Wrap an additional dusty amount
        // WBTC: 3.99999999
        // c95WBTC: 2 (0.00000001 pending)
        await this.WBTC.transfer(this.c95WBTC.address, "1");
        assert.equal((await this.WBTC.balanceOf(x3)).valueOf().toString(), "399999999");
        await this.c95WBTC.wrapAtomic(x3);
        // WBTC: 3.99999999
        // c95WBTC: 2.00000001
        assert.equal((await this.c95WBTC.balanceOf(x3)).valueOf().toString(), "200000001");
        // Unwrap 1 WBTC worth of tokens
        await this.c95WBTC.unwrap(1e8);
        // WBTC: 4.99999999
        // c95WBTC: 1.00000001
        assert.equal((await this.WBTC.balanceOf(x3)).valueOf().toString(), "499999999");
        assert.equal((await this.c95WBTC.balanceOf(x3)).valueOf().toString(), "100000001");
        // Unwrap a dusty amount
        await this.c95WBTC.unwrap(1);
        // WBTC: 5
        // c95WBTC: 1
        assert.equal((await this.WBTC.balanceOf(x3)).valueOf().toString(), "500000000");
        assert.equal((await this.c95WBTC.balanceOf(x3)).valueOf().toString(), "100000000");
        // Unwrap the rest
        await this.c95WBTC.unwrapAll();
        // WBTC: 6
        // c95WBTC: 0
        assert.equal((await this.WBTC.balanceOf(x3)).valueOf().toString(), "600000000");
        assert.equal((await this.c95WBTC.balanceOf(x3)).valueOf().toString(), 0);
    });*/
    it("Should have the initial balances in the 2nd test", async () => {
        //1 c95-50WBTC+50DORE should be exactly - 50*1e8/100 WBTC and 50*1e18/100 DORE
        //constructor(string memory name, string memory symbol, address[] memory _addresses, uint8[] memory _percent, uint8[] memory tokenDecimals) public {
        const c95_50WBTC_50DORE_args = [
            "c95-50WBTC+50DORE",
            "c95-50WBTC+50DORE",
            [
                this.WBTC.address,
                this.DORE.address
            ],
            [
                50,
                50
            ],
            [
                8,
                18
            ]
        ]
        // x3 balances
        // WBTC: 6
        // dorewbtc: 0
        this.c95_50WBTC_50DORE = await ERC95.new(...c95_50WBTC_50DORE_args, { from: x3 });
        const dorewbtc = this.c95_50WBTC_50DORE; // dorewbtc is just a nickname for this wrapped 50/50 wbtc/dore thing
        // Send in 1 WBTC (8 decimals)
        await this.WBTC.transfer(dorewbtc.address, 1e8.toString(), { from: x3 });
        // Now send in 1 DORE (18 decimals)
        await this.DORE.transfer(dorewbtc.address, 1e18.toString(), { from: x3 });
        // Confirm those transfers
        let doreBalanceOfDorewbtc = await this.DORE.balanceOf(dorewbtc.address);
        console.log(`doreBalanceOfDorewbtc: ${doreBalanceOfDorewbtc}`);

        let wbtcBalanceOfDorewbtc = await this.WBTC.balanceOf(dorewbtc.address);
        console.log(`wbtcBalanceOfDorewbtc: ${wbtcBalanceOfDorewbtc}`);

        await dorewbtc.wrapAtomic(x3);
        // let balance = await dorewbtc.balanceOf(x3);
        // console.log(balance);
    });
});