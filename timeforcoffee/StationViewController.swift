//
//  StationViewController
//
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import UIKit
import timeforcoffeeKit

class StationViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, APIControllerProtocol, MGSwipeTableCellDelegate {

    @IBOutlet weak var titleLabel: UINavigationItem!
    @IBOutlet var appsTableView : UITableView?
    var api : APIController?
    var refreshControl:UIRefreshControl!
    var departures: [TFCDeparture]?
    var station: TFCStation?
    var networkErrorMsg: String?
    let kCellIdentifier: String = "DeparturesListCell"


    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel.title = self.station?.name
        self.api = APIController(delegate: self)
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.departures = nil;
        self.api?.getDepartures(self.station?.st_id)
        self.refreshControl = UIRefreshControl()
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.appsTableView?.addSubview(refreshControl)

        var favButton = UIBarButtonItem(title: "☆", style: UIBarButtonItemStyle.Plain, target: self, action: "favoriteClicked:")

        if (station!.isFavorite()) {
           favButton.title = "★";
        }

        self.navigationItem.rightBarButtonItem = favButton
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidBecomeActive:", name: "UIApplicationDidBecomeActiveNotification", object: nil)

    }
    
    func applicationDidBecomeActive(notification: NSNotification) {
        self.departures = nil
        self.api?.getDepartures(self.station?.st_id)
    }

    deinit {
        println("deinit")
    }
    
    override func viewWillDisappear(animated: Bool) {
        station = nil
        api = nil
        departures = nil
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    @IBAction func favoriteClicked(sender: UIBarButtonItem) {
        if (self.station!.isFavorite()) {
            TFCStations.unsetFavoriteStation(self.station!)
            sender.title = "☆";
        } else {
            TFCStations.setFavoriteStation(self.station!)
            sender.title = "★";
        }
        self.appsTableView?.reloadData()
    }


    func refresh(sender:AnyObject)
    {
        // Code to refresh table view
        self.departures = nil
        self.api?.getDepartures(self.station?.st_id)
    }

    func didReceiveAPIResults(results: JSONValue, error: NSError?) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        self.refreshControl.endRefreshing()
        dispatch_async(dispatch_get_main_queue(), {
            if (error != nil) {
                self.networkErrorMsg = NSLocalizedString("Network error. Please try again", comment:"")
            } else {
                self.networkErrorMsg = nil
            }
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
        if (self.departures == nil || self.departures!.count == 0) {
            return 1
        }
        return self.departures!.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell:MGSwipeTableCell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier) as MGSwipeTableCell

        cell.delegate = self
        cell.tag = indexPath.row


        let lineNumberLabel = cell.viewWithTag(100) as UILabel
        let destinationLabel = cell.viewWithTag(200) as UILabel
        let departureLabel = cell.viewWithTag(300) as UILabel
        let minutesLabel = cell.viewWithTag(400) as UILabel
        let station2 = station!

        if (self.departures == nil || self.departures!.count == 0) {
            departureLabel.text = nil
            lineNumberLabel.text = nil
            minutesLabel.text = nil
            lineNumberLabel.backgroundColor = UIColor.clearColor()
            if (self.departures == nil) {
                destinationLabel.text = NSLocalizedString("Loading", comment: "Loading ..")
            } else {
                destinationLabel.text = NSLocalizedString("No departures found.", comment: "")
                if (self.networkErrorMsg != nil) {
                    departureLabel.text = self.networkErrorMsg
                }
            }
            return cell
        }
        
        let departure: TFCDeparture = self.departures![indexPath.row]

        lineNumberLabel.text = departure.getLine()
        var unabridged = false
        if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
            unabridged = true
        }
        destinationLabel.text = departure.getDestinationWithSign(station, unabridged: unabridged)
        
        
        minutesLabel.text = departure.getMinutes()
        if (station2.isFiltered(departure)) {
            destinationLabel.textColor = UIColor.grayColor()
            minutesLabel.textColor = UIColor.grayColor()
        } else {
            destinationLabel.textColor = UIColor.blackColor()
            minutesLabel.textColor = UIColor.blackColor()
        }

        departureLabel.text = departure.getDepartureTime()

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

    func swipeTableCell(cell: MGSwipeTableCell!, canSwipe direction: MGSwipeDirection) -> Bool {
        return true
    }

    func swipeTableCell(cell: MGSwipeTableCell!, swipeButtonsForDirection direction: MGSwipeDirection, swipeSettings: MGSwipeSettings!, expansionSettings: MGSwipeExpansionSettings!) -> [AnyObject]! {
        var buttons = []
        let station2 = station!
        if (direction == MGSwipeDirection.RightToLeft) {
            let departure: TFCDeparture = self.departures![cell.tag]
            if (station2.isFiltered(departure)) {
                buttons = [MGSwipeButton( title:"Unfilter", backgroundColor: UIColor.redColor())]
            } else {
                buttons = [MGSwipeButton( title:"Filter", backgroundColor: UIColor.greenColor())]
            }
        }
        expansionSettings.buttonIndex = 0
        expansionSettings.fillOnTrigger = true
        expansionSettings.threshold = 2.5

        return buttons
    }

    func swipeTableCell(cell: MGSwipeTableCell!, tappedButtonAtIndex index: Int, direction: MGSwipeDirection, fromExpansion: Bool) -> Bool {
        let departure: TFCDeparture = self.departures![cell.tag]
        let station2 = station!
        if (station2.isFiltered(departure)) {
            station2.unsetFilter(departure);
            var button = cell.rightButtons[0] as MGSwipeButton
            button.backgroundColor = UIColor.greenColor();
        } else {
            station2.setFilter(departure);
            var button = cell.rightButtons[0] as MGSwipeButton
            button.backgroundColor = UIColor.redColor();
        }
        self.appsTableView?.reloadData()

        return true
    }
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        
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
}
