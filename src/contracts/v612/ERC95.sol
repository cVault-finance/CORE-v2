// SPDX-License-Identifier: MIT
// COPYRIGHT cVault.finance TEAM
// NO COPY
// COPY = BAD
// This code is provided with no assurances or guarantees of any kind. Use at your own responsibility.

pragma experimental ABIEncoderV2;
// # ERC95 technical documentation 

// tl;dr - ERC95 is a wrap for one or more underlying tokens.
// It can be eg. cYFI or 25% cYFI 10% AMPL 50% X
// This balances are unchangeable.
// Name of this token should be standardised

// cX for X coin
// For partial coins eg.
// 25cX+25cY+50cZ
// Tokens should be able to be multiwrappable, into any derivatives.

// special carveout for LP tokens naming should be
// 50lpX+25lpY+25lpZ


// special carveout for leveraged multiplier tokens
// x25Y+x50Z

// All prefixes are lowercase :

// c for CORE wrap
// x for times ( leverage ) - not clear how this would work right now but its on the goal list
// lp for Liquidity pool token.


// Short term goal for ERC95 is to start few LGEs and lock liquidity in pairs with them
// Long term goal is to pay out everyones fees and let anyone create a pair with CORE with any wrap or derivative they want. And pay out fees on that pair to them, in a permisionless way
// That benefits CORE/LP holders by a part of the fees from those and all other pairs.
// This will be ensured in CoreVault but I outlined it here so the goal of this is clear.

// ## Token wrap token

// A token wrapping standard.
// Recieves token, issues cToken
// eg. YFI -> cYFI
// Unwrapping and wrapping should be fee-less and permissionless the same principles as WETH.

// Note : This might need to be 20 decimals. Because of change of holding multiple tokens under one.
// I'm not sure about support for this everywhere. - will it break websites?
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@nomiclabs/buidler/console.sol";
import "@openzeppelin/contracts/GSN/Context.sol";

