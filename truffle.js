module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",     // Localhost
      port: 8545,            // Standard Ganache UI port
      network_id: '*'
    }
  },
  compilers: {
    solc: {
      version: "^0.5.0"
    }
  }
};