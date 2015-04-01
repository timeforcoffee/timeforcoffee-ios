//
//  TFCWatchData.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 04.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation

public class TFCWatchData: NSObject, TFCLocationManagerDelegate {

    var replyNearby: replyClosure?
    
    lazy var locManager: TFCLocationManager? = self.lazyInitLocationManager()

    public override init () {
        super.init()
    }
    
    func lazyInitLocationManager() -> TFCLocationManager? {
        return TFCLocationManager(delegate: self)
    }
    
    public func locationFixed(coord: CLLocationCoordinate2D?) {
        //do nothing here, you have to overwrite that
        if (coord != nil) {
            replyNearby!(["lat" : coord!.latitude, "long": coord!.longitude]);
        } else {
            replyNearby!(["coord" : "none"]);
        }
    }

    public func getLocation(reply: replyClosure?) {
        // this is a not so nice way to get the reply Closure to later when we actually have
        // the data from the API... (in locationFixed)
        self.replyNearby = reply
        locManager?.refreshLocation()
    }
}
