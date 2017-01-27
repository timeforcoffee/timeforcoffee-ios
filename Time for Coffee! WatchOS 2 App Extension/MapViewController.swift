//
//  StationsOverviewViewController.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 13.04.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import WatchKit
import Foundation

class MapViewController: WKInterfaceController {



    @IBOutlet weak var map: WKInterfaceMap!
    weak var station: TFCStation?

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        DLog("awake StationsOverviewViewController")
        self.station = context as? TFCStation

    }

    override func willActivate() {

        if let station = self.station {
            self.setTitle(station.getName(true))
            if let coordinate = station.coord?.coordinate {
                let region = MKCoordinateRegionMakeWithDistance(coordinate, 1000, 1000);
                map.setRegion(region)
                map.addAnnotation(coordinate, with: WKInterfaceMapPinColor.red)
                if let currentCoord = TFCLocationManager.getCurrentLocation()?.coordinate {
                    map.addAnnotation(currentCoord, with: WKInterfaceMapPinColor.green)
                }
            }
        }
        
    }
    
    
}

