# FlightSurety

FlightSurety is a sample application project for Udacity's Blockchain course.

## Install

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then:

`npm install`  
`truffle compile`  
`ganache-cli -m "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat" --accounts=50`

## Develop Client

To run truffle tests:

`truffle test ./test/flightSurety.js`  
`truffle test ./test/oracles.js`

To use the dapp:

`truffle migrate`  
`npm run dapp`

To view dapp:

`http://localhost:8000`

## Develop Server

`npm run server`  
`truffle test ./test/oracles.js`

## Deploy

To build dapp for prod:  
`npm run dapp:prod`

Deploy the contents of the ./dapp folder


## Hints

During testing with `truffle test` I got the following error:  
"Error: the tx doesn't have the correct nonce. account has nonce of: 10 tx has nonce of: 9"

I was able to solve this by changing the truffle config in `truffle.js` from 

```js
var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";

module.exports = {
  networks: {
    development: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/", 0, 50);
      },
      network_id: '*'
    }
  },
  compilers: {
    solc: {
      version: "^0.5.0"
    }
  }
};
```

to  

```js
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
```

## Resources

* [How does Ethereum work anyway?](https://medium.com/@preethikasireddy/how-does-ethereum-work-anyway-22d1df506369)
* [BIP39 Mnemonic Generator](https://iancoleman.io/bip39/)
* [Truffle Framework](http://truffleframework.com/)
* [Ganache Local Blockchain](http://truffleframework.com/ganache/)
* [Remix Solidity IDE](https://remix.ethereum.org/)
* [Solidity Language Reference](http://solidity.readthedocs.io/en/v0.4.24/)
* [Ethereum Blockchain Explorer](https://etherscan.io/)
* [Web3Js Reference](https://github.com/ethereum/wiki/wiki/JavaScript-API)