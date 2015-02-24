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

class TodayViewController: TFCBaseViewController, NCWidgetProviding, UITableViewDataSource, UITableViewDelegate, APIControllerProtocol, UIGestureRecognizerDelegate {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var appsTableView: UITableView!
    let kCellIdentifier: String = "SearchResultCellWidget"

    var stations = [Station]()
    var departures = [Departure]()
    var api : APIController?
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
    
    override func initLocationManager() {
        titleLabel.text = "Looking for nearest station ..."
        self.currentStationIndex = 0
        super.initLocationManager()
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        var coord = locationManagerFix(manager,didUpdateLocations: locations);
        if (coord != nil) {
            self.api?.searchFor(coord!)
        }
    }

    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.departures.count
    }
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier) as UITableViewCell
        
        cell.layoutMargins = UIEdgeInsetsZero
        cell.preservesSuperviewLayoutMargins = false
        
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
            lineNumberLabel.backgroundColor = UIColor(netHexString:departure.colorBg!);
            lineNumberLabel.textColor = UIColor(netHexString:departure.colorFg!);
        } else {
            lineNumberLabel.textColor = UIColor.blackColor()
            lineNumberLabel.backgroundColor = UIColor.whiteColor()
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
    
    
    @IBAction func buttonPressed()  {
        NSLog("Button Pressed")
    }
    
}

