//
//  TodayViewController.swift
//  timeforcoffee Widget
//
//  Created by Christian Stocker on 23.02.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import UIKit
import NotificationCenter
import CoreLocation
import timeforcoffeeKit

class TodayViewController: TFCBaseViewController, NCWidgetProviding, UITableViewDataSource, UITableViewDelegate, APIControllerProtocol, UIGestureRecognizerDelegate {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var appsTableView: UITableView!
    let kCellIdentifier: String = "SearchResultCellWidget"

    var stations: TFCStations!
    var departures: [TFCDeparture]?
    var networkErrorMsg: String?
    var api : APIController?
    var currentStationIndex = 0
   
    override func viewDidLoad() {
        NewRelicAgent.startWithApplicationToken("AAe7c5942c67612bc82125c42d8b0b5c6a7df227b2")
        super.viewDidLoad()
        api = APIController(delegate: self)
        stations = TFCStations()
        titleLabel.userInteractionEnabled = true;
        let tapGesture  = UITapGestureRecognizer(target: self, action: "handleTap:")
        titleLabel.addGestureRecognizer(tapGesture)
        // Do any additional setup after loading the view from its nib.
    }
    
    @IBAction func nextButtonTouchUp(sender: AnyObject) {
        
        
        if (stations.count() != nil) {
            self.currentStationIndex++
            if (self.currentStationIndex >= self.stations.count()) {
                self.currentStationIndex = 0
            }
            self.departures = nil;
            let station = self.stations.getStation(self.currentStationIndex)
            if (station.st_id != "0000") {
                self.appsTableView!.reloadData()
                self.titleLabel.text = self.stations.getStation(self.currentStationIndex).getNameWithStarAndFilters()
                self.api?.getDepartures(self.stations.getStation(self.currentStationIndex).st_id)
            } else {
                self.currentStationIndex = 0
            }
        }

    }
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func handleTap(recognizer: UITapGestureRecognizer) {
        
        var station = self.stations.getStation(self.currentStationIndex);
        if (station.st_id != "0000") {
            var name = station.name.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
            let long = station.getLongitude()
            let lat = station.getLatitude()
            var urlstring = "timeforcoffee://station?id=\(station.st_id)&name=\(name)"
            if (long != nil && lat != nil) {
                urlstring = "\(urlstring)&long=\(long!)&lat=\(lat!)"
            }
            let url: NSURL = NSURL(string: urlstring)!
            self.extensionContext?.openURL(url, completionHandler: nil);
        }
    }
    
    override func lazyInitLocationManager() -> TFCLocationManager {
        titleLabel.text = NSLocalizedString("Looking for nearest station ...", comment: "")
        self.currentStationIndex = 0
        return super.lazyInitLocationManager()
    }
    
    override func locationFixed(coord: CLLocationCoordinate2D?) {
        println("locationFixed")
        if (coord != nil) {
            if (self.stations.addNearbyFavorites(locManager.currentLocation!)) {
                self.titleLabel.text = self.stations.getStation(0).getNameWithStarAndFilters()
                self.departures = nil
                self.api?.getDepartures(self.stations.getStation(0).st_id)
            }
            self.api?.searchFor(coord!)
        }

    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (self.departures == nil || self.departures!.count == 0) {
            return 1
        }
        return self.departures!.count
    }
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier) as UITableViewCell
        
        cell.layoutMargins = UIEdgeInsetsZero
        cell.preservesSuperviewLayoutMargins = false
        
        
        
        let lineNumberLabel = cell.viewWithTag(100) as DepartureLineLabel
        let destinationLabel = cell.viewWithTag(200) as UILabel
        let departureLabel = cell.viewWithTag(300) as UILabel
        let minutesLabel = cell.viewWithTag(400) as UILabel
        let station = self.stations.getStation(self.currentStationIndex)

        if (self.departures == nil || self.departures!.count == 0) {
            departureLabel.text = nil
            minutesLabel.text = nil
            if (self.departures == nil) {
                destinationLabel.text = NSLocalizedString("Loading", comment: "Loading ..")
            } else {
                destinationLabel.text = NSLocalizedString("No departures found.", comment: "")
                if (self.networkErrorMsg != nil) {
                    departureLabel.text = self.networkErrorMsg
                } else if (station.hasFilters()) {
                    departureLabel.text = NSLocalizedString("Remove some filters.", comment: "")
                }
            }
            return cell
        }
        
        cell.textLabel!.text = nil

        let departure: TFCDeparture = self.departures![indexPath.row]
        var unabridged = false
        if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
            unabridged = true
        }
        destinationLabel.text = departure.getDestinationWithSign(station, unabridged: unabridged)
        departureLabel.attributedText = departure.getDepartureTime()
        minutesLabel.text = departure.getMinutes()
        
        lineNumberLabel.setStyle("dark", departure: departure)
        
        return cell
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func widgetPerformUpdateWithCompletionHandler(completionHandler: ((NCUpdateResult) -> Void)!) {
        // Perform any setup necessary in order to update the view.
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        //this should only be called, after everything is updated. didReceiveAPIResults ;)
        // see also https://stackoverflow.com/questions/25961513/ios-8-today-widget-stops-working-after-a-while
        locManager.refreshLocation()
        completionHandler(NCUpdateResult.NewData)
    }
    
    func didReceiveAPIResults(results: JSONValue, error: NSError?, context: Any?) {
        dispatch_async(dispatch_get_main_queue(), {
            if (!(error != nil && error?.code == -999)) {
                if (error != nil) {
                    self.networkErrorMsg = NSLocalizedString("Network error. Please try again", comment: "")
                } else {
                    self.networkErrorMsg = nil
                }
                if (TFCStation.isStations(results)) {
                    let hasAlreadyFavouritesDisplayed = self.stations.count()
                    self.stations.addWithJSON(results, append: true)
                    self.titleLabel.text = self.stations.getStation(self.currentStationIndex).getNameWithStarAndFilters()
                    if (hasAlreadyFavouritesDisplayed == nil || hasAlreadyFavouritesDisplayed == 0) {
                        self.api?.getDepartures(self.stations.getStation(self.currentStationIndex).st_id)
                    }
                } else {
                    self.departures = TFCDeparture.withJSON(results, filterStation: self.stations.getStation(self.currentStationIndex))
                    
                }
            
            self.appsTableView!.reloadData()
            }
        })
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        coordinator.animateAlongsideTransition(
            {
                (context) -> Void in
            },
            completion: {
                (context) -> Void in
                self.appsTableView?.reloadData()
                return
        })
    }

}


