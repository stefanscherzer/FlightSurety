pragma solidity ^0.5.0;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    mapping (address=>bool) public authorizedCallers;

    struct Airline{
        bool exists;
        bool registered;
        bool funded;
        bytes32[] flightKeys;
        Votes votes;
        uint numberOfInsurance;
    }
    mapping(address => Airline) private airlines;
    uint private airlinesCount = 0;
    uint private registeredAirlinesCount = 0;
    uint private fundedAirlinesCount = 0;
    
    struct Votes{
        uint votersCount;
        mapping(address => bool) voters;
    }

    struct Insurance {
        address buyer;
        uint value;
        address airline;
        string flightName;
        uint256 departure;
        InsuranceState state;
    }

    enum InsuranceState {
        NotExist,
        WaitingForBuyer,
        Bought,
        Passed,
        Expired
    }

    struct FlightInsurance {
        mapping(address => Insurance) insurances;
        address[] keys;
    }
    mapping(bytes32 => FlightInsurance) private flightInsurances;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AuthorizeCaller(address caller);
    event AirlineExist(address airline, bool exist);
    event AirlineRegistered(address airline, bool exist, bool registered);
    event AirlineFunded(address airlineAddress, bool exist, bool registered, bool funded, uint fundedCount);
    event InsuranceBought(bytes32 flightKey);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address airlineAddress
                                ) 
                                public 
    {
        contractOwner = msg.sender;

        airlines[airlineAddress] = Airline({
                exists: true,
                registered: true,
                funded: false,
                flightKeys: new bytes32[](0),
                votes: Votes(0),
                numberOfInsurance: 0
            });

        airlinesCount = airlinesCount.add(1);
        registeredAirlinesCount = registeredAirlinesCount.add(1);
        emit AirlineExist(airlineAddress, airlines[airlineAddress].exists);
        emit AirlineRegistered(airlineAddress, airlines[airlineAddress].exists, airlines[airlineAddress].registered);
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
        require(operational, "Contract is currently not operational");
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

     modifier requireAuthorizedCaller(address contractAddress)
    {
        require(authorizedCallers[contractAddress] == true, "Not Authorized Caller");
        _;
    }

    modifier requireAirLineExist(address airlineAddress)
    {
        require(airlines[airlineAddress].exists, "Airline does not exist");
        _;
    }

    modifier requireAirLineRegistered(address airlineAddress)
    {
        require(airlines[airlineAddress].exists, "Airline does not exist");
        require(airlines[airlineAddress].registered, "Airline is not registered");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational()
                        public
                        view
                        returns(bool)
    {
        return operational;
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            )
                            public
                            requireContractOwner
    {
        operational = mode;
    }

    function authorizeCaller
                        (
                            address contractAddress
                        )
                        public
                        requireContractOwner
                        requireIsOperational
    {
        require(authorizedCallers[contractAddress] == false, "already authorized");
        authorizedCallers[contractAddress] = true;
        emit AuthorizeCaller(contractAddress);
    }

    function callerAuthorized
                        (
                            address contractAddress
                        )
                        public
                        view
                        returns (bool)
    {
        return authorizedCallers[contractAddress];
    }

    function getExistAirlinesCount()
                                public
                                view
                                returns(uint)
    {
        return airlinesCount;
    }

    function getRegisteredAirlinesCount()
                                    public
                                    view
                                    returns(uint)
    {
        return registeredAirlinesCount;
    }

    function getFundedAirlinesCount()
                                public
                                view
                                returns(uint)
    {
        return fundedAirlinesCount;
    }

    function getAirlineVotesCount
                            (
                                address airlineAddress
                            )
                            public
                            view
                            returns(uint)
    {
        return airlines[airlineAddress].votes.votersCount;
    }

    function airlineExists
                        (
                            address airlineAddress
                        )
                        public
                        view
                        returns(bool)
    {
        return airlines[airlineAddress].exists;
    }

    function airlineRegistered
                            (
                                address airlineAddress
                            )
                            public
                            view
                            returns(bool)
    {
        return (airlines[airlineAddress].exists ? airlines[airlineAddress].registered : false);
    }

    function airlineFunded
                        (
                            address airlineAddress
                        )
                        public
                        view
                        returns(bool)
    {
        return airlines[airlineAddress].funded;
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
                        InsuranceState state
                    )
    {
        bytes32 flightKey = getFlightKey(airlineAddress, flightName, departure);
        FlightInsurance storage flightInsurance = flightInsurances[flightKey];
        Insurance storage insurance = flightInsurance.insurances[buyer];
        return (insurance.value, insurance.state);
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function registerAirline
                            (
                                address airlineAddress,
                                bool registered
                            )
                            public
                            requireIsOperational
    {
        airlines[airlineAddress] = Airline({
                exists: true,
                registered: registered,
                funded: false,
                flightKeys: new bytes32[](0),
                votes: Votes(0),
                numberOfInsurance: 0
            });

        airlinesCount = airlinesCount.add(1);
        if(registered == true) {
            registeredAirlinesCount = registeredAirlinesCount.add(1);
            emit AirlineRegistered(airlineAddress, airlines[airlineAddress].exists, airlines[airlineAddress].registered);
        } else {
            emit AirlineExist(airlineAddress, airlines[airlineAddress].exists);
        }
    }

    function setAirlineRegistered
                                (
                                    address airlineAddress
                                )
                                requireIsOperational
                                requireAirLineExist(airlineAddress)
                                public
    {
        require(airlines[airlineAddress].registered == false, "Airline is already registered");
        airlines[airlineAddress].registered = true;
        registeredAirlinesCount = registeredAirlinesCount.add(1);
        emit AirlineRegistered(airlineAddress, airlines[airlineAddress].exists, airlines[airlineAddress].registered);
    }

    function getMinimumRequiredVotingCount()
                                        public
                                        view
                                        returns(uint)
    {
        return registeredAirlinesCount.div(2);
    }

    function voteForAirline
                        (
                            address votingAirlineAddress,
                            address airlineAddress
                        )
                        public
                        requireIsOperational
    {
        require(airlines[airlineAddress].votes.voters[votingAirlineAddress] == false, "Airline already voted");

        airlines[airlineAddress].votes.voters[votingAirlineAddress] = true;
        uint startingVotes = getAirlineVotesCount(airlineAddress);

        airlines[airlineAddress].votes.votersCount = startingVotes.add(1);
    }

    function registerFlightKey
                            (
                                address airlineAddress,
                                bytes32 flightKey
                            )
                            public
                            requireAuthorizedCaller(msg.sender)
    {
        airlines[airlineAddress].flightKeys.push(flightKey);
    }

   /**
    * @dev Buy insurance for a flight
    *
    */
    function buyInsurance
                    (
                        address buyer,
                        address airlineAddress,
                        string memory flightName,
                        uint256 departure
                    )
                    public
                    payable
    {
        bytes32 flightKey = getFlightKey(airlineAddress, flightName, departure);
        FlightInsurance storage flightInsurance = flightInsurances[flightKey];
        flightInsurance.insurances[buyer] = Insurance(
            {
                buyer: buyer,
                value: msg.value,
                airline: airlineAddress,
                flightName: flightName,
                departure: departure,
                state: InsuranceState.Bought
            });
        flightInsurance.keys.push(buyer);
        emit InsuranceBought(flightKey);
    }

    // REQ: Insurance payouts are not sent directly to passenger’s wallet
    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                        (
                            bytes32 flightKey,
                            uint8 creditRate
                        )
                        public
                        requireAuthorizedCaller(msg.sender)
     {
        FlightInsurance storage flightInsurance = flightInsurances[flightKey];

        for (uint i = 0; i < flightInsurance.keys.length; i++) {
            Insurance storage insurance = flightInsurance.insurances[flightInsurance.keys[i]];

            if (insurance.state == InsuranceState.Bought) {
                insurance.value = insurance.value.mul(creditRate).div(100);
                if (insurance.value > 0)
                    insurance.state = InsuranceState.Passed;
                else
                    insurance.state = InsuranceState.Expired;
            } else {
                insurance.state = InsuranceState.Expired;
            }
        }
    }

    // REQ: Passenger can withdraw any funds owed to them
    // as a result of receiving credit for insurance payout
    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                (
                    bytes32 flightKey
                )
                external
                payable
    {
        FlightInsurance storage flightInsurance = flightInsurances[flightKey];
        Insurance storage insurance = flightInsurance.insurances[msg.sender];

        require(insurance.state == InsuranceState.Passed, "Insurance is not valid");
        require(address(this).balance > insurance.value, "Try again later");

        uint value = insurance.value;
        insurance.value = 0;
        insurance.state = InsuranceState.Expired;
        address payable insuree = address(uint160(insurance.buyer));
        insuree.transfer(value);
    }


   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */
    function fund
                (
                    address airlineAddress
                )
                public
                payable
                requireIsOperational
                requireAirLineRegistered(airlineAddress)
    {
        airlines[airlineAddress].funded = true;
        fundedAirlinesCount = fundedAirlinesCount.add(1);
        emit AirlineFunded(airlineAddress, airlines[airlineAddress].exists, airlines[airlineAddress].registered, airlines[airlineAddress].funded, fundedAirlinesCount);
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        internal
                        pure
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function()
            external
            payable
    {
        fund(msg.sender);
    }
}

