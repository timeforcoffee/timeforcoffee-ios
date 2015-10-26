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

final class PasslistViewController: WithMapViewController, UITableViewDataSource {

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
        DLog("deinit DeparturesViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = UIRectEdge.None;

        nameLabel.text = self.departure?.getDestination()
      /* FIXME don't know what to show here
        let currentLocation = TFCLocationManager.getCurrentLocation()
        if (self.station?.coord != nil) {
            self.distanceLabel.text = self.station?.getDistanceForDisplay(currentLocation, completion: {
                text in
                if (text != nil) {
                    self.distanceLabel.text = text
                }
            })
        }*/

        UIApplication.sharedApplication().networkActivityIndicatorVisible = true

        startHeight = topBarHeight.constant
        self.appsTableView?.contentInset = UIEdgeInsets(top: startHeight, left: 0, bottom: 0, right: 0)

        favButton.addTarget(self, action: "favoriteClicked:", forControlEvents: UIControlEvents.TouchUpInside)
        stationIconButton.addTarget(self, action: "favoriteClicked:", forControlEvents: UIControlEvents.TouchUpInside)
/* FIXME show a star if that departure is a favorite
        if (station!.isFavorite()) {
            favButton.setTitle("★", forState: UIControlState.Normal)
        }
*/
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
    }

    override func viewDidAppear(animated: Bool) {
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
        /* FIXME toggle connection fav
        self.station!.toggleIcon(stationIconButton, icon: stationIconView, completion: completion)
        if (self.station!.isFavorite()) {
            favButton.setTitle("★", forState: UIControlState.Normal)
        } else {
            favButton.setTitle("☆", forState: UIControlState.Normal)
        }
        self.appsTableView?.reloadData()
        SKTUser.currentUser().addProperties(["usedFavorites": true])
*/
    }


    func refresh(sender:AnyObject)
    {
        // Code to refresh table view
      //  self.station?.updateDepartures(self, force: true, context: nil)
    }

    func displayPasslist() {
        self.appsTableView?.reloadData()
    }

    internal func setDeparture(departure departure: TFCDeparture) {
        self.departure = departure
    }

    func departuresUpdated(error: NSError?, context: Any?, forStation: TFCStation?) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false

        //FIXME use with departures..
        /*
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
        }*/
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
     /* FIXME get actual passlist...
let passlist = departure.getPasslist()
        if let passlist = passlist {
            let count = passlist.count
            if count == 0 {
                return 1
            }
            return count
        }
*/        return 1

    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell:MGSwipeTableCell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier) as! MGSwipeTableCell

        cell.delegate = self
        cell.tag = indexPath.row


        let lineNumberLabel = cell.viewWithTag(99100) as! DepartureLineLabel
        let destinationLabel = cell.viewWithTag(99200) as! UILabel
        let departureLabel = cell.viewWithTag(99300) as! UILabel
        let minutesLabel = cell.viewWithTag(99400) as! UILabel
        /* FIXME ...
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
*/
        return cell
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.performSegueWithIdentifier("SegueToPasslistView", sender: nil)
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // FIXME
/*    let detailsViewController: DeparturesViewController = segue.destinationViewController as! DeparturesViewController
        let index = appsTableView?.indexPathForSelectedRow?.row
        if let index = index, station = self.departure.getPasslist()?[index].getStation() {

            departure.getDepartureTime()
            detailsViewController.setStation(station: station!);
        }
  */
    }
    
}
