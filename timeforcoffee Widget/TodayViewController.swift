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

class TodayViewController: TFCBaseViewController, NCWidgetProviding, UITableViewDataSource, UITableViewDelegate, APIControllerProtocol, UIGestureRecognizerDelegate,  TFCDeparturesUpdatedProtocol {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var appsTableView: UITableView!
    @IBOutlet weak var actionLabel: UIButton!
    let kCellIdentifier: String = "SearchResultCellWidget"

    lazy var stations: TFCStations? =  {return TFCStations()}()

    weak var currentStation: TFCStation?

    var networkErrorMsg: String?
    lazy var api : APIController? = {return APIController(delegate: self)}()
    var currentStationIndex = 0

    var showStations: Bool = false {
        didSet {
            if (showStations == true) {
                actionLabel.setTitle("Back", forState: UIControlState.Normal)
                titleLabel.text = "Nearby Stations"

            } else {
                actionLabel.setTitle("Stations", forState: UIControlState.Normal)
                titleLabel.text = currentStation?.getNameWithStarAndFilters()
            }
        }
    }
   
    override func viewDidLoad() {
        //NewRelicAgent.startWithApplicationToken("AAe7c5942c67612bc82125c42d8b0b5c6a7df227b2")
        super.viewDidLoad()
        titleLabel.userInteractionEnabled = true;
        let tapGesture  = UITapGestureRecognizer(target: self, action: "handleTap:")
        titleLabel.addGestureRecognizer(tapGesture)
        // Do any additional setup after loading the view from its nib.
        let gtracker = GAI.sharedInstance()
        gtracker.trackUncaughtExceptions = true
        gtracker.dispatchInterval = 20;
        //GAI.sharedInstance().logger.logLevel = GAILogLevel.Verbose
        gtracker.trackerWithTrackingId("UA-37092982-2")
        gtracker.defaultTracker.set("&uid", value: UIDevice().identifierForVendor.UUIDString)

    }
    
    deinit {
        println("deinit widget")
    }

    @IBAction func nextButtonTouchUp(sender: AnyObject) {
        let gtracker = GAI.sharedInstance().defaultTracker
        if (showStations == true) {
            showStations = false
            self.appsTableView.reloadData()
            gtracker.set(kGAIScreenName, value: "todayviewStation")
        } else if (stations?.count() > 0) {
            showStations = true
            self.appsTableView.reloadData()
            gtracker.set(kGAIScreenName, value: "todayviewMore")
        }
        gtracker.send(GAIDictionaryBuilder.createScreenView().build())
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        let gtracker = GAI.sharedInstance().defaultTracker
        gtracker.set(kGAIScreenName, value: "todayviewStation")
        gtracker.send(GAIDictionaryBuilder.createScreenView().build())
    }

    func handleTap(recognizer: UITapGestureRecognizer) {
        if (showStations) {
            var urlstring = "timeforcoffee://nearby"
            let url: NSURL = NSURL(string: urlstring)!
            self.extensionContext?.openURL(url, completionHandler: nil);
        } else if (currentStation != nil && currentStation?.st_id != "0000") {
            let station = currentStation!
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
    
    override func lazyInitLocationManager() -> TFCLocationManager? {
        titleLabel.text = NSLocalizedString("Looking for nearest station ...", comment: "")
        self.currentStationIndex = 0
        return super.lazyInitLocationManager()
    }
    
    override func locationFixed(coord: CLLocationCoordinate2D?) {
        println("locationFixed")
        if (coord != nil) {
            showStations = true
            if (locManager?.currentLocation != nil) {
                let nearbyStationsAdded = self.stations?.addNearbyFavorites((locManager?.currentLocation)!)
                if (nearbyStationsAdded == true) {
                    currentStation = self.stations?.getStation(0)
                    if (!showStations) {
                        self.titleLabel.text = currentStation?.getNameWithStarAndFilters()
                        displayDepartures()
                    }
                }
            }
            self.api?.searchFor(coord!)
        }

    }


    func displayDepartures() {
        currentStation?.removeObseleteDepartures()
        currentStation?.filterDepartures()
        self.appsTableView?.reloadData()
        //UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        currentStation?.updateDepartures(self, maxDepartures: 6)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (showStations) {
            if (stations?.count() != nil) {
                return (self.stations?.count())!
            }
            return 1
        }
        let departures = self.currentStation?.getDepartures()
        if (departures == nil || departures!.count == 0) {
            return 1
        }
        return departures!.count
    }
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        if (showStations) {
            cell = tableView.dequeueReusableCellWithIdentifier("NearbyStationsCell") as UITableViewCell
        } else {
            cell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier) as UITableViewCell
        }
        cell.layoutMargins = UIEdgeInsetsZero
        cell.preservesSuperviewLayoutMargins = false
        
        
        
