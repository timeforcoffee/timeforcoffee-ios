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
    var updateInAMinuteTimer: NSTimer?
    let updateOnceQueue:dispatch_queue_t = dispatch_queue_create(
        "ch.opendata.timeforcoffee.updateinaminute", DISPATCH_QUEUE_SERIAL)

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var BackButton: UIButton!
    @IBOutlet weak var favButton: UIButton!

    @IBOutlet weak var segmentedControl: UISegmentedControl!

    @IBOutlet weak var stationIconButton: UIButton!

    @IBAction func BackButtonClicked(sender: UIButton) {
        self.navigationController?.popViewControllerAnimated(true)
    }

    var viewAppeared: Bool = false

    @IBAction func iconTouchUp(sender: UIButton) {
        favoriteClicked(nil)
    }

    @IBOutlet weak var segmentedView: UISegmentedControl!

    @IBAction func segmentedViewChanged(sender: AnyObject) {
        displayDepartures()
    }

    @IBAction func segementedViewTouched(sender: AnyObject) {
        TFCDataStore.sharedInstance.getUserDefaults()?.setObject(segmentedView.selectedSegmentIndex, forKey: "segmentedViewDepartures")
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    deinit {
        DLog("deinit DeparturesViewController")
        NSNotificationCenter.defaultCenter().removeObserver(self)
        self.updateInAMinuteTimer?.invalidate()

    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidLoad() {
        DLog("viewDidLoad")
        super.viewDidLoad()
        self.edgesForExtendedLayout = UIRectEdge.None;

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

        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.refreshControl = UIRefreshControl()
        self.refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.refreshControl.backgroundColor = UIColor(red: 242.0/255.0, green: 243.0/255.0, blue: 245.0/255.0, alpha: 1.0)
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.appsTableView?.addSubview(refreshControl)

        startHeight = topBarHeight.constant
        self.appsTableView?.contentInset = UIEdgeInsets(top: startHeight, left: 0, bottom: 0, right: 0)

        favButton.addTarget(self, action: "favoriteClicked:", forControlEvents: UIControlEvents.TouchUpInside)
        stationIconButton.addTarget(self, action: "favoriteClicked:", forControlEvents: UIControlEvents.TouchUpInside)

        if (station?.isFavorite() == true) {
            favButton.setTitle("★", forState: UIControlState.Normal)
        }
        self.stationIconView.layer.cornerRadius = self.stationIconView.frame.width / 2
        //        self.stationIconImage.image = station?.getIcon()
        self.stationIconButton.setImage(station?.getIcon(), forState: UIControlState.Normal)

        self.gradientView.image = UIImage(named: "gradient.png")

        topViewProperties(0.0)
        self.mapView?.userInteractionEnabled = false;
        self.mapView?.rotateEnabled = false
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
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBecomeInactive:", name: "UIApplicationDidEnterBackgroundNotification", object: nil)
        if let segmentedViewIndex = TFCDataStore.sharedInstance.getUserDefaults()?.integerForKey("segmentedViewDepartures") {
            segmentedView.selectedSegmentIndex = segmentedViewIndex
        }
        self.station?.removeObsoleteDepartures()

    }

    override func viewDidAppear(animated: Bool) {
        DLog("viewDidAppear")
        super.viewDidAppear(animated)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            let gtracker = GAI.sharedInstance().defaultTracker
            gtracker.set(kGAIScreenName, value: "departures")
            gtracker.send(GAIDictionaryBuilder.createScreenView().build() as [NSObject : AnyObject]!)
        }
        displayDepartures()

        viewAppeared = true
        if let station2 = self.station {
            //check if the icon is cache already for mapview later.
            if (!self.checkIfIconIsCachedAsImage(station2)) {
                self.getIconViewAsImage(self.stationIconView, station: station2)
            }
            station2.setStationActivity()
            if #available(iOS 9.0, *) {
                // in 9.1 make it UIApplicationShortcutIcon(type: .MarkLocation)
                let icon:UIApplicationShortcutIcon?
                if #available(iOS 9.1, *) {
                    icon = UIApplicationShortcutIcon(type: .MarkLocation)
                } else {
                    icon = nil
                }
                let shortcut = UIMutableApplicationShortcutItem(type: "ch.opendata.timeforcoffee.station", localizedTitle: station2.name, localizedSubtitle: nil, icon: icon, userInfo: ["st_id": station2.st_id, "name": station2.name])
                var shortCuts = [shortcut]
                let existingShortcutItems = UIApplication.sharedApplication().shortcutItems ?? []
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

                UIApplication.sharedApplication().shortcutItems = shortCuts
            }
        }
        
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
        dispatch_sync(updateOnceQueue) {
            [unowned self] in
            self.updateInAMinuteTimer?.invalidate()
            return
        }
    }

    override func scrollViewDidScroll(scrollView: UIScrollView) {
        let offset = super.scrolled(scrollView)
        self.segmentedControl.alpha = 1 - (offset / 80)
    }

    override func topViewProperties(offsetForAnimation: CGFloat) {
        super.topViewProperties(offsetForAnimation)
        self.segmentedControl.alpha = 1.0 - offsetForAnimation

    }

    func applicationDidBecomeInactive(notification: NSNotification) {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBecomeActive:", name: "UIApplicationDidBecomeActiveNotification", object: nil)
        dispatch_sync(updateOnceQueue) {
            [unowned self] in
            self.updateInAMinuteTimer?.invalidate()
            return
        }
    }
    
    func applicationDidBecomeActive(notification: NSNotification) {
        self.station?.setStationActivity()
        NSNotificationCenter.defaultCenter().removeObserver(self)
          NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBecomeInactive:", name: "UIApplicationDidEnterBackgroundNotification", object: nil)
        displayDepartures()
    }

    func favoriteClicked(sender: UIBarButtonItem?) {
        func completion() {
        }
        self.station!.toggleIcon(stationIconButton, icon: stationIconView, completion: completion)
        if (self.station!.isFavorite()) {
            favButton.setTitle("★", forState: UIControlState.Normal)
        } else {
            favButton.setTitle("☆", forState: UIControlState.Normal)
        }
        self.appsTableView?.reloadData()
        SKTUser.currentUser().addProperties(["usedFavorites": true])
    }


    func refresh(sender:AnyObject)
    {
        // Code to refresh table view
        self.station?.updateDepartures(self, force: true, context: nil)
    }

    func displayDepartures() {
        if (self.station != nil) {
            updateInAMinute()
            self.station?.updateDepartures(self)
            if (station?.hasFavoriteDepartures() != true && station?.hasFilters() != true) {
                segmentedView.setTitle("Favourites?", forSegmentAtIndex: 1)
            } else {
                segmentedView.setTitle("Favourites", forSegmentAtIndex: 1)
            }
            self.appsTableView?.reloadData()
        }
    }

    internal func setStation(station station: TFCStation) {
        self.station = station
    }

    func departuresUpdated(error: NSError?, context: Any?, forStation: TFCStation?) {
        self.refreshControl.endRefreshing()
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        if (forStation?.st_id == station?.st_id) {
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

    func departuresStillCached(context: Any?, forStation: TFCStation?) {
        self.refreshControl.endRefreshing()
    }

    private func getDeparturesDependentOnView(station: TFCStation?) -> [TFCDeparture]? {
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

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell:MGSwipeTableCell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier) as! MGSwipeTableCell

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
                lineNumberLabel.hidden = true
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
            lineNumberLabel.hidden = false
            let departure: TFCDeparture = departures![indexPath.row]
            
            var unabridged = false
            if (UIDeviceOrientationIsLandscape(UIDevice.currentDevice().orientation)) {
                unabridged = true
            }
            if (segmentedView.selectedSegmentIndex == 1) {
                destinationLabel.text = departure.getDestination(station, unabridged: unabridged)
            } else {
                destinationLabel.text = departure.getDestinationWithSign(station, unabridged: unabridged)
            }

            minutesLabel.text = departure.getMinutes()
            destinationLabel.textColor = UIColor.blackColor()
            minutesLabel.textColor = UIColor.blackColor()

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
                departure.toggleFavorite(station2)
                self.appsTableView?.reloadData()
            }

        }
        return cell
    }

    override func getMapIcon(pass:TFCPass? = nil) -> UIImage {
        return getIconViewAsImage(self.stationIconView, station: self.station)
    }

    func swipeTableCell(cell: MGSwipeTableCell!, canSwipe direction: MGSwipeDirection) -> Bool {
        if (direction == MGSwipeDirection.RightToLeft) {
            return true
        }
        return false
    }

    func swipeTableCell(cell: MGSwipeTableCell!, swipeButtonsForDirection direction: MGSwipeDirection, swipeSettings: MGSwipeSettings!, expansionSettings: MGSwipeExpansionSettings!) -> [AnyObject]! {

        let buttonClickCallbackFavorite : MGSwipeButtonCallback = { (cell: MGSwipeTableCell!) in
            let station2 = self.station!
            let departures: [TFCDeparture] = self.getDeparturesDependentOnView(station2)!
            let departure: TFCDeparture = departures[cell.tag]
            SKTUser.currentUser().addProperties(["usedFilters": true])
            let index = 0
            if (station2.isFavoriteDeparture(departure)) {
                station2.unsetFavoriteDeparture(departure)
                let button = cell.rightButtons[index] as! MGSwipeButton
                button.backgroundColor = UIColor.greenColor();
            } else {
                station2.setFavoriteDeparture(departure);
                let button = cell.rightButtons[index] as! MGSwipeButton
                button.backgroundColor = UIColor.redColor();
            }
            self.displayDepartures()
            return true
        }
        var buttons:[AnyObject] = []
        if (station != nil) {
            let station2 = station!
            let departures = getDeparturesDependentOnView(station2)
            if (departures != nil) {
                if (direction == MGSwipeDirection.RightToLeft) {
                    let departure: TFCDeparture = departures![cell.tag]
                    if (station2.isFavoriteDeparture(departure)) {
                        buttons.append(MGSwipeButton( title:"Unfavorite", backgroundColor: UIColor.redColor(), callback: buttonClickCallbackFavorite))
                    } else {
                        buttons.append(MGSwipeButton( title:"Favorite", backgroundColor: UIColor.greenColor(), callback: buttonClickCallbackFavorite))
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

    private func buttonClickCallbackFilter(cell: MGSwipeTableCell!) -> Bool {
        let station2 = station!
        let departures: [TFCDeparture] = getDeparturesDependentOnView(station2)!

        let departure: TFCDeparture = departures[cell.tag]
        SKTUser.currentUser().addProperties(["usedFilters": true])
        var index = 0
        if (cell.rightButtons.count == 2) {
            index = 1
        }
        if (station2.isFilteredDeparture(departure)) {
            station2.unsetFilterDeparture(departure);
            let button = cell.rightButtons[index] as! MGSwipeButton
            button.backgroundColor = UIColor.greenColor();
        } else {
            station2.setFilterDeparture(departure);
            let button = cell.rightButtons[index] as! MGSwipeButton
            button.backgroundColor = UIColor.redColor();
        }
        self.appsTableView?.reloadData()
        return true
    }

    func updateInAMinute() {
        // make sure this only runs serially
        dispatch_async(updateOnceQueue, {
            [unowned self] in
            // invalidate timer to be sure we don't have more than one
            self.updateInAMinuteTimer?.invalidate()
            let now = NSDate.timeIntervalSinceReferenceDate()
            let timeInterval = 60.0
            let nextMinute = floor(now / timeInterval) * timeInterval + (timeInterval + Double(arc4random_uniform(10))) //time interval for next minute, plus random 0 - 10 seconds, to avoid server overload
            let delay = max(25.0, nextMinute - now) //don't set the delay to less than 25 seconds
          //  let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
            dispatch_sync(dispatch_get_main_queue(), {
                self.updateInAMinuteTimer = NSTimer.scheduledTimerWithTimeInterval(delay, target: self,  selector: "displayDepartures", userInfo: nil, repeats: false)
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


    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if (self.getDeparturesDependentOnView(station)?.count > 0) {
            self.performSegueWithIdentifier("SegueToPasslistView", sender: nil)
        }
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
       let detailsViewController: PasslistViewController = segue.destinationViewController as! PasslistViewController

        let index = appsTableView?.indexPathForSelectedRow?.row
        if let index = index, departure = self.getDeparturesDependentOnView(station)?[index] {

            DLog(departure)
//            departure.getDepartureTime()
            //            let station = appsTableView?.stations.getStation(index!)
            detailsViewController.setDeparture(departure: departure);        }
        
    }
    
}
