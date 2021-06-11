import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);

var oracles = [];

(async() => {
  let accounts = await web3.eth.getAccounts();
  try {
    await flightSuretyData.methods.authorizeCaller(config.appAddress).send({from: accounts[0]});
  } catch(e) {
    console.log('authorizeCaller failed!', e);
  }

  let fee = await flightSuretyApp.methods.REGISTRATION_FEE().call()

  // A server app has been created for simulating oracle behavior. Server can be launched with “npm run server”

  // Upon startup, 20+ oracles are registered and their assigned indexes are persisted in memory
  // start ganache-cli with this command: ganache-cli -m "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat" --accounts=50
  accounts.slice(30,50).forEach( async(oracleAddress) => {
    try {
      await flightSuretyApp.methods.registerOracle().send({from: oracleAddress, value: fee, gas: 3000000});
      let indexesResult = await flightSuretyApp.methods.getMyIndexes().call({from: oracleAddress});
      oracles.push({
        address: oracleAddress,
        indexes: indexesResult
      });
    } catch(e) {
      console.log('registerOracle or getMyIndexes failed!', e);
    }
  });
})();

console.log("Registering Oracles.\n");
setTimeout(() => {
  oracles.forEach(oracle => {
    console.log(`Oracle: address[${oracle.address}], indexes[${oracle.indexes}]`);
  })
  console.log("Start watching for event OracleRequest to submit responses.")
}, 20000) // 20000 milliseconds = 20 seconds


// Update flight status requests from client Dapp result in OracleRequest event emitted by Smart Contract that is captured by server (displays on console and handled in code)
flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {

    if (error) {
      console.log('OracleRequest error: ', error);
    } else {

      // Server will loop through all registered oracles, identify those oracles for which the OracleRequest event applies, 
      // and respond by calling into FlightSuretyApp contract with random status code of Unknown (0), On Time (10) or Late Airline (20), 
      // Late Weather (30), Late Technical (40), or Late Other (50)
      let statusCode = Math.floor(Math.random() * 6) * 10;
      let result = event.returnValues;
      console.log(`OracleRequest: [${result.index}] for ${result.flight} ${result.timestamp}`);
  
      oracles.forEach((oracle) => {
        oracle.indexes.forEach((index) => {
          flightSuretyApp.methods.submitOracleResponse(
            index, 
            result.airline, 
            result.flight, 
            result.timestamp, 
            statusCode
          ).send(
            { from: oracle.address, gas:5555555}
          ).then(res => {
              console.log(`OracleResponse: address(${oracle.address}) index(${index}) accepted[${statusCode}]`)
          }).catch(err => {
              console.log(`OracleResponse: address(${oracle.address}) index(${index}) rejected[${statusCode}]`)
          });
        });
      });
    }
});

const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;


