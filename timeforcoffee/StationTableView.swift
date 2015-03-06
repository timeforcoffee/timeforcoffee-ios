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

class StationTableView: UITableView, UITableViewDelegate, APIControllerProtocol, TFCLocationManagerDelegate {
    
    var refreshControl:UIRefreshControl!
    var stations: TFCStations!
    lazy var locManager: TFCLocationManager = self.lazyInitLocationManager()
    lazy var api : APIController = { return APIController(delegate: self)}()
    var networkErrorMsg: String?

    override func awakeFromNib() {
        super.awakeFromNib()
        /* Adding the refresh controls */
        self.refreshControl = UIRefreshControl()
        self.refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.refreshControl.backgroundColor = UIColor(red: 242.0/255.0, green: 243.0/255.0, blue: 245.0/255.0, alpha: 1.0)
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.addSubview(refreshControl)
        
        self.registerNib(UINib(nibName: "StationTableViewCell", bundle: nil), forCellReuseIdentifier: "StationTableViewCell")
        
    }

    func pushData(stations: TFCStations) {
        self.stations = stations
        self.reloadData()
    }


    func refresh(sender:AnyObject)
    {
        refreshLocation()
    }

    func refreshLocation() {
        /*if (showFavorites) {
            self.stations?.loadFavorites(locManager.currentLocation)
            self.reloadData()
        } else {*/
            self.locManager.refreshLocation()
//        }
    }

    internal func lazyInitLocationManager() -> TFCLocationManager {
        return TFCLocationManager(delegate: self)
    }

    internal func locationFixed(coord: CLLocationCoordinate2D?) {
        if (coord != nil) {
            self.api.searchFor(coord!)
        }
    }

    func didReceiveAPIResults(results: JSONValue, error: NSError?, context: Any?) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        dispatch_async(dispatch_get_main_queue(), {
            if (error != nil && error?.code != -999) {
                self.networkErrorMsg = "Network error. Please try again"
            } else {
                self.networkErrorMsg = nil
            }
            if (self.stations == nil) {
                self.stations = TFCStations()
            }
            self.stations!.addWithJSON(results)
            self.reloadData()
            self.refreshControl.endRefreshing()

        })
    }


}
