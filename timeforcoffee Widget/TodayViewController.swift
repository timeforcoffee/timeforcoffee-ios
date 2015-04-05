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

class TodayViewController: TFCBaseViewController, NCWidgetProviding, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate,  TFCDeparturesUpdatedProtocol, TFCStationsUpdatedProtocol {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var appsTableView: UITableView!
    @IBOutlet weak var actionLabel: UIButton!
    let kCellIdentifier: String = "SearchResultCellWidget"
    lazy var gtracker: GAITracker = {
        let gtrackerInstance = GAI.sharedInstance()
        gtrackerInstance.trackUncaughtExceptions = true
        gtrackerInstance.dispatchInterval = 10;
        //GAI.sharedInstance().logger.logLevel = GAILogLevel.Verbose
        gtrackerInstance.trackerWithTrackingId("UA-37092982-2")
        var gtrack = gtrackerInstance.defaultTracker
        gtrack?.set("&uid", value: UIDevice().identifierForVendor.UUIDString)
        return gtrack
    }()

    lazy var stations: TFCStations? =  {return TFCStations(delegate: self)}()

    weak var currentStation: TFCStation?

    var networkErrorMsg: String?

    var currentStationIndex = 0
    var viewDidAppear = false
    var showStations: Bool = false {
        didSet {
            if (showStations == true) {
                setLastUsedView()
                actionLabel.setTitle("Back", forState: UIControlState.Normal)
                titleLabel.text = "Nearby Stations"
            } else {
                if (currentStation != nil) {
                    setLastUsedView()
                }
                actionLabel.setTitle("Stations", forState: UIControlState.Normal)
                if let stationName = currentStation?.getNameWithStarAndFilters() {
                    titleLabel.text = currentStation?.getNameWithStarAndFilters()
                } else {
                    titleLabel.text = "Time for Coffee"
                }
            }
            actionLabel.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        }
    }

