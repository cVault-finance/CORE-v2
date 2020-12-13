
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";

contract COREPanicButton  {

    address public governance;
    address public governancePending;
    IERC20 public constant CORE = IERC20(0x62359Ed7505Efc61FF1D56fEF82158CcaffA23D7);
    bool public panic;
    
    constructor () public {
        governance = msg.sender;
    }

    modifier governanceOnly {
        require(msg.sender == governance, "CORE : !core-gov");
        _;
    }

    function transferGovernance(address _to) governanceOnly public {
        require(_to != address(0), "CORE : address not specified");
        governancePending = _to;
    }

    function acceptGovernance() public {
        require(msg.sender == governancePending, "CORE : Wrong address calling");
        require(governancePending != address(0), "CORE : Governance switch not pending");
        governance = governancePending;
        governancePending = address(0);
    }

    // Panic button pressable by anyone. Will flip the boolean panic flag
    // If this contract hare more than 500 CORE
    function pressButton() public { 
        panic = CORE.balanceOf(address(this)) >= 500 ether;
    }

    function togglePanicButton() governanceOnly public {
        panic = !panic;
    }

    function refundCOREForCorrectButtonPress(address _to, uint256 _amountCORE) governanceOnly public {
        require(CORE.transfer(_to, _amountCORE),"CORE : transfer failed");
    }

    function refundCOREForCorrectButtonPress(address[] memory  _to, uint256[] memory  _amountCORE) governanceOnly public {
        uint256 lenAddresses = _to.length;
        require(lenAddresses == _amountCORE.length, "CORE : Lenght mismatch");
        for(uint256 i = 0; i < lenAddresses; i++) {
            require(CORE.transfer(_to[i], _amountCORE[i]), "CORE : transfer failed");
        }
    }
    
    function panicModeActive() public view returns (bool) {
        return panic;
    }

}