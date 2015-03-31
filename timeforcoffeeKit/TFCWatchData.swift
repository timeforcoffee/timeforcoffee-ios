//
//  TFCWatchData.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 04.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation

public class TFCWatchData: NSObject, APIControllerProtocol, TFCLocationManagerDelegate {

    var api : APIController?
    var stations: TFCStations!
    var replyNearby: replyClosure?
    
    lazy var locManager: TFCLocationManager? = self.lazyInitLocationManager()

    struct contextData {
        var reply: replyClosure?
        var st_id: String?
        var st_name: String?
    }


    public override init () {
        super.init()
        stations =  TFCStations()
        api = APIController(delegate: self)
    }
    
    func lazyInitLocationManager() -> TFCLocationManager? {
        return TFCLocationManager(delegate: self)
    }
    
    public func locationFixed(coord: CLLocationCoordinate2D?) {
        //do nothing here, you have to overwrite that
        if (coord != nil) {
            self.stations.addNearbyFavorites((locManager?.currentLocation)!)
            self.api?.searchFor(coord!)
        } else {
            if (replyNearby != nil) {
                replyNearby!(["error" : "no coordinates delivered"]);
            }
        }
    }
  

    
    public func getNearbyStations(reply: replyClosure?)  {
        // this is a not so nice way to get the reply Closure to later when we actually have
        // the data from the API... (in locationFixed)
        self.replyNearby = reply
        self.stations?.clear()
        locManager?.refreshLocation()
    }
    
    public func getFavorites(reply: replyClosure?) {
        // Location is missing, they are not sorted yet
        if (reply != nil) {
            stations.loadFavorites(nil)
            var stationsReply: [NSDictionary] = []
            for station in self.stations.stations! {
                stationsReply.append(station.getAsDict())
            }
            reply!(["stations": stationsReply])
        }
    }
    
    public func didReceiveAPIResults(results: JSONValue, error: NSError?, context: Any?) {
        dispatch_async(dispatch_get_main_queue(), {
            //TODO: show network error in watch
            if (error != nil && error?.code != -999) {
                //   self.networkErrorMsg = "Network error. Please try again"
            } else {
                //   self.networkErrorMsg = nil
            }

            if (TFCStation.isStations(results)) {
                self.stations.loadFavorites(self.locManager?.currentLocation)
                self.stations.addWithJSON(results, append: true)

                if (self.replyNearby != nil) {
                    var stationsReply: [NSDictionary] = []
                    for station in self.stations.stations! {
                        stationsReply.append(station.getAsDict())
                    }
                    self.replyNearby!(["stations": stationsReply])
                }
            }
        })
    }
}
