// SPDX-License-Identifier: MIT
// COPYRIGHT cVault.finance TEAM
// NO COPY
// COPY = BAD
// This code is provided with no assurances or guarantees of any kind. Use at your own responsibility.

interface ICOREGlobals {
    function CORETokenAddress() external view returns (address);
    function COREGlobalsAddress() external view returns (address);
    function COREDelegatorAddress() external view returns (address);
    function COREVaultAddress() external returns (address);
    function COREWETHUniPair() external view returns (address);
    function UniswapFactory() external view returns (address);
    function transferHandler() external view returns (address);
    function addDelegatorStateChangePermission(address that, bool status) external;
    function isStateChangeApprovedContract(address that)  external view returns (bool);
}