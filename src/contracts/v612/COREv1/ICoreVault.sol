pragma solidity ^0.6.0;


interface ICoreVault {
    function devaddr() external returns (address);
    function addPendingRewards(uint _amount) external;
}