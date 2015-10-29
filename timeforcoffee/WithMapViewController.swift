//
//  WithMapView.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 26.10.15.
//  Copyright © 2015 opendata.ch. All rights reserved.
//

import Foundation
import timeforcoffeeKit
import MapKit
import MGSwipeTableCell


class WithMapViewController: UIViewController, UITableViewDelegate, UIScrollViewDelegate, MGSwipeTableCellDelegate, MKMapViewDelegate {

    var mapOnBottom: Bool = false
    var gestureRecognizer: UIGestureRecognizerDelegate?
    var startHeight: CGFloat!
    var mapSwipeUpStart: CGFloat?
    var destinationPlacemark: MKPlacemark?
    var mapDirectionOverlay: MKOverlay?
    var distanceLabelVisibleOnTop = false
    var station: TFCStation?

    @IBOutlet var appsTableView : UITableView?

    @IBOutlet weak var mapHeight: NSLayoutConstraint!
    @IBOutlet weak var gradientView: UIImageView!
    @IBOutlet weak var navBarBackgroundView: UIView!

    @IBOutlet var topBarHeight: NSLayoutConstraint!
    @IBOutlet weak var stationNameBottomSpace: NSLayoutConstraint!
    @IBOutlet weak var navBarView: UIView!
    @IBOutlet weak var borderBottomView: UIView!
    @IBOutlet internal weak var stationIconView: UIView!
    @IBOutlet weak var distanceLabel: UILabel!

    @IBOutlet weak var topView: UIView!

    @IBOutlet var topBarBottomSpace: NSLayoutConstraint!
    @IBOutlet weak var releaseToViewLabel: UILabel!

    @IBOutlet weak var mapView: MKMapView!

    override func viewWillAppear(animated: Bool) {
        if (self.mapOnBottom) {
            self.mapView.showsUserLocation = true
        }
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        gestureRecognizer = self.navigationController?.interactivePopGestureRecognizer!.delegate
        self.navigationController?.interactivePopGestureRecognizer!.delegate = nil
    }

    override final func viewWillDisappear(animated: Bool) {
        self.mapView.showsUserLocation = false
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        self.navigationController?.interactivePopGestureRecognizer!.delegate = gestureRecognizer
    }

    override final func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if (self.mapOnBottom && self.topBarBottomSpace.active == false) {
            //needed for example on ration
            NSLayoutConstraint.deactivateConstraints([self.topBarHeight])
            NSLayoutConstraint.activateConstraints([self.topBarBottomSpace])
            self.view.layoutIfNeeded()
        }
    }

    func scrollViewDidScroll(scrollView: UIScrollView) {
        scrolled(scrollView)
    }

    func scrolled(scrollView: UIScrollView) -> CGFloat {
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
        if (!distanceLabelVisibleOnTop) {
            self.distanceLabel.alpha =  offset / 80
        }
        return offset
    }

    @IBAction final func panOnTopView(sender: UIPanGestureRecognizer) {
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
                    drawAnnotations()
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
                    self.mapViewReachedBottom()
                }
            }
        )
        let gtracker = GAI.sharedInstance().defaultTracker
        gtracker.set(kGAIScreenName, value: "departuresMap")
        gtracker.send(GAIDictionaryBuilder.createScreenView().build() as [NSObject : AnyObject]!)
    }

    func mapViewReachedBottom() {
        self.mapOnBottom = true
        self.topBarHeight?.constant = self.topView.frame.height
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
        if (!distanceLabelVisibleOnTop) {
            self.distanceLabel.alpha = 0.0 + offsetForAnimation
        }
    }

    @IBAction func mapUpAction(sender: AnyObject) {
        moveMapViewUp(nil)
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
        let stationannotation = annotation as? StationAnnotation

        let ident:String
        if let pass = stationannotation?.pass {
            // we only have special icons for the first and last one
            // for all, just use the general icon, no need to get Station
            ident = getIconIdentifier(pass)
        } else {
            ident = getIconIdentifier(self.station)
        }

        let annotationIdentifier = "CustomViewAnnotation-\(ident)"
        var annotationView = self.mapView.dequeueReusableAnnotationViewWithIdentifier(annotationIdentifier)

        if (annotationView == nil) {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: annotationIdentifier)
        }

        annotationView?.canShowCallout = true
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        let buttonImage = UIImage(named: "Walking")
        button.setImage(buttonImage, forState: UIControlState.Normal)
        annotationView?.leftCalloutAccessoryView = button
        annotationView!.image = getMapIcon(stationannotation?.pass)
        annotationView!.opaque = false
        annotationView!.alpha = 1.0
        annotationView!.frame.size.height = 30
        annotationView!.frame.size.width = 30

        return annotationView;

    }

    func getMapIcon(pass:TFCPass? = nil) -> UIImage {
        return UIImage()
    }

    func drawStationAndWay(station:TFCStation, drawStation: Bool? = true) {

        if let stationCoordinate = station.coord?.coordinate, stationDistance = distanceLabel.text {

            let annotation = StationAnnotation(title: station.name, distance: stationDistance, coordinate: stationCoordinate )
            if (drawStation == true) {
                mapView.addAnnotation(annotation)
            }
            destinationPlacemark = MKPlacemark(coordinate: annotation.coordinate, addressDictionary: nil)

            let currentLocation = TFCLocationManager.getCurrentLocation()
            let currentCoordinate = currentLocation?.coordinate

            if (currentCoordinate == nil || station.getDistanceInMeter(currentLocation) >= 5000) {
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

    func getIconIdentifier(station: TFCStation?) -> String {
        if let ident = station?.getIconIdentifier() {
            return ident
        }
        return "stationicon-pin"
    }

    func getIconIdentifier(pass: TFCPass?) -> String {

        if (pass?.isFirst == true) {
            return getIconIdentifier(pass?.getStation())
        } else if (pass?.isLast == true) {
            return "stationicon-pin-map"
        }
        return "stationicon-pin-map"
    }


    func checkIfIconIsCachedAsImage(station: TFCStation) -> Bool {
        let filePath = getIconAsImageFilepath(station)
        return  NSFileManager.defaultManager().fileExistsAtPath(filePath)
    }

    func getIconAsImageFilepath(station: TFCStation?) -> String {
        let documentsDirectory = (NSTemporaryDirectory() as NSString)
        let ident = getIconIdentifier(station)
        return documentsDirectory.stringByAppendingPathComponent("\(ident)-round.png")
    }

    func getIconAsImage(station: TFCStation?) -> (UIImage?, String) {
        let filePath = getIconAsImageFilepath(station)

        if let image = UIImage(contentsOfFile: filePath) {
            return (image, filePath)
        }
        return (nil, filePath)
    }

    func getIconViewAsImage(view: UIView, station: TFCStation?) -> UIImage {
        let (image, filePath) = getIconAsImage(station)
        if let image = image {
            return image
        }
        view.opaque = false

        UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0.0);
        view.layer.renderInContext(UIGraphicsGetCurrentContext()!)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        UIImagePNGRepresentation(img)?.writeToFile(filePath, atomically: true)
        return img;
    }

    override final func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {

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

    func drawAnnotations() {}


}
