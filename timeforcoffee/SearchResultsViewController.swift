//
//  ViewController.swift
//  nextMigros
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit
import timeforcoffeeKit

class SearchResultsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, APIControllerProtocol, CLLocationManagerDelegate {
    @IBOutlet var appsTableView : UITableView?
    var stations = [Station]()
    let kCellIdentifier: String = "SearchResultCell"
    var imageCache = [String : UIImage]()
    var api : APIController?
    var locationManager : CLLocationManager!
    var seenError : Bool = false
    var locationFixAchieved : Bool = false
    var locationStatus : NSString = "Not Started"
    var currentLocation: CLLocation?
    var refreshControl:UIRefreshControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        api = APIController(delegate: self)
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.refreshControl = UIRefreshControl()
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.appsTableView?.addSubview(refreshControl)
        initLocationManager()
    }
    
    func refresh(sender:AnyObject)
    {
        // Code to refresh table view
        locationFixAchieved = false
        self.locationManager.startUpdatingLocation()
    }
    
    // Location Manager helper stuff
    func initLocationManager() {
        seenError = false
        locationFixAchieved = false
        self.locationManager = CLLocationManager()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()


    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        self.locationManager.stopUpdatingLocation()
        if ((error) != nil) {
            if (seenError == false) {
                seenError = true
                print(error)
            }
        }
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        if (locationFixAchieved == false) {
            locationFixAchieved = true
            var locationArray = locations as NSArray
            var locationObj = locationArray.lastObject as CLLocation
            var coord = locationObj.coordinate
            self.currentLocation = locationObj;
            self.api?.searchFor(coord)
            self.locationManager.stopUpdatingLocation()
        }
    }
    
    // authorization status
    func locationManager(manager: CLLocationManager!,
        didChangeAuthorizationStatus status: CLAuthorizationStatus) {
            var shouldIAllow = false
            
            switch status {
            case CLAuthorizationStatus.Restricted:
                locationStatus = "Restricted Access to location"
            case CLAuthorizationStatus.Denied:
                locationStatus = "User denied access to location"
            case CLAuthorizationStatus.NotDetermined:
                locationStatus = "Status not determined"
            default:
                locationStatus = "Allowed to location Access"
                shouldIAllow = true
            }
            NSNotificationCenter.defaultCenter().postNotificationName("LabelHasbeenUpdated", object: nil)
            if (shouldIAllow == true) {
                NSLog("Location to Allowed")
                // Start location services
                locationManager.startUpdatingLocation()
            } else {
                NSLog("Denied access: \(locationStatus)")
            }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stations.count
    }


    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier) as UITableViewCell
        
        let station = self.stations[indexPath.row]
        cell.textLabel?.text = station.name
        //cell.imageView?.image = UIImage(named: "Blank52")
        var distance = Int(currentLocation?.distanceFromLocation(station.coord) as Double!)
        cell.detailTextLabel?.text = "\(distance) Meter"
        
        // Get the formatted price string for display in the subtitle
//        let formattedPrice = album.price
        
        // Grab the artworkUrl60 key to get an image URL for the app's thumbnail
        /*var urlString: String?
        urlString = nil
        if (urlString != nil) {
            // Check our image cache for the existing key. This is just a dictionary of UIImages
            //var image: UIImage? = self.imageCache.valueForKey(urlString) as? UIImage
            var image = self.imageCache[urlString!]
            station.imageURL = urlString
            
            if( image == nil ) {
                // If the image does not exist, we need to download it
                var imgURL: NSURL = NSURL(string: urlString!)!
                
                // Download an NSData representation of the image at the URL
                let request: NSURLRequest = NSURLRequest(URL: imgURL)
                NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue(), completionHandler: {(response: NSURLResponse!,data: NSData!,error: NSError!) -> Void in
                    if error == nil {
                        image = UIImage(data: data)
                        
                        // Store the image in to our cache
                        self.imageCache[urlString!] = image
                        if let cellToUpdate = tableView.cellForRowAtIndexPath(indexPath) {
                           
                            cellToUpdate.imageView?.image = image
                            self.fixWidthImage(cellToUpdate)
                        }
                    }
                    else {
                        println("Error: \(error.localizedDescription)")
                    }
                })
                
            }
            else {
                dispatch_async(dispatch_get_main_queue(), {
                    if let cellToUpdate = tableView.cellForRowAtIndexPath(indexPath) {
                        cellToUpdate.imageView?.image = image
                        self.fixWidthImage(cellToUpdate)
                    }
                })
            }
        }
        */
        // calculate exact distance
        let currentCoordinate = currentLocation?.coordinate
        var sourcePlacemark:MKPlacemark = MKPlacemark(coordinate: currentCoordinate!, addressDictionary: nil)
        
        var destinationPlacemark:MKPlacemark = MKPlacemark(coordinate: station.coord.coordinate, addressDictionary: nil)
        var source:MKMapItem = MKMapItem(placemark: sourcePlacemark)
        var destination:MKMapItem = MKMapItem(placemark: destinationPlacemark)
        var directionRequest:MKDirectionsRequest = MKDirectionsRequest()
        
        directionRequest.setSource(source)
        directionRequest.setDestination(destination)
        directionRequest.transportType = MKDirectionsTransportType.Walking
        directionRequest.requestsAlternateRoutes = true
        
        var directions:MKDirections = MKDirections(request: directionRequest)
        directions.calculateDirectionsWithCompletionHandler({
            (response: MKDirectionsResponse!, error: NSError?) in
            if error != nil{
                println("Error")
            }
            if response != nil{
                println("number of routes = \(response.routes.count)")
                for r in response.routes { println("route = \(r)") }
                var route: MKRoute = response.routes[0] as MKRoute;
                
                
                var time =  Int(round(route.expectedTravelTime / 60))
                var meters = Int(route.distance);
                cell.detailTextLabel?.text = "\(time) min Fussweg, \(meters) m"
                println(route.expectedTravelTime / 60)
            }
            else{
                println("No response")
            }
            println(error?.description)
        })

        
//        cell.detailTextLabel?.text = formattedPrice

        return cell

    }
    
    func fixWidthImage(cell: UITableViewCell) {
        let itemSize = CGSizeMake(52, 52);
        UIGraphicsBeginImageContextWithOptions(itemSize, false, UIScreen.mainScreen().scale);
        let imageRect = CGRectMake(0.0, 0.0, itemSize.width, itemSize.height);
        cell.imageView?.image?.drawInRect(imageRect)
        cell.imageView?.image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    func didReceiveAPIResults(results: JSONValue) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        self.refreshControl.endRefreshing()
        dispatch_async(dispatch_get_main_queue(), {
            self.stations = Station.withJSON(results)
            self.appsTableView!.reloadData()
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        })
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        var detailsViewController: StationViewController = segue.destinationViewController as StationViewController
        var albumIndex = appsTableView?.indexPathForSelectedRow()?.row
//        var albumIndex = appsTableView!.indexPathForSelectedRow().row
        var selectedAlbum = self.stations[albumIndex!]
        detailsViewController.station = selectedAlbum
    }

    
}


