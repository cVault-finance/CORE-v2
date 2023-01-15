import '@uniswap/v2-periphery/contracts/interfaces/IWETH.sol';
import "@openzeppelin/contracts/math/SafeMath.sol"; 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import "@openzeppelin/contracts/access/Ownable.sol";

interface ITransferHandler01{
    function feePercentX100() external view returns (uint8);
}

contract FannyRouter is Ownable {
    using SafeMath for uint256;

    IERC20 immutable public FANNY;
    IERC20 constant public CORE  = IERC20(0x62359Ed7505Efc61FF1D56fEF82158CcaffA23D7);
    IUniswapV2Pair public pairFANNYxCORE;  // we dont know token0 and token 1
    IUniswapV2Pair public pairWETHxCORE =  IUniswapV2Pair(0x32Ce7e48debdccbFE0CD037Cc89526E4382cb81b); // CORE is token 0, WETH token 1
    IWETH constant public WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ITransferHandler01 constant public transferHandler = ITransferHandler01(0x2e2A33CECA9aeF101d679ed058368ac994118E7a);


    constructor(address _fanny) public {
        FANNY = IERC20(_fanny);
    }

    function listFanny() public onlyOwner {
        require(address(pairFANNYxCORE) == address(0), "Fanny is already listed");
        uint256 balanceOfFanny = FANNY.balanceOf(address(this));
        uint256 balanceOfCORE = CORE.balanceOf(address(this));

        require(balanceOfCORE > 0, "Mo core");
        require(balanceOfFanny > 150 ether, "Mo fanny");

        address pair = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f).getPair(address(FANNY), address(CORE));
        if(pair == address(0)) { // We make the pair
            pair = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f).createPair(
                address(FANNY),
                address(CORE)
            );
        }
        require(pair != address(0), "Sanity failure");

        FANNY.transfer(pair, balanceOfFanny);
        CORE.transfer(pair, balanceOfCORE);
        require(CORE.balanceOf(pair) >= balanceOfCORE, "FoT off failure on list");
        pairFANNYxCORE = IUniswapV2Pair(pair);
        pairFANNYxCORE.mint(msg.sender);
        require(IERC20(address(pairFANNYxCORE)).balanceOf(msg.sender) > 0 , "Did not get any LP tokens");
    }


    function ETHneededToBuyFanny(uint256 amountFanny) public view returns (uint256) {
        // We get the amount CORE thats neededed to buy fanny
        address token0 = pairFANNYxCORE.token0();
        (uint256 reserves0, uint256 reserves1,) = pairFANNYxCORE.getReserves();
        uint256 coreNeededPreTax;
        if(token0 ==  address(FANNY)) {
            coreNeededPreTax = getAmountIn(amountFanny, reserves1 , reserves0);
        } else {
            coreNeededPreTax = getAmountIn(amountFanny, reserves0 , reserves1); 
        }
        uint256 coreNeededAfterTax = getCOREPreTaxForAmountPostTax(coreNeededPreTax);
        (uint256 reserveCORE, uint256 reserveWETH,) = pairWETHxCORE.getReserves();
        return getAmountIn(coreNeededAfterTax, reserveWETH , reserveCORE).mul(101).div(100); // add 1% slippage
    }

    function CORENeededToBuyFanny(uint256 amountFanny) public view returns (uint256) {
        // We get the amount CORE thats neededed to buy fanny
        address token0 = pairFANNYxCORE.token0();
        (uint256 reserves0, uint256 reserves1,) = pairFANNYxCORE.getReserves();
        uint256 coreNeededPreTax;
        if(token0 ==  address(FANNY)) {
            coreNeededPreTax = getAmountIn(amountFanny, reserves1 , reserves0);
        } else {
            coreNeededPreTax = getAmountIn(amountFanny, reserves0 , reserves1); 
        }
        return getCOREPreTaxForAmountPostTax(coreNeededPreTax).mul(101).div(100);// add 1% slippage because math isnt perfect
                                                                                // And we rather people buy 1 whole unit with dust
    }

    function getCOREPreTaxForAmountPostTax(uint256 _postTaxAmount) public view returns (uint256 coreNeededAfterTax) {
        uint256 tax = uint256(transferHandler.feePercentX100());
        uint256 divisor = uint256(1e8).sub((tax * 1e8).div(1000));
        coreNeededAfterTax = _postTaxAmount.mul(1e8).div(divisor);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator);
    }


    receive() external payable {
        if(msg.sender != address(WETH)) revert();
    }

    function buyFannyForETH(uint256 minFannyOut) public payable {
        WETH.deposit{value : msg.value}();
        _buyFannyForWETH(msg.value, minFannyOut);
    }

    function buyFannyForWETH(uint256 amount,uint256 minFannyOut) public {
        safeTransferFrom(address(WETH), msg.sender, address(this), amount);
        _buyFannyForWETH(amount, minFannyOut);
    }

    function _buyFannyForWETH(uint256 amount,uint256 minFannyOut) internal {
        (uint256 reserveCORE, uint256 reserveWETH,) = pairWETHxCORE.getReserves();
        uint256 coreOut = getAmountOut(amount, reserveWETH, reserveCORE);
        WETH.transfer(address(pairWETHxCORE), amount);
        pairWETHxCORE.swap(coreOut, 0 , address(this),"");
        uint256 coreBalanceOfPair = CORE.balanceOf(address(pairFANNYxCORE));
        CORE.transfer(address(pairFANNYxCORE), coreOut);
        _buyFannyForCORE(minFannyOut,coreBalanceOfPair);
    }

    function _buyFannyForCORE(uint256 minFannyOut, uint256 coreBalanceOfPairBefore) internal {
        uint256 coreBalanceOfAfter = CORE.balanceOf(address(pairFANNYxCORE));
        uint256 coreDelta = coreBalanceOfAfter.sub(coreBalanceOfPairBefore, "??");
        address token0 = pairFANNYxCORE.token0();
        (uint256 reserves0, uint256 reserves1,) = pairFANNYxCORE.getReserves();
        uint256 fannyOut;
        if(token0 == address(CORE)) {
            fannyOut = getAmountOut(coreDelta, reserves0, reserves1);
            pairFANNYxCORE.swap(0, fannyOut, msg.sender, "");
        } else {
            fannyOut = getAmountOut(coreDelta, reserves1, reserves0);
            pairFANNYxCORE.swap(fannyOut, 0, msg.sender, "");
        }
        require(fannyOut >= minFannyOut, "Slippage was too high on trade");
    }

    function buyFannyForCORE(uint256 amount,uint256 minFannyOut) public {
        uint256 coreBalanceOfPair = CORE.balanceOf(address(pairFANNYxCORE));
        safeTransferFrom(address(CORE), msg.sender, address(pairFANNYxCORE), amount);
        _buyFannyForCORE(minFannyOut, coreBalanceOfPair);
    }

    function sellFannyForCORE(uint256 amount,uint256 minCOREOut) public {
        safeTransferFrom(address(FANNY), msg.sender, address(pairFANNYxCORE), amount);
        _sellFannyForCORE(amount, minCOREOut, msg.sender);
    }


    function _sellFannyForCORE(uint256 amount,uint256 minCOREOut, address recipent) internal returns(uint256 coreOut) {
        address token0 = pairFANNYxCORE.token0();
        (uint256 reserves0, uint256 reserves1,) = pairFANNYxCORE.getReserves();
        if(token0 == address(FANNY)) {
            coreOut = getAmountOut(amount, reserves0, reserves1);
            pairFANNYxCORE.swap(0, coreOut, recipent, "");
        } else {
            coreOut = getAmountOut(amount, reserves1, reserves0);
            pairFANNYxCORE.swap(coreOut, 0, recipent, "");
        }
        require(coreOut > 0, "Sold for nothing");
        require(coreOut >= minCOREOut, "Too much slippage in trade");
    }


    function sellFannyForETH(uint256 amount, uint256 minETHOut) public {
        safeTransferFrom(address(FANNY), msg.sender, address(pairFANNYxCORE), amount);
        uint256 coreOut = _sellFannyForCORE(amount, 0, address(this));
        uint256 COREBefore = CORE.balanceOf(address(pairWETHxCORE));
        CORE.transfer(address(pairWETHxCORE), coreOut);
        uint256 COREAfter = CORE.balanceOf(address(pairWETHxCORE));

        (uint256 reserveCORE, uint256 reserveWETH,) = pairWETHxCORE.getReserves();
        uint256 ethOut = getAmountOut(COREAfter - COREBefore, reserveCORE, reserveWETH);
        pairWETHxCORE.swap(0, ethOut , address(this), "");
        require(ethOut >= minETHOut, "Too much slippage in trade");
        WETH.withdraw(ethOut);
        (bool success, ) = msg.sender.call.value(ethOut)("");
        require(success, "Transfer failed.");
    }


    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'MUH FANNY: TRANSFER_FROM_FAILED');
    }

}