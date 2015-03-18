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

class DeparturesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate, MGSwipeTableCellDelegate, MKMapViewDelegate, TFCDeparturesUpdatedProtocol {

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
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var BackButton: UIButton!
    @IBOutlet weak var favButton: UIButton!

    @IBOutlet weak var distanceLabel: UILabel!

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

    @IBAction func iconTouchUp(sender: UIButton) {
        favoriteClicked(nil)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    deinit {
        println("deinit")
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    override func viewWillAppear(animated: Bool) {
        if (self.mapOnBottom) {
            self.mapView.showsUserLocation = true
        }
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        gestureRecognizer = self.navigationController?.interactivePopGestureRecognizer.delegate
        self.navigationController?.interactivePopGestureRecognizer.delegate = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = UIRectEdge.None;

        nameLabel.text = self.station?.name
        let currentLocation = TFCLocationManager.getCurrentLocation()
        self.distanceLabel.text = self.station?.getDistanceForDisplay(currentLocation, completion: {
            text in
            if (text != nil) {
                self.distanceLabel.text = text
            }
        })

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
        var region = MKCoordinateRegionMakeWithDistance((station?.coord?.coordinate)! ,450,450);
        self.mapView.setRegion(region, animated: false)
        // put it to true when within a few hundred meters
        self.mapView.showsUserLocation = false
        self.mapView.delegate = self
        displayDepartures()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBecomeInactive:", name: "UIApplicationDidEnterBackgroundNotification", object: nil)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        let gtracker = GAI.sharedInstance().defaultTracker
        gtracker.set(kGAIScreenName, value: "departures")
        gtracker.send(GAIDictionaryBuilder.createScreenView().build())
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
        //fixme, station should stay in NSCache, and especially departures
//        station?.clearDepartures ()
        station = nil
        self.navigationController?.interactivePopGestureRecognizer.delegate = gestureRecognizer
        NSNotificationCenter.defaultCenter().removeObserver(self)
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
        self.destinationPlacemark = MKPlacemark(coordinate: (station?.coord?.coordinate)!, addressDictionary: nil)
        self.mapView.addAnnotation(destinationPlacemark)
        self.mapView.showsUserLocation = true

        let currentLocation = TFCLocationManager.getCurrentLocation()?
        let currentCoordinate = currentLocation?.coordinate

        if (currentCoordinate == nil || station?.getDistanceInMeter(currentLocation) >= 5000) {
            return
        }
        var sourcePlacemark:MKPlacemark = MKPlacemark(coordinate: currentCoordinate!, addressDictionary: nil)

        var sourceMapItem = MKMapItem(placemark: sourcePlacemark)
        var destinationMapItem = MKMapItem(placemark: destinationPlacemark)
        var directionRequest:MKDirectionsRequest = MKDirectionsRequest()

        directionRequest.setSource(sourceMapItem)
        directionRequest.setDestination(destinationMapItem)
        directionRequest.transportType = MKDirectionsTransportType.Walking
        directionRequest.requestsAlternateRoutes = false

        var directions:MKDirections = MKDirections(request: directionRequest)
        directions.calculateDirectionsWithCompletionHandler({
            (response: MKDirectionsResponse!, error: NSError?) in
            if error != nil{
                println("Error")
            }
            if response != nil{
//                for r in response.routes { println("route = \(r)") }
                var route: MKRoute = response.routes[0] as MKRoute;
                self.mapDirectionOverlay = route.polyline
                self.mapView.addOverlay(self.mapDirectionOverlay)
            }
            else{
                println("No response")
            }
            println(error?.description)
        })
    }

    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if overlay is MKPolyline {
            var polylineRenderer = MKPolylineRenderer(overlay: overlay)
            polylineRenderer.strokeColor = UIColor.blueColor()
            polylineRenderer.lineWidth = 1
            return polylineRenderer
        }
        return nil
    }

    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {

        if (annotation.isKindOfClass(MKUserLocation)) {
            return nil
        }

        let annotationIdentifier = "CustomViewAnnotation"
        var annotationView = self.mapView.dequeueReusableAnnotationViewWithIdentifier(annotationIdentifier)

        if (annotationView == nil) {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: annotationIdentifier)
        }

        annotationView.image = getIconViewAsImage(self.stationIconView)
        annotationView.opaque = false
        annotationView.alpha = 1.0
        annotationView.frame.size.height = 30
        annotationView.frame.size.width = 30

        return annotationView;

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
        gtracker.send(GAIDictionaryBuilder.createScreenView().build())

    }

