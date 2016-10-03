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

final class StationTableView: UITableView, UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating, TFCStationsUpdatedProtocol {
    
    var refreshControl2:UIRefreshControl?
    lazy var stations: TFCStations = {return TFCStations(delegate: self)}()
    var showFavorites: Bool?
    weak var stationsViewController: StationsViewController?
    weak var searchBar: UISearchBar?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        /* Adding the refresh controls */
        self.dataSource = self

        self.refreshControl2 = UIRefreshControl()
        self.refreshControl2?.addTarget(self, action: #selector(StationTableView.refresh(_:)), forControlEvents: UIControlEvents.ValueChanged)
        self.refreshControl2?.backgroundColor = UIColor(red: 242.0/255.0, green: 243.0/255.0, blue: 245.0/255.0, alpha: 1.0)
        self.refreshControl2?.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.addSubview(refreshControl2!)
    }


    func refreshFromCoreDataSetup(notification: NSNotification) {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: notification.name, object: nil)
        self.refreshLocation(false)
    }

    internal func refresh(sender:AnyObject)
    {
        refreshLocation(true)
    }

    func refreshLocation() {
        refreshLocation(false)
    }

    func refreshLocation(force: Bool) {
        guard TFCDataStore.sharedInstance.checkForCoreDataStackSetup(
            self,
            selector: #selector(self.refreshFromCoreDataSetup(_:))
            ) else { return }

        if ((showFavorites) == true) {
            self.stations.loadFavorites()
            self.reloadData()
            self.refreshControl2?.endRefreshing()
        } else {
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            if (!self.stations.updateStations(force)) {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                self.refreshControl2?.endRefreshing()
            }
        }
    }

    func stationsUpdated(err: String?, favoritesOnly: Bool, context: Any?) {
        dispatch_async(dispatch_get_main_queue(), {
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            self.refreshControl2?.endRefreshing()
            self.reloadData()
        })
    }

    func updateSearchResultsForSearchController(searchController: UISearchController) {
        let whitespaceCharacterSet = NSCharacterSet.whitespaceCharacterSet()
        let strippedString = searchController.searchBar.text!.stringByTrimmingCharactersInSet(whitespaceCharacterSet)
        if (strippedString != "") {
            self.stations.updateStations(searchFor: strippedString)
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
        let cell = tableView.dequeueReusableCellWithIdentifier("StationTableViewCell", forIndexPath: indexPath) as! StationTableViewCell

        cell.tag = indexPath.row

        let textLabel = cell.StationNameLabel
        let detailTextLabel = cell.StationDescriptionLabel

        let stationsCount = stations.count()

        if (stationsCount == nil || stationsCount == 0) {
            cell.userInteractionEnabled = false;
            if (stationsCount == nil) {
                textLabel?.text = NSLocalizedString("Loading", comment: "Loading ..")
                detailTextLabel?.text = stations.loadingMessage
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

    func removePullToRefresh() {
        if (self.refreshControl2 != nil) {
            self.refreshControl2?.removeFromSuperview()
            self.refreshControl2 = nil
        }
    }

    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
            searchBar?.resignFirstResponder()
    }
}
