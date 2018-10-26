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

    @IBAction func BackButtonClicked(_ sender: UIButton) {
        let _ = self.navigationController?.popViewController(animated: true)
    }

    @IBAction func iconTouchUp(_ sender: UIButton) {
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
        self.edgesForExtendedLayout = UIRectEdge();

        nameLabel.text = self.departure?.getDestination()
        if let stationName = self.departure?.getStation()?.name {
            self.distanceLabel.text = NSLocalizedString("From", comment: "") + ": \(stationName)"
        }
        super.distanceLabelVisibleOnTop = true
        super.distanceLabel.alpha = 0.9
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        if #available(iOS 11.0, *) {
            if let navController = self.navigationController {
                safeAreaTop = navController.view.safeAreaInsets.top
            }
        } else {
            safeAreaTop = 20
        }
        topBarHeight.constant = safeAreaTop + 130

        startHeight = topBarHeight.constant

        self.appsTableView?.contentInset = UIEdgeInsets(top: 130, left: 0, bottom: 0, right: 0)

        favButton.addTarget(self, action: #selector(PasslistViewController.favoriteClicked(_:)), for: UIControl.Event.touchUpInside)
 //       stationIconButton.addTarget(self, action: "favoriteClicked:", forControlEvents: UIControlEvents.TouchUpInside)


        if let departure = departure {

            favButton.accessibilityLabel = NSLocalizedString("Favorite Connection?", comment: "Favorite Connection?")

            if (departure.isFavorite() == true) {
                favButton.setTitle("★", for: UIControl.State())
                favButton.accessibilityHint = NSLocalizedString("Double-Tap for unfavoriting this connection", comment: "Double-Tap for unfavoriting this connection")
                favButton.accessibilityValue = NSLocalizedString("Yes", comment: "Yes")
            } else {
                favButton.accessibilityValue = NSLocalizedString("No", comment: "No")
                favButton.accessibilityHint = NSLocalizedString("Double-Tap for favoriting this connection", comment: "Double-Tap for favoriting this connection")
            }
            self.stationIconButton.setStyle("normal", departure: departure)
        }

        self.stationIconView.layer.cornerRadius = self.stationIconView.frame.width / 2
        //        self.stationIconImage.image = station?.getIcon()

        self.gradientView.image = UIImage(named: "gradient.png")

        topViewProperties(0.0)
        self.mapView?.isUserInteractionEnabled = false;
        self.mapView?.isRotateEnabled = false

        if let coordinate = departure?.getStation()?.coord?.coordinate {
            let region = MKCoordinateRegion(center: coordinate ,latitudinalMeters: 450,longitudinalMeters: 450);
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

    override func viewDidAppear(_ animated: Bool) {
        DLog("viewDidAppear")
        super.viewDidAppear(animated)
        GATracker.sharedInstance?.sendScreenName("passlist")
        viewAppeared = true

    }

    override func viewDidDisappear(_ animated: Bool) {
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
                if let coord = pass.coord
                {

                    let annotation = StationAnnotation(title: pass.name, distance: nil, coordinate: coord, pass: pass) 
                    if (annotationUpper != nil && annotationLower != nil) {
                        let latitude = coord.latitude
                        let longitude = coord.longitude
                        if (latitude > annotationUpper!.latitude) {annotationUpper!.latitude = latitude}
                        if (latitude < annotationLower!.latitude) {annotationLower!.latitude = latitude}
                        if (longitude > annotationUpper!.longitude) {annotationUpper!.longitude = longitude}
                        if (longitude < annotationLower!.longitude) {annotationLower!.longitude = longitude}
                    }
                    mapView.addAnnotation(annotation)
                }
            }
        }
    }

    
    override func getMapIcon(_ pass:TFCPass? = nil) -> UIImage {
        if (pass?.isFirst == true) {
            let (image, _) = getIconAsImage(pass?.getStation())
            if let image = image {
                return image
            }
        }
        let ident = getIconIdentifier(pass: pass)
        return UIImage(named: "\(ident)")!
    }

    @objc func favoriteClicked(_ sender: UIBarButtonItem?) {
        func completion() {
        }

        if (self.departure?.isFavorite() == true) {
            self.departure?.unsetFavorite()
            favButton.setTitle("☆", for: UIControl.State())
        } else {
            self.departure?.setFavorite()
            favButton.setTitle("★", for: UIControl.State())
        }
        self.stationIconButton.toggleIcon(nil)
        self.appsTableView?.reloadData()

    }

    func displayPasslist() {
        self.appsTableView?.reloadData()
        self.departure?.updatePasslist(self)

    }

    internal func setDeparture(departure: TFCDeparture) {
        self.departure = departure
    }

    func passlistUpdated(_ error: Error?, context: Any?, forDeparture: TFCDeparture?) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        if (error != nil) {
            self.networkErrorMsg = NSLocalizedString("Network error. Please try again", comment:"")
        } else {
            self.networkErrorMsg = nil
        }
        self.appsTableView!.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let passlist = self.departure?.getPasslist() {
            let count = passlist.count
            if count == 0 {
                return 1
            }
            return count
        }
        return 1
    }

    override func moveMapViewDown(_ velocity: Double?) {
        super.moveMapViewDown(velocity)
    }

    override func mapViewReachedBottom() {
        super.mapViewReachedBottom()
        if (!mapMovedDownOnce) {


            var locationSpan:MKCoordinateSpan = MKCoordinateSpan()
            var locationCenter:CLLocationCoordinate2D = CLLocationCoordinate2D()
            if let annotationUpper = annotationUpper, let annotationLower = annotationLower {
                locationSpan.latitudeDelta = (annotationUpper.latitude - annotationLower.latitude) * 1.5;
                locationSpan.longitudeDelta = (annotationUpper.longitude - annotationLower.longitude) * 1.2;
                locationCenter.latitude = (annotationUpper.latitude + annotationLower.latitude) / 2;
                locationCenter.longitude = (annotationUpper.longitude + annotationLower.longitude) / 2;
                let region = MKCoordinateRegion(center: locationCenter, span: locationSpan)
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

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:UITableViewCell = tableView.dequeueReusableCell(withIdentifier: kCellIdentifier, for: indexPath) as UITableViewCell

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
                minutesLabel.textColor = UIColor.black

                let (departureTimeAttr, departureTimeString) = pass.getDepartureTime()
                let (arrivalTimeAttr, arrivalTimeString) = pass.getDepartureTime(pass.arrivalScheduled, realtime: pass.arrivalRealtime)

                if (pass.scheduled != nil && pass.arrivalScheduled != nil && pass.realtime != pass.arrivalRealtime) {
                    departureLabel.text = nil
                  //  departureLabel.text = "complicated"
                    let labelAttr = NSMutableAttributedString(string: NSLocalizedString("Arr", comment: "Arrival") + ": ")
                    if let arrivalTimeAttr = arrivalTimeAttr {
                        labelAttr.append(arrivalTimeAttr)
                    } else {
                        if let arrivalTimeString = arrivalTimeString {
                            labelAttr.append(NSMutableAttributedString(string: arrivalTimeString))
                        }
                    }

                    labelAttr.append(NSMutableAttributedString(string: " / "  + NSLocalizedString("Dep", comment: "Departure") + ": "))
                    if let departureTimeAttr = departureTimeAttr {
                        labelAttr.append(departureTimeAttr)
                    } else {
                        if let departureTimeString = departureTimeString {
                            labelAttr.append(NSMutableAttributedString(string: departureTimeString))
                        }
                    }
                    departureLabel.attributedText = labelAttr

                } else if (pass.arrivalScheduled != nil) {
                    if let arrivalTimeAttr = arrivalTimeAttr {
                        departureLabel.text = nil
                        let attrPre = NSMutableAttributedString(string: NSLocalizedString("Arr", comment: "Arrival") + ": ")
                        attrPre.append(arrivalTimeAttr)
                        departureLabel.attributedText = attrPre
                    } else {
                        departureLabel.attributedText = nil
                        departureLabel.text = NSLocalizedString("Arr", comment: "Arrival") + ": \(arrivalTimeString!)"
                    }
                } else {
                    let arrDepString:String
                    // for the first row, it's only Departure
                    if (indexPath.row == 0) {
                        arrDepString = NSLocalizedString("Dep", comment: "Departure") + ": "
                    } else {
                        arrDepString = NSLocalizedString("Arr", comment: "Arrival") + " / " + NSLocalizedString("Dep", comment: "Departure") + ": "
                    }
                    if let departureTimeAttr = departureTimeAttr {
                        departureLabel.text = nil
                        let attrPre = NSMutableAttributedString(string: arrDepString)
                        attrPre.append(departureTimeAttr)
                        departureLabel.attributedText = attrPre
                    } else {
                        departureLabel.attributedText = nil
                        departureLabel.text =  "\(arrDepString)\(departureTimeString!)"
                    }
                }
            }

        }
        return cell
    }

    @objc func tableView(_ tableView: UITableView, didSelectRowAtIndexPath indexPath: IndexPath) {
        if let _ = getStationForSelect(indexPath) {
            self.performSegue(withIdentifier: "SegueBackToStationView", sender: nil)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let detailsViewController: DeparturesViewController = segue.destination as! DeparturesViewController

        if let station = getStationForSelect(appsTableView?.indexPathForSelectedRow) {
            detailsViewController.setStation(station: station)
        }
    }

    fileprivate func getStationForSelect(_ indexpath:IndexPath?) -> TFCStation? {
        if let index = indexpath?.row, let stations = self.departure?.getPasslist() {
            if (index < stations.count) {
                if let station = stations[index].getStation() {
                    return station
                }
            }
        }
        return nil
    }
}
