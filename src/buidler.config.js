usePlugin("@nomiclabs/buidler-truffle5");
usePlugin('buidler-log-remover');
usePlugin("@nomiclabs/buidler-ganache");

module.exports = {
  solc: {
    version: "0.6.12",
    optimizer: {
      enabled: true,
      runs: 99999
    },
  },
  networks: {
    buidlerevm: {
      allowUnlimitedContractSize: false,
      settings: {
        evmVersion: "byzantium"
      }
    },
  },
  paths: {
    sources: "./contracts/v612",
  },
  /*defaultNetwork: "ganache",
  networks: {
    ganache: {
      gasLimit: 6000000000,
      defaultBalanceEther: 100,
      url: "http://localhost:8545",
      fork_block: 11088006,
      fork: "https://mainnet.infura.io/v3/2bb161be6f8d454f9cddc9a2d61fc211@11088006"
    }
  }*/
};
