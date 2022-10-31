module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 8545,            // Standard Ethereum port (default: none)
      network_id: "42220",       // Any network (default: none)
      gasPrice: "0",
      gas: 19000000,
      disableConfirmationListener: true,
      networkCheckTimeout: 360000,
    },
  },

  mocha: {
    timeout: 360000
  },

  compilers: {
    solc: {
      version: "0.6.12", // Fetch exact version from solc-bin (default: truffle's version)
      settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
         enabled: true,
         runs: 1
        },
      }
    }
  }
};
