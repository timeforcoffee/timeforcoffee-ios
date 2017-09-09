//
//  StationViewController
//
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import UIKit
import timeforcoffeeKit
import MapKit
import MGSwipeTableCell

final class DeparturesViewController: WithMapViewController, UITableViewDataSource, TFCDeparturesUpdatedProtocol {

    var refreshControl:UIRefreshControl!
    var networkErrorMsg: String?
    let kCellIdentifier: String = "DeparturesListCell"
    var updateInAMinuteTimer: Timer?
    let updateOnceQueue:DispatchQueue = DispatchQueue(
        label: "ch.opendata.timeforcoffee.updateinaminute", attributes: [])

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var BackButton: UIButton!
    @IBOutlet weak var favButton: UIButton!

    @IBOutlet weak var segmentedControl: UISegmentedControl!

    @IBOutlet weak var stationIconButton: UIButton!

    @IBAction func BackButtonClicked(_ sender: UIButton) {
        let _ = self.navigationController?.popViewController(animated: true)
    }

    var viewAppeared: Bool = false

    @IBAction func iconTouchUp(_ sender: UIButton) {
        favoriteClicked(nil)
    }

    @IBOutlet weak var segmentedView: UISegmentedControl!

    @IBAction func segmentedViewChanged(_ sender: AnyObject) {
        displayDepartures()
    }

