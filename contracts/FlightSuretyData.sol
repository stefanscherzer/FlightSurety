pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    uint256 public registeredCount = 0;

    uint256 public constant InsuranceFee = 1 ether;

    struct airline {
      bool registered;
      bool hasPaid;
      mapping(address => bool) voters;
      uint256 votes;
    }

    struct passengerFlights {
      bool exist;
      uint256 status;
      bool registered;
      uint256 departuretime;
      uint256 price;
      mapping(address => bool) boughtInsurance;
    }

    // struct Flight {
    //     bool isRegistered;
    //     uint8 statusCode;
    //     uint256 updatedTimestamp;        
    //     address airline;
    // }
    // mapping(bytes32 => Flight) private flights;

    mapping(address => uint256) private credit;
    mapping(address => bool) private authorizedCallers;
    mapping(bytes32 => passengerFlights) private flights;

    mapping(address => airline) private airlines;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


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
        
        airline memory Airline;
        Airline.registered = true;
        Airline.hasPaid = true;
        Airline.votes = 0;
        airlines[airlineAddress] = Airline;

        registeredCount = registeredCount.add(1);
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

    modifier isAuthorized()
    {
        require(authorizedCallers[msg.sender] == true, "Caller is not authorized to make calls on data contract");
        _;
    }

    modifier wasInsuranced(bytes32 key, address passenger)
    {
        require(flights[key].boughtInsurance[passenger] == true, "Passenger is not insured or insurance for this flight was  refunded already");
        _;
    }

    modifier isNotInsuranced(bytes32 key, address passenger)
    {
        require(flights[key].boughtInsurance[passenger] == false, "Passenger bought insurance for this flight already");
        _;
    }

    modifier flightExists(bytes32 key)
    {
        require(flights[key].exist == true, "Flight does not exist");
        _;
    }

    modifier flightstatus(bytes32 key)
    {
        require(flights[key].status != 10, "Flight was on time --> no insurance for you");
        _;
    }

    modifier timesUp(bytes32 key)
    {
        require(flights[key].departuretime >= now, "Too late to buy insurance for this flight");
        _;
    }

    modifier toSoon(bytes32 key)
    {
        require(flights[key].departuretime < now, "Flight must be pass depature date/time for insurance payout");
        _;
    }

    modifier minimumFundBalance()
    {
        require(address(this).balance > 10 ether, "Contract has insufficient funds for withdraw");
        _;
    }
    modifier checkBalance(address passenger)
    {
        require(credit[passenger] > 0, "Address has no credit");
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
                            isAuthorized
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
                            external
                            requireContractOwner 
    {
        require(operational != mode, "operating status would not change");
        operational = mode;
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/


    function authorizeCaller
                        (
                            address addressToAuthorize
                        ) 
                        external
                        requireContractOwner
    {
        authorizedCallers[addressToAuthorize] = true;
    }

    function hasPaid
                (
                    address airlineAddress
                ) 
                external 
                view
                requireIsOperational
                isAuthorized
                returns(bool)
    {
        return airlines[airlineAddress].hasPaid;
    }

    function hasAlreadyVoted
                        (
                            address newAirline, 
                            address voter
                        ) 
                        external 
                        view
                        requireIsOperational
                        isAuthorized
                        returns(bool)
    {
        return airlines[newAirline].voters[voter];
    }

    function getRegistrationCount() 
                            external 
                            view
                            requireIsOperational
                            isAuthorized
                            returns(uint256)
    {
        return registeredCount;
    }

    function isRegisteredAirline
                        (
                            address airlineAddress
                        ) 
                        external 
                        view
                        requireIsOperational
                        isAuthorized
                        returns(bool registered, bool paid, uint256 votes)
    {
        airline memory Airline = airlines[airlineAddress];
        return (
                Airline.registered, 
                Airline.hasPaid, 
                Airline.votes
            );
    }

    function isInsured
                    (
                        bytes32 key, 
                        address passenger
                    ) 
                    external 
                    view 
                    returns(bool)
    {
        return flights[key].boughtInsurance[passenger];
    }

    function getTicketPriceWithInsurance
                                    (
                                        bytes32 key
                                    ) 
                                    external
                                    view
                                    requireIsOperational
                                    isAuthorized
                                    flightExists(key)
                                    returns(uint256 ticketPrice, uint256 ticketPriceWithInsurance)
    {
        uint256 priceWithInsurance = flights[key].price.add(InsuranceFee);
        return (
                flights[key].price, 
                priceWithInsurance
            );
    }

    function getFlight
                    (
                        bytes32 key
                    ) 
                    external 
                    view
                    isAuthorized
                    returns(bool exist, uint256 status, bool registered, uint256 departuretime, uint256 price)
    {
        return (
                flights[key].exist,
                flights[key].status,
                flights[key].registered,
                flights[key].departuretime,
                flights[key].price
            );
    }

    function setFlightStatus
                            (
                                bytes32 key, 
                                uint256 status
                            ) 
                            external
                            requireIsOperational
                            isAuthorized
                            flightExists(key)
    {
        flights[key].status = status;
    }

    function getConsensusCount() 
                            external 
                            view
                            requireIsOperational
                            isAuthorized
                            returns(uint256)
    {
        uint256 consensusCount = registeredCount.div(2);
        return consensusCount;
    }

    function changeRegistration
                            (
                                address newAirline,
                                bool registrationState
                            ) 
                            external
                            requireIsOperational
                            isAuthorized
    {
        airlines[newAirline].registered = registrationState;
        registeredCount = registeredCount.add(1);
    }

    function addVote
                (
                    address votedAirline, 
                    address voter
                ) 
                external
                requireIsOperational
                isAuthorized
    {
        airlines[votedAirline].voters[voter] = true;
        airlines[votedAirline].votes = airlines[votedAirline].votes.add(1);
    }

    function payFee
                (
                    address payingAirline
                ) 
                external 
                payable
                requireIsOperational
                isAuthorized
    {
        airlines[payingAirline].hasPaid = true;
    }

    function addRegisteredFlight
                            (
                                bytes32 key, 
                                uint256 price, 
                                uint256 time
                            ) 
                            external
                            requireIsOperational
                            isAuthorized
    {
        passengerFlights memory newFlight;

        newFlight.exist = true;
        newFlight.status = 10;
        newFlight.registered = true;
        newFlight.price = price;
        newFlight.departuretime = time;

        flights[key] = newFlight;
    }

    /**
    * @dev Buy insurance for a flight
    *
    */
    function buy
            (
                bytes32 key, 
                address passenger, 
                bool withInsurance
            ) 
            external 
            payable
            requireIsOperational
            isAuthorized
            isNotInsuranced(key, passenger)
            flightExists(key)
            timesUp(key)
    {
        flights[key].boughtInsurance[passenger] = (withInsurance == true ? true : false);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                        (
                            address passenger
                        ) 
                        external 
                        view
                        requireIsOperational
                        isAuthorized
                        returns (uint256)
    {
        return credit[passenger];
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
            (
                address passenger
            ) 
            external
            requireIsOperational
            isAuthorized
            checkBalance(passenger)
            minimumFundBalance
    {
        passenger.transfer(credit[passenger]);
        credit[passenger] = 0;
    }

    /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */ 
    function fund(
                bytes32 key,
                address passenger
            ) 
            public
            requireIsOperational
            isAuthorized
            toSoon(key)
            wasInsuranced(key, passenger)
            flightstatus(key)
    {
        flights[key].boughtInsurance[passenger] = false;
        uint256 half = flights[key].price.div(2);
        uint256 amountTofund = flights[key].price.add(half);
        credit[passenger] += amountTofund;
    }

    function getFlightKey
                    (
                        address airlineAddress,
                        string memory flight,
                        uint256 timestamp
                    ) 
                    internal 
                    pure 
                    returns(bytes32)
    {
        return keccak256(abi.encodePacked(airlineAddress, flight, timestamp));
    }                        

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    // function registerAirline
    //                         (   
    //                         )
    //                         external
    //                         pure
    // {
    // }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    // function() 
    //                         external 
    //                         payable 
    // {
    //     fund();
    // }

}

