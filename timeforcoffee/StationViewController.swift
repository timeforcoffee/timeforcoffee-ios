//
//  StationViewController
//  
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import UIKit
import timeforcoffeeKit

class StationViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, APIControllerProtocol {
    
    @IBOutlet weak var titleLabel: UINavigationItem!
    @IBOutlet var appsTableView : UITableView?
    var api : APIController?
    var refreshControl:UIRefreshControl!
    var departures = [TFCDeparture]()
    var station: TFCStation?
    let kCellIdentifier: String = "DeparturesListCell"

    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.title = self.station?.name
        self.api = APIController(delegate: self)
        self.api?.getDepartures(self.station?.st_id)
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.refreshControl = UIRefreshControl()
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.appsTableView?.addSubview(refreshControl)
        
        var buttonContainer = UIView(frame: CGRectMake(0, 0, 200, 44))

        buttonContainer.backgroundColor = UIColor.clearColor()
        var button0: UIButton = UIButton.buttonWithType(UIButtonType.Custom) as UIButton
        button0.frame = CGRectMake(160, 7 , 40,  30)
       // if (station.isFavorite()) {
            button0.setTitle("★", forState: UIControlState.Normal)
        //} else {
          //  button0.setTitle("☆", forState: UIControlState.Normal)
            
        //}
        button0.setTitleColor(UIColor.blackColor(), forState: UIControlState.Normal)
    
        button0.titleLabel?.font = UIFont(name: "Helvetica", size: 30)
        
        //button0.addTarget(self, action: "star", forControlEvents: UIControlEvents.TouchUpInside)
        button0.showsTouchWhenHighlighted = true
        buttonContainer.addSubview(button0)
        
        self.navigationItem.titleView = buttonContainer;
        
        
    }
    
    func refresh(sender:AnyObject)
    {
        // Code to refresh table view
        self.api?.getDepartures(self.station?.st_id)
    }
    
    func didReceiveAPIResults(results: JSONValue) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        self.refreshControl.endRefreshing()
        dispatch_async(dispatch_get_main_queue(), {
            self.departures = TFCDeparture.withJSON(results)
            if (self.station?.name == "") {
                self.station?.name = TFCDeparture.getStationNameFromJson(results)!;
                self.titleLabel.title = self.station?.name
            }
            self.appsTableView!.reloadData()
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        })
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.departures.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier) as UITableViewCell
        
        let lineNumberLabel = cell.viewWithTag(100) as UILabel
        let destinationLabel = cell.viewWithTag(200) as UILabel
        let departureLabel = cell.viewWithTag(300) as UILabel
        
        
        let departure: TFCDeparture = self.departures[indexPath.row]
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
}