    lazy var lastViewedStation: TFCStation? = {
        let stationDict = TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("lastUsedStation") as [String: String]?
        if (stationDict == nil) {
            return nil
        }
        var station = TFCStation.initWithCache(stationDict!)
        station.isLastUsed = true
        return station
    }()
   
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.userInteractionEnabled = true;
        let tapGesture  = UITapGestureRecognizer(target: self, action: "handleTap:")
        titleLabel.addGestureRecognizer(tapGesture)
        // Do any additional setup after loading the view from its nib.
    }


    override init() {
        super.init()
    }

    override init(coder aDecoder: NSCoder) {
        NSLog("init")
        super.init(coder: aDecoder)
        if (getLastUsedView() == "nearbyStations") {
            showStations = true
        } else {
            showStations = false
        }
        TFCDataStore.sharedInstance.registerForNotifications()
        TFCDataStore.sharedInstance.synchronize()
    }

    deinit {
        NSLog("deinit widget")
        TFCURLSession.sharedInstance.cancelURLSession()
        TFCDataStore.sharedInstance.removeNotifications()
    }

    override func viewDidAppear(animated: Bool) {
        //actionLabel.hidden = false
        NSLog("viewDidAppear")
        viewDidAppear = true
        actionLabel.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        super.viewDidAppear(animated)
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        actionLabel.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Normal)
    }

    func widgetPerformUpdateWithCompletionHandler(completionHandler: ((NCUpdateResult) -> Void)!) {
        // Perform any setup necessary in order to update the view.
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        NSLog("widgetPerformUpdateWithCompletionHandler")
        completionHandler(NCUpdateResult.NewData)

        // if lastUsedView is a single station and we did look at it no longer than 5 minutes ago, just show it again
        // without even checking the location
        if (getLastUsedView() == "nearbyStations") {
            sendScreenNameToGA("todayviewNearby")
            showStations = true
        } else {
            sendScreenNameToGA("todayviewStation")
            showStations = false
            if (lastUsedViewUpdatedInterval() > -300) {
                currentStation = lastViewedStation
                if (currentStation != nil) {
                    showStations = false
                    displayDepartures()
                    return
                }
            }
           locManager?.refreshLocation()
        }
        stations?.updateStations()
    }

    override func lazyInitLocationManager() -> TFCLocationManager? {
        if (currentStation == nil) {
            titleLabel.text = NSLocalizedString("Looking for nearest station ...", comment: "")
        }
        self.currentStationIndex = 0
        return super.lazyInitLocationManager()
    }

    override func locationFixed(coord: CLLocation?) {
        NSLog("locationFixed")
        if (coord != nil) {
            if (locManager?.currentLocation != nil) {
                // if lastUsedView is a single station and we did look at it no longer than 30 minutes
                // and the distance is not much more (200m), just show it again
                if (currentStation == nil) {
                    if (lastUsedViewUpdatedInterval() > -(60 * 30)) {
                        let distance2lastViewedStationNow: CLLocationDistance? = locManager?.currentLocation?.distanceFromLocation(lastViewedStation?.coord)
                        let distance2lastViewedStationLasttime: CLLocationDistance? = TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("lastUsedStationDistance") as CLLocationDistance?
                        if (distance2lastViewedStationNow != nil && distance2lastViewedStationLasttime != nil && distance2lastViewedStationNow! < distance2lastViewedStationLasttime! + 200) {
                            currentStation = lastViewedStation
                            if (currentStation != nil) {
                                showStations = false
                                displayDepartures()
                            }
                        }
                    }
                }
            }
        }
    }

    override func locationDenied(manager: CLLocationManager) {
        self.networkErrorMsg = "Location not available"
        self.stations?.empty()
        self.titleLabel.text = "Time for Coffee!"
        self.appsTableView?.reloadData()
    }


    @IBAction func nextButtonTouchUp(sender: AnyObject) {
        if (showStations == true) {
            if (currentStation == nil) {
                if (lastViewedStation != nil) {
                    currentStation = lastViewedStation
                } else if (stations?.count() > 0) {
                    currentStation = stations?.getStation(0)
                }
            }
            showStations = false
            self.networkErrorMsg = nil
            currentStation?.updateDepartures(self)
            self.appsTableView.reloadData()
            sendScreenNameToGA("todayviewStation")
        } else { // if (stations?.count() > 0) {
            showStations = true
            stations?.updateStations(false)
            self.appsTableView?.reloadData()
            sendScreenNameToGA("todayviewNearby")
        }
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


    func setLastUsedView() {
        let userDefaults = TFCDataStore.sharedInstance.getUserDefaults()
        if (showStations) {
            userDefaults?.setObject("nearbyStations", forKey: "lastUsedView")
        } else {
            if (currentStation != nil) {
                userDefaults?.setObject("singleStation", forKey: "lastUsedView")
                currentStation?.isLastUsed = true
                lastViewedStation?.isLastUsed = false
                // FIXME, use NSCoding serialisation ..
                // and maybe one object for all these values
                userDefaults?.setObject(currentStation?.getAsDict(), forKey: "lastUsedStation")
                userDefaults?.setObject(locManager?.currentLocation?.distanceFromLocation(currentStation?.coord), forKey: "lastUsedStationDistance")
            } else {
                userDefaults?.removeObjectForKey("lastUsedView")
                userDefaults?.removeObjectForKey("lastUsedStation")
                userDefaults?.removeObjectForKey("lastUsedStationDistance")
                lastViewedStation?.isLastUsed = false
            }
        }
        userDefaults?.setObject(NSDate(), forKey: "lastUsedViewUpdate")
    }

    func getLastUsedView() -> String? {
        return TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("lastUsedView") as String?
    }

    func lastUsedViewUpdatedInterval() -> NSTimeInterval? {
        let lastUpdate: NSDate? = TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("lastUsedViewUpdate") as NSDate?
        return lastUpdate?.timeIntervalSinceNow
    }

    func displayDepartures() {
        //UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.networkErrorMsg = nil
        currentStation?.updateDepartures(self)
        self.appsTableView?.reloadData()
        setLastUsedView()
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (showStations) {
            let count = stations?.count()
            if (count == nil || count == 0) {
                return 1
            }
            return min(6, count!)
        }
        if (viewDidAppear == false && currentStation == nil) {
            return 0
        }
        let departures = self.currentStation?.getFilteredDepartures(6)
        if (departures == nil || departures!.count == 0) {
            return 1
        }
        return min(6, departures!.count)
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
            let stationsCount = self.stations?.count()
            if (stationsCount == nil || stationsCount == 0) {
                if (stationsCount == nil) {
                    destinationLabel.text = NSLocalizedString("Loading", comment: "Loading ..")
                    departureLabel.text = ""
                } else {
                    destinationLabel.text = NSLocalizedString("No stations found.", comment: "")
                    departureLabel.text = stations?.networkErrorMsg
                }
                lineNumberLabel.hidden = true
                minutesLabel.text = nil

                return cell
            }

            let station = self.stations?.getStation(indexPath.row)
            let departures = station?.getFilteredDepartures(1)
            let firstDeparture = departures?.first
            let iconLabel = cell.viewWithTag(500) as UIImageView
            iconLabel.layer.cornerRadius = iconLabel.layer.bounds.width / 2
            iconLabel.clipsToBounds = true
            iconLabel.image = station?.getIcon()
            iconLabel.hidden = false
            lineNumberLabel.hidden = false
            destinationLabel.text = station?.getNameWithFilters(false)

            if (firstDeparture != nil && firstDeparture?.getMinutesAsInt() >= 0) {
                lineNumberLabel.setStyle("dark", departure: firstDeparture!)
                minutesLabel.text = firstDeparture!.getMinutes()
                departureLabel.text = firstDeparture!.getDestinationWithSign(station, unabridged: false)
            } else {
                lineNumberLabel.hidden = true
                minutesLabel.text = nil
                departureLabel.text = nil
            }
            station?.updateDepartures(self)
            cell.userInteractionEnabled = true
            return cell
        }
        let station = currentStation
        let departures = currentStation?.getFilteredDepartures(6)
        if (departures == nil || departures!.count == 0) {
            lineNumberLabel.hidden = true
            departureLabel.text = nil
            minutesLabel.text = nil
            if (station != nil && departures == nil) {
                destinationLabel.text = NSLocalizedString("Loading", comment: "Loading ..")
            } else {
                if (station == nil ) {
                    destinationLabel.text = NSLocalizedString("No stations found.", comment: "")
                    departureLabel.text = stations?.networkErrorMsg
                } else {
                    destinationLabel.text = NSLocalizedString("No departures found.", comment: "")
                    if (self.networkErrorMsg != nil) {
                        departureLabel.text = self.networkErrorMsg
                    }
                }

                if (station?.hasFilters() == true && station?.getDepartures()?.count > 0) {
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

        let (departureTimeAttr, departureTimeString) = departure.getDepartureTime()
        if (departureTimeAttr != nil) {
            departureLabel.text = nil
            departureLabel.attributedText = departureTimeAttr
        } else {
            departureLabel.attributedText = nil
            departureLabel.text = departureTimeString
        }

        minutesLabel.text = departure.getMinutes()
        lineNumberLabel.hidden = false
        lineNumberLabel.setStyle("dark", departure: departure)
        
        return cell
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if (showStations) {
            currentStation = self.stations?.getStation(indexPath.row)
            showStations = false
            if (currentStation?.st_id != "0000") {
                currentStationIndex = indexPath.row
                displayDepartures()
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func departuresUpdated(error: NSError?, context: Any?, forStation: TFCStation?) {
        if (showStations) {
            self.appsTableView!.reloadData()
        } else {
            if (forStation?.st_id == currentStation?.st_id) {
                if (error != nil) {
                    self.networkErrorMsg = NSLocalizedString("Network error. Please try again", comment:"")
                } else {
                    self.networkErrorMsg = nil
                }
                self.appsTableView!.reloadData()
            }
        }
    }

    func departuresStillCached(context: Any?, forStation: TFCStation?) {
        // do nothing
    }

    func stationsUpdated(error: String?, favoritesOnly: Bool) {
        dispatch_async(dispatch_get_main_queue(), {
            // if we show a single station, but it's not determined which one
            //   try to get one from the stations array
            if (self.showStations == false && self.currentStation == nil) {
                self.currentStation = self.stations?.getStation(self.currentStationIndex)
                if (self.currentStation != nil) {
                    self.titleLabel.text = self.currentStation?.getNameWithStarAndFilters()
                    self.displayDepartures()
                    self.actionLabel.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
                } else {
                    self.titleLabel.text = "Time for Coffee!"
                    self.actionLabel.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Normal)
                }
            }
            self.appsTableView.reloadData()
        })
    }

    func sendScreenNameToGA(screenname: String) {
        gtracker.set(kGAIScreenName, value: screenname)
        gtracker.send(GAIDictionaryBuilder.createScreenView().build())
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