        let lineNumberLabel = cell.viewWithTag(100) as DepartureLineLabel
        let destinationLabel = cell.viewWithTag(200) as UILabel
        let departureLabel = cell.viewWithTag(300) as UILabel
        let minutesLabel = cell.viewWithTag(400) as UILabel

        if (showStations) {
            let station = self.stations?.getStation(indexPath.row)
            station?.removeObseleteDepartures()
            station?.filterDepartures()
            let firstDeparture = station?.getDepartures()?.first
            let iconLabel = cell.viewWithTag(500) as UIImageView
            iconLabel.layer.cornerRadius = iconLabel.layer.bounds.width / 2
            iconLabel.clipsToBounds = true
            iconLabel.image = station?.getIcon()
            iconLabel.hidden = false
            lineNumberLabel.hidden = false
            destinationLabel.text = station?.getName(false)

            if (firstDeparture != nil) {
                lineNumberLabel.setStyle("dark", departure: firstDeparture!)
                minutesLabel.text = firstDeparture!.getMinutes()
                departureLabel.text = firstDeparture!.getDestinationWithSign(station, unabridged: false)
            } else {
                lineNumberLabel.hidden = true
                minutesLabel.text = nil
                departureLabel.text = nil
            }

            //if we already have departures, get all 6
            // if not, then just load 1 for the overview
            if (station?.getDepartures()?.count > 1) {
                station?.updateDepartures(self, maxDepartures: 6)
            } else {
                station?.updateDepartures(self, maxDepartures: 1)
            }
            cell.userInteractionEnabled = true
            return cell
        }
        let station = currentStation
        let departures = currentStation?.getDepartures()
        if (departures == nil || departures!.count == 0) {
            lineNumberLabel.hidden = true
            departureLabel.text = nil
            minutesLabel.text = nil
            if (departures == nil) {
                destinationLabel.text = NSLocalizedString("Loading", comment: "Loading ..")
            } else {
                destinationLabel.text = NSLocalizedString("No departures found.", comment: "")
                if (self.networkErrorMsg != nil) {
                    departureLabel.text = self.networkErrorMsg
                } else if (station?.hasFilters() == true) {
                    departureLabel.text = NSLocalizedString("Remove some filters.", comment: "")
                }
            }
            return cell
        }
        cell.textLabel!.text = nil
        let departure: TFCDeparture = departures![indexPath.row]
        var unabridged = false
        if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
            unabridged = true
        }
        destinationLabel.text = departure.getDestinationWithSign(station, unabridged: unabridged)
        departureLabel.attributedText = departure.getDepartureTime()
        minutesLabel.text = departure.getMinutes()
        lineNumberLabel.hidden = false
        lineNumberLabel.setStyle("dark", departure: departure)
        
        return cell
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if (showStations) {
            showStations = false
            currentStation = self.stations?.getStation(indexPath.row)
            currentStationIndex = indexPath.row
            if (currentStation?.st_id != "0000") {
                self.titleLabel.text = currentStation?.getNameWithStarAndFilters()
                displayDepartures()
            }
        }
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
        locManager?.refreshLocation()
        completionHandler(NCUpdateResult.NewData)
    }

    func departuresUpdated(error: NSError?, context: Any?, forStation: TFCStation?) {
        //  UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        if (showStations) {
            self.appsTableView!.reloadData()
        } else {
            if (forStation?.st_id == currentStation?.st_id) {
                if (error != nil) {
                    self.networkErrorMsg = NSLocalizedString("Network error. Please try again", comment:"")
                } else {
                    self.networkErrorMsg = nil
                }
                currentStation?.filterDepartures()
                self.appsTableView!.reloadData()
            }
        }
    }

    func departuresStillCached(context: Any?, forStation: TFCStation?) {
        // do nothing
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
                    let hasAlreadyFavouritesDisplayed = self.stations?.count()
                    self.stations?.addWithJSON(results, append: true)
                    self.currentStation = self.stations?.getStation(self.currentStationIndex)
                    if (self.showStations == false) {
                        self.titleLabel.text = self.currentStation?.getNameWithStarAndFilters()
                        if (hasAlreadyFavouritesDisplayed == nil || hasAlreadyFavouritesDisplayed == 0) {
                            self.displayDepartures()
                        }
                    }
                } else {
                    //self.currentStation?.addDepartures(TFCDeparture.withJSON(results, filterStation: self.stations.getStation(self.currentStationIndex)))
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


