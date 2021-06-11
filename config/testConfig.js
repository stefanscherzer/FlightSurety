var FlightSuretyApp = artifacts.require("FlightSuretyApp");
var FlightSuretyData = artifacts.require("FlightSuretyData");
var BigNumber = require('bignumber.js');
var TruffleAssert = require('truffle-assertions');

var Config = async function(accounts) {

    let owner = accounts[0];
    let firstAirline = accounts[10];
    let airlines = accounts.slice(10, 20);
    let passengers = accounts.slice(21, 25);
    let oracles = accounts.slice(30,50);
    
    // console.log(firstAirline);
    // console.log('airlines: ', airlines.length);
    // console.log(airlines);
    // console.log('passengers: ', passengers.length);
    // console.log(passengers);
    // console.log('oracles: ', oracles.length);
    // console.log(oracles);

    let flightSuretyData = await FlightSuretyData.new(firstAirline);
    let flightSuretyApp = await FlightSuretyApp.new(flightSuretyData.address);
    
    return {
        owner: owner,
        firstAirline: firstAirline,
        airlines: airlines,
        passengers: passengers,
        oracles: oracles,
        weiMultiple: (new BigNumber(10)).pow(18),
        flightSuretyData: flightSuretyData,
        flightSuretyApp: flightSuretyApp
    }
}

var passesWithEvent = async(eventName, asyncFunction) => {
    await TruffleAssert.passes(asyncFunction);
    TruffleAssert.eventEmitted(await asyncFunction, eventName);
}

module.exports = {
    Config: Config,
    passesWithEvent: passesWithEvent
};