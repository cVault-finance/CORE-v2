usePlugin("@nomiclabs/buidler-truffle5");
usePlugin('buidler-log-remover');

module.exports = {
  solc: {
    version: "0.4.24",
  },
  networks: {
    buidlerevm: {
      allowUnlimitedContractSize: true,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
        evmVersion: "byzantium"
       }
    },
  },
  paths: {
    sources: "./contracts/v424",
  }
};
