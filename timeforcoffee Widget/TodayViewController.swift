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

final class TodayViewController: TFCBaseViewController, NCWidgetProviding, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate,  TFCDeparturesUpdatedProtocol, TFCStationsUpdatedProtocol {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var appsTableView: UITableView!
    @IBOutlet weak var actionLabel: UIButton!
    let kCellIdentifier: String = "SearchResultCellWidget"

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var ContainerViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var ContainerViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var ContainerViewTrailingConstraint: NSLayoutConstraint!

    lazy var gtracker: GAITracker = {
        let gtrackerInstance = GAI.sharedInstance()
        gtrackerInstance.trackUncaughtExceptions = true
        gtrackerInstance.dispatchInterval = 10;
        //GAI.sharedInstance().logger.logLevel = GAILogLevel.Verbose
        gtrackerInstance.trackerWithTrackingId("UA-37092982-2")
        var gtrack = gtrackerInstance.defaultTracker
        return gtrack
    }()

    lazy var stations: TFCStations? =  {return TFCStations(delegate: self)}()

    weak var currentStation: TFCStation?

    var networkErrorMsg: String?
    lazy var numberOfCells:Int = {
        var number = 6

        // not implemented yet, settings screen is missing
        if let newNumber = TFCDataStore.sharedInstance.getUserDefaults()?.integerForKey("numberOfCellsToday")
        {
            if (newNumber > 0) {
                number = newNumber
            }
        }

        let height = max(UIScreen.mainScreen().bounds.height,
            UIScreen.mainScreen().bounds.width)
        if (height < 568) { //iPhone 4S
            let maxNumber = max(2, Int((height - 33.0) / 52.0) - 3)
            if (maxNumber < number) {
                number = maxNumber
            }
        }
        return number
    }()


    var viewDidAppear = false
    var dataIsFromInitCache = false
    var showStations: Bool = false {
        didSet {
            dispatch_async(dispatch_get_main_queue(), {
                if (self.showStations == true) {
                    self.setLastUsedView()
                    self.actionLabel.setTitle("Back", forState: UIControlState.Normal)

                    self.titleLabel.text = "Nearby Stations"
                } else {
                    if (self.currentStation != nil) {
                        self.setLastUsedView()
                    }
                    self.actionLabel.setTitle("Stations", forState: UIControlState.Normal)

                    if let stationName = self.currentStation?.getNameWithStarAndFilters() {
                        self.titleLabel.text = stationName
                        self.currentStation?.setStationActivity()
                    }
                }
                self.actionLabel.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
            })
        }
    }

