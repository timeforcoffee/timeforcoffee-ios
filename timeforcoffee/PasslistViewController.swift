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
    var annotations:[StationAnnotation]?
    var viewAppeared: Bool = false
    var mapMovedDownOnce = false
    var annotationUpper:CLLocationCoordinate2D?
    var annotationLower:CLLocationCoordinate2D?

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var BackButton: UIButton!
    @IBOutlet weak var favButton: UIButton!

    @IBOutlet weak var stationIconButton: DepartureLineLabel!

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
        if let stationName = self.departure?.getStation()?.name {
            self.distanceLabel.text = NSLocalizedString("From", comment: "") + ": \(stationName)"
        }
        super.distanceLabelVisibleOnTop = true
        super.distanceLabel.alpha = 0.9
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true

        startHeight = topBarHeight.constant
        self.appsTableView?.contentInset = UIEdgeInsets(top: startHeight, left: 0, bottom: 0, right: 0)

        favButton.addTarget(self, action: "favoriteClicked:", forControlEvents: UIControlEvents.TouchUpInside)
 //       stationIconButton.addTarget(self, action: "favoriteClicked:", forControlEvents: UIControlEvents.TouchUpInside)


        if let departure = departure {
            if (departure.isFavorite() == true) {
                favButton.setTitle("★", forState: UIControlState.Normal)
            }
            self.stationIconButton.setStyle("normal", departure: departure)
        }

        self.stationIconView.layer.cornerRadius = self.stationIconView.frame.width / 2
        //        self.stationIconImage.image = station?.getIcon()

        self.gradientView.image = UIImage(named: "gradient.png")

        topViewProperties(0.0)
        self.mapView?.userInteractionEnabled = false;
        self.mapView?.rotateEnabled = false

        if let coordinate = departure?.getStation()?.coord?.coordinate {
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
    }


    override func drawAnnotations() {

        //FIXME draw all stations...

        mapView.removeAnnotations(mapView.annotations)

        if let station = departure?.getStation() {
            drawStationAndWay(station, drawStation: false)
            annotationUpper = station.coord?.coordinate
            annotationLower = station.coord?.coordinate
        }
        if let passlist = departure?.getPasslist() {
            for (pass) in passlist {
                if let coord = pass.coord {
                    let annotation = StationAnnotation(title: pass.name, distance: nil, coordinate: coord, pass: pass)

                    let latitude = coord.latitude
                    let longitude = coord.longitude
                    if (latitude > annotationUpper?.latitude) {annotationUpper?.latitude = latitude}
                    if (latitude < annotationLower?.latitude) {annotationLower?.latitude = latitude}
                    if (longitude > annotationUpper?.longitude) {annotationUpper?.longitude = longitude}
                    if (longitude < annotationLower?.longitude) {annotationLower?.longitude = longitude}
                    mapView.addAnnotation(annotation)
                }
            }
        }
    }

    
    override func getMapIcon(pass:TFCPass? = nil) -> UIImage {
        if (pass?.isFirst == true) {
            let (image, _) = getIconAsImage(pass?.getStation())
            if let image = image {
                return image
            }
        }
        let ident = getIconIdentifier(pass: pass)
        return UIImage(named: "\(ident)")!
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
        self.stationIconButton.toggleIcon(nil)
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

    override func moveMapViewDown(velocity: Double?) {
        super.moveMapViewDown(velocity)
    }

    override func mapViewReachedBottom() {
        super.mapViewReachedBottom()
        if (!mapMovedDownOnce) {


            var locationSpan:MKCoordinateSpan = MKCoordinateSpan()
            var locationCenter:CLLocationCoordinate2D = CLLocationCoordinate2D()
            if let annotationUpper = annotationUpper, annotationLower = annotationLower {
                locationSpan.latitudeDelta = (annotationUpper.latitude - annotationLower.latitude) * 1.5;
                locationSpan.longitudeDelta = (annotationUpper.longitude - annotationLower.longitude) * 1.2;
                locationCenter.latitude = (annotationUpper.latitude + annotationLower.latitude) / 2;
                locationCenter.longitude = (annotationUpper.longitude + annotationLower.longitude) / 2;
                let region = MKCoordinateRegionMake(locationCenter, locationSpan)
                mapView.setRegion(mapView.regionThatFits(region), animated: true)
            } else {
                if let annotations = self.annotations {
                    //since our map is bigger than the view, this may produce pois outside of the viewable area
                    mapView.showAnnotations(annotations, animated: true)
                }
            }
            mapMovedDownOnce = true
        }
        mapView.showsUserLocation = true
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell:UITableViewCell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier, forIndexPath: indexPath) as UITableViewCell

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
                    destinationLabel.text = NSLocalizedString("No connection information found.", comment: "")
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
                if let firstscheduled = passlist?[0].getRealDepartureDate() {
                    minutesLabel.text = pass.getMinutes(firstscheduled)
                } else {
                    minutesLabel.text = ""
                }
                minutesLabel.textColor = UIColor.blackColor()

                let (departureTimeAttr, departureTimeString) = pass.getDepartureTime()
                if (departureTimeAttr != nil) {
                    departureLabel.text = nil
                    departureLabel.attributedText = departureTimeAttr
                } else {
                    departureLabel.attributedText = nil
                    departureLabel.text = departureTimeString
                }
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