contract ERC95 is Context, IERC20 {     // XXXXX Ownable is new
    using SafeMath for uint256;
    using SafeMath for uint8;


    /// XXXXX ERC95 Specific functions




        // Events
        event Wrapped(address indexed from, address indexed to, uint256 amount);
        event Unwrapped(address indexed from, address indexed to, uint256 amount);

        uint8 immutable public _numTokensWrapped;
        WrappedToken[] public _wrappedTokens;

        // Structs
        struct WrappedToken {
            address _address;
            uint256 _reserve;
            uint256 _amountWrapperPerUnit;
        }

        function _setName(string memory name) internal {
            _name = name;
        }

        constructor(string memory name, string memory symbol, address[] memory _addresses, uint8[] memory _percent, uint8[] memory tokenDecimals) public {
            
            // We check if numbers are supplied 1:1
            // And get the total number of them.
            require(_addresses.length == _percent.length, "ERC95 : Mismatch num tokens");
            uint8 decimalsMax;
            uint percentTotal; // To make sure they add up to 100
            uint8 numTokensWrapped = 0;
            for (uint256 loop = 0; loop < _addresses.length; loop++) {
                // 0 % tokens cannnot be permitted
                require(_percent[loop] > 0 ,"ERC95 : All wrapped tokens have to have at least 1% of total");

                // we check the decimals of current token
                // decimals is not part of erc20 standard, and is safer to provide in the caller
                // tokenDecimals[loop] = IERC20(_addresses[loop]).decimals();
                decimalsMax = tokenDecimals[loop] > decimalsMax ? tokenDecimals[loop] : decimalsMax; // pick max
                
                percentTotal += _percent[loop]; // further for checking everything adds up
                //_numTokensWrapped++; // we might just assign this
                numTokensWrapped++;
                console.log("loop one loop count:", loop);
            }
            
            require(percentTotal == 100, "ERC95 : Percent of all wrapped tokens should equal 100");
            require(numTokensWrapped == _addresses.length, "ERC95 : Length mismatch sanity check fail"); // Is this sanity check needed? // No, but let's leave it anyway in case it becomes needed later
            _numTokensWrapped = numTokensWrapped;

            // Loop over all tokens against to populate the structs
            for (uint256 loop = 0; loop < numTokensWrapped; loop++) {
                 console.log("loop 2 constructor loop count:", loop);

                // We get the difference between decimals because 6 decimal token should have 1000000000000000000 in 18 decimal token per unit
                uint256 decimalDifference = decimalsMax - tokenDecimals[loop]; // 10 ** 0 is 1 so good
                    // cast to safemath
                console.log("Decimal difference", decimalDifference);
                console.log("Percent loop", _percent[loop]);
                console.log("10**decimal diff", 10**decimalDifference);
                uint256 pAmountWrapperPerUnit = numTokensWrapped > 1 ? (10**decimalDifference).mul(_percent[loop]) : 1;
                console.log("adding wrapped token with pAmountWrapperPerUnit: ", pAmountWrapperPerUnit);
                _wrappedTokens.push(
                    WrappedToken({
                        _address: _addresses[loop],
                        _reserve: 0, /* TODO: I don't know what reserve does here so just stick 0 in it */
                        _amountWrapperPerUnit : pAmountWrapperPerUnit // if its one token then we can have the same decimals
                        /// 10*0 = 1 * 1 = 1
                        /// 10*0 = 1 * 50 = 50 this means half because +2 decimals
                     })
                );
            }

            _name = name;
            _symbol = symbol;                                                    // we dont need more decimals if its 1 token wraped
            _decimals = numTokensWrapped > 1 ? decimalsMax + 2 : decimalsMax; //  2 more decimals to support percentage wraps we support up to 1%-100% in integers
        }                                                      


        // returns info for a token with x id in the loop
        function getTokenInfo(uint _id) public view returns (address, uint256, uint256) {
            WrappedToken memory wt = _wrappedTokens[_id];
            return (wt._address, wt._reserve, wt._amountWrapperPerUnit);
        }

        // Mints the ERC20 during a wrap
        function _mintWrap(address to, uint256 amt) internal {
            console.log("_totalSupply before mint: ", _totalSupply);
            _mint(to, amt);
            console.log("_totalSupply after mint: ", _totalSupply);
             emit Wrapped(msg.sender, to, amt);
        }

        // burns the erc and sends underlying tokens 
        function _unwrap(address from, address to, uint256 amt) internal {
            _burn(from, amt);
            sendUnderlyingTokens(to, amt);
            emit Unwrapped(from, to, amt);
        }

        /// public function to unwrap
        function unwrap(uint256 amt) public {
            _unwrap(msg.sender, msg.sender, amt);
        }

        function unwrapAll() public {
            unwrap(_balances[msg.sender]);
        }

        // TODO: Unit test with USDT
        // TODO: use the safetransfer shit from uinswap
        // TODO: Account for decimals in transfer amt (EtherDelta and IDEX would have this logic already)
        // TODO: Land-mine testing of USDT
        function sendUnderlyingTokens(address to, uint256 amt) internal {
            for (uint256 loop = 0; loop < _numTokensWrapped; loop++) {
                WrappedToken memory currentToken = _wrappedTokens[loop];
                safeTransfer(currentToken._address, to, amt.mul(currentToken._amountWrapperPerUnit));
            }
        }

        function safeTransfer(address token, address to, uint256 value) internal {
            // bytes4(keccak256(bytes('transfer(address,uint256)')));
            (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
            require(success && (data.length == 0 || abi.decode(data, (bool))), 'ERC95: TRANSFER_FAILED');
        }

        function safeTransferFrom(address token, address from, address to, uint256 value) internal {
            // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
            (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
            require(success && (data.length == 0 || abi.decode(data, (bool))), 'ERC95: TRANSFER_FROM_FAILED');
        }
        
        // You can unwrap if you have allowance to erc20 wrap
        function unwrapFor(address spender, uint256 amt) public {
            require(_allowances[spender][msg.sender] >= amt, "ERC95 allowance exceded");
            _unwrap(spender, msg.sender, amt);
            _allowances[spender][msg.sender] = _allowances[spender][msg.sender].sub(amt);
        }

        // Loops over all tokens in the wrap and deposits them with allowance
        function _depositUnderlying(uint256 amt) internal {
            for (uint256 loop = 0; loop < _numTokensWrapped; loop++) {
                WrappedToken memory currentToken = _wrappedTokens[loop];
                // req successful transfer
                uint256 amtToSend = amt.mul(currentToken._amountWrapperPerUnit);
                safeTransferFrom(currentToken._address, msg.sender, address(this), amtToSend);
                // Transfer went OK this means we can add this balance we just took.
                _wrappedTokens[loop]._reserve = currentToken._reserve.add(amtToSend);
            }
        }

        // Deposits by checking against reserves
        function wrapAtomic(address to) noNullAddress(to) public {
            console.log('wrapAtomic::Mint to ', to);
            uint256 amt = _updateReserves();
            console.log('Mint amount: ', amt);
            _mintWrap(to, amt);
        }

        // public function to call the deposit with allowance and mint
        function wrap(address to, uint256 amt) noNullAddress(to) public { // works as wrap for
            _depositUnderlying( amt);
            _mintWrap(to, amt); // No need to check underlying?
        }

        // safety for front end bugs
        modifier noNullAddress(address to) {
            require(to != address(0), "ERC95 : null address safety check");
            _;
        }

        
        function _updateReserves() internal returns (uint256 qtyOfNewTokens) {
            // Loop through all tokens wrapped, and find the maximum quantity of wrapped tokens that can be created, given the balance delta for this block
            console.log("_numTokensWrapped: ", _numTokensWrapped);
            for (uint256 loop = 0; loop < _numTokensWrapped; loop++) {
                WrappedToken memory currentToken = _wrappedTokens[loop];
                uint256 currentTokenBal = IERC20(currentToken._address).balanceOf(address(this));
                console.log("currentTokenBal inside loop: ", currentTokenBal, currentToken._address);
                console.log("currentToken._amountWrapperPerUnit: ", currentToken._amountWrapperPerUnit);
                // TODO: update to not use percentages
                uint256 amtCurrent = currentTokenBal.sub(currentToken._reserve).div(currentToken._amountWrapperPerUnit); // math check pls
                console.log("amtCurrent: ", amtCurrent);
                qtyOfNewTokens = qtyOfNewTokens > amtCurrent ? amtCurrent : qtyOfNewTokens; // logic check // pick lowest amount so dust attack doesn't work 
                                                           // can't skim in txs or they have non-deterministic gas price
                console.log("qtyOfNewTokens: ", qtyOfNewTokens);
                if(loop == 0) {
                    qtyOfNewTokens = amtCurrent;
                }
            }
            console.log("Lowest common denominator for token mint: ", qtyOfNewTokens);
            // second loop makes reserve numbers match from computed amount
            for (uint256 loop2 = 0; loop2 < _numTokensWrapped; loop2++) {
                WrappedToken memory currentToken = _wrappedTokens[loop2];

                uint256 amtDelta = qtyOfNewTokens.mul(currentToken._amountWrapperPerUnit);// math check pls
                _wrappedTokens[loop2]._reserve = currentToken._reserve.add(amtDelta);// math check pls
            }   
        }

        // Force to match reserves by transfering out to anyone the excess
        function skim(address to) public {
            for (uint256 loop = 0; loop < _numTokensWrapped; loop++) {
                WrappedToken memory currentToken = _wrappedTokens[loop];
                uint256 currentTokenBal = IERC20(currentToken._address).balanceOf(address(this));
                uint256 excessTokensQuantity = currentTokenBal.sub(currentToken._reserve);
                if(excessTokensQuantity > 0) {
                    safeTransfer(currentToken._address , to, excessTokensQuantity);
                }
            }
        }

    /// END ERC95 SPECIFIC FUNCTIONS START ERC20 
    // we propably should inherit ERC20 somehow

    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;



    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }




}