    lazy var lastViewedStation: TFCStation? = {
        let stationDict = TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("lastUsedStation") as! [String: String]?
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


    required init?(coder aDecoder: NSCoder) {
        NSLog("init")
        super.init(coder: aDecoder)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            TFCDataStore.sharedInstance.registerForNotifications()
            TFCDataStore.sharedInstance.synchronize()
        }
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
        super.viewDidAppear(animated)
        // adjust containerView height, if it's too big
        if (self.containerView.frame.height > 0 && self.containerView.frame.height < ContainerViewHeightConstraint.constant) {
            self.numberOfCells = min(self.numberOfCells, max(2, Int((self.containerView.frame.height - 33.0) / 52.0)))
            setPreferredContentSize()
        }
        self.actionLabel.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Highlighted)
    }

    override func awakeFromNib() {


        let userDefaults = TFCDataStore.sharedInstance.getUserDefaults()

        if let preferredHeight = userDefaults?.objectForKey("lastPreferredContentHeight") as? CGFloat {
            self.preferredContentSize = CGSize(width: CGFloat(0.0), height: preferredHeight)
        }
        if (getLastUsedView() == "nearbyStations") {
            showStations = true
            populateStationsFromLastUsed()
            dataIsFromInitCache = true
        } else {
            self.currentStation = self.lastViewedStation
            if (self.currentStation != nil && self.currentStation?.getDepartures()?.count > 0) {
                showStations = false
                self.appsTableView?.reloadData()
                // if lastUsedView is a single station and we did look at it no longer than
                // 5 minutes ago, just show it again without even checking the location later
                if (self.lastUsedViewUpdatedInterval() > -300) {
                    self.dataIsFromInitCache = false
                    self.currentStation?.updateDepartures(self)
                } else {
                    dataIsFromInitCache = true
                }
            } else {
                self.currentStation = nil
                showStations = false
            }
        }

        NSLog("awakeFromNib")
    }
    private func setPreferredContentSize() {
        let height = CGFloat(33 + (self.numberOfCells * 52))
        self.ContainerViewHeightConstraint?.constant = height
        // don't jump around, if it's only a small amount
        if (abs(height - self.view.frame.height) > 10) {
            self.preferredContentSize = CGSize(width: CGFloat(0.0), height: height)
            self.view.setNeedsLayout()
            TFCDataStore.sharedInstance.getUserDefaults()?.setObject(height, forKey: "lastPreferredContentHeight")
        } else {
            TFCDataStore.sharedInstance.getUserDefaults()?.setObject(self.view.frame.height, forKey: "lastPreferredContentHeight")
        }

    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        //sometimes strange things happen with the calculated width
        // just fix it here, and it should stay...
        ContainerViewTrailingConstraint?.active = false
        ContainerViewWidthConstraint?.constant = self.containerView.frame.width
        self.view.setNeedsLayout()
/*        if (getLastUsedView() == "nearbyStations") {
            actionLabel.titleLabel?.text = "Back"
        } else {
            actionLabel.titleLabel?.text = "Stations"
        }*/
        actionLabel.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        setPreferredContentSize()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        actionLabel.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Normal)
    }

    override func viewDidDisappear(animated: Bool) {
        TFCURLSession.sharedInstance.cancelURLSession()

    }
    func widgetPerformUpdateWithCompletionHandler(completionHandler: ((NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        NSLog("widgetPerformUpdateWithCompletionHandler")
        completionHandler(NCUpdateResult.NewData)

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            if (self.getLastUsedView() == "nearbyStations") {
                self.sendScreenNameToGA("todayviewNearby")
                self.showStations = true
            } else {
                self.sendScreenNameToGA("todayviewStation")
                // if we're within the 5 minutes from last time (checked in awakeFromNiB)
                // don't do anything
                if (self.currentStation != nil && self.dataIsFromInitCache == false) {
                    return
                }
                self.showStations = false
                self.locManager?.refreshLocation()
            }
            self.stations?.updateStations()
        }
    }

    override func lazyInitLocationManager() -> TFCLocationManager? {
        if (currentStation == nil || self.dataIsFromInitCache == true) {
            dispatch_async(dispatch_get_main_queue(), {
                self.titleLabel.text = NSLocalizedString("Looking for nearest station ...", comment: "")
            })
        }
        return super.lazyInitLocationManager()
    }

    override func locationFixed(coord: CLLocation?) {
        NSLog("locationFixed")
        if (coord != nil) {
            if (locManager?.currentLocation != nil) {
                // if lastUsedView is a single station and we did look at it no longer than 30 minutes
                // and the distance is not much more (200m), just show it again
                if (self.dataIsFromInitCache && showStations == false) {
                    if (lastUsedViewUpdatedInterval() > -(60 * 30)) {
                        let distance2lastViewedStationNow: CLLocationDistance? = locManager?.currentLocation?.distanceFromLocation((lastViewedStation?.coord)!)
                        let distance2lastViewedStationLasttime: CLLocationDistance? = TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("lastUsedStationDistance") as! CLLocationDistance?
                        if (distance2lastViewedStationNow != nil && distance2lastViewedStationLasttime != nil && distance2lastViewedStationNow! < distance2lastViewedStationLasttime! + 200) {
                            dataIsFromInitCache = false
                            self.currentStation?.updateDepartures(self)
                        }
                    }
                }
            }
        }
    }

    override func locationDenied(manager: CLLocationManager, err:NSError) {
        if (err.code == CLError.LocationUnknown.rawValue) {
            self.networkErrorMsg = "Airplane mode?"
            self.appsTableView?.reloadData()
            return
        }
        dispatch_async(dispatch_get_main_queue(), {
            self.networkErrorMsg = "Location not available"
            self.stations?.empty()
            self.titleLabel.text = "Time for Coffee!"
            self.appsTableView?.reloadData()
        })
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
            populateStationsFromLastUsed()
            stations?.updateStations(false)
            self.appsTableView?.reloadData()
            sendScreenNameToGA("todayviewNearby")
        }
    }

    func handleTap(recognizer: UITapGestureRecognizer) {
        if (showStations) {
            let urlstring = "timeforcoffee://nearby"
            let url: NSURL = NSURL(string: urlstring)!
            self.extensionContext?.openURL(url, completionHandler: nil);
        } else if (currentStation != nil && currentStation?.st_id != "0000") {
            let station = currentStation!
            let name = station.name.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
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
        if (self.showStations) {
            userDefaults?.setObject("nearbyStations", forKey: "lastUsedView")
        } else {
            if (self.currentStation != nil) {
                userDefaults?.setObject("singleStation", forKey: "lastUsedView")
                self.currentStation?.isLastUsed = true
                self.lastViewedStation?.isLastUsed = false
                // FIXME, use NSCoding serialisation ..
                // and maybe one object for all these values
                userDefaults?.setObject(self.currentStation?.getAsDict(), forKey: "lastUsedStation")
                userDefaults?.setObject(self.locManager?.currentLocation?.distanceFromLocation((self.currentStation?.coord)!), forKey: "lastUsedStationDistance")
            } else {
                userDefaults?.removeObjectForKey("lastUsedView")
                userDefaults?.removeObjectForKey("lastUsedStation")
                userDefaults?.removeObjectForKey("lastUsedStationDistance")
                self.lastViewedStation?.isLastUsed = false
            }
        }
        userDefaults?.setObject(NSDate(), forKey: "lastUsedViewUpdate")
    }

    func getLastUsedView() -> String? {
        return TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("lastUsedView") as! String?
    }

    func lastUsedViewUpdatedInterval() -> NSTimeInterval? {
        let lastUpdate: NSDate? = TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("lastUsedViewUpdate") as! NSDate?
        return lastUpdate?.timeIntervalSinceNow
    }

    func displayDepartures() {
        //UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.networkErrorMsg = nil
        currentStation?.updateDepartures(self)
        dispatch_async(dispatch_get_main_queue(), {
            self.appsTableView?.reloadData()
            return
        })
        setLastUsedView()
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (showStations) {
            let count = stations?.count()
            if (count == nil || count == 0) {
                return 1
            }
            return min(self.numberOfCells, count!)
        }
        if (viewDidAppear == false && currentStation == nil) {
            return 0
        }
        let departures = self.currentStation?.getFilteredDepartures(self.numberOfCells)
        if (departures == nil || departures!.count == 0) {
            return 1
        }
        return min(self.numberOfCells, departures!.count)
    }
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        if (showStations) {
            cell = tableView.dequeueReusableCellWithIdentifier("NearbyStationsCell") as! NearbyStationsTableViewCell
        } else {
            cell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier) as UITableViewCell!
        }
        cell.layoutMargins = UIEdgeInsetsZero
        cell.preservesSuperviewLayoutMargins = false
        
        
        
        let lineNumberLabel = cell.viewWithTag(100) as! DepartureLineLabel
        let destinationLabel = cell.viewWithTag(200) as! UILabel
        let departureLabel = cell.viewWithTag(300) as! UILabel
        let minutesLabel = cell.viewWithTag(400) as! UILabel

        if (showStations) {
            let stationsCount = self.stations?.count()
            if (stationsCount == nil || stationsCount == 0) {
                titleLabel.text = "Time for Coffee!"
                if (stationsCount == nil) {
                    destinationLabel.text = NSLocalizedString("Loading", comment: "Loading ..")
                    departureLabel.text = stations?.loadingMessage
                } else {
                    destinationLabel.text = NSLocalizedString("No stations found.", comment: "")
                    departureLabel.text = stations?.networkErrorMsg
                }
                lineNumberLabel.hidden = true
                minutesLabel.text = nil

                return cell
            }

            let station = self.stations?.getStation(indexPath.row)
            station?.updateDepartures(self)
            let cellinstance = cell as! NearbyStationsTableViewCell
            cellinstance.station = station
            cellinstance.drawCell()
            return cell
        }
        let station = currentStation
        let departures = currentStation?.getFilteredDepartures(self.numberOfCells)
        if (departures == nil || departures!.count == 0) {
            lineNumberLabel.hidden = true
            departureLabel.text = nil
            minutesLabel.text = nil
            if ((station != nil && departures == nil) || stations?.isLoading == true) {
                destinationLabel.text = NSLocalizedString("Loading", comment: "Loading ..")
                departureLabel.text = stations?.loadingMessage
            } else {
                if (station == nil ) {
                    titleLabel.text = "Time for Coffee!"
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
        if (UIDeviceOrientationIsLandscape(UIDevice.currentDevice().orientation)) {
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
        lineNumberLabel.hidden = false
        lineNumberLabel.setStyle("dark", departure: departure)
        
        return cell
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if (showStations) {
            currentStation = self.stations?.getStation(indexPath.row)
            showStations = false
            if (currentStation?.st_id != "0000") {
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
            if (self.showStations == false && (self.currentStation == nil ||                             self.dataIsFromInitCache == false)) {
                self.currentStation = self.stations?.getStation(0)
                if (self.currentStation != nil) {
                    if let title = self.currentStation?.getNameWithStarAndFilters() {
                        self.titleLabel.text = title
                    }
                    self.displayDepartures()
                }
            }
            if (self.showStations) {
                var lastUsedStationsNormal:[String] = []
                var lastUsedStationsFavorites:[String] = []
                if let stations = self.stations {
                    let userDefaults = TFCDataStore.sharedInstance.getUserDefaults()
                    for (station) in stations {
                        if (station.isFavorite()) {
                            lastUsedStationsFavorites.append(station.st_id)
                        } else {
                            lastUsedStationsNormal.append(station.st_id)
                        }
                    }
                    userDefaults?.setObject(lastUsedStationsNormal, forKey: "lastUsedStationsNormal")
                    userDefaults?.setObject(lastUsedStationsFavorites, forKey: "lastUsedStationsFavorites")
                }
            }
            self.dataIsFromInitCache = false
            self.appsTableView.reloadData()
        })
    }

    private func sendScreenNameToGA(screenname: String) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            self.gtracker.set(kGAIScreenName, value: screenname)
            self.gtracker.send(GAIDictionaryBuilder.createScreenView().build() as [NSObject : AnyObject]!)
        }
    }

    private func populateStationsFromLastUsed() {
        if (!(self.stations?.count() > 0)) {
            let stationDict = TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("lastUsedStationsNormal") as? [String]?
            let stationDictFavs = TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("lastUsedStationsFavorites") as? [String]?
            if (stationDict != nil && stationDictFavs != nil) {
                self.stations?.populateWithIds(stationDictFavs!, nonfavorites:stationDict!)
                self.appsTableView?.reloadData()
            }
        }
    }
}
