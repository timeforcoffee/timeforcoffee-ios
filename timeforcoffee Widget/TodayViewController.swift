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
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var ContainerViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var ContainerViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var ContainerViewTrailingConstraint: NSLayoutConstraint!

    // some older devices (my 4S for example) don't always properly deinit
    // sp we keep track of the last init and if it's more than 30 seconds, reload the tableview
    private var lastInitTime:NSDate? = nil

    lazy var stations: TFCStations? =  {
        [unowned self] in
        return TFCStations(delegate: self, maxStations: 6)
    }()

    weak var currentStation: TFCStation?

    private var currentTitle:String = ""
    private var loadingStage:Int = 0

    private lazy var modelName: String = {
        return UIDevice.currentDevice().modelName
    }()

    private lazy var datastore:TFCDataStore = {
        DLog("init datastore", toFile: true)
        return TFCDataStore.sharedInstance
    }()


//    private lazy var dispatchTime = { return dispatch_time(DISPATCH_TIME_NOW, Int64(6.0 * Double(NSEC_PER_SEC))) }()

    var networkErrorMsg: String?
    lazy var numberOfCells:Int = {
        var number = 6

        // not implemented yet, settings screen is missing
        if let newNumber = self.datastore.getUserDefaults()?.integerForKey("numberOfCellsToday")
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

    private var completionHandlerCallback:((NCUpdateResult) -> Void)? = nil

    var viewDidAppear = false
    var needsLocationUpdate = true
    var showStations: Bool = false {
        didSet {
            dispatch_async(dispatch_get_main_queue(), {
                if (self.showStations == true) {
                    self.setLastUsedView()
                    self.actionLabel.setTitle(NSLocalizedString("Back", comment: ""), forState: UIControlState.Normal)
                    self.setTitleText(NSLocalizedString("Nearby Stations", comment: ""))

                } else {
                    if (self.currentStation != nil) {
                        self.setLastUsedView()
                    }
                    self.actionLabel.setTitle(NSLocalizedString("Stations", comment: ""), forState: UIControlState.Normal)

                    if let stationName = self.currentStation?.getNameWithStarAndFilters() {
                        self.setTitleText(stationName)
                        self.currentStation?.setStationActivity()
                    }
                }
                if #available(iOSApplicationExtension 10.0, *) {
                    self.actionLabel.setTitleColor(UIColor.blackColor(), forState: UIControlState.Normal)
                } else {
                    self.actionLabel.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
                }
            })
        }
    }

    lazy var lastViewedStation: TFCStation? = {
        let stationDict = self.datastore.getUserDefaults()?.objectForKey("lastUsedStation") as! [String: String]?
        if (stationDict == nil) {
            return nil
        }
        var station = TFCStation.initWithCache(stationDict!)
        station?.isLastUsed = true
        return station
    }()
   
    override func viewDidLoad() {
        super.viewDidLoad()
        DLog("viewDidLoad", toFile: true)
        titleLabel.userInteractionEnabled = true;
        if #available(iOSApplicationExtension 10.0, *) {
        } else {
            titleLabel.textColor = UIColor(white: 100, alpha: 1)
        }

        let tapGesture  = UITapGestureRecognizer(target: self, action: #selector(TodayViewController.handleTap(_:)))
        titleLabel.addGestureRecognizer(tapGesture)
        if #available(iOSApplicationExtension 10.0, *) {
            self.extensionContext?.widgetLargestAvailableDisplayMode = .Expanded
        } else {
            // Fallback on earlier versions
        }
        // Do any additional setup after loading the view from its nib.
    }

    @available(iOSApplicationExtension 10.0, *)
    func widgetActiveDisplayModeDidChange(activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        //self.preferredContentSize = maxSize

        let numberOfCells = min(self.numberOfCells, max(1, Int((maxSize.height - 33.0) / 52.0)))
        var preferredContentSize = maxSize
        preferredContentSize.height = CGFloat(33 + (numberOfCells * 52))
        if (self.preferredContentSize.height != preferredContentSize.height) {
            self.preferredContentSize = preferredContentSize
            dispatch_async(dispatch_get_main_queue(), {
                self.appsTableView.reloadData()
            })
        }
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        DLog("init", toFile: true)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        DLog("init", toFile: true)
        self.lastInitTime = NSDate()
        super.init(coder: aDecoder)
        self.setLoadingStage(2)
        self.lastViewedStation?.removeObsoleteDepartures()
        self.currentStation = self.lastViewedStation
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            TFCCrashlytics.sharedInstance.initCrashlytics()
            self.datastore.registerForNotifications()
            self.datastore.synchronize()
            let gtracker = GATracker.sharedInstance
            gtracker?.setCustomDimension(6, value: "yes")
            gtracker?.setCustomDimension(9, value: UIDevice.currentDevice().systemVersion)
        }
    }

    deinit {
        DLog("deinit widget", toFile: true)
        TFCURLSession.sharedInstance.cancelURLSession()
        self.datastore.removeNotifications()
    }

    override func viewDidAppear(animated: Bool) {
        //actionLabel.hidden = false
        DLog("viewDidAppear", toFile: true)
        viewDidAppear = true
        super.viewDidAppear(animated)
        // adjust containerView height, if it's too big
        if #available(iOSApplicationExtension 10.0, *) {
        } else {
            if (self.containerView.frame.height > 0 && self.containerView.frame.height < ContainerViewHeightConstraint.constant) {
                self.numberOfCells = min(self.numberOfCells, max(2, Int((self.containerView.frame.height - 33.0) / 52.0)))
                setPreferredContentSize()
            }
        }

        if #available(iOSApplicationExtension 10.0, *) {
            self.actionLabel.setTitleColor(UIColor.darkGrayColor(), forState: UIControlState.Highlighted)
        } else {
            self.actionLabel.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Highlighted)
        }

    }

    override func awakeFromNib() {
        DLog("awakeFromNib", toFile: true)

        let userDefaults = self.datastore.getUserDefaults()

        TFCFavorites.sharedInstance.doGeofences = false

        if let preferredHeight = userDefaults?.objectForKey("lastPreferredContentHeight") as? CGFloat {
            self.preferredContentSize = CGSize(width: CGFloat(0.0), height: preferredHeight)
        }
        if (getLastUsedView() == "nearbyStations") {
            showStations = true
            populateStationsFromLastUsed()
        } else {
            self.currentStation = self.lastViewedStation
            if (self.currentStation != nil && self.currentStation?.getDepartures()?.count > 0) {
                showStations = false
                self.appsTableView?.reloadData()
                // if lastUsedView is a single station and we did look at it no longer than
                // 5 minutes ago, just show it again without even checking the location later
                if (self.lastUsedViewUpdatedInterval() > -60) { //FIXME: Put back to 300
                    self.setLoadingStage(1)
                    self.needsLocationUpdate = false
                    self.currentStation?.updateDepartures(self)
                } else {
                    self.needsLocationUpdate = true
                }
            } else {
                self.currentStation = nil
                showStations = false
            }
        }

        DLog("awakeFromNib")
    }
    
    private func setPreferredContentSize() {
        if #available(iOSApplicationExtension 10.0, *) {
        } else {
        let height = CGFloat(33 + (self.numberOfCells * 52))
        self.ContainerViewHeightConstraint?.constant = height
        // don't jump around, if it's only a small amount
        if (abs(height - self.view.frame.height) > 10) {
            self.preferredContentSize = CGSize(width: CGFloat(0.0), height: height)
            self.view.setNeedsLayout()
            self.datastore.getUserDefaults()?.setObject(height, forKey: "lastPreferredContentHeight")
        } else {
            self.datastore.getUserDefaults()?.setObject(self.view.frame.height, forKey: "lastPreferredContentHeight")
        }
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        DLog("viewWillAppear \(self.lastInitTime?.timeIntervalSinceNow)", toFile: true)
        // some old devices (my 4S) don't deinit/init properly, that's a way to not show outdated info
        if (self.lastInitTime?.timeIntervalSinceNow < -10 && (
            floor(self.lastInitTime!.timeIntervalSinceReferenceDate / 60) !=  floor(NSDate.timeIntervalSinceReferenceDate() / 60))) {
            self.lastInitTime = NSDate()
            awakeFromNib()
        }

        self.datastore.synchronize()
        //sometimes strange things happen with the calculated width
        // just fix it here, and it should stay...
        ContainerViewTrailingConstraint?.active = false
        ContainerViewWidthConstraint?.constant = self.containerView.frame.width
        self.view.setNeedsLayout()
        if #available(iOSApplicationExtension 10.0, *) {
            actionLabel.setTitleColor(UIColor.blackColor(), forState: UIControlState.Normal)
        } else {
            actionLabel.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        }
        setPreferredContentSize()
    }

    override func viewWillDisappear(animated: Bool) {
        DLog("viewWillDisappear", toFile: true)
        super.viewWillDisappear(animated)
        if #available(iOSApplicationExtension 10.0, *) {
            self.actionLabel.setTitleColor(UIColor.darkGrayColor(), forState: UIControlState.Highlighted)
        } else {
            self.actionLabel.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Highlighted)
        }
        TFCDataStore.sharedInstance.saveContext()
    }

    override func viewDidDisappear(animated: Bool) {
        DLog("viewDidDisappear, memsize: \(TFCCache.getMemorySize())", toFile: true)
        TFCURLSession.sharedInstance.cancelURLSession()
    }
    func widgetPerformUpdateWithCompletionHandler(completionHandler: ((NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        DLog("widgetPerformUpdateWithCompletionHandler")
        self.completionHandlerCallback = completionHandler
        updateViewAfterStart()
    }

    func updateViewAfterStart(notification:NSNotification? = nil) {
        if let notification = notification {
            DLog("was notified", toFile: true)
            NSNotificationCenter.defaultCenter().removeObserver(self, name: notification.name, object: nil)
        }
        DLog("sendCompletionHandler", toFile: true)

        self.sendCompletionHandler()

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            DLog("updateViewAfterStart", toFile: true)
            if (self.getLastUsedView() == "nearbyStations") {
                self.sendScreenNameToGA("todayviewNearby")
                self.showStations = true
                DLog("show nearbystations", toFile: true)
            } else {
                self.sendScreenNameToGA("todayviewStation")
                // if we're within the 5 minutes from last time (checked in awakeFromNiB)
                // don't do anything
                if (self.currentStation != nil && self.needsLocationUpdate == false) {
                    DLog("5 minutes rule", toFile: true)
                    /* DLog("sendCompletionHandler", toFile: true)
                     self.sendCompletionHandler()*/
                    return
                }
                DLog("show new nearest station", toFile: true)

                self.showStations = false
                DLog("Refresh Location", toFile: true)
                self.setLoadingStage(2)
                self.locManager?.refreshLocation()
            }
            self.stations?.updateStations()
        }
    }

    private func sendCompletionHandler() {
        DLog("locationFixed")
        if let completionHandler = self.completionHandlerCallback {
            DLog("do completionHandler", toFile: true)
            completionHandler(NCUpdateResult.NewData)
            self.completionHandlerCallback = nil
        }
    }

    override func lazyInitLocationManager() -> TFCLocationManager? {
        if (currentStation == nil || self.needsLocationUpdate == true) {
            dispatch_async(dispatch_get_main_queue(), {

                self.setLoadingStage(2)
                if (self.currentTitle == "") {
                    self.setTitleText(NSLocalizedString("Looking for nearest station ...", comment: ""))
                }
            })
        }
        return super.lazyInitLocationManager()
    }

    override func locationFixed(coord: CLLocation?) {
        self.setLoadingStage(1)

        DLog("locationFixed \(coord)", toFile: true)
        if (coord != nil) {
            if (locManager?.currentLocation != nil) {
                // if lastUsedView is a single station and we did look at it no longer than 30 minutes
                // and the distance is not much more (200m), just show it again
                if (self.needsLocationUpdate && showStations == false) {
                    if (lastUsedViewUpdatedInterval() > -(60 * 30)) {
                        DLog("__", toFile: true)
                        if (lastViewedStation != nil) {
                            let distance2lastViewedStationNow: CLLocationDistance? = locManager?.currentLocation?.distanceFromLocation((lastViewedStation?.coord)!)
                            let distance2lastViewedStationLasttime: CLLocationDistance? = self.datastore.getUserDefaults()?.objectForKey("lastUsedStationDistance") as! CLLocationDistance?
                            if (distance2lastViewedStationNow != nil && distance2lastViewedStationLasttime != nil && distance2lastViewedStationNow! < distance2lastViewedStationLasttime! + 200) {
                                DLog("not moved more than 200m", toFile: true)
                                DLog("__", toFile: true)
                                needsLocationUpdate = false
                                self.setLoadingStage(1)
                                self.currentStation?.updateDepartures(self)
                            }
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
            self.setTitleText("Time for Coffee! Error")
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
            self.setLoadingStage(1)
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
        let userDefaults = self.datastore.getUserDefaults()
        if (self.showStations) {
            userDefaults?.setObject("nearbyStations", forKey: "lastUsedView")
        } else {
            if (self.currentStation != nil) {
                userDefaults?.setObject("singleStation", forKey: "lastUsedView")
                self.lastViewedStation?.isLastUsed = false
                self.currentStation?.isLastUsed = true
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
        return self.datastore.getUserDefaults()?.objectForKey("lastUsedView") as! String?
    }

    func lastUsedViewUpdatedInterval() -> NSTimeInterval? {
        let lastUpdate: NSDate? = self.datastore.getUserDefaults()?.objectForKey("lastUsedViewUpdate") as! NSDate?
        return lastUpdate?.timeIntervalSinceNow
    }

    func displayDepartures() {
        //UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.networkErrorMsg = nil
        self.setLoadingStage(1)
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
            return min(self.getNumberOfCellsForPreferredContentSize(), count!)
        }
        if (viewDidAppear == false && currentStation == nil) {
            return 0
        }
        let departures = self.currentStation?.getFilteredDepartures(6)
        if (departures == nil || departures!.count == 0) {
            return 1
        }
        let numberOfCells = min(self.getNumberOfCellsForPreferredContentSize(), departures!.count)
        return numberOfCells
    }
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        if (showStations) {
            cell = tableView.dequeueReusableCellWithIdentifier("NearbyStationsCell", forIndexPath: indexPath)
        } else {
            cell = tableView.dequeueReusableCellWithIdentifier("SearchResultCellWidget", forIndexPath: indexPath)
        }
        cell.layoutMargins = UIEdgeInsetsZero
        cell.preservesSuperviewLayoutMargins = false
        
        
        
        let lineNumberLabel = cell.viewWithTag(100) as! DepartureLineLabel
        let destinationLabel = cell.viewWithTag(200) as! UILabel
        let departureLabel = cell.viewWithTag(300) as! UILabel
        let minutesLabel = cell.viewWithTag(400) as! UILabel
        if #available(iOSApplicationExtension 10.0, *) {
        } else {
            destinationLabel.textColor = UIColor(white: 100, alpha: 1)
            departureLabel.textColor = UIColor(white: 100, alpha: 0.6)
            minutesLabel.textColor = UIColor(white: 100, alpha: 1)
        }
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
            let showDepartures:Bool
            if (self.modelName == "iPhone 4s") {
                showDepartures = false
            } else {
                showDepartures = true
                self.setLoadingStage(1)
            }
            let station = self.stations?.getStation(indexPath.row)
            if (showDepartures) {
                station?.updateDepartures(self, context: ["indexPath": indexPath], onlyFirstDownload: true)
            }

            if let cellinstance = cell as? NearbyStationsTableViewCell {
                cellinstance.stationId = station?.st_id
                cellinstance.drawCell(showDepartures)
            }
            return cell
        }
        let station = currentStation
        let departures = currentStation?.getFilteredDepartures(6)
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
        cell.textLabel?.text = nil
        if let departures = departures {
            if (indexPath.row < departures.count) {
                if let departure: TFCDeparture = departures[indexPath.row] {
                    //if on first row and it's in the past, remove obsolete departures and reload
                    if (indexPath.row == 0 && departure.getMinutesAsInt() < 0) {
                        dispatch_async(dispatch_get_main_queue()) {
                            station?.removeObsoleteDepartures(true)
                            self.appsTableView?.reloadData()
                        }
                    }
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
                }
            }
        }
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
        DLog("didReceiveMemoryWarning memory warning", toFile: true)
        //TFCCache.clearMemoryCache()
        self.stations?.removeDeparturesFromMemory()
        TFCFavorites.sharedInstance.clearStationCache()
        GATracker.sharedInstance?.deinitTracker()
        TFCDataStore.sharedInstance.saveContext()
        super.didReceiveMemoryWarning()
    }
    
    func departuresUpdated(error: NSError?, context: Any?, forStation: TFCStation?) {
        DLog("departuresUpdated", toFile: true)
        dispatch_async(dispatch_get_main_queue()) {
        self.setLoadingStage(0)
        if (self.showStations) {
            if let context2 = context as? [String: NSIndexPath],
                   indexPath = context2["indexPath"],
                   cellinstance = self.appsTableView?.cellForRowAtIndexPath(indexPath) as? NearbyStationsTableViewCell {
                //self.appsTableView?.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
                if (cellinstance.stationId != nil) {
                    if (cellinstance.stationId == forStation?.st_id) {
                        cellinstance.drawCell()
                    } else {
                        cellinstance.getStation()
                        cellinstance.station?.updateDepartures(self, onlyFirstDownload: true)
                    }
                }
            } else {
                self.appsTableView?.reloadData()
            }
        } else {
            if (forStation?.st_id == self.currentStation?.st_id) {
                if (error != nil) {
                    self.networkErrorMsg = NSLocalizedString("Network error. Please try again", comment:"")
                } else {
                    self.networkErrorMsg = nil
                }
                self.appsTableView?.reloadData()
            }
        }
        }
    }

    func departuresStillCached(context: Any?, forStation: TFCStation?) {
        // do nothing
        self.departuresUpdated(nil, context: context, forStation: forStation)
    }

    func stationsUpdated(error: String?, favoritesOnly: Bool, context: Any?) {
        dispatch_async(dispatch_get_main_queue(), {
            // if we show a single station, but it's not determined which one
            //   try to get one from the stations array
            if (self.showStations == false && (self.currentStation == nil ||                             self.needsLocationUpdate == true)) {
                self.currentStation = self.stations?.getStation(0)
                if (self.currentStation != nil) {
                    if let title = self.currentStation?.getNameWithStarAndFilters() {
                        self.setTitleText(title)
                        self.currentStation?.setStationActivity()
                    }
                    self.displayDepartures()
                }
            }
            if (self.showStations) {
                if let stations = self.stations {
                    let userDefaults = self.datastore.getUserDefaults()
                    userDefaults?.setObject(stations.getNearbyNonFavoriteIds(), forKey: "lastUsedStationsNormal")
                    userDefaults?.setObject(stations.getNearbyFavoriteIds(), forKey: "lastUsedStationsFavorites")
                }
            }
            self.needsLocationUpdate = false
            self.appsTableView.reloadData()
        })
    }

    private func sendScreenNameToGA(screenname: String) {
        GATracker.sharedInstance?.sendScreenName(screenname)
    }

    private func populateStationsFromLastUsed() {
        if (!(self.stations?.count() > 0)) {
            let stationDict = self.datastore.getUserDefaults()?.objectForKey("lastUsedStationsNormal") as? [String]?
            let stationDictFavs = self.datastore.getUserDefaults()?.objectForKey("lastUsedStationsFavorites") as? [String]?
            if (stationDict != nil && stationDictFavs != nil) {
                self.stations?.populateWithIds(stationDictFavs!, nonfavorites:stationDict!)
                self.appsTableView?.reloadData()
            }
        }
    }

    private func getNumberOfCellsForPreferredContentSize() -> Int {
        let numberOfCells = min(self.numberOfCells, max(1, Int((self.preferredContentSize.height - 33.0) / 52.0)))
        return numberOfCells
    }

    private func setTitleText(text: String? = nil) {
        let newText:String
        if (text == nil) {
            newText = self.currentTitle
        } else {
            newText = text!
            self.currentTitle = newText
        }
        if let textLabel = self.titleLabel {
            var loadingIndicator = ""
            if (loadingStage == 1) {
                loadingIndicator = " ."
            } else if (loadingStage == 2) {
                loadingIndicator = " .."
            } else if (loadingStage == 3) {
                loadingIndicator = " ..."
            }

            dispatch_async(dispatch_get_main_queue()) {
                textLabel.text = "\(newText)\(loadingIndicator)"
            }
        }
    }

    private func setLoadingStage(stage:Int) {
        if (loadingStage != stage) {
            DLog("loadingStage \(stage)", toFile: true)
            self.loadingStage = stage
        }
        self.setTitleText()
    }
}

import UIKit

public extension UIDevice {

    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8 where value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        switch identifier {
        case "iPod5,1":                                 return "iPod Touch 5"
        case "iPod7,1":                                 return "iPod Touch 6"
        case "iPhone3,1", "iPhone3,2", "iPhone3,3":     return "iPhone 4"
        case "iPhone4,1":                               return "iPhone 4s"
        case "iPhone5,1", "iPhone5,2":                  return "iPhone 5"
        case "iPhone5,3", "iPhone5,4":                  return "iPhone 5c"
        case "iPhone6,1", "iPhone6,2":                  return "iPhone 5s"
        case "iPhone7,2":                               return "iPhone 6"
        case "iPhone7,1":                               return "iPhone 6 Plus"
        case "iPhone8,1":                               return "iPhone 6s"
        case "iPhone8,2":                               return "iPhone 6s Plus"
        case "iPhone9,1", "iPhone9,3":                  return "iPhone 7"
        case "iPhone9,2", "iPhone9,4":                  return "iPhone 7 Plus"
        case "iPhone8,4":                               return "iPhone SE"
        case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":return "iPad 2"
        case "iPad3,1", "iPad3,2", "iPad3,3":           return "iPad 3"
        case "iPad3,4", "iPad3,5", "iPad3,6":           return "iPad 4"
        case "iPad4,1", "iPad4,2", "iPad4,3":           return "iPad Air"
        case "iPad5,3", "iPad5,4":                      return "iPad Air 2"
        case "iPad2,5", "iPad2,6", "iPad2,7":           return "iPad Mini"
        case "iPad4,4", "iPad4,5", "iPad4,6":           return "iPad Mini 2"
        case "iPad4,7", "iPad4,8", "iPad4,9":           return "iPad Mini 3"
        case "iPad5,1", "iPad5,2":                      return "iPad Mini 4"
        case "iPad6,3", "iPad6,4", "iPad6,7", "iPad6,8":return "iPad Pro"
        case "AppleTV5,3":                              return "Apple TV"
        case "i386", "x86_64":                          return "Simulator"
        default:                                        return identifier
        }
    }
    
}