    @IBAction func segementedViewTouched(_ sender: AnyObject) {
        TFCDataStore.sharedInstance.getUserDefaults()?.set(segmentedView.selectedSegmentIndex, forKey: "segmentedViewDepartures")
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    deinit {
        DLog("deinit DeparturesViewController")
        NotificationCenter.default.removeObserver(self)
        self.updateInAMinuteTimer?.invalidate()

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidLoad() {
        DLog("viewDidLoad")
        super.viewDidLoad()
        self.edgesForExtendedLayout = UIRectEdge();

        nameLabel.text = self.station?.name
        let currentLocation = TFCLocationManager.getCurrentLocation()
        if (self.station?.coord != nil) {
            self.distanceLabel.text = self.station?.getDistanceForDisplay(currentLocation, completion: {
                text in
                if (text != nil) {
                    self.distanceLabel.text = text
                }
            })
        }

        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        self.refreshControl = UIRefreshControl()
        self.refreshControl.addTarget(self, action: #selector(DeparturesViewController.refresh(_:)), for: UIControlEvents.valueChanged)
        self.refreshControl.backgroundColor = UIColor(red: 242.0/255.0, green: 243.0/255.0, blue: 245.0/255.0, alpha: 1.0)
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.appsTableView?.addSubview(refreshControl)

        startHeight = topBarHeight.constant
        self.appsTableView?.contentInset = UIEdgeInsets(top: startHeight, left: 0, bottom: 0, right: 0)

        favButton.addTarget(self, action: #selector(DeparturesViewController.favoriteClicked(_:)), for: UIControlEvents.touchUpInside)
        stationIconButton.addTarget(self, action: #selector(DeparturesViewController.favoriteClicked(_:)), for: UIControlEvents.touchUpInside)

        favButton.accessibilityLabel = NSLocalizedString("Favourite Station?", comment: "Favourite Station?")

        if (station?.isFavorite() == true) {
            favButton.setTitle("★", for: UIControlState())
            favButton.accessibilityHint = NSLocalizedString("Double-Tap for favouriting this station", comment: "Double-Tap for favouriting this station")
            favButton.accessibilityValue = NSLocalizedString("Yes", comment: "Yes")
        } else {
            favButton.accessibilityValue = NSLocalizedString("No", comment: "No")
            favButton.accessibilityHint = NSLocalizedString("Double-Tap for favouriting this station", comment: "Double-Tap for favouriting this station")
        }
        self.stationIconView.layer.cornerRadius = self.stationIconView.frame.width / 2
        //        self.stationIconImage.image = station?.getIcon()
        self.stationIconButton.setImage(station?.getIcon(), for: UIControlState.normal)

        self.gradientView.image = UIImage(named: "gradient.png")

        topViewProperties(0.0)
        self.mapView?.isUserInteractionEnabled = false;
        self.mapView?.isRotateEnabled = false
        if let coordinate = station?.coord?.coordinate {
            let region = MKCoordinateRegionMakeWithDistance(coordinate ,450,450);
            //with some regions, this fails, so check if it does and only then show a map
            let newRegion = self.mapView.regionThatFits(region)
            if (!(newRegion.span.latitudeDelta.isNaN)) {
                self.mapView.setRegion(newRegion, animated: false)
            }
        }
        // put it to true when within a few hundred meters
        self.mapView.showsUserLocation = false
        self.mapView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(DeparturesViewController.applicationDidBecomeInactive(_:)), name: NSNotification.Name(rawValue: "UIApplicationDidEnterBackgroundNotification"), object: nil)
        if let segmentedViewIndex = TFCDataStore.sharedInstance.getUserDefaults()?.integer(forKey: "segmentedViewDepartures") {
            segmentedView.selectedSegmentIndex = segmentedViewIndex
        }
        let _ = self.station?.removeObsoleteDepartures()

    }

    override func viewDidAppear(_ animated: Bool) {
        DLog("viewDidAppear")
        super.viewDidAppear(animated)
        DispatchQueue.global(qos: .utility).async {
            let gtracker = GATracker.sharedInstance
            gtracker?.sendScreenName("departures")
        }
        displayDepartures()

        viewAppeared = true
        if let station2 = self.station {
            //check if the icon is cache already for mapview later.
            if (!self.checkIfIconIsCachedAsImage(station2)) {
               let _ = self.getIconViewAsImage(self.stationIconView, station: station2)
            }
            station2.setStationActivity()
            if #available(iOS 9.0, *) {
                // in 9.1 make it UIApplicationShortcutIcon(type: .MarkLocation)
                let icon:UIApplicationShortcutIcon?
                if #available(iOS 9.1, *) {
                    icon = UIApplicationShortcutIcon(type: .markLocation)
                } else {
                    icon = nil
                }
                let shortcut = UIMutableApplicationShortcutItem(type: "ch.opendata.timeforcoffee.station", localizedTitle: station2.name, localizedSubtitle: nil, icon: icon, userInfo: ["st_id": station2.st_id, "name": station2.name])
                var shortCuts = [shortcut]
                let existingShortcutItems = UIApplication.shared.shortcutItems ?? []
                if let firstExistingShortcutItem = existingShortcutItems.first {
                    if let ua: [String: String] = firstExistingShortcutItem.userInfo as? [String: String] {
                        if ua["st_id"] != station2.st_id {
                            let oldShortcutItem = firstExistingShortcutItem.mutableCopy() as! UIMutableApplicationShortcutItem
                            shortCuts.append(oldShortcutItem)
                        } else {
                            if let lastExistingShortcutItem = existingShortcutItems.last {
                                let oldShortcutItem = lastExistingShortcutItem.mutableCopy() as! UIMutableApplicationShortcutItem
                                shortCuts.append(oldShortcutItem)
                            }
                        }
                    }
                }

                UIApplication.shared.shortcutItems = shortCuts
            }
        }
        
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        updateOnceQueue.sync {
            [unowned self] in
            self.updateInAMinuteTimer?.invalidate()
            return
        }
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = super.scrolled(scrollView)
        self.segmentedControl.alpha = 1 - (offset / 80)
    }

    override func topViewProperties(_ offsetForAnimation: CGFloat) {
        super.topViewProperties(offsetForAnimation)
        self.segmentedControl.alpha = 1.0 - offsetForAnimation

    }

    @objc func applicationDidBecomeInactive(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(self, selector: #selector(UIApplicationDelegate.applicationDidBecomeActive(_:)), name: NSNotification.Name(rawValue: "UIApplicationDidBecomeActiveNotification"), object: nil)
        updateOnceQueue.sync {
            [unowned self] in
            self.updateInAMinuteTimer?.invalidate()
            return
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        self.station?.setStationActivity()
        NotificationCenter.default.removeObserver(self)
          NotificationCenter.default.addObserver(self, selector: #selector(DeparturesViewController.applicationDidBecomeInactive(_:)), name: NSNotification.Name(rawValue: "UIApplicationDidEnterBackgroundNotification"), object: nil)
        displayDepartures()
    }

    @objc func favoriteClicked(_ sender: UIBarButtonItem?) {
        func completion() {
        }
        self.station!.toggleIcon(stationIconButton, icon: stationIconView, completion: completion)
        if (self.station!.isFavorite()) {
            favButton.setTitle("★", for: UIControlState())
        } else {
            favButton.setTitle("☆", for: UIControlState())
        }
        self.appsTableView?.reloadData()
        if let currentUser = SKTUser.current() {
            currentUser.addProperties(["usedFavorites": true])
        }
    }


    @objc func refresh(_ sender:AnyObject)
    {
        // Code to refresh table view
        self.station?.updateDepartures(self, force: true, context: nil)
    }

    @objc func displayDepartures() {
        if (self.station != nil) {
            updateInAMinute()
            self.station?.updateDepartures(self)
            let favLocalized = NSLocalizedString("Favourites", comment: "")
            if (station?.hasFavoriteDepartures() != true && station?.hasFilters() != true) {
                segmentedView.setTitle(favLocalized + "?", forSegmentAt: 1)
            } else {
                segmentedView.setTitle(favLocalized, forSegmentAt: 1)
            }
            self.appsTableView?.reloadData()
        }
    }

    internal func setStation(station: TFCStation) {
        self.station = station
    }

    func departuresUpdated(_ error: Error?, context: Any?, forStation: TFCStation?) {
        DispatchQueue.main.async {
            self.refreshControl.endRefreshing()
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            if (forStation?.st_id == self.station?.st_id) {
                if (error != nil) {
                    self.networkErrorMsg = NSLocalizedString("Network error. Please try again", comment:"")
                } else {
                    self.networkErrorMsg = nil
                }
                if (self.nameLabel.text == "") {
                    self.nameLabel.text = self.station?.name
                }
                self.appsTableView!.reloadData()
            }
        }
    }

    func departuresStillCached(_ context: Any?, forStation: TFCStation?) {
        self.refreshControl.endRefreshing()
    }

    fileprivate func getDeparturesDependentOnView(_ station: TFCStation?) -> [TFCDeparture]? {
        let departures:[TFCDeparture]?
        if (segmentedView.selectedSegmentIndex == 1) {
            if (station?.hasFavoriteDepartures() == true || station?.hasFilters() == true) {
                departures = station?.getFilteredDepartures()
            } else {
                if (viewAppeared == false) {
                    segmentedView.selectedSegmentIndex = 0
                    displayDepartures()
                }
                departures = []
            }
        } else {
            departures = station?.getDepartures()
        }
        return departures
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let departures = getDeparturesDependentOnView(station)
        if let departures = departures {
            let count = departures.count
            if count == 0 {
                return 1
            }
            return count
        }
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:MGSwipeTableCell = tableView.dequeueReusableCell(withIdentifier: kCellIdentifier) as! MGSwipeTableCell

        cell.delegate = self
        cell.tag = indexPath.row
        let lineNumberLabel = cell.viewWithTag(99100) as! DepartureLineLabel
        let destinationLabel = cell.viewWithTag(99200) as! UILabel
        let departureLabel = cell.viewWithTag(99300) as! UILabel
        let minutesLabel = cell.viewWithTag(99400) as! UILabel
        if (station != nil) {
            let station2 = station!
            let departures = getDeparturesDependentOnView(station2)
            if (departures == nil || departures!.count == 0) {
                departureLabel.text = nil
                minutesLabel.text = nil
                lineNumberLabel.isHidden = true
                if (departures == nil) {
                    destinationLabel.text = NSLocalizedString("Loading", comment: "Loading ..")
                } else {
                    if (segmentedView.selectedSegmentIndex == 0 ||  station?.hasFavoriteDepartures() == true) {
                        destinationLabel.text = NSLocalizedString("No departures found.", comment: "")
                    } else {
                        destinationLabel.text = NSLocalizedString("No favourites found.", comment: "")

                    }
                    if (self.networkErrorMsg != nil) {
                        departureLabel.text = self.networkErrorMsg
                    }
                }
                return cell
            }
            lineNumberLabel.isHidden = false
            if let departures = departures {
                if (indexPath.row < departures.count) {
                    let departure = departures[indexPath.row]
                        //if on first row and it's in the past, remove obsolete departures and reload
                        if (indexPath.row == 0 && departure.getMinutesAsInt()! < 0) {
                            DispatchQueue.main.async {
                                let _ = self.station?.removeObsoleteDepartures(true)
                                self.appsTableView?.reloadData()
                            }
                        }

                        var unabridged = false
                        if (UIDeviceOrientationIsLandscape(UIDevice.current.orientation)) {
                            unabridged = true
                        }
                        if (segmentedView.selectedSegmentIndex == 1) {
                            destinationLabel.text = departure.getDestination(station, unabridged: unabridged)
                        } else {
                            destinationLabel.text = departure.getDestinationWithSign(station, unabridged: unabridged)
                        }

                        minutesLabel.text = departure.getMinutes()
                        destinationLabel.textColor = UIColor.black
                        minutesLabel.textColor = UIColor.black

                        let (departureTimeAttr, departureTimeString) = departure.getDepartureTime()
                        if (departureTimeAttr != nil) {
                            departureLabel.text = nil
                            departureLabel.attributedText = departureTimeAttr
                        } else {
                            departureLabel.attributedText = nil
                            departureLabel.text = departureTimeString
                        }
                        lineNumberLabel.setStyle("normal", departure: departure)
                        lineNumberLabel.linelabelClickedCallback = {
                            [unowned self] in
                            departure.toggleFavorite(station2)
                            self.appsTableView?.reloadData()
                        }

                        if let minutes = departure.getMinutesAsInt(), let time = departure.getRealDepartureDateAsShortDate() {

                            var access = "\(departure.getLine()) \(departure.getDestination(station, unabridged: false)) in \(minutes) minutes."
                            var platformStr = ""

                            if let platform = departure.platform {
                                platformStr = NSLocalizedString("Platform", comment: "On platform") + " " + platform
                            }
                            access = String.localizedStringWithFormat(
                                NSLocalizedString("%@ %@ in %d minutes. %@ At %@",
                                    comment: "Accessibilty Departure"), departure.getLine(), departure.getDestination(station, unabridged: false), minutes, platformStr, time)
                            cell.accessibilityLabel = access
                        }
                }
            }

        }
        return cell
    }

    override func getMapIcon(_ pass:TFCPass? = nil) -> UIImage {
        return getIconViewAsImage(self.stationIconView, station: self.station)
    }

    func swipeTableCell(_ cell: MGSwipeTableCell!, canSwipe direction: MGSwipeDirection) -> Bool {
        if (direction == MGSwipeDirection.rightToLeft) {
            return true
        }
        return false
    }

    func swipeTableCell(_ cell: MGSwipeTableCell!, swipeButtonsForDirection direction: MGSwipeDirection, swipeSettings: MGSwipeSettings!, expansionSettings: MGSwipeExpansionSettings!) -> [AnyObject]! {

        let buttonClickCallbackFavorite : MGSwipeButtonCallback = { (cell: MGSwipeTableCell?) -> Bool in
            if let station2 = self.station {
                if let departures: [TFCDeparture] = self.getDeparturesDependentOnView(station2),
                    let cell = cell {
                    let departure: TFCDeparture = departures[cell.tag]
                    SKTUser.current()?.addProperties(["usedFilters": true])
                    let index = 0
                    if (station2.isFavoriteDeparture(departure)) {
                        station2.unsetFavoriteDeparture(departure)
                        let button = cell.rightButtons[index] as! MGSwipeButton
                        button.backgroundColor = UIColor.green;
                    } else {
                        station2.setFavoriteDeparture(departure);
                        let button = cell.rightButtons[index] as! MGSwipeButton
                        button.backgroundColor = UIColor.red;
                    }
                    self.displayDepartures()
                }
            }
            return true
        }
        var buttons:[AnyObject] = []
        if let station2 = station {
            let departures = getDeparturesDependentOnView(station2)
            if (departures != nil) {
                if (direction == MGSwipeDirection.rightToLeft) {
                    let departure: TFCDeparture = departures![cell.tag]
                    if (station2.isFavoriteDeparture(departure)) {
                        buttons.append(MGSwipeButton( title:"Unfavorite", backgroundColor: UIColor.red, callback: buttonClickCallbackFavorite))
                    } else {
                        buttons.append(MGSwipeButton( title:"Favorite", backgroundColor: UIColor.green, callback: buttonClickCallbackFavorite))
                    }
                    /*if (!station2.hasFavoriteDepartures()) {
                        if (station2.isFilteredDeparture(departure)) {
                            buttons.append(MGSwipeButton( title:"Show", backgroundColor: UIColor.redColor(), callback: buttonClickCallbackFilter))
                        } else {
                            buttons.append(MGSwipeButton( title:"Don't show", backgroundColor: UIColor.greenColor(), callback: buttonClickCallbackFilter))
                        }
                    }*/


                }
                expansionSettings.buttonIndex = 0
                expansionSettings.fillOnTrigger = true
                expansionSettings.threshold = 2.5
            }
        }
        return buttons as [AnyObject]
    }

    fileprivate func buttonClickCallbackFilter(_ cell: MGSwipeTableCell!) -> Bool {
        let station2 = station!
        let departures: [TFCDeparture] = getDeparturesDependentOnView(station2)!

        let departure: TFCDeparture = departures[cell.tag]
        SKTUser.current()?.addProperties(["usedFilters": true])
        var index = 0
        if (cell.rightButtons.count == 2) {
            index = 1
        }
        if (station2.isFilteredDeparture(departure)) {
            station2.unsetFilterDeparture(departure);
            let button = cell.rightButtons[index] as! MGSwipeButton
            button.backgroundColor = UIColor.green;
        } else {
            station2.setFilterDeparture(departure);
            let button = cell.rightButtons[index] as! MGSwipeButton
            button.backgroundColor = UIColor.red;
        }
        self.appsTableView?.reloadData()
        return true
    }

    func updateInAMinute() {
        // make sure this only runs serially
        updateOnceQueue.async(execute: {
            [unowned self] in
            // invalidate timer to be sure we don't have more than one
            self.updateInAMinuteTimer?.invalidate()
            let now = Date.timeIntervalSinceReferenceDate
            let timeInterval = 60.0
            let nextMinute = floor(now / timeInterval) * timeInterval + (timeInterval + Double(arc4random_uniform(10))) //time interval for next minute, plus random 0 - 10 seconds, to avoid server overload
            let delay = max(25.0, nextMinute - now) //don't set the delay to less than 25 seconds
          //  let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
            DispatchQueue.main.sync(execute: {
                self.updateInAMinuteTimer = Timer.scheduledTimer(timeInterval: delay, target: self,  selector: #selector(DeparturesViewController.displayDepartures), userInfo: nil, repeats: false)
            })
        })
    }

    override func drawAnnotations() {

        mapView.removeAnnotations(mapView.annotations)
        self.mapView.showsUserLocation = false

        if let station = station {
            drawStationAndWay(station)
        }
        self.mapView.showsUserLocation = true
    }


    func tableView(_ tableView: UITableView, didSelectRowAtIndexPath indexPath: IndexPath) {
        if let count = self.getDeparturesDependentOnView(station)?.count {
            if (count > 0) {
                self.performSegue(withIdentifier: "SegueToPasslistView", sender: nil)
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
       let detailsViewController: PasslistViewController = segue.destination as! PasslistViewController

        let index = appsTableView?.indexPathForSelectedRow?.row
        if let index = index, let departure = self.getDeparturesDependentOnView(station)?[index] {

            DLog(departure)
//            departure.getDepartureTime()
            //            let station = appsTableView?.stations.getStation(index!)
            detailsViewController.setDeparture(departure: departure);        }
        
    }
    
}
