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

class StationTableView: UITableView, UITableViewDelegate, CLLocationManagerDelegate {
    
    var refreshControl:UIRefreshControl!
    var stations: TFCStations!
    
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
    
    
    
}
