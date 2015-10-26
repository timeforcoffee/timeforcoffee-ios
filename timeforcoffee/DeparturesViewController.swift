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

final class DeparturesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate, MGSwipeTableCellDelegate, MKMapViewDelegate, TFCDeparturesUpdatedProtocol {

    @IBOutlet var appsTableView : UITableView?
    var refreshControl:UIRefreshControl!
    var station: TFCStation?
    var networkErrorMsg: String?
    let kCellIdentifier: String = "DeparturesListCell"
    var gestureRecognizer: UIGestureRecognizerDelegate?
    var mapSwipeUpStart: CGFloat?
    var destinationPlacemark: MKPlacemark?
    var mapDirectionOverlay: MKOverlay?
    var startHeight: CGFloat!
    var updateInAMinuteTimer: NSTimer?
    let updateOnceQueue:dispatch_queue_t = dispatch_queue_create(
        "ch.opendata.timeforcoffee.updateinaminute", DISPATCH_QUEUE_SERIAL)

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var BackButton: UIButton!
    @IBOutlet weak var favButton: UIButton!

    @IBOutlet weak var distanceLabel: UILabel!

    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var gradientView: UIImageView!
    @IBOutlet weak var borderBottomView: UIView!

    @IBOutlet weak var navBarBackgroundView: UIView!

    @IBOutlet weak var stationIconButton: UIButton!
    @IBOutlet weak var stationIconView: UIView!

    @IBOutlet weak var navBarView: UIView!

    @IBOutlet weak var releaseToViewLabel: UILabel!

    @IBAction func BackButtonClicked(sender: UIButton) {
        self.navigationController?.popViewControllerAnimated(true)
    }

    @IBOutlet var topBarHeight: NSLayoutConstraint!

    @IBOutlet weak var mapHeight: NSLayoutConstraint!

    @IBOutlet var topBarBottomSpace: NSLayoutConstraint!

    @IBOutlet weak var stationNameBottomSpace: NSLayoutConstraint!

    var mapOnBottom: Bool = false
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
        if (self.mapOnBottom) {
            self.mapView.showsUserLocation = true
        }
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        gestureRecognizer = self.navigationController?.interactivePopGestureRecognizer!.delegate
        self.navigationController?.interactivePopGestureRecognizer!.delegate = nil

