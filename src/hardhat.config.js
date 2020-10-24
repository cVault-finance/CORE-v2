require("@nomiclabs/hardhat-truffle5");
// usePlugin('buidler-log-remover');
require("@nomiclabs/hardhat-ganache");

module.exports = {
  solidity: {
    version: "0.6.12",
    settings: {
      optimizer: {
        enabled: true,
        runs: 99999
      }
    }
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false,
      settings: {
        evmVersion: "byzantium"
      }
    },
  },
  paths: {
    sources: "./contracts/v612",
  },
  defaultNetwork: "ganache",
  networks: {
    ganache: {
      gasLimit: 6000000000,
      defaultBalanceEther: 100,
      url: "http://localhost:8545/",
      fork: "https://mainnet.infura.io/v3/2bb161be6f8d454f9cddc9a2d61fc211",
      fork_block: 11088006,
      unlocked_accounts: ["0x5A16552f59ea34E44ec81E58b3817833E9fD5436", "0xca06411bd7a7296d7dbdd0050dfc846e95febeb7", "0x000000000000000000000000000000000000dEaD", "0xd5b47B80668840e7164C1D1d81aF8a9d9727B421"],
      callGasLimit: "0x1fffffffffffff",
      gasLimit: 0x1fffffffffffff,
      allowUnlimitedContractSize: true,
      mnemonic: "lift pottery popular bid consider dumb faculty better alpha mean game attack"
    }
  }
};
