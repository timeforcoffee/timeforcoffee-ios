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
import PINCache

class TodayViewController: TFCBaseViewController, NCWidgetProviding, UITableViewDataSource, UITableViewDelegate, APIControllerProtocol, UIGestureRecognizerDelegate,  TFCDeparturesUpdatedProtocol {
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

    lazy var stations: TFCStations? =  {return TFCStations()}()

    weak var currentStation: TFCStation?

    var networkErrorMsg: String?
    lazy var api : APIController? = {return APIController(delegate: self)}()
    var currentStationIndex = 0

    var showStations: Bool = false {
        didSet {
            setLastUsedView()
            if (showStations == true) {
                actionLabel.setTitle("Back", forState: UIControlState.Normal)
                titleLabel.text = "Nearby Stations"
            } else {
                actionLabel.setTitle("Stations", forState: UIControlState.Normal)
                titleLabel.text = currentStation?.getNameWithStarAndFilters()
            }
            actionLabel.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        }
    }

    lazy var lastViewedStation: TFCStation? = {
        let stationDict = TFCStations.getUserDefaults()?.objectForKey("lastUsedStation") as [String: String]?
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
        super.init(coder: aDecoder)
        TFCDataStore.sharedInstance.registerForNotifications()
        TFCDataStore.sharedInstance.synchronize()
    }

    deinit {
        NSLog("deinit widget")
        TFCDataStore.sharedInstance.removeNotifications()
    }

    override func viewDidAppear(animated: Bool) {
        //actionLabel.hidden = false
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

        // if lastUsedView is a single station and we did look at it no longer than 5 minutes ago, just show it again
        // without even checking the location
        if (getLastUsedView() == "nearbyStations") {
            sendScreenNameToGA("todayviewNearby")
        } else {
            sendScreenNameToGA("todayviewStation")
            if (lastUsedViewUpdatedInterval() > -300) {
                currentStation = lastViewedStation
                if (currentStation != nil) {
                    showStations = false
                    displayDepartures()
                    currentStation?.updateDepartures(self, maxDepartures: 6)
                }
            }
        }
        locManager?.refreshLocation()
        //this should only be called, after everything is updated. didReceiveAPIResults ;)
        // see also https://stackoverflow.com/questions/25961513/ios-8-today-widget-stops-working-after-a-while
        completionHandler(NCUpdateResult.NewData)
    }

    override func lazyInitLocationManager() -> TFCLocationManager? {
        if (currentStation == nil) {
            titleLabel.text = NSLocalizedString("Looking for nearest station ...", comment: "")
        }
        self.currentStationIndex = 0
        return super.lazyInitLocationManager()
    }

    override func locationFixed(coord: CLLocationCoordinate2D?) {
        NSLog("locationFixed")
        if (coord != nil) {

            if (getLastUsedView() == "nearbyStations") {
                showStations = true
            } else {
                showStations = false
            }
            if (locManager?.currentLocation != nil) {
                // if lastUsedView is a single station and we did look at it no longer than 30 minutes
                // and the distance is not much more (200m), just show it again
                if (currentStation == nil && getLastUsedView() == "singleStation" && lastUsedViewUpdatedInterval() > -(60 * 30)) {
                    let distance2lastViewedStationNow: CLLocationDistance? = locManager?.currentLocation?.distanceFromLocation(lastViewedStation?.coord)
                    let distance2lastViewedStationLasttime: CLLocationDistance? = TFCStations.getUserDefaults()?.objectForKey("lastUsedStationDistance") as CLLocationDistance?
                    if (distance2lastViewedStationNow != nil && distance2lastViewedStationLasttime != nil && distance2lastViewedStationNow! < distance2lastViewedStationLasttime! + 200) {
                        currentStation = lastViewedStation
                        if (currentStation != nil) {
                            showStations = false
                            displayDepartures()
                            currentStation?.updateDepartures(self, maxDepartures: 6, force: true)
                        }
                    }
                }

                let nearbyStationsAdded = self.stations?.addNearbyFavorites((locManager?.currentLocation)!)
                if (nearbyStationsAdded == true) {
                    if (currentStation == nil) {
                        currentStation = self.stations?.getStation(0)
                        if (!showStations) {
                            titleLabel.text = currentStation?.getNameWithStarAndFilters()
                            displayDepartures()
                        }
                    }
                }
            }
            self.api?.searchFor(coord!)
        }

    }

    @IBAction func nextButtonTouchUp(sender: AnyObject) {
        if (showStations == true) {
            showStations = false
            currentStation?.updateDepartures(self, maxDepartures: 6)
            self.appsTableView.reloadData()
            sendScreenNameToGA("todayviewStation")
        } else if (stations?.count() > 0) {
            showStations = true
            self.appsTableView.reloadData()
            sendScreenNameToGA("todayviewMore")
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
        let userDefaults = TFCStations.getUserDefaults()
        if (showStations) {
            userDefaults?.setObject("nearbyStations", forKey: "lastUsedView")
        } else {
            userDefaults?.setObject("singleStation", forKey: "lastUsedView")
            if (currentStation != nil) {
                currentStation?.isLastUsed = true
                lastViewedStation?.isLastUsed = false
                // FIXME, use NSCoding serialisation ..
                // and maybe one object for all these values
                userDefaults?.setObject(currentStation?.getAsDict(), forKey: "lastUsedStation")
                userDefaults?.setObject(locManager?.currentLocation?.distanceFromLocation(currentStation?.coord), forKey: "lastUsedStationDistance")
            }
        }
        userDefaults?.setObject(NSDate(), forKey: "lastUsedViewUpdate")
    }

    func getLastUsedView() -> String? {
        return TFCStations.getUserDefaults()?.objectForKey("lastUsedView") as String?
    }

    func lastUsedViewUpdatedInterval() -> NSTimeInterval? {
        let lastUpdate: NSDate? = TFCStations.getUserDefaults()?.objectForKey("lastUsedViewUpdate") as NSDate?
        return lastUpdate?.timeIntervalSinceNow
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
            destinationLabel.text = station?.getNameWithFilters(false)

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
                    if (self.showStations == false && self.currentStation == nil) {
                        self.currentStation = self.stations?.getStation(self.currentStationIndex)
                        self.titleLabel.text = self.currentStation?.getNameWithStarAndFilters()
                        if (hasAlreadyFavouritesDisplayed == nil || hasAlreadyFavouritesDisplayed == 0) {
                            self.displayDepartures()
                        }
                    }
                }
            self.appsTableView!.reloadData()
            }
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
