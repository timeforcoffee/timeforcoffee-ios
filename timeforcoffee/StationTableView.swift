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
        self.refreshControl2?.addTarget(self, action: #selector(StationTableView.refresh(_:)), for: UIControl.Event.valueChanged)
        self.refreshControl2?.backgroundColor = UIColor(red: 242.0/255.0, green: 243.0/255.0, blue: 245.0/255.0, alpha: 1.0)
        self.refreshControl2?.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.addSubview(refreshControl2!)
    }

    @objc internal func refresh(_ sender:AnyObject)
    {
        refreshLocation(true)
    }

    func refreshLocation() {
        refreshLocation(false)
    }

    func refreshLocation(_ force: Bool) {
        if ((showFavorites) == true) {
            self.stations.loadFavorites()

            self.reloadData()

            self.refreshControl2?.endRefreshing()
        } else {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            if (!self.stations.updateStations(force)) {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                self.refreshControl2?.endRefreshing()
            }
        }
    }
    
    func resortFavorites() {
        if showFavorites == true {
            self.stations.sortStations(TFCLocationManager.getCurrentLocation())
        }
    }

    func stationsUpdated(_ err: String?, favoritesOnly: Bool, context: Any?, stations:TFCStations) {
        DispatchQueue.main.async(execute: {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            self.refreshControl2?.endRefreshing()
            self.reloadData()
        })
    }

    func updateSearchResults(for searchController: UISearchController) {
        let whitespaceCharacterSet = CharacterSet.whitespaces
        let strippedString = searchController.searchBar.text!.trimmingCharacters(in: whitespaceCharacterSet)
        if (strippedString != "") {
            let _ = self.stations.updateStations(searchFor: strippedString)
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (stations.count() == nil || stations.count() == 0) {
            if (stations.isLoading || stations.networkErrorMsg != nil) {
                return 1
            }
            return 0
        }
        return stations.count()!
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StationTableViewCell", for: indexPath) as! StationTableViewCell

        cell.tag = indexPath.row

        let textLabel = cell.StationNameLabel
        let detailTextLabel = cell.StationDescriptionLabel

        let stationsCount = stations.count()

        if (stationsCount == nil || stationsCount == 0) {
            cell.isUserInteractionEnabled = false;
            if (stationsCount == nil) {
                textLabel?.text = NSLocalizedString("Loading", comment: "Loading ..")
                detailTextLabel?.text = stations.loadingMessage
            } else {
                textLabel?.text = NSLocalizedString("No stations found.", comment: "")
                detailTextLabel?.text = stations.networkErrorMsg
            }
            return cell
        }
        cell.isUserInteractionEnabled = true;


        let station = self.stations.getStation(indexPath.row)
        if (station != nil) {
            cell.station = station!
        }
        cell.drawCell()
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell:StationTableViewCell? = tableView.cellForRow(at: indexPath) as! StationTableViewCell?
        self.stationsViewController?.performSegue(withIdentifier: "SegueToStationView", sender: cell?.station)
    }

    func removePullToRefresh() {
        if (self.refreshControl2 != nil) {
            self.refreshControl2?.removeFromSuperview()
            self.refreshControl2 = nil
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            searchBar?.resignFirstResponder()
    }
}