    func moveMapViewUp(velocity: Double?) {

        let height = CGFloat(startHeight)

        self.mapView.userInteractionEnabled = false
        self.topBarHeight.constant = height
        let maxDuration = 0.5
        var duration: NSTimeInterval = maxDuration
        if (velocity != nil) {
            duration = min(maxDuration, 600.0 / abs(velocity!))
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
                if (self.destinationPlacemark != nil) {
                    self.mapView.removeAnnotation(self.destinationPlacemark)
                    self.mapView.removeOverlay(self.mapDirectionOverlay)
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
    }

    @IBAction func mapUpAction(sender: AnyObject) {
        moveMapViewUp(nil)
    }

    func scrollViewDidScroll(scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y + startHeight
        self.topBarHeight.constant = max(min(self.startHeight - offset, self.startHeight), 64)
        self.borderBottomView.alpha = offset / 80
        self.mapView?.alpha = min(1 - (offset / 80), 0.5)
        self.stationIconView.alpha = 1 - (offset / 80)
    }
    
    func mapViewDidFinishRenderingMap(mapView: MKMapView!, fullyRendered: Bool) {
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

    }
    
    func applicationDidBecomeActive(notification: NSNotification) {
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
    }


    func refresh(sender:AnyObject)
    {
        // Code to refresh table view
        self.station?.updateDepartures(self, force: true)
    }

    func displayDepartures() {
        station!.removeObseleteDepartures()
        self.appsTableView?.reloadData()
        self.station?.updateDepartures(self)
    }

    internal func setStation(station: TFCStation) {
        self.station = station
       // self.station?.clearDepartures()
    }

    func departuresUpdated(error: NSError?, context: Any?, forStation: TFCStation?) {
        self.refreshControl.endRefreshing()
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

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let departures = station?.getDepartures()
        if (departures == nil || departures!.count == 0) {
            return 1
        }
        return departures!.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell:MGSwipeTableCell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier) as MGSwipeTableCell

        cell.delegate = self
        cell.tag = indexPath.row


        let lineNumberLabel = cell.viewWithTag(100) as DepartureLineLabel
        let destinationLabel = cell.viewWithTag(200) as UILabel
        let departureLabel = cell.viewWithTag(300) as UILabel
        let minutesLabel = cell.viewWithTag(400) as UILabel
        if (station != nil) {
            let station2 = station!
            let departures = station2.getDepartures()
            if (departures == nil || departures!.count == 0) {
                departureLabel.text = nil
                minutesLabel.text = nil
                lineNumberLabel.hidden = true
                if (departures == nil) {
                    destinationLabel.text = NSLocalizedString("Loading", comment: "Loading ..")
                } else {
                    destinationLabel.text = NSLocalizedString("No departures found.", comment: "")
                    if (self.networkErrorMsg != nil) {
                        departureLabel.text = self.networkErrorMsg
                    }
                }
                return cell
            }
            lineNumberLabel.hidden = false
            let departure: TFCDeparture = station2.getDepartures()![indexPath.row]
            
            var unabridged = false
            if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
                unabridged = true
            }
            destinationLabel.text = departure.getDestinationWithSign(station, unabridged: unabridged)
            
            
            minutesLabel.text = departure.getMinutes()
            if (station2.isFiltered(departure)) {
                destinationLabel.textColor = UIColor.grayColor()
                minutesLabel.textColor = UIColor.grayColor()
            } else {
                destinationLabel.textColor = UIColor.blackColor()
                minutesLabel.textColor = UIColor.blackColor()
            }
            
            departureLabel.attributedText = departure.getDepartureTime()
            
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
        var buttons = []
        if (station != nil) {
            let station2 = station!
            let departures = station2.getDepartures()
            if (departures != nil) {
                if (direction == MGSwipeDirection.RightToLeft) {
                    let departure: TFCDeparture = departures![cell.tag]
                    if (station2.isFiltered(departure)) {
                        buttons = [MGSwipeButton( title:"Unfilter", backgroundColor: UIColor.redColor())]
                    } else {
                        buttons = [MGSwipeButton( title:"Filter", backgroundColor: UIColor.greenColor())]
                    }
                }
                expansionSettings.buttonIndex = 0
                expansionSettings.fillOnTrigger = true
                expansionSettings.threshold = 2.5
            }
        }
        return buttons
    }

    func swipeTableCell(cell: MGSwipeTableCell!, tappedButtonAtIndex index: Int, direction: MGSwipeDirection, fromExpansion: Bool) -> Bool {
        let station2 = station!
        let departures: [TFCDeparture] = station2.getDepartures()!
        let departure: TFCDeparture = departures[cell.tag]
        if (station2.isFiltered(departure)) {
            station2.unsetFilter(departure);
            var button = cell.rightButtons[0] as MGSwipeButton
            button.backgroundColor = UIColor.greenColor();
        } else {
            station2.setFilter(departure);
            var button = cell.rightButtons[0] as MGSwipeButton
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
        view.layer.renderInContext(UIGraphicsGetCurrentContext())
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
}
