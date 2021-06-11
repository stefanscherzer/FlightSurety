pragma solidity ^0.5.0;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    FlightSuretyData dataContract;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
        string flightName;
        uint256 departure;
    }
    mapping(bytes32 => Flight) private flights;

    uint8 private constant minAirlinesCount = 4;
    uint256 private constant AIRLINE_FUND = 10 ether;
    uint8 private constant CREDIT_RATE = 150;
 
    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address payable flightSuretyDataAddress) public
    {
        contractOwner = msg.sender;
        dataContract = FlightSuretyData(flightSuretyDataAddress);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational()
    {
        // Modify to call data contract's status
        require(dataContract.isOperational() == true, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsAirLine(address airlineAddress)
    {
        require(dataContract.airlineExists(airlineAddress), "Airline does not exist");
        _;
    }

    modifier requireIsFundedAirLine(address airlineAddress)
    {
        require(dataContract.airlineFunded(airlineAddress), "Airline is not funded");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational()
                        public
                        view
                        returns(bool)
    {
        return dataContract.isOperational();
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
    * @dev Add an airline to the registration queue
    *
    */
    function registerAirline
                        (
                            address airlineAddress
                        )
                        public
                        requireIsOperational
                        requireIsFundedAirLine(msg.sender) // Airline can be registered, but does not participated in contract until it submits funding of 10 ether.
    {
        // Only existing airline may register a new airline until there are at least four airlines registed.
        if (dataContract.getRegisteredAirlinesCount() < minAirlinesCount) {
            dataContract.registerAirline(airlineAddress, true);
        }
        // Registration of 5th and subsequent airlines requires multi-party consensus of 50% of registered airlines.
        else {
            dataContract.registerAirline(airlineAddress, false);
        }
    }

    function voteForAirline
                        (
                            address airlineAddress
                        )
                        public
                        requireIsOperational
                        requireIsFundedAirLine(msg.sender)
                        requireIsAirLine(airlineAddress)
    {
        require(dataContract.airlineRegistered(airlineAddress) == false, "Not yet registered for voting");
        dataContract.voteForAirline(msg.sender, airlineAddress);

        uint voteCount = dataContract.getAirlineVotesCount(airlineAddress);
        uint minimumRequiredVotingCount = dataContract.getMinimumRequiredVotingCount();
        if ( voteCount > minimumRequiredVotingCount){
            dataContract.setAirlineRegistered(airlineAddress);
        }
    }

   /**
    * @dev Register a future flight for insuring.
    *
    */
    function registerFlight
                        (
                            string memory flightName,
                            uint256 departure
                        )
                        public
                        requireIsOperational
                        requireIsFundedAirLine(msg.sender)
    {
        bytes32 flightKey = getFlightKey(msg.sender, flightName, departure);
        require(!flights[flightKey].isRegistered, "Flight is already registered");

        flights[flightKey] = Flight(
            {
                flightName: flightName,
                departure: departure,
                isRegistered: true,
                statusCode: 0,
                updatedTimestamp: now,
                airline: msg.sender
            });

        dataContract.registerFlightKey(msg.sender, flightKey);
    }

   /**
    * @dev Called after oracle has updated flight status
    *
    */
    function processFlightStatus
                            (
                                address airline,
                                string memory flight,
                                uint256 timestamp,
                                uint8 statusCode
                            )
                            internal
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        flights[flightKey].statusCode = statusCode;

        // If flight is delayed due to airline fault, passenger receives credit of 1.5X the amount they paid
        if (statusCode == STATUS_CODE_LATE_AIRLINE ){
            dataContract.creditInsurees(flightKey, CREDIT_RATE);
        }
        else{
            dataContract.creditInsurees(flightKey, 0);
        }

    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                            (
                                address airline,
                                string calldata flight,
                                uint256 timestamp
                            )
                            external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo(
            {
                requester: msg.sender,
                isOpen: true
            });

        emit OracleRequest(index, airline, flight, timestamp);
    }

    function fundAirline
                    (
                        address airlineAddress
                    )
                    public
                    payable
                    requireIsOperational
    {
        require(msg.sender == airlineAddress, "Only the airline can fund itself");
        require(msg.value >= AIRLINE_FUND, "No enough funding recieved");
        dataContract.fund.value(AIRLINE_FUND)(airlineAddress);
    }

    function buyInsurance
                    (
                        address airlineAddress,
                        string memory flightName,
                        uint256 departure
                    )
                    public
                    payable
                    requireIsOperational
    {
        // Passengers may pay up to 1 ether for purchasing flight insurance
        require(msg.value > 0, "Insurance needs payment with more than 0 ether");
        require(msg.value <= 1 ether, "Insurance accept less or equal payment than 1 ether");

        dataContract.buyInsurance.value(msg.value)(msg.sender, airlineAddress, flightName, departure);

        bytes32 flightKey = getFlightKey(msg.sender, flightName, departure);
        emit InsuranceBought(flightKey);
    }

    function getInsurance
                        (
                            address buyer,
                            address airlineAddress,
                            string memory flightName,
                            uint256 departure
                        )
                        public
                        view
                        returns (
                            uint value,
                            FlightSuretyData.InsuranceState state
                        )
    {
        return dataContract.getInsurance(
            buyer,
            airlineAddress,
            flightName,
            departure
        );
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);

    event InsuranceBought(bytes32 flightKey);

    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes()
                        view
                        external
                        returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string calldata flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion


}