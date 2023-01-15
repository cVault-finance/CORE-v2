// SPDX-License-Identifier: MIT
// COPYRIGHT cVault.finance TEAM
// NO COPY
// COPY = BAD
// This code is provided with no assurances or guarantees of any kind. Use at your own responsibility.
//  _____ ___________ _____   _____ _       _           _     
// /  __ \  _  | ___ \  ___| |  __ \ |     | |         | |    
// | /  \/ | | | |_/ / |__   | |  \/ | ___ | |__   __ _| |___ 
// | |   | | | |    /|  __|  | | __| |/ _ \| '_ \ / _` | / __|
// | \__/\ \_/ / |\ \| |___  | |_\ \ | (_) | |_) | (_| | \__ \
//  \____/\___/\_| \_\____/   \____/_|\___/|_.__/ \__,_|_|___/                                                         
//                                                          
// This contract stores all different CORE contract addreses 
// and is responsible for contract authentification in the CORE smart contract mesh
//
// BBBBBBBBBBBBBBBBBBBBBBBBBBB
// BMB---------------------B B
// BBB---------------------BBB
// BBB---------------------BBB
// BBB------CORE.exe-------BBB
// BBB---------------------BBB
// BBB---------------------BBB
// BBBBBBBBBBBBBBBBBBBBBBBBBBB
// BBBBB++++++++++++++++BBBBBB
// BBBBB++BBBBB+++++++++BBBBBB
// BBBBB++BBBBB+++++++++BBBBBB
// BBBBB++BBBBB+++++++++BBBBBB
// BBBBB++++++++++++++++BBBBBB


import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "hardhat/console.sol";


contract COREGlobals is OwnableUpgradeSafe {

    address public CORETokenAddress;
    address public COREGlobalsAddress;
    address public COREDelegatorAddress;
    address public COREVaultAddress;
    address public COREWETHUniPair;
    address public UniswapFactory;
    address public TransferHandler;

    function initialize(address _COREWETHUniPair, address _COREToken, address _COREDelegator, address _COREVault, address _uniFactory, address _transferHandler) public initializer {
        OwnableUpgradeSafe.__Ownable_init();
        CORETokenAddress = _COREToken;
        COREGlobalsAddress = address(this);
        COREDelegatorAddress = _COREDelegator;
        COREVaultAddress = _COREVault;
        UniswapFactory = _uniFactory;
        TransferHandler = _transferHandler;
        COREWETHUniPair = _COREWETHUniPair;
    }

    function setCoreToken(address _COREToken) public onlyOwner {
        CORETokenAddress = _COREToken;
    }

    function setCoreDelegator(address _COREDelegator) public onlyOwner {
        COREDelegatorAddress = _COREDelegator;
    }

    function setCoreVaultAddress(address _COREVault) public onlyOwner {
        COREVaultAddress = _COREVault;
    }

    function setTransferHandler(address _transferHandler) public onlyOwner {
        TransferHandler = _transferHandler;
    }

    mapping (address => bool) private delegatorStateChangeApproved;

    function addDelegatorStateChangePermission(address that, bool status) public onlyOwner {
        return _addDelegatorStateChangePermission(that, status);
    }

    function _addDelegatorStateChangePermission(address that, bool status) internal {
        require(isContract(that), "Only contracts");
        delegatorStateChangeApproved[that] = status;
    }

    // Only contracts.
    function isStateChangeApprovedContract(address that)  public view returns (bool) {
        return _isStateChangeApprovedContract(that);
    }

    function _isStateChangeApprovedContract(address that) internal view returns (bool) {
        return delegatorStateChangeApproved[that];
    }

    function isContract(address addr) public view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

}