//
//  StationTableView.swift
//  timeforcoffee
//
//  Created by Jan Hug on 04.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import UIKit
import MapKit
import timeforcoffeeKit
import CoreLocation

class StationTableView: UITableView, UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating, TFCStationsUpdatedProtocol {
    
    var refreshControl:UIRefreshControl!
    lazy var stations: TFCStations = {return TFCStations(delegate: self)}()
    var showFavorites: Bool?
    var stationsViewController: StationsViewController?

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        /* Adding the refresh controls */
        self.dataSource = self

        self.refreshControl = UIRefreshControl()
        self.refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.refreshControl.backgroundColor = UIColor(red: 242.0/255.0, green: 243.0/255.0, blue: 245.0/255.0, alpha: 1.0)
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.addSubview(refreshControl)
    }

    internal func refresh(sender:AnyObject)
    {
        refreshLocation(true)
    }

    func refreshLocation() {
        refreshLocation(false)
    }

    func refreshLocation(force: Bool) {
        if (TFCDataStore.sharedInstance.getUserDefaults()?.boolForKey("onboardingShown") == true) {
        if ((showFavorites) == true) {
            self.stations.loadFavorites()
            self.reloadData()
            self.refreshControl.endRefreshing()
        } else {
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            if (!self.stations.updateStations(force)) {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                self.refreshControl.endRefreshing()
            }
        }
        }
    }

    func stationsUpdated(err: String?, favoritesOnly: Bool) {
        dispatch_async(dispatch_get_main_queue(), {
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            self.refreshControl.endRefreshing()
            self.reloadData()
        })
    }

    func updateSearchResultsForSearchController(searchController: UISearchController) {
        let whitespaceCharacterSet = NSCharacterSet.whitespaceCharacterSet()
        let strippedString = searchController.searchBar.text.stringByTrimmingCharactersInSet(whitespaceCharacterSet)
        if (strippedString != "") {
            stations.clear()
            self.stations.updateStations(strippedString)
        }
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (stations.count() == nil || stations.count() == 0) {
            if (stations.isLoading || stations.networkErrorMsg != nil) {
                return 1
            }
            return 0
        }
        return stations.count()!
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("StationTableViewCell", forIndexPath: indexPath) as StationTableViewCell

        cell.tag = indexPath.row

        let textLabel = cell.StationNameLabel
        let detailTextLabel = cell.StationDescriptionLabel

        let stationsCount = stations.count()

        if (stationsCount == nil || stationsCount == 0) {
            cell.userInteractionEnabled = false;
            if (stationsCount == nil) {
                textLabel?.text = NSLocalizedString("Loading", comment: "Loading ..")
                detailTextLabel?.text = ""
            } else {
                textLabel?.text = NSLocalizedString("No stations found.", comment: "")
                detailTextLabel.text = stations.networkErrorMsg
            }
            return cell
        }
        cell.userInteractionEnabled = true;


        let station = self.stations.getStation(indexPath.row)
        if (station != nil) {
            cell.station = station!
        }
        cell.drawCell()
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.stationsViewController?.performSegueWithIdentifier("SegueToStationView", sender: tableView)
    }
}
