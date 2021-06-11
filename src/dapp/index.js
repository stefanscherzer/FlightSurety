import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log('err: ', error, ' | res:', result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });
    
        // Passengers can choose from a fixed list of flight numbers and departure that are defined in the Dapp client - https://www.random.org/strings/
        const flightNumbers = ['IS6580', 'TO9254', 'DJ0341', 'YY4244'];
        var sel = DOM.elid('flights-dropdown');
        for (var a = 0; a < flightNumbers.length; a++) {
            sel.innerHTML = sel.innerHTML +
                '<option value=\'' + flightNumbers[a] + '\'>' 
                + flightNumbers[a] + '</option>';
        }

        // A Dapp client has been created and is used for triggering contract calls. Client can be launched with “npm run dapp” and is available at http://localhost:8000
        // Specific contract calls:
        // 1) Passenger can purchase insurance for flight
        DOM.elid('purchase-insurance').addEventListener('click', () => {
            let flightName = DOM.elid('flightName').value;
            let departure = DOM.elid('departure').value;
            let ether = DOM.elid('ether').value;
            // Write transaction
            contract.buyInsurance(flightName, departure, ether, (error, result) => {
                if (error)
                    display('Insurance', 'Purchase Insurance', [ { label: 'Insurance Status', error: error, value: result} ]);
                else
                    contract.getInsurance(flightName, departure, (error, result) => {
                        display('Insurance', 'Purchase Insurance', [ { label: 'Insurance Status', error: error, value: result.value + ' ' + result.state} ]);
                    });
            });
        })

        // 2) Trigger contract to request flight status update
        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flights-dropdown').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                DOM.elid('flightName').value = result.flight;
                DOM.elid('departure').value = result.timestamp;
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })    
    });
    
})();

function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);
}
