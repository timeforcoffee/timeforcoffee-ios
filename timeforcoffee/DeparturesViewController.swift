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

class DeparturesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate, APIControllerProtocol, MGSwipeTableCellDelegate, MKMapViewDelegate {

    @IBOutlet var appsTableView : UITableView?
    var api : APIController?
    var refreshControl:UIRefreshControl!
    var departures: [TFCDeparture]?
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

    @IBOutlet weak var navBarImage: UIImageView!

//    @IBOutlet weak var stationIconImage: UIImageView!

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

    var mapOnBottom: Bool = false

    @IBAction func iconTouchUp(sender: UIButton) {
        println("iconTouchUp")
        favoriteClicked(nil)
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
            if (mapSwipeUpStart != nil) {
                if ((UIScreen.mainScreen().bounds.size.height - topBarCalculatedHeight)  > 40) {
                    moveMapViewUp(sender.velocityInView(self.appsTableView))
                } else {
                    moveMapViewDown(sender.velocityInView(self.appsTableView))
                }
            } else if (topBarCalculatedHeight > releasePoint) {
                moveMapViewDown(sender.velocityInView(self.appsTableView))
            } else {
                moveMapViewUp(sender.velocityInView(self.appsTableView))

            }
            return
        }
        topBarHeight?.constant = topBarCalculatedHeight
        if (topBarCalculatedHeight < releasePoint) {
            let offsetForAnimation: CGFloat = ((topBarCalculatedHeight - startHeight) / (releasePoint - startHeight))
            self.mapView?.alpha = 0.5 + offsetForAnimation * 0.5
            self.gradientView.alpha = 1.0 - offsetForAnimation
            self.navBarImage.alpha = 0.0 + offsetForAnimation * 1.0
            self.stationIconView.alpha = 1.0 - offsetForAnimation
            self.stationIconView.transform = CGAffineTransformMakeScale(1 - offsetForAnimation, 1 - offsetForAnimation)
            self.borderBottomView.alpha = offsetForAnimation
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
            self.mapView?.alpha = 1.0
            self.gradientView.alpha = 0.0
            self.navBarImage.alpha = 1.0
            self.stationIconView.alpha = 0.0
        }

