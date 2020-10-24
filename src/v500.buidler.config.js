require("@nomiclabs/hardhat-truffle5");
require('buidler-log-remover');

module.exports = {
  solidity: {
    version: "0.5.0",
    settings: {
      optimizer: {
        enabled: true,
        runs: 99999
      }
    }
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      settings: {
        evmVersion: "byzantium"
      }
    },
  },
  paths: {
    sources: "./contracts/v500",
  }
};
