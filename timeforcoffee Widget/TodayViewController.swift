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
    fileprivate var lastInitTime:Date? = nil

    lazy var stations: TFCStations? =  {
        [unowned self] in
        return TFCStations(delegate: self, maxStations: 6)
    }()

    weak var currentStation: TFCStation?

    fileprivate var currentTitle:String = ""
    fileprivate var loadingStage:Int = 0

    fileprivate lazy var modelName: String = {
        return UIDevice.current.modelName
    }()

    fileprivate lazy var datastore:TFCDataStore = {
        DLog("init datastore", toFile: true)
        return TFCDataStore.sharedInstance
    }()


//    private lazy var dispatchTime = { return dispatch_time(DISPATCH_TIME_NOW, Int64(6.0 * Double(NSEC_PER_SEC))) }()

    var networkErrorMsg: String?
    lazy var numberOfCells:Int = {
        var number = 6

        // not implemented yet, settings screen is missing
        if let newNumber = self.datastore.getUserDefaults()?.integer(forKey: "numberOfCellsToday")
        {
            if (newNumber > 0) {
                number = newNumber
            }
        }

        let height = max(UIScreen.main.bounds.height,
            UIScreen.main.bounds.width)
        if (height < 568) { //iPhone 4S
            let maxNumber = max(2, Int((height - 33.0) / 52.0) - 3)
            if (maxNumber < number) {
                number = maxNumber
            }
        }
        return number
    }()

    fileprivate var completionHandlerCallback:((NCUpdateResult) -> Void)? = nil

    var viewDidAppear = false
    var needsLocationUpdate = true
    var showStations: Bool = false {
        didSet {
            DispatchQueue.main.async(execute: {
                if (self.showStations == true) {
                    self.setLastUsedView()
                    self.actionLabel.setTitle(NSLocalizedString("Back", comment: ""), for: UIControl.State())
                    self.setTitleText(NSLocalizedString("Nearby Stations", comment: ""))

                } else {
                    if (self.currentStation != nil) {
                        self.setLastUsedView()
                    }
                    self.actionLabel.setTitle(NSLocalizedString("Stations", comment: ""), for: UIControl.State())

                    if let stationName = self.currentStation?.getNameWithStarAndFilters() {
                        self.setTitleText(stationName)
                        self.currentStation?.setStationActivity()
                    }
                }
                if #available(iOSApplicationExtension 10.0, *) {
                    self.actionLabel.setTitleColor(UIColor.black, for: UIControl.State())
                } else {
                    self.actionLabel.setTitleColor(UIColor.white, for: UIControl.State())
                }
            })
        }
    }

    lazy var lastViewedStation: TFCStation? = {
        let stationDict = self.datastore.getUserDefaults()?.object(forKey: "lastUsedStation") as! [String: String]?
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
        titleLabel.isUserInteractionEnabled = true;
        if #available(iOSApplicationExtension 10.0, *) {
        } else {
            titleLabel.textColor = UIColor(white: 100, alpha: 1)
        }

        let tapGesture  = UITapGestureRecognizer(target: self, action: #selector(TodayViewController.handleTap(_:)))
        titleLabel.addGestureRecognizer(tapGesture)
        if #available(iOSApplicationExtension 10.0, *) {
            self.extensionContext?.widgetLargestAvailableDisplayMode = .expanded
        } else {
            // Fallback on earlier versions
        }
        // Do any additional setup after loading the view from its nib.
    }

    @available(iOSApplicationExtension 10.0, *)
    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        //self.preferredContentSize = maxSize

        let numberOfCells = min(self.numberOfCells, max(1, Int((maxSize.height - 33.0) / 52.0)))
        var preferredContentSize = maxSize
        preferredContentSize.height = CGFloat(33 + (numberOfCells * 52))
        if (self.preferredContentSize.height != preferredContentSize.height) {
            self.preferredContentSize = preferredContentSize
            DispatchQueue.main.async(execute: {
                self.appsTableView.reloadData()
            })
        }
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        DLog("init", toFile: true)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        DLog("init", toFile: true)
        self.lastInitTime = Date()
        super.init(coder: aDecoder)
        self.setLoadingStage(2)
        let _ = self.lastViewedStation?.removeObsoleteDepartures()
        self.currentStation = self.lastViewedStation
        DispatchQueue.global(qos: .utility).async {
            TFCCrashlytics.sharedInstance.initCrashlytics()
            self.datastore.registerForNotifications()
            self.datastore.synchronize()
            let _ = GATracker.sharedInstance
        }
    }

    deinit {
        DLog("deinit widget", toFile: true)
        //TFCURLSession.sharedInstance.cancelURLSession()
        self.datastore.removeNotifications()
    }

    override func viewDidAppear(_ animated: Bool) {
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
            self.actionLabel.setTitleColor(UIColor.darkGray, for: UIControl.State.highlighted)
        } else {
            self.actionLabel.setTitleColor(UIColor.lightGray, for: UIControl.State.highlighted)
        }

    }

    override func awakeFromNib() {
        DLog("awakeFromNib", toFile: true)

        let userDefaults = self.datastore.getUserDefaults()

        TFCFavorites.sharedInstance.doGeofences = false

        if let preferredHeight = userDefaults?.object(forKey: "lastPreferredContentHeight") as? CGFloat {
            self.preferredContentSize = CGSize(width: CGFloat(0.0), height: preferredHeight)
        }
        if (getLastUsedView() == "nearbyStations") {
            showStations = true
            populateStationsFromLastUsed()
        } else {
            self.currentStation = self.lastViewedStation
            if let c = self.currentStation?.getDepartures()?.count, c > 0 {
                showStations = false
                self.appsTableView?.reloadData()
                // if lastUsedView is a single station and we did look at it no longer than
                // 5 minutes ago, just show it again without even checking the location later
                if let i = self.lastUsedViewUpdatedInterval(), i > -300 {
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
    
    fileprivate func setPreferredContentSize() {
        if #available(iOSApplicationExtension 10.0, *) {
        } else {
        let height = CGFloat(33 + (self.numberOfCells * 52))
        self.ContainerViewHeightConstraint?.constant = height
        // don't jump around, if it's only a small amount
        if (abs(height - self.view.frame.height) > 10) {
            self.preferredContentSize = CGSize(width: CGFloat(0.0), height: height)
            self.view.setNeedsLayout()
            self.datastore.getUserDefaults()?.set(height, forKey: "lastPreferredContentHeight")
        } else {
            self.datastore.getUserDefaults()?.set(self.view.frame.height, forKey: "lastPreferredContentHeight")
        }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DLog("viewWillAppear \(String(describing: self.lastInitTime?.timeIntervalSinceNow))", toFile: true)
        // some old devices (my 4S) don't deinit/init properly, that's a way to not show outdated info
        if let i = self.lastInitTime?.timeIntervalSinceNow, i < -10 {
            if (floor(self.lastInitTime!.timeIntervalSinceReferenceDate / 60) !=  floor(Date.timeIntervalSinceReferenceDate / 60)) {
                self.lastInitTime = Date()
                awakeFromNib()
            }
        }

        self.datastore.synchronize()
        //sometimes strange things happen with the calculated width
        // just fix it here, and it should stay...
        ContainerViewTrailingConstraint?.isActive = false
        ContainerViewWidthConstraint?.constant = self.containerView.frame.width
        self.view.setNeedsLayout()
        if #available(iOSApplicationExtension 10.0, *) {
            actionLabel.setTitleColor(UIColor.black, for: UIControl.State())
        } else {
            actionLabel.setTitleColor(UIColor.white, for: UIControl.State())
        }
        setPreferredContentSize()
    }

    override func viewWillDisappear(_ animated: Bool) {
        DLog("viewWillDisappear", toFile: true)
        super.viewWillDisappear(animated)
        if #available(iOSApplicationExtension 10.0, *) {
            self.actionLabel.setTitleColor(UIColor.darkGray, for: UIControl.State.highlighted)
        } else {
            self.actionLabel.setTitleColor(UIColor.lightGray, for: UIControl.State.highlighted)
        }
        TFCDataStore.sharedInstance.saveContext()
    }

    override func viewDidDisappear(_ animated: Bool) {
        DLog("viewDidDisappear, memsize: \(String(describing: TFCCache.getMemorySize()))", toFile: true)

        DispatchQueue.global(qos: .utility).async {
            GATracker.sharedInstance?.setCustomDimension(6, value: "yes")
            GATracker.sharedInstance?.setCustomDimension(9, value: UIDevice.current.systemVersion)
        }

      //  TFCURLSession.sharedInstance.cancelURLSession()
    }
    func widgetPerformUpdate(completionHandler: @escaping ((NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        DLog("widgetPerformUpdateWithCompletionHandler")
        self.completionHandlerCallback = completionHandler
        updateViewAfterStart()
    }

    func updateViewAfterStart(_ notification:Notification? = nil) {
        if let notification = notification {
            DLog("was notified", toFile: true)
            NotificationCenter.default.removeObserver(self, name: notification.name, object: nil)
        }
        DLog("sendCompletionHandler", toFile: true)

        self.sendCompletionHandler()

        DispatchQueue.global(qos: .default).async {
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
            let _ = self.stations?.updateStations()
        }
    }

    fileprivate func sendCompletionHandler() {
        DLog("locationFixed")
        if let completionHandler = self.completionHandlerCallback {
            DLog("do completionHandler", toFile: true)
            completionHandler(NCUpdateResult.newData)
            self.completionHandlerCallback = nil
        }
    }

    override func lazyInitLocationManager() -> TFCLocationManager? {
        if (currentStation == nil || self.needsLocationUpdate == true) {
            DispatchQueue.main.async(execute: {

                self.setLoadingStage(2)
                if (self.currentTitle == "") {
                    self.setTitleText(NSLocalizedString("Looking for closest station ...", comment: ""))
                }
            })
        }
        return super.lazyInitLocationManager()
    }

    override func locationFixed(_ coord: CLLocation?) {
        self.setLoadingStage(1)

        DLog("locationFixed \(String(describing: coord))", toFile: true)
        if (coord != nil) {
            if (locManager?.currentLocation != nil) {
                // if lastUsedView is a single station and we did look at it no longer than 30 minutes
                // and the distance is not much more (200m), just show it again
                if (self.needsLocationUpdate && showStations == false) {
                    if let i = lastUsedViewUpdatedInterval(), i > -(60 * 30) {
                        DLog("__", toFile: true)
                        if (lastViewedStation != nil) {
                            let distance2lastViewedStationNow: CLLocationDistance? = locManager?.currentLocation?.distance(from: (lastViewedStation?.coord)!)
                            let distance2lastViewedStationLasttime: CLLocationDistance? = self.datastore.getUserDefaults()?.object(forKey: "lastUsedStationDistance") as! CLLocationDistance?
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

    override func locationDenied(_ manager: CLLocationManager, err:Error) {
        DLog("location denied")
        if ((err as NSError).code == CLError.Code.locationUnknown.rawValue) {
            self.networkErrorMsg = "Airplane mode?"
            self.appsTableView?.reloadData()
            return
        }
        DispatchQueue.main.async(execute: {
            self.networkErrorMsg = "Location not available"
            TFCFavorites.sharedInstance.repopulateFavorites()
            self.setTitleText("Time for Coffee! Error")
            self.appsTableView?.reloadData()
        })
    }


    @IBAction func nextButtonTouchUp(_ sender: AnyObject) {
        if (showStations == true) {
            if (currentStation == nil) {
                if (lastViewedStation != nil) {
                    currentStation = lastViewedStation
                } else if let c = stations?.count(), c > 0 {
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
            let _ = stations?.updateStations(false)
            self.appsTableView?.reloadData()
            sendScreenNameToGA("todayviewNearby")
        }
    }

    @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        if (showStations) {
            let urlstring = "timeforcoffee://nearby"
            let url: URL = URL(string: urlstring)!
            self.extensionContext?.open(url, completionHandler: nil);
        } else if (currentStation != nil && currentStation?.st_id != "0000") {
            let station = currentStation!
            let name = station.name.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
            let long = station.getLongitude()
            let lat = station.getLatitude()
            var urlstring = "timeforcoffee://station?id=\(station.st_id)&name=\(name ?? ""))"
            if (long != nil && lat != nil) {
                urlstring = "\(urlstring)&long=\(long!)&lat=\(lat!)"
            }
            if let url: URL = URL(string: urlstring) {
                self.extensionContext?.open(url, completionHandler: nil);
            }
        }
    }


    func setLastUsedView() {
        let userDefaults = self.datastore.getUserDefaults()
        if (self.showStations) {
            userDefaults?.set("nearbyStations", forKey: "lastUsedView")
        } else {
            if (self.currentStation != nil) {
                userDefaults?.set("singleStation", forKey: "lastUsedView")
                self.lastViewedStation?.isLastUsed = false
                self.currentStation?.isLastUsed = true
                // FIXME, use NSCoding serialisation ..
                // and maybe one object for all these values
                userDefaults?.set(self.currentStation?.getAsDict(), forKey: "lastUsedStation")
                userDefaults?.set(self.locManager?.currentLocation?.distance(from: (self.currentStation?.coord)!), forKey: "lastUsedStationDistance")
            } else {
                userDefaults?.removeObject(forKey: "lastUsedView")
                userDefaults?.removeObject(forKey: "lastUsedStation")
                userDefaults?.removeObject(forKey: "lastUsedStationDistance")
                self.lastViewedStation?.isLastUsed = false
            }
        }
        userDefaults?.set(Date(), forKey: "lastUsedViewUpdate")
    }

    func getLastUsedView() -> String? {
        return self.datastore.getUserDefaults()?.object(forKey: "lastUsedView") as! String?
    }

    func lastUsedViewUpdatedInterval() -> TimeInterval? {
        let lastUpdate: Date? = self.datastore.getUserDefaults()?.object(forKey: "lastUsedViewUpdate") as! Date?
        return lastUpdate?.timeIntervalSinceNow
    }

    func displayDepartures() {
        //UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.networkErrorMsg = nil
        self.setLoadingStage(1)
        currentStation?.updateDepartures(self)
        DispatchQueue.main.async(execute: {
            self.appsTableView?.reloadData()
            return
        })
        setLastUsedView()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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
        let departures = self.currentStation?.getFilteredDepartures(6, fallbackToAll: true)
        if (departures == nil || departures!.count == 0) {
            return 1
        }
        let numberOfCells = min(self.getNumberOfCellsForPreferredContentSize(), departures!.count)
        return numberOfCells
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        if (showStations) {
            cell = tableView.dequeueReusableCell(withIdentifier: "NearbyStationsCell", for: indexPath)
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCellWidget", for: indexPath)
        }
        cell.layoutMargins = UIEdgeInsets.zero
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
                lineNumberLabel.isHidden = true
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
            lineNumberLabel.isHidden = true
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

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
    
    func departuresUpdated(_ error: Error?, context: Any?, forStation: TFCStation?) {
        DLog("departuresUpdated", toFile: true)
        DispatchQueue.main.async {
        self.setLoadingStage(0)
        if (self.showStations) {
            if let context2 = context as? [String: IndexPath],
                   let indexPath = context2["indexPath"],
                   let cellinstance = self.appsTableView?.cellForRow(at: indexPath) as? NearbyStationsTableViewCell {
                //self.appsTableView?.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
                if (cellinstance.stationId != nil) {
                    if (cellinstance.stationId == forStation?.st_id) {
                        cellinstance.drawCell()
                    } else {
                        let _ = cellinstance.getStation()
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

    func departuresStillCached(_ context: Any?, forStation: TFCStation?) {
        // do nothing
        self.departuresUpdated(nil, context: context, forStation: forStation)
    }

    func stationsUpdated(_ error: String?, favoritesOnly: Bool, context: Any?, stations:TFCStations) {
        DispatchQueue.main.async(execute: {
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
                    userDefaults?.set(stations.getNearbyNonFavoriteIds(), forKey: "lastUsedStationsNormal")
                    userDefaults?.set(stations.getNearbyFavoriteIds(), forKey: "lastUsedStationsFavorites")
                }
            }
            self.needsLocationUpdate = false
            self.appsTableView.reloadData()
        })
    }

    fileprivate func sendScreenNameToGA(_ screenname: String) {
        GATracker.sharedInstance?.sendScreenName(screenname)
    }

    fileprivate func populateStationsFromLastUsed() {
        let c = self.stations?.count()
        if (c == nil || c == 0) {
            let stationDict = self.datastore.getUserDefaults()?.object(forKey: "lastUsedStationsNormal") as? [String]?
            let stationDictFavs = self.datastore.getUserDefaults()?.object(forKey: "lastUsedStationsFavorites") as? [String]?
            if (stationDict != nil && stationDictFavs != nil) {
                self.stations?.populateWithIds(stationDictFavs!, nonfavorites:stationDict!)
                self.appsTableView?.reloadData()
            }
        }
    }

    fileprivate func getNumberOfCellsForPreferredContentSize() -> Int {
        let numberOfCells = min(self.numberOfCells, max(1, Int((self.preferredContentSize.height - 33.0) / 52.0)))
        return numberOfCells
    }

    fileprivate func setTitleText(_ text: String? = nil) {
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

            DispatchQueue.main.async {
                textLabel.text = "\(newText)\(loadingIndicator)"
            }
        }
    }

    fileprivate func setLoadingStage(_ stage:Int) {
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
            guard let value = element.value as? Int8, value != 0 else { return identifier }
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
