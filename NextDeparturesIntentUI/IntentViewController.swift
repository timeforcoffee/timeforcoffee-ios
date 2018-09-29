//
//  IntentViewController.swift
//  NextDeparturesIntentUI
//
//  Created by Christian Stocker on 21.09.18.
//  Copyright © 2018 opendata.ch. All rights reserved.
//

import IntentsUI
import timeforcoffeeKit
// As an example, this extension's Info.plist has been configured to handle interactions for INSendMessageIntent.
// You will want to replace this or add other intents as appropriate.
// The intents whose interactions you wish to handle must be declared in the extension's Info.plist.

// You can test this example integration by saying things to Siri like:
// "Send a message using <myApp>"

@available(iOSApplicationExtension 12.0, *)
class IntentViewController: UIViewController, INUIHostedViewControlling, UITableViewDelegate, UITableViewDataSource, TFCDeparturesUpdatedProtocol {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var appsTableView: UITableView!

    weak var currentStation: TFCStation?
    fileprivate var stationUpdate:TFCStationsUpdate? = nil
    fileprivate var currentTitle:String = ""
    
    deinit {
        self.stationUpdate = nil
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        titleLabel.isUserInteractionEnabled = true;
        if let station = self.currentStation {
            self.setStationTitleWithDistance(station)
        }
    }
  
    // MARK: - INUIHostedViewControlling
    
    // Prepare your view controller for the interaction to handle.
    func configureView(for parameters: Set<INParameter>, of interaction: INInteraction, interactiveBehavior: INUIInteractiveBehavior, context: INUIHostedViewContext, completion: @escaping (Bool, Set<INParameter>, CGSize) -> Void) {
        // Do configuration here, including preparing views and calculating a desired size for presentation.
        guard interaction.intent is NextDeparturesIntent else {
            completion(false, Set(), .zero)
            return
        }
        let intent = interaction.intent as! NextDeparturesIntent
        self.appsTableView.dataSource = self
        let desiredSize = CGSize(width: self.desiredSize.width, height: 350)
        
        if let st_id = intent.stationObj?.identifier {
            if let station = TFCStation.initWithCacheId(st_id) {
                self.currentStation = station
                self.setStationTitleWithDistance(station)
                station.updateDepartures(self)
            } else {
                completion(false, Set(), .zero)
                return
            }
            completion(true, parameters, desiredSize)

        } else {
            func stationsUpdateCompletion(stations:TFCStations?, error: String?, context: Any?) {
                if let stations = stations {
                    if let station = stations.getStation(0) {
                        self.currentStation = station
                        self.setStationTitleWithDistance(station)
                        station.updateDepartures(self)
                    }
                }
                completion(true, parameters, desiredSize)

            }
            self.stationUpdate = TFCStationsUpdate(completion: stationsUpdateCompletion)
            self.stationUpdate?.update(maxStations: 1)
        }
    }
    
    fileprivate func setStationTitleWithDistance(_ station: TFCStation) {
        let stationName = station.getNameWithStarAndFilters()
        var stationTitle = stationName
        if let distance = self.currentStation?.getDistanceForDisplay(TFCLocationManager.getCurrentLocation(ttl: 90), completion: { (text: String?) in
            if let distance = text, distance != "" {
                DispatchQueue.main.async {
                    self.titleLabel.text = "\(stationName), \(distance)"
                }
            }
        }),  distance != "" {
            stationTitle = "\(stationTitle), \(distance)"
        }
        DispatchQueue.main.async {
            self.titleLabel.text = stationTitle
        }   
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if (currentStation == nil) {
            return 0
        }
        let departures = self.currentStation?.getFilteredDepartures(6, fallbackToAll: true)
        if (departures == nil || departures!.count == 0) {
            return 1
        }
        let numberOfCells = min(6, departures!.count)
        return numberOfCells
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell
     
        cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCellWidget", for: indexPath)
        cell.layoutMargins = UIEdgeInsets.zero
        cell.preservesSuperviewLayoutMargins = false
        
        
        
        let lineNumberLabel = cell.viewWithTag(100) as! DepartureLineLabel
        let destinationLabel = cell.viewWithTag(200) as! UILabel
        let departureLabel = cell.viewWithTag(300) as! UILabel
        let minutesLabel = cell.viewWithTag(400) as! UILabel

    
        let station = currentStation
        let departures = currentStation?.getFilteredDepartures(6)
        if (departures == nil || departures!.count == 0) {
            lineNumberLabel.isHidden = true
            departureLabel.text = nil
            minutesLabel.text = nil
            if ((station != nil && departures == nil)) {
                destinationLabel.text = NSLocalizedString("Loading", comment: "Loading ..")
            } else {
                if (station == nil ) {
                    titleLabel.text = "Time for Coffee!"
                    destinationLabel.text = NSLocalizedString("No stations found.", comment: "")
                } else {
                    destinationLabel.text = NSLocalizedString("No departures found.", comment: "")
                }
                if let c = station?.getDepartures()?.count, (c > 0 && station?.hasFilters() == true) {
                    departureLabel.text = NSLocalizedString("Remove some filters.", comment: "")
                }
            }
            return cell
        }
        cell.textLabel?.text = nil
        if let departures = departures {
            if (indexPath.row < departures.count) {
                let departure: TFCDeparture = departures[indexPath.row]
                //if on first row and it's in the past, remove obsolete departures and reload
                if (indexPath.row == 0) {
                    if let i = departure.getMinutesAsInt(), i  < 0 {
                        DispatchQueue.main.async {
                            let _ = station?.removeObsoleteDepartures(true)
                            self.appsTableView?.reloadData()
                        }
                    }
                }
                var unabridged = false
                if (UIDevice.current.orientation.isLandscape) {
                    unabridged = true
                }
                destinationLabel.text = departure.getDestination(station, unabridged: unabridged)
                
                let (departureTimeAttr, departureTimeString) = departure.getDepartureTime()
                if (departureTimeAttr != nil) {
                    departureLabel.text = nil
                    departureLabel.attributedText = departureTimeAttr
                } else {
                    departureLabel.attributedText = nil
                    departureLabel.text = departureTimeString
                }
                
                minutesLabel.text = departure.getMinutes()
                lineNumberLabel.isHidden = false
                lineNumberLabel.setStyle("dark", departure: departure)
            }
        }
        return cell
    }

    func departuresUpdated(_ error: Error?, context: Any?, forStation: TFCStation?) {
        DLog("departuresUpdated", toFile: true)
        DispatchQueue.main.async {
                if (forStation?.st_id == self.currentStation?.st_id) {
                    self.appsTableView?.reloadData()
                    if let station = forStation {
                        self.setStationTitleWithDistance(station)
                    }
                }
        }
    }
    
    func departuresStillCached(_ context: Any?, forStation: TFCStation?) {
        // do nothing
        self.departuresUpdated(nil, context: context, forStation: forStation)
    }
    
    var desiredSize: CGSize {
        return self.extensionContext!.hostedViewMaximumAllowedSize
    }
    
}
