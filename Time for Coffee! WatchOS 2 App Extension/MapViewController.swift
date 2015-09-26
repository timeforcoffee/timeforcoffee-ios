//
//  StationsOverviewViewController.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 13.04.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import WatchKit
import Foundation
import timeforcoffeeWatchKit

class MapViewController: WKInterfaceController {



    @IBOutlet weak var map: WKInterfaceMap!
    weak var station: TFCStation?

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        NSLog("awake StationsOverviewViewController")
        self.station = context as? TFCStation

    }

    override func willActivate() {

        if let station = self.station {
            self.setTitle(station.getName(true))
            if let coordinate = station.coord?.coordinate {
                let region = MKCoordinateRegionMakeWithDistance(coordinate, 1000, 1000);
                map.setRegion(region)
                map.addAnnotation(coordinate, withPinColor: WKInterfaceMapPinColor.Red)
                if let currentCoord = TFCLocationManager.getCurrentLocation()?.coordinate {
                    map.addAnnotation(currentCoord, withPinColor: WKInterfaceMapPinColor.Green)
                }
            }
        }
        
    }
    
    
}

