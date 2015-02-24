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

class TodayViewController: UIViewController, NCWidgetProviding, CLLocationManagerDelegate,  UITableViewDataSource, UITableViewDelegate, APIControllerProtocol, UIGestureRecognizerDelegate {
    @IBOutlet weak var titleLabel: UILabel!
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
    var currentStationIndex = 0
   
    override func viewDidLoad() {
        super.viewDidLoad()
        api = APIController(delegate: self)
        titleLabel.userInteractionEnabled = true;
        let tapGesture  = UITapGestureRecognizer(target: self, action: "handleTap:")
        titleLabel.addGestureRecognizer(tapGesture)
        // Do any additional setup after loading the view from its nib.
    }
    
    @IBAction func nextButtonTouchUp(sender: AnyObject) {
        
        self.currentStationIndex++
        if (self.currentStationIndex >= self.stations.count) {
            self.currentStationIndex = 0
        }
        self.departures = [Departure]();
        self.appsTableView!.reloadData()
        self.titleLabel.text = self.stations[self.currentStationIndex].name
        self.api?.getDepartures(self.stations[self.currentStationIndex].st_id)

    }
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func handleTap(recognizer: UITapGestureRecognizer) {
        let url: NSURL = NSURL(string: "timeforcoffee://home")!
        self.extensionContext?.openURL(url, completionHandler: nil);
    }
    
    func initLocationManager() {
        titleLabel.text = "Looking for nearest station ..."
        seenError = false
        locationFixAchieved = false
        self.locationManager = CLLocationManager()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.currentStationIndex = 0
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
    
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.departures.count
    }
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier) as UITableViewCell
        
        let lineNumberLabel = cell.viewWithTag(100) as UILabel
        let destinationLabel = cell.viewWithTag(200) as UILabel
        let departureLabel = cell.viewWithTag(300) as UILabel
        
        
        let departure: Departure = self.departures[indexPath.row]
        lineNumberLabel.text = departure.getLine()
        destinationLabel.text = departure.getLineAndDestination()
        departureLabel.text = departure.getTimeString()
        
        lineNumberLabel.layer.cornerRadius = 4.0
        lineNumberLabel.layer.masksToBounds = true
        
        if (departure.colorBg != nil) {
            println("FOO")
            println(departure.colorBg);
            lineNumberLabel.backgroundColor = UIColor(netHexString:departure.colorBg!);
            lineNumberLabel.textColor = UIColor(netHexString:departure.colorFg!);
        } else {
            lineNumberLabel.textColor = UIColor.whiteColor()
        }
        
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
        initLocationManager()
        //this should only be called, after everything is updated. didReceiveAPIResults ;)
        // see also https://stackoverflow.com/questions/25961513/ios-8-today-widget-stops-working-after-a-while
        completionHandler(NCUpdateResult.NewData)
    }
    
    func didReceiveAPIResults(results: JSONValue) {
        dispatch_async(dispatch_get_main_queue(), {
            if (Station.isStations(results)) {
                self.stations = Station.withJSON(results)
                self.titleLabel.text = self.stations[self.currentStationIndex].name
                self.api?.getDepartures(self.stations[self.currentStationIndex].st_id)
            } else {
                self.departures = Departure.withJSON(results)
                self.appsTableView!.reloadData()
            }
        })
    }
    
    func widgetMarginInsetsForProposedMarginInsets(defaultMarginInsets: UIEdgeInsets) -> UIEdgeInsets
    {
        var newMargins = defaultMarginInsets
        newMargins.right = 0
        newMargins.left = 0
        newMargins.bottom = 5
        return newMargins
    }
    
    @IBAction func buttonPressed()  {
        NSLog("Button Pressed")
    }
    
}

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    convenience init(netHex:Int) {
        self.init(red:(netHex >> 16) & 0xff, green:(netHex >> 8) & 0xff, blue:netHex & 0xff)
    }
    
    convenience init(netHexString: String) {
        var cString:String = netHexString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet() as NSCharacterSet).uppercaseString
    
        if (cString.hasPrefix("#")) {
            cString = cString.substringFromIndex(advance(cString.startIndex, 1))
        }
        println(netHexString)
        println(cString)
        var rgbValue:UInt32 = 0
        NSScanner(string: cString).scanHexInt(&rgbValue)
    
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
            )
    }
}
