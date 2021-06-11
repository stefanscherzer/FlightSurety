import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.config = config;
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
        
        this.initialize(callback);
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
            
            this.owner = accts[0];

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            this.flightSuretyData.methods.callerAuthorized(this.config.appAddress)
                .call({ from: this.config.appAddress }, (err, res) => {
                        console.log('callerAuthorized', res);
                });

            this.flightSuretyData.methods.airlineRegistered(this.airlines[0])
                .call({ from: this.owner }, (err, res) => {
                        console.log("firstAirline registered", res);
                });

            callback();
        });
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({from: self.owner}, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            passenger: self.passengers[0],
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        };
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({from: payload.passenger}, (error, result) => {
                callback(error, payload);
            });
    }

    buyInsurance(flightName, departure, ether, callback){
        let self = this;
        let payload = {
            airline: self.airlines[0],
            passenger: self.passengers[0],
            flightName: flightName,
            departure: departure
        };
        
        console.log('purchase:', payload.airline, payload.passenger, flightName, departure, ether);
        
        self.flightSuretyApp.methods.buyInsurance(
                payload.airline,
                flightName,
                departure
            )
            .send({
                from: payload.passenger,
                value: self.web3.utils.toWei(ether, "ether"),
                gas: 50000, 
            }, (err, res) => {
                callback(err, res);
            });
    }

    getInsurance(flightName, departure, callback){
        let self = this;
        let payload = {
            airline: self.airlines[0],
            passenger: self.passengers[0],
            flightName: flightName,
            departure: departure
        };
        
        console.log('getInsurance:', payload.airline, payload.passenger, flightName, departure);
        
        self.flightSuretyApp.methods.getInsurance(
            payload.passenger,
            payload.airline,
            flightName,
            departure
            )
            .call({
                from: payload.passenger,
            }, (err, res) => {
                console.log('result: ', res); 
                console.log('error: ', err); 
                callback(err, res);
            });
    }
}