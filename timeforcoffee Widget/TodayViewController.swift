//
//  TodayViewController.swift
//  timeforcoffee Widget
//
//  Created by Christian Stocker on 23.02.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import UIKit
import NotificationCenter
import CoreLocation
import timeforcoffeeKit

class TodayViewController: UIViewController, NCWidgetProviding, CLLocationManagerDelegate,  UITableViewDataSource, UITableViewDelegate, APIControllerProtocol {
    @IBOutlet weak var helloWorld: UILabel!
    @IBOutlet weak var appsTableView: UITableView!
    let kCellIdentifier: String = "SearchResultCellWidget"

    var stations = [Station]()
    var departures = [Departure]()
    var api : APIController?
    var locationManager : CLLocationManager!
    var seenError : Bool = false
    var locationFixAchieved : Bool = false
    var locationStatus : NSString = "Not Started"
    var currentLocation: CLLocation?
   
    override func viewDidLoad() {
        super.viewDidLoad()
        helloWorld.text = "Did Load"
        api = APIController(delegate: self)

        // Do any additional setup after loading the view from its nib.
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        helloWorld.text = "Did Appear"
        initLocationManager()
        
    }
    
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
            helloWorld.text = "coordinate received"
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
    
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.departures.count
    }
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier) as UITableViewCell
        
        let departure: Departure = self.departures[indexPath.row]
        cell.textLabel?.text = departure.getLineAndDestination()
        cell.detailTextLabel?.text = departure.getTimeString()
        return cell
        
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func widgetPerformUpdateWithCompletionHandler(completionHandler: ((NCUpdateResult) -> Void)!) {
        // Perform any setup necessary in order to update the view.

        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData

        completionHandler(NCUpdateResult.NewData)
    }
    
    func didReceiveAPIResults(results: JSONValue) {
        dispatch_async(dispatch_get_main_queue(), {
            if (Station.isStations(results)) {
                self.stations = Station.withJSON(results)
                self.helloWorld.text = self.stations[0].name
                self.api?.getDepartures(self.stations[0].st_id)
            } else {
                self.departures = Departure.withJSON(results)
                self.appsTableView!.reloadData()
            }
        })
    }
    
}
