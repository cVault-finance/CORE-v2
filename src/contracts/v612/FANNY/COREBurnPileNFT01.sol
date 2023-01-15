pragma solidity 0.6.12;

// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@@&%%%%%%@@@@@&%%%%%%@%%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@&@@@@@@@@@&%%*****#%%%%&&&&&&&&&&@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@&&&&&&&%%*******#%%%# /%&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@&&&&&&%%%********#*,,,*. %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&/******,.          %@@@@@@%%%%%@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@%%%&@@@@@%***%***             %%&@@&%%,**%@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@%,,(%@@@%%*(#***,              (%%@&%  (%@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@%    %%%%*,,**                   %%,   (%@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@%    %%%**,,                    %    %%%@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@%*                                  %@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@&%*                                %@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@&#%%                                %@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@%#****%*                             %@@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@%%%/**%*                             %%@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@%%*                              %@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@%                                %@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@%                                %@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@&%                                %@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@%                                 %%%@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@%                                  (%@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@&*                                     %@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@%%/,                                    %@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@%*****                                   %@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@&%%*****                                   %@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@&/******                                   %@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@&/******                                   %@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@&/,****,                                 (%%@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@%,*****,                                  (&@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@%*,***.                                   (&@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@%                                        %%%@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@%                                        %@@@@@@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@&#(                                ((((%////%%&@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@&%%,. . ./%&&&&&%*.............%%&&&&&&&&&&&&&@@@@@@@@@@@@@@@
// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

interface RARIBLENFT {
    function ownerOf(uint256) external view returns (address);
    function tokenURI(uint256) external view returns (string memory);
}

contract COREBurnPileNFT01 {
    using SafeMath for uint256;

    IERC20 constant CORE = IERC20(0x62359Ed7505Efc61FF1D56fEF82158CcaffA23D7);
    RARIBLENFT constant NFT = RARIBLENFT(0x60F80121C31A0d46B5279700f9DF786054aa5eE5);
    uint256 constant NFTNum = 73604;
    bool public auctionOngoing;
    uint256 public auctionEndTime;
    uint256 public topBid;
    address public topBidder;
    address private _owner;
    event AuctionStarted(address indexed byOwner, uint256 startTimestamp);
    event AuctionEnded(address indexed newOwner, uint256 timestamp, uint256 soldForETH);
    event Bid(address indexed bidBy, uint256 amountETH, uint256 timestamp);

    modifier onlyOwner {
        require(msg.sender == _owner);
        _;
    }

    constructor() public {
        _owner = msg.sender;
    }

    function transferOwnership(address _to) onlyOwner public {
        _owner = _to;
    }

    function startAuction(uint256 daysLong) public onlyOwner {
        require(auctionOngoing == false, "Auction is ongoing");
        auctionOngoing = true;
        auctionEndTime = block.timestamp.add(daysLong * 1 days);
        emit AuctionStarted(msg.sender, block.timestamp);
    }

    function bid() public payable {
        require(tx.origin == msg.sender, "Only dumb wallets can own this NFT");
        require(auctionOngoing == true, "Auction is not happening");
        require(block.timestamp < auctionEndTime, "Auction ended");
        require(msg.sender != _owner, "no");
        require(msg.value >= topBid.mul(105).div(100), "Didn't beat top bid");
        topBid = msg.value;
        topBidder = msg.sender;
        emit Bid(msg.sender, msg.value, block.timestamp);
    }

    function endAuction() public {
        require(auctionOngoing == true, "Auction is not happening");
        require(block.timestamp > auctionEndTime, "Auction still ongoing");
        auctionOngoing = false;
        auctionEndTime = uint256(-1);
        emit AuctionEnded(topBidder, block.timestamp, address(this).balance);
        address previousOwner = _owner;
        _owner = topBidder;
        (bool success, ) = previousOwner.call.value(address(this).balance)("");
        require(success, "Transfer failed.");
    }



    function admireStack() public view returns (uint256) {
        return CORE.balanceOf(address(this));
    }

    function veryRichOwner() public view returns (address) {
        return _owner;
    }

    function isNFTOwner() public view returns (bool) {
        return (NFT.ownerOf(NFTNum) == address(this));
    }

    function getURI() public view returns (string memory)  {
        return NFT.tokenURI(NFTNum);
    }

    function transferCOREOut() onlyOwner public  {
        revert("Lol You Wish");
    }



}