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

final class PasslistViewController: WithMapViewController, UITableViewDataSource, TFCPasslistUpdatedProtocol {

    var departure: TFCDeparture?
    var networkErrorMsg: String?
    let kCellIdentifier: String = "DeparturesListCell"

    var viewAppeared: Bool = false

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var BackButton: UIButton!
    @IBOutlet weak var favButton: UIButton!

    @IBOutlet weak var stationIconButton: UIButton!

    @IBAction func BackButtonClicked(sender: UIButton) {
        self.navigationController?.popViewControllerAnimated(true)
    }

    @IBAction func iconTouchUp(sender: UIButton) {
        favoriteClicked(nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    deinit {
        DLog("deinit PasslistViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = UIRectEdge.None;

        nameLabel.text = self.departure?.getDestination()
        if let  stationName = self.departure?.getStation()?.name {
            self.distanceLabel.text = NSLocalizedString("From", comment: "") + ": \(stationName)"
        }
        super.distanceLabelVisibleOnTop = true
        super.distanceLabel.alpha = 0.9
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true

        startHeight = topBarHeight.constant
        self.appsTableView?.contentInset = UIEdgeInsets(top: startHeight, left: 0, bottom: 0, right: 0)

        favButton.addTarget(self, action: "favoriteClicked:", forControlEvents: UIControlEvents.TouchUpInside)
        stationIconButton.addTarget(self, action: "favoriteClicked:", forControlEvents: UIControlEvents.TouchUpInside)

        if (departure?.isFavorite() == true) {
            favButton.setTitle("★", forState: UIControlState.Normal)
        }

        self.stationIconView.layer.cornerRadius = self.stationIconView.frame.width / 2
        //        self.stationIconImage.image = station?.getIcon()

/* FIXME SHow the number instead of ...
        self.stationIconButton.setImage(station?.getIcon(), forState: UIControlState.Normal)

        self.gradientView.image = UIImage(named: "gradient.png")
*/
        topViewProperties(0.0)
        self.mapView?.userInteractionEnabled = false;
        self.mapView?.rotateEnabled = false

        /* FIXME show the whole way somehow
        if let coordinate = station?.coord?.coordinate {
            let region = MKCoordinateRegionMakeWithDistance(coordinate ,450,450);
            //with some regions, this fails, so check if it does and only then show a map
            let newRegion = self.mapView.regionThatFits(region)
            if (!(newRegion.span.latitudeDelta.isNaN)) {
                self.mapView.setRegion(newRegion, animated: false)
            }
        }
*/
        // put it to true when within a few hundred meters
        self.mapView.showsUserLocation = false
        self.mapView.delegate = self
        displayPasslist()
        DLog("viewDidLoad")
    }

    override func viewDidAppear(animated: Bool) {
        DLog("viewDidAppear")
        super.viewDidAppear(animated)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            let gtracker = GAI.sharedInstance().defaultTracker
            gtracker.set(kGAIScreenName, value: "passlist")
            gtracker.send(GAIDictionaryBuilder.createScreenView().build() as [NSObject : AnyObject]!)
        }
        viewAppeared = true

    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        departure = nil
    }


    override func drawStationAndWay() {
        //FIXME draw all stations...

        mapView.removeAnnotations(mapView.annotations)
/*
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
*/
    }

    func favoriteClicked(sender: UIBarButtonItem?) {
        func completion() {
        }

        if (self.departure?.isFavorite() == true) {
            self.departure?.unsetFavorite()
            favButton.setTitle("☆", forState: UIControlState.Normal)
        } else {
            self.departure?.setFavorite()
            favButton.setTitle("★", forState: UIControlState.Normal)
        }
        self.appsTableView?.reloadData()

    }

    func displayPasslist() {
        self.appsTableView?.reloadData()
        self.departure?.updatePasslist(self)

    }

    internal func setDeparture(departure departure: TFCDeparture) {
        self.departure = departure
    }

    func passlistUpdated(error: NSError?, context: Any?, forDeparture: TFCDeparture?) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        if (error != nil) {
            self.networkErrorMsg = NSLocalizedString("Network error. Please try again", comment:"")
        } else {
            self.networkErrorMsg = nil
        }
        self.appsTableView!.reloadData()
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let passlist = self.departure?.getPasslist() {
            let count = passlist.count
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

        let destinationLabel = cell.viewWithTag(99200) as! UILabel
        let departureLabel = cell.viewWithTag(99300) as! UILabel
        let minutesLabel = cell.viewWithTag(99400) as! UILabel

        if let departure = departure {
            let passlist = departure.getPasslist()
            if (passlist == nil || passlist!.count == 0) {
                departureLabel.text = nil
                minutesLabel.text = nil
                if (passlist == nil) {
                    destinationLabel.text = NSLocalizedString("Loading", comment: "Loading ..")
                } else {
                    destinationLabel.text = NSLocalizedString("No passlist found.", comment: "")
                    if (self.networkErrorMsg != nil) {
                        departureLabel.text = self.networkErrorMsg
                    }
                }
                return cell
            }

            if let pass = passlist?[indexPath.row] {

  /*              var unabridged = false
                if (UIDeviceOrientationIsLandscape(UIDevice.currentDevice().orientation)) {
                    unabridged = true
                }
*/
                destinationLabel.text = pass.name //abridged?
                if let firstscheduled = passlist?[0].scheduled {
                    minutesLabel.text = pass.getMinutes(firstscheduled)
                } else {
                    minutesLabel.text = ""
                }
                minutesLabel.textColor = UIColor.blackColor()
                departureLabel.text = pass.scheduled?.formattedWith("HH:mm")
            }

        }
        return cell
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.performSegueWithIdentifier("SegueBackToStationView", sender: nil)
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        let detailsViewController: DeparturesViewController = segue.destinationViewController as! DeparturesViewController
        let index = appsTableView?.indexPathForSelectedRow?.row
        if let index = index, station = self.departure?.getPasslist()?[index].getStation() {
            detailsViewController.setStation(station: station)
        }
    }
    
}