        if (topBarCalculatedHeight > mapHeight.constant) {
            mapHeight.constant = topBarCalculatedHeight + 200
        }
    }

    func drawStationAndWay() {
        self.destinationPlacemark = MKPlacemark(coordinate: (station?.coord?.coordinate)!, addressDictionary: nil)
        self.mapView.addAnnotation(destinationPlacemark)

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
                for r in response.routes { println("route = \(r)") }
                var route: MKRoute = response.routes[0] as MKRoute;
                self.mapDirectionOverlay = route.polyline
                self.mapView.addOverlay(self.mapDirectionOverlay)

               // self.mapView.setVisibleMapRect(route.polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 30.0, left: 30.0, bottom: 30.0, right: 30.0), animated: true)


               // var time =  Int(round(route.expectedTravelTime / 60))
               // var meters = Int(route.distance);
               // self.distanceLabel.text = "\(time) min, \(meters) m"
                //println(route.expectedTravelTime / 60)
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

    func moveMapViewDown(velocity: CGPoint?) {
        let height = UIScreen.mainScreen().bounds.size.height
        self.releaseToViewLabel.hidden = true
        self.mapView.userInteractionEnabled = true
        if (self.mapHeight.constant < height + 200) {
            self.mapHeight.constant = height + 200
        }
        var duration: NSTimeInterval = Double(600.0) / Double(abs((velocity?.y)!))
        if (duration > 0.5) {
            duration = 0.5
        }
        NSLayoutConstraint.deactivateConstraints([self.topBarHeight])
        NSLayoutConstraint.activateConstraints([self.topBarBottomSpace])
        self.topBarBottomSpace?.constant = 0

        UIView.animateWithDuration(duration,
            animations: {
                self.view.layoutIfNeeded()
                self.stationIconView.alpha = 0.0
                return
            }, completion: { (finished:Bool) in
                if (finished) {
                    self.mapOnBottom = true
                    self.topBarHeight?.constant = self.topView.frame.height
                }
            }
        )
    }

    func moveMapViewUp(velocity: CGPoint?) {
        let height = CGFloat(startHeight)

        self.mapView.userInteractionEnabled = false
        self.topBarHeight.constant = height
        var duration: NSTimeInterval = Double(600.0) / Double(abs((velocity?.y)!))
        if (duration > 0.5) {
            duration = 0.5
        }

        UIView.animateWithDuration(duration,
            animations: {
                self.mapView?.alpha = 0.5
                self.gradientView?.alpha = 1.0
                self.navBarImage.alpha = 0.0
                self.stationIconView.alpha = 1.0
                self.stationIconView.transform = CGAffineTransformMakeScale(1, 1)
                self.borderBottomView.alpha = 0
                self.topView.layoutIfNeeded()
                self.mapOnBottom = false
                return
            }, completion: { (finished:Bool) in
                if (self.destinationPlacemark != nil) {
                    self.mapView.removeAnnotation(self.destinationPlacemark)
                    self.mapView.removeOverlay(self.mapDirectionOverlay)

                    self.destinationPlacemark = nil
                }
                return
            }
        )
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y + startHeight
        self.topBarHeight.constant = max(min(self.startHeight - offset, self.startHeight), 64)
        self.borderBottomView.alpha = offset / 80
        self.mapView?.alpha = min(1 - (offset / 80), 0.5)
        self.stationIconView.alpha = 1 - (offset / 80)
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
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

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        gestureRecognizer = self.navigationController?.interactivePopGestureRecognizer.delegate
        self.navigationController?.interactivePopGestureRecognizer.delegate = nil
        self.edgesForExtendedLayout = UIRectEdge.None;

        nameLabel.text = self.station?.name
        let currentLocation = TFCLocationManager.getCurrentLocation()
        self.distanceLabel.text = self.station?.getDistanceForDisplay(currentLocation, completion: {
            text in
            if (text != nil) {
                self.distanceLabel.text = text
            }
        })

        self.api = APIController(delegate: self)
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.departures = nil;
        self.api?.getDepartures(self.station?.st_id)
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
        self.mapView?.alpha = 0.0
        self.mapView?.userInteractionEnabled = false;
        var region = MKCoordinateRegionMakeWithDistance((station?.coord?.coordinate)! ,300,300);
        self.mapView.setRegion(region, animated: false)
        self.mapView.showsUserLocation = true
        self.mapView.delegate = self

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBecomeInactive:", name: "UIApplicationDidEnterBackgroundNotification", object: nil)
    }

    override func viewWillDisappear(animated: Bool) {
        self.navigationController?.navigationBar.setBackgroundImage(nil, forBarMetrics: UIBarMetrics.Default)
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        self.navigationController?.interactivePopGestureRecognizer.delegate = gestureRecognizer

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
        self.departures = nil
        self.api?.getDepartures(self.station?.st_id)
    }

    deinit {
        println("deinit")
         NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    override func viewDidDisappear(animated: Bool) {
        station = nil
        api = nil
        departures = nil
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func favoriteClicked(sender: UIBarButtonItem?) {
        func completion() {
        }

        println("favoriteClicked")
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
        self.departures = nil
        self.api?.getDepartures(self.station?.st_id)
    }
    
    internal func setStation(station: TFCStation) {
        self.station = station
        self.departures = nil
    }

    func didReceiveAPIResults(results: JSONValue, error: NSError?, context: Any?) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        self.refreshControl.endRefreshing()
        dispatch_async(dispatch_get_main_queue(), {
            if (error != nil) {
                self.networkErrorMsg = NSLocalizedString("Network error. Please try again", comment:"")
            } else {
                self.networkErrorMsg = nil
            }
            self.departures = TFCDeparture.withJSON(results)
            if (self.station?.name == "") {
                self.station?.name = TFCDeparture.getStationNameFromJson(results)!;
                self.nameLabel.text = self.station?.name
            }
            self.appsTableView!.reloadData()
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        })
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (self.departures == nil || self.departures!.count == 0) {
            return 1
        }
        return self.departures!.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell:MGSwipeTableCell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier) as MGSwipeTableCell

        cell.delegate = self
        cell.tag = indexPath.row


        let lineNumberLabel = cell.viewWithTag(100) as UILabel
        let destinationLabel = cell.viewWithTag(200) as UILabel
        let departureLabel = cell.viewWithTag(300) as UILabel
        let minutesLabel = cell.viewWithTag(400) as UILabel
        if (station != nil) {
            let station2 = station!
            
            if (self.departures == nil || self.departures!.count == 0) {
                departureLabel.text = nil
                lineNumberLabel.text = nil
                minutesLabel.text = nil
                lineNumberLabel.backgroundColor = UIColor.clearColor()
                if (self.departures == nil) {
                    destinationLabel.text = NSLocalizedString("Loading", comment: "Loading ..")
                } else {
                    destinationLabel.text = NSLocalizedString("No departures found.", comment: "")
                    if (self.networkErrorMsg != nil) {
                        departureLabel.text = self.networkErrorMsg
                    }
                }
                return cell
            }
            
            let departure: TFCDeparture = self.departures![indexPath.row]
            
            lineNumberLabel.text = departure.getLine()
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
            
            lineNumberLabel.layer.cornerRadius = 4.0
            lineNumberLabel.layer.masksToBounds = true
            
            if (departure.colorBg != nil) {
                lineNumberLabel.backgroundColor = UIColor(netHexString:departure.colorBg!);
                lineNumberLabel.textColor = UIColor(netHexString:departure.colorFg!);
            } else {
                lineNumberLabel.textColor = UIColor.blackColor()
                lineNumberLabel.backgroundColor = UIColor.whiteColor()
            }
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
            if (self.departures != nil) {
                if (direction == MGSwipeDirection.RightToLeft) {
                    let departure: TFCDeparture = self.departures![cell.tag]
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
        let departure: TFCDeparture = self.departures![cell.tag]
        let station2 = station!
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
