var Test = require('../config/testConfig.js');

contract('Flight Surety Tests', async (accounts) => {

    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);
        await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
    });

    /****************************************************************************************/
    /* Operations and Settings                                                              */
    /****************************************************************************************/

    it(`(multiparty) has correct initial isOperational() value`, async function () {

        // Get operating status
        let status = await config.flightSuretyData.isOperational.call();
        assert.equal(status, true, "Incorrect initial operating status value");

    });

    it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

        // Ensure that access is denied for non-Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false, { from: config.airlines[0] });
        }
        catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

        // Ensure that access is allowed for Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false, { from: config.owner });
        }
        catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`,
        async function () {

        await config.flightSuretyData.setOperatingStatus(false, { from: config.owner });

        let reverted = false;
        try {
            await config.flightSuretyApp.registerAirline(config.airlines[0]);
        }
        catch (e) {
            reverted = true;
        }
        assert.equal(reverted, true, "Access not blocked for requireIsOperational");

        // Set it back for other tests to work
        await config.flightSuretyData.setOperatingStatus(true, { from: config.owner });

    });

    // Airline can be registered, but does not participate in contract until it submits funding of 10 ether
    it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {

        // ARRANGE
        let registered = true;
        let funded = true;

        // ACT
        funded = await config.flightSuretyData.airlineFunded.call(config.firstAirline);

        try {
            await config.flightSuretyApp.registerAirline(config.airlines[1], { from: config.firstAirline });
        }
        catch (e) {
            registered = false;
        }

        // ASSERT
        assert.equal(funded, false, "The airline is registered but not funded");
        assert.equal(registered, false, "Airline should not be able to register another airline if it hasn't provided funding");

    });

    it('(airline) can fund itself', async () => {

        //ARRANGE
        let before = await config.flightSuretyData.airlineFunded.call(config.firstAirline);

        // ACT
        try {
            await config.flightSuretyApp.fundAirline(config.firstAirline, { from: config.firstAirline, value: web3.utils.toWei('10', "ether") });
        }
        catch (e) {
        }

        let after = await config.flightSuretyData.airlineFunded.call(config.firstAirline);

        // ASSERT
        assert.equal(before, false, "The airline is already funded");
        assert.equal(after, true, "Airline can not fund itself");

    });

    it('(airline) can be registered using registerAirline() if it is funded', async () => {

        // ARRANGE

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(config.airlines[1], { from: config.firstAirline });
        }
        catch (e) {
            console.log("Error: ", e);
        }
        let result = await config.flightSuretyData.airlineRegistered.call(config.airlines[1]);
        let count = await config.flightSuretyData.getRegisteredAirlinesCount();

        // ASSERT
        assert.equal(result, true, "new irline was not registered using registerAirline() even if the registering airline is funded");
        assert.equal(count, 2, "Registered airlines: firstAirline, this new airline");

    });

    // Only existing airline may register a new airline until there are at least four airlines registered (different scenario after four registered airlines)
    it('Only existing airline can register a new airline using registerAirline() until there are at least four airlines registered it is funded', async () => {

        // ARRANGE

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(config.airlines[2], { from: config.firstAirline });
            await config.flightSuretyApp.registerAirline(config.airlines[3], { from: config.firstAirline });
        }
        catch (e) {
            console.log("Error: ", e);
        }
        let before = await config.flightSuretyData.getRegisteredAirlinesCount();
        assert.equal(before, 4, "There are not 4 registered airlines");

        try {
            await config.flightSuretyApp.registerAirline(config.airlines[4], { from: config.firstAirline });
            await config.flightSuretyApp.registerAirline(config.airlines[5], { from: config.firstAirline });
            await config.flightSuretyApp.registerAirline(config.airlines[6], { from: config.firstAirline });
        }
        catch (e) {
            console.log("Error: ", e);
        }

        let registered = await config.flightSuretyData.getRegisteredAirlinesCount();
        let exist = await config.flightSuretyData.getExistAirlinesCount();
        assert.equal(registered, 4, "There are not 4 registered airlines");
        assert.equal(exist, 7, "7 airlines were expected to exist now");
    });

    // Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines
    it('5th airline will recieve votes util it gets registered', async () => {

        // ARRANGE
        let newAirline = config.airlines[4];

        // ACT
        try {
            await config.flightSuretyApp.fundAirline(config.airlines[1], { from: config.airlines[1], value: web3.utils.toWei('10', "ether") });
            await config.flightSuretyApp.fundAirline(config.airlines[2], { from: config.airlines[2], value: web3.utils.toWei('10', "ether") });
            await config.flightSuretyApp.fundAirline(config.airlines[3], { from: config.airlines[3], value: web3.utils.toWei('10', "ether") });
        }
        catch (e) {
            console.log('Error: ', e);
        }

        let funded = await config.flightSuretyData.getFundedAirlinesCount();
        assert.equal(funded, 4, 'Expected number of 4 funded airlines does not match');

        try {
            await config.flightSuretyApp.voteForAirline(newAirline, { from: config.airlines[0] });
            await config.flightSuretyApp.voteForAirline(newAirline, { from: config.airlines[1] });
            await config.flightSuretyApp.voteForAirline(newAirline, { from: config.airlines[2] });
        }
        catch (e) {
            console.log('Error: ', e);
        }

        let registered = await config.flightSuretyData.airlineRegistered(newAirline);
        // ASSERT
        assert.equal(registered, true, "Voting and registering the 5th airline did not work like expected");

    });

    // Passengers may pay up to 1 ether for purchasing flight insurance.
    it(`passenger can buy insurance for his ticket, event InsuranceBought emited`, async () => {
        let flight = 'ND1309'; // Course number
        let timestamp = Math.floor(Date.now() / 1000);
        
        await Test.passesWithEvent(
            'InsuranceBought',
            config.flightSuretyApp.buyInsurance(
                config.firstAirline,
                flight,
                timestamp,
                { from: config.passengers[0], value: web3.utils.toWei('0.1', 'ether') }
            )
        );

        let insurance = await config.flightSuretyApp.getInsurance.call(config.passengers[0], config.firstAirline, flight, timestamp, { from: config.passengers[0] });
        let value = web3.utils.fromWei(insurance.value, 'ether').toString();

        assert.equal(insurance.state, "2", "expected BOUGHT state of insurance not given")
        assert.equal(value, "0.1", "paid insurance price does not match");
    });
});
