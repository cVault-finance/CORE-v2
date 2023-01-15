// SPDX-License-Identifier: FANNY

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; 



interface ICOREGlobals {
    function TransferHandler() external returns (address);
}
interface ICORETransferHandler{
    function handleRestrictedTokenTransfer(address, address, uint256) external;
}

/**
 * You find yourself deep in the forest
 * You're lost, your flashlight is running out of batteries
 * It barely shines anymore...
 * You barely see a large figure approaching you
 * its moving towards you fast
 * there is no way you can run
 * just in the field of vision of your feint flashlight
 * appears a smiling face, its a 6'4" muscule bound male
 * he says with a gravel like voice 
 * "I thikn your flashlight is out of battery, here take my spare"
 * He reaches inside a fanny pack and hands you 3 AAA batteries
 * "Are you lost? I'm X3"
 */

contract FANNY is ERC20 ("cVault.finance/FANNY", "FANNY")  {

    ICOREGlobals public coreGlobals;
    Claim [] allClaims;
    mapping (address => Claim[]) public claimsByPerson;

    constructor() public {
        _mint(msg.sender, 300 ether);
        coreGlobals = ICOREGlobals(0x255CA4596A963883Afe0eF9c85EA071Cc050128B);
    }

    struct Claim {
        uint256 id;
        uint256 timestamp;
        address claimerAddress;
    }

    function claimFanny() public returns (uint256 claimID) {
        require(msg.sender == tx.origin, "Only dumb wallets.");
        _burn(msg.sender, 1e18);
        claimsByPerson[msg.sender].push(
            Claim ({
                id : claimsByPerson[msg.sender].length,
                timestamp : block.timestamp,
                claimerAddress : msg.sender
            })
        );

        allClaims.push(
            Claim ({
                id : allClaims.length,
                timestamp : block.timestamp,
                claimerAddress : msg.sender

            })
        );
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal  virtual override {
        ICORETransferHandler(coreGlobals.TransferHandler()).handleRestrictedTokenTransfer(from, to, amount);
    }

}
