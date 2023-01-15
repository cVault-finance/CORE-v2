pragma solidity 0.6.12;
import './ERC95.sol';
import "hardhat/console.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
interface ICOREGlobals {
    function TransferHandler() external returns (address);
}
interface ICORETransferHandler{
    function handleTransfer(address, address, uint256) external;
}

contract cBTC is OwnableUpgradeSafe, ERC95 {

    bool public paused; // Once only unpause
    address LGEAddress;
    ICOREGlobals coreGlobals;

    function initialize(address[] memory _addresses, uint8[] memory _percent, uint8[] memory tokenDecimals,  address _coreGlobals) public initializer {
        require(tx.origin == address(0x5A16552f59ea34E44ec81E58b3817833E9fD5436));
        OwnableUpgradeSafe.__Ownable_init();
        ERC95.__ERC95_init("cVault.finance/cBTC", "cBTC", _addresses, _percent, tokenDecimals);
        console.log("cBTC constructor called");
        coreGlobals = ICOREGlobals(_coreGlobals);
        paused = true;
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
        console.log("Transfer handler address", coreGlobals.TransferHandler());
        ICORETransferHandler(coreGlobals.TransferHandler()).handleTransfer(from, to, amount);
    }

}