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

    private var api : APIController?
    private var stations: TFCStations!
    private var replyNearby: replyClosure?
    
    private lazy var locManager: TFCLocationManager? = self.lazyInitLocationManager()

    private struct contextData {
        var reply: replyClosure?
        var st_id: String?
        var st_name: String?
    }

    public override init () {
        super.init()
        stations =  TFCStations()
        api = APIController(delegate: self)
    }
    
    private func lazyInitLocationManager() -> TFCLocationManager? {
        return TFCLocationManager(delegate: self)
    }
    
    public func locationFixed(loc: CLLocation?) {
        //do nothing here, you have to overwrite that
        if let coord = loc?.coordinate {
            self.stations.addNearbyFavorites(loc!)
            self.api?.searchFor(coord)
        } else {
            if (replyNearby != nil) {
                replyNearby!(["error" : "no coordinates delivered"]);
            }
        }
    }

    public func locationDenied(manager: CLLocationManager) {

    }

    
    public func getDepartures(info: NSDictionary, reply: replyClosure?) {
        var context = contextData(reply: reply, st_id: info["st_id"] as String?, st_name: info["st_name"] as String?)
        self.api?.getDepartures(context.st_id, context: context)
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
            } else {
                if (context != nil) {

                    let contextInfo = context as contextData?

                    var stationName = contextInfo?.st_name
                    var stationId = contextInfo?.st_id
                    let station = TFCStation(name: stationName!, id: stationId!, coord: nil)
                    //let reply = contextData.ValReply(contextInfo["reply"]?)
                    let departuresObjects: [TFCDeparture]? = TFCDeparture.withJSON(results)
                    var departures: [NSDictionary] = []
                    for departure in departuresObjects! as [TFCDeparture] {
                        departures.append(departure.getAsDict(station))
                    }
                    contextInfo?.reply!(["departures": departures])
                }
            }

        })
    }
}
