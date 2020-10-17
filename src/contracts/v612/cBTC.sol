pragma solidity 0.6.12;
import './ERC95.sol';
import "@openzeppelin/contracts/access/Ownable.sol"; 
interface ICOREGlobals {
    function TransferHandler() external returns (address);
}
interface ICORETransferHandler{
    function handleTransfer(address, address, uint256) external;
}

contract cBTC is Ownable, ERC95 {

    bool paused = true; // Once only unpause
    address LGEAddress;
    ICOREGlobals coreGlobals;


    constructor(address[] memory _addresses, uint8[] memory _percent, uint8[] memory tokenDecimals,  address _coreGlobals)
     ERC95("cVault.finance/cBTC", "cBTC", _addresses, _percent, tokenDecimals)
     public {
        coreGlobals = ICOREGlobals(_coreGlobals);
    }

    function changeWrapTokenName(string memory name) public onlyOwner {
        _setName(name);
    }

    // Changing it after does nothing, all this can do is unpause once.
    function setLGEAddress(address _LGEAddress) public onlyOwner {
        LGEAddress = _LGEAddress;
    }

    // Unpauses transfers of this once
    // This is needed so people don't wrap before LGE isover and screw liquidity adds
    function unpauseTransfers() public onlyLGEContract {
        paused = false;
    }

    // Checks if contract is LGE address
    modifier onlyLGEContract {
        require(LGEAddress != address(0), "Address not set");
        require(msg.sender == LGEAddress, "Not LGE address");
        _;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal  virtual override {
        require(paused == false, "Transfers paused until LGE is over");
        ICORETransferHandler(coreGlobals.TransferHandler()).handleTransfer(from, to, amount);
    }

}



        // internal {
