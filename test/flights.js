var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flights Test', async (accounts) => {

    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);
        await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
    });

    it('Getting flight price', async function () {
        let flightNumber = "ND1309";
        let price = web3.utils.toWei("4");
        let timestamp = Math.floor(Date.now() / 1000);
        await config.flightSuretyApp.registerFlight(flightNumber, timestamp, price, { from: config.firstAirline } );
        let result = await config.flightSuretyApp.getTicketPrice.call(flightNumber, timestamp, config.firstAirline);

        assert.equal(price, result[0].toString(), "Getting the wrong flight price back!");
        console.log('result ', result[1].toString());
    });

    it('Buying insurance for flight', async function () {
        let passenger = accounts[2];
        let flightNumber = "ND1309";
        let insured = true;
        let price = web3.utils.toWei("4");
        let priceInsured = web3.utils.toWei("5");
        let timestamp = Math.floor(Date.now() / 1000); 

        await config.flightSuretyApp.registerFlight(flightNumber, timestamp, price, { from: config.firstAirline } );
        
        // try {
            await config.flightSuretyApp.buyTicket(flightNumber, timestamp, config.firstAirline, insured, { from: passenger, value: priceInsured } );
        // } 
        // catch(e) {
        //     console.log('\nError', flightNumber, timestamp, config.firstAirline, insured, passenger, priceInsured, e.toString());
        // }
        let isInsured = false; // await config.flightSuretyApp.isInsured.call(flightNumber, timestamp, config.firstAirline, { from: passenger } );
        
        assert.equal(isInsured, true, "Passenger got no insurance for the flight!");
    });
});