        if let segmentedViewIndex = TFCDataStore.sharedInstance.getUserDefaults()?.integerForKey("segmentedViewDepartures") {
            segmentedView.selectedSegmentIndex = segmentedViewIndex
        }

    }

    override func viewDidLoad() {
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

        if (station!.isFavorite()) {
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
        displayDepartures()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBecomeInactive:", name: "UIApplicationDidEnterBackgroundNotification", object: nil)

    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            let gtracker = GAI.sharedInstance().defaultTracker
            gtracker.set(kGAIScreenName, value: "departures")
            gtracker.send(GAIDictionaryBuilder.createScreenView().build() as [NSObject : AnyObject]!)
        }
        viewAppeared = true
        if let station2 = self.station {
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


    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if (self.mapOnBottom && self.topBarBottomSpace.active == false) {
            //needed for example on ration
            NSLayoutConstraint.deactivateConstraints([self.topBarHeight])
            NSLayoutConstraint.activateConstraints([self.topBarBottomSpace])
            self.view.layoutIfNeeded()
        }
    }

    override func viewWillDisappear(animated: Bool) {
        self.mapView.showsUserLocation = false
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }

    override func viewDidDisappear(animated: Bool) {
        station = nil
        self.navigationController?.interactivePopGestureRecognizer!.delegate = gestureRecognizer
        NSNotificationCenter.defaultCenter().removeObserver(self)
        dispatch_sync(updateOnceQueue) {
            [unowned self] in
            self.updateInAMinuteTimer?.invalidate()
            return
        }
    }

    @IBAction func panOnTopView(sender: UIPanGestureRecognizer) {
        let location = sender.locationInView(self.topView)
        let releasePoint = CGFloat(200.0)
        var topBarCalculatedHeight = floor(startHeight + (location.y - startHeight) / 3)

        if (mapSwipeUpStart != nil) {
            topBarCalculatedHeight = floor(location.y + mapSwipeUpStart!)
        }

        if (topBarCalculatedHeight < startHeight) {
            topBarCalculatedHeight = 150.0
        }
        if (sender.state == UIGestureRecognizerState.Began) {
            if (self.mapOnBottom == true ) {
                self.mapSwipeUpStart = UIScreen.mainScreen().bounds.size.height - location.y
                self.mapView.userInteractionEnabled = false
                NSLayoutConstraint.deactivateConstraints([self.topBarBottomSpace])
                NSLayoutConstraint.activateConstraints([self.topBarHeight])
                self.mapOnBottom = false
                self.view.layoutIfNeeded()
            } else {
                self.mapSwipeUpStart = nil
            }
            return
        }
        if (sender.state == UIGestureRecognizerState.Ended) {
            let velocity = sender.velocityInView(self.appsTableView)
            let yVelocity = Double(velocity.y)

            if (yVelocity < -100) {
                moveMapViewUp(yVelocity)
            } else if (yVelocity > 100) {
                moveMapViewDown(yVelocity)
            } else if (mapSwipeUpStart != nil) {
                if ((UIScreen.mainScreen().bounds.size.height - topBarCalculatedHeight)  > 40) {
                    moveMapViewUp(yVelocity)
                } else {
                    moveMapViewDown(yVelocity)
                }
            } else if (topBarCalculatedHeight > releasePoint) {
                moveMapViewDown(yVelocity)
            } else {
                moveMapViewUp(yVelocity)

            }
            return
        }
        topBarHeight?.constant = topBarCalculatedHeight
        if (topBarCalculatedHeight < releasePoint) {
            let offsetForAnimation: CGFloat = ((topBarCalculatedHeight - startHeight) / (releasePoint - startHeight))
            topViewProperties(offsetForAnimation)
            self.releaseToViewLabel.hidden = true
            if (mapSwipeUpStart == nil) {
                if (self.destinationPlacemark == nil) {
                    drawStationAndWay()
                }
            }
        } else {
            if (mapSwipeUpStart == nil) {
                self.releaseToViewLabel.hidden = false
            }
            topViewProperties(1.0)
        }

        if (topBarCalculatedHeight > mapHeight.constant) {
            mapHeight.constant = topBarCalculatedHeight + 300
            self.view.layoutIfNeeded()
        }
    }

    func drawStationAndWay() {
        
        mapView.removeAnnotations(mapView.annotations)

        if let stationCoordinate = station?.coord?.coordinate, let stationName = station?.name, let stationDistance = distanceLabel.text {
            
            let annotation = StationAnnotation(title: stationName, distance: stationDistance, coordinate: stationCoordinate)
            mapView.addAnnotation(annotation)
            destinationPlacemark = MKPlacemark(coordinate: annotation.coordinate, addressDictionary: nil)
            self.mapView.showsUserLocation = true
            
            let currentLocation = TFCLocationManager.getCurrentLocation()
            let currentCoordinate = currentLocation?.coordinate
            
            if (currentCoordinate == nil || station?.getDistanceInMeter(currentLocation) >= 5000) {
                return
            }
            let sourcePlacemark:MKPlacemark = MKPlacemark(coordinate: currentCoordinate!, addressDictionary: nil)
            
            let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
            let destinationMapItem = MKMapItem(placemark: destinationPlacemark!)
            let directionRequest:MKDirectionsRequest = MKDirectionsRequest()
            
            directionRequest.source = sourceMapItem
            directionRequest.destination = destinationMapItem
            directionRequest.transportType = MKDirectionsTransportType.Walking
            directionRequest.requestsAlternateRoutes = false
            
            let directions:MKDirections = MKDirections(request: directionRequest)
            
            directions.calculateDirectionsWithCompletionHandler({
                (response: MKDirectionsResponse?, error: NSError?) in
                if error != nil{
                    DLog("Error")
                }
                if response != nil{
                    //                for r in response.routes { DLog("route = \(r)") }
                    let route: MKRoute = response!.routes[0] as MKRoute;
                    self.mapDirectionOverlay = route.polyline
                    self.mapView.addOverlay(self.mapDirectionOverlay!)
                }
                else{
                    DLog("No response")
                }
                print(error?.description)
            })
        }
    }

    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKPolyline {
            let polylineRenderer = MKPolylineRenderer(overlay: overlay)
            polylineRenderer.strokeColor = UIColor.blueColor()
            polylineRenderer.lineWidth = 1
            return polylineRenderer
        }
        return MKPolylineRenderer()
    }

    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {

        if (annotation.isKindOfClass(MKUserLocation)) {
            return nil
        }

        let annotationIdentifier = "CustomViewAnnotation"
        var annotationView = self.mapView.dequeueReusableAnnotationViewWithIdentifier(annotationIdentifier)

        if (annotationView == nil) {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: annotationIdentifier)
        }
        
        annotationView?.canShowCallout = true
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        let buttonImage = UIImage(named: "Walking")
        button.setImage(buttonImage, forState: UIControlState.Normal)
        annotationView?.leftCalloutAccessoryView = button

        annotationView!.image = getIconViewAsImage(self.stationIconView)
        annotationView!.opaque = false
        annotationView!.alpha = 1.0
        annotationView!.frame.size.height = 30
        annotationView!.frame.size.width = 30

        return annotationView;

    }
    
    // Launch Maps app when the left accessory button is tapped
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if let stationAnnotation = view.annotation as? StationAnnotation {
            if control == view.leftCalloutAccessoryView {
                let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
                stationAnnotation.mapItem().openInMapsWithLaunchOptions(launchOptions)
                mapView.deselectAnnotation(view.annotation, animated: false)
            }
        }
    }
    
    func moveMapViewDown(velocity: Double?) {
        let height = UIScreen.mainScreen().bounds.size.height
        self.releaseToViewLabel.hidden = true
        self.mapView.userInteractionEnabled = true
        if (self.mapHeight.constant < height + 200) {
            self.mapHeight.constant = height + 200
        }
        let maxDuration = 0.5
        var duration: NSTimeInterval = maxDuration
        if (velocity != nil) {
            duration = min(maxDuration, 600.0 / abs(velocity!))
        }
        NSLayoutConstraint.deactivateConstraints([self.topBarHeight])
        NSLayoutConstraint.activateConstraints([self.topBarBottomSpace])
        self.topBarBottomSpace?.constant = 0

        UIView.animateWithDuration(duration,
            animations: {
                self.view.layoutIfNeeded()
                self.topViewProperties(1.0)
                return
            }, completion: { (finished:Bool) in
                if (finished) {
                    self.mapOnBottom = true
                    self.topBarHeight?.constant = self.topView.frame.height
                }
            }
        )
        let gtracker = GAI.sharedInstance().defaultTracker
        gtracker.set(kGAIScreenName, value: "departuresMap")
        gtracker.send(GAIDictionaryBuilder.createScreenView().build() as [NSObject : AnyObject]!)

    }

    func moveMapViewUp(velocity: Double?) {

        let height = CGFloat(startHeight)

        self.mapView.userInteractionEnabled = false
        self.topBarHeight.constant = height
        let maxDuration = 0.5
        var duration: NSTimeInterval = maxDuration
        if let velo = velocity {
            duration = min(maxDuration, 600.0 / abs(velo))
        }
        self.mapView.userInteractionEnabled = false
        NSLayoutConstraint.deactivateConstraints([self.topBarBottomSpace])
        NSLayoutConstraint.activateConstraints([self.topBarHeight])
        self.releaseToViewLabel.hidden = true
        UIView.animateWithDuration(duration,
            animations: {
                self.topViewProperties(0.0)
                self.topView.layoutIfNeeded()
                self.mapOnBottom = false
                return
            }, completion: { (finished:Bool) in
                if let destinationPlacemark2 = self.destinationPlacemark {
                    self.mapView.removeAnnotation(destinationPlacemark2)
                    if let mapDirectionOverlay2 = self.mapDirectionOverlay {
                        self.mapView.removeOverlay(mapDirectionOverlay2)
                    }
                    self.mapView.showsUserLocation = false
                    self.destinationPlacemark = nil
                }
                return
            }
        )
    }


    func topViewProperties(offsetForAnimation: CGFloat) {

        self.mapView?.alpha        = 0.5 + offsetForAnimation * 0.5
        self.gradientView.alpha    = 1.0 - offsetForAnimation
        self.navBarBackgroundView.alpha     = 0.0 + offsetForAnimation
        self.stationIconView.alpha = 1.0 - offsetForAnimation
        self.stationIconView.transform = CGAffineTransformMakeScale(1 - offsetForAnimation, 1 - offsetForAnimation)
        self.borderBottomView.alpha = 0.0 + offsetForAnimation
        self.stationNameBottomSpace.constant = -28.0 - offsetForAnimation * 11.0
        self.distanceLabel.alpha = 0.0 + offsetForAnimation
        self.segmentedControl.alpha = 1.0 - offsetForAnimation
    }

    @IBAction func mapUpAction(sender: AnyObject) {
        moveMapViewUp(nil)
    }

    func scrollViewDidScroll(scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y + startHeight
        self.topBarHeight.constant = max(min(self.startHeight - offset, self.startHeight), 64)
        if (self.topBarHeight.constant < 71) {
            self.stationNameBottomSpace.constant = -22 - (self.topBarHeight.constant - 64)
        } else {
            self.stationNameBottomSpace.constant = -28
        }
        // the navbar title view has to be above the icon when we
        //  make the navbar smaller, but below  when we move the map down
        if (offset < 10) {
            self.navBarView.layer.zPosition = 0
        } else {
            self.navBarView.layer.zPosition = 2
        }
        self.borderBottomView.alpha = offset / 80
        self.mapView?.alpha = min(1 - (offset / 80), 0.5)
        self.stationIconView.alpha = 1 - (offset / 80)
        self.distanceLabel.alpha =  offset / 80
        self.segmentedControl.alpha = 1 - (offset / 80)
    }
    
    func mapViewDidFinishRenderingMap(mapView: MKMapView, fullyRendered: Bool) {
        if(self.mapView.alpha <= 0.6) {
            UIView.animateWithDuration(0.8,
                delay: 0.0,
                options: UIViewAnimationOptions.CurveLinear,
                animations: {
                    self.mapView?.alpha = 0.5
                    return
                }, completion: { (finished:Bool) in
                }
            )
        }
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
        }
        return cell
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

    func getIconViewAsImage(view: UIView) -> UIImage {
        view.opaque = false
        //in case we want a different backgroundColor
        //let oldBG = view.backgroundColor
        //view.backgroundColor = UIColor.blueColor();

        UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0.0);
        view.layer.renderInContext(UIGraphicsGetCurrentContext()!)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        //view.backgroundColor = oldBG

        return img;
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
    

    
}
