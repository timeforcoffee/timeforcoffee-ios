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
    
    lazy var locManager: TFCLocationManager = self.lazyInitLocationManager()

    enum contextData {
        case ValString(String)
        case ValReply(replyClosure?)
    }
    
    
    public override init () {
        super.init()
        stations =  TFCStations()
        api = APIController(delegate: self)
    }
    
    func lazyInitLocationManager() -> TFCLocationManager {
        return TFCLocationManager(delegate: self)
    }
    
    public func locationFixed(coord: CLLocationCoordinate2D?) {
        //do nothing here, you have to overwrite that
        if (coord != nil) {
            self.stations.addNearbyFavorites(locManager.currentLocation!)
            self.api?.searchFor(coord!)
        } else {
            if (replyNearby != nil) {
                replyNearby!(["error" : "no coordinates delivered"]);
            }
        }
    }
  
    
    public func getDepartures(info: NSDictionary, reply: replyClosure?) {
        let context: Dictionary<String, contextData> = [
                "reply": .ValReply(reply),
                "st_id": .ValString(info["st_id"] as String),
                "st_name": .ValString(info["st_name"] as String)
                    ]
        self.api?.getDepartures(info["st_id"] as String, context: context)
    }
    
    public func getNearbyStations(reply: replyClosure?)  {
        // this is a not so nice way to get the reply Closure to later when we actually have
        // the data from the API... (in locationFixed)
        self.replyNearby = reply
        locManager.refreshLocation()
    }
    
 
    public func didReceiveAPIResults(results: JSONValue, error: NSError?, context: Any?) {
        dispatch_async(dispatch_get_main_queue(), {
            if (error != nil && error?.code != -999) {
                //   self.networkErrorMsg = "Network error. Please try again"
            } else {
                //   self.networkErrorMsg = nil
            }

            if (TFCStation.isStations(results)) {
                let hasAlreadyFavouritesDisplayed = self.stations.count()
                self.stations.addWithJSON(results, append: true)

                if (self.replyNearby != nil) {
                    println("send nearby reply")

                    var stationsReply: [NSDictionary] = []
                    var stationDict: [String: [String: AnyObject]] = [:]
                    for station in self.stations.stations! {
                        
                        // Hier dann station info ins gleiche Format wie
                        // getFavoriteStationsDict bringen
                        // (evt grad in TFCStation reintun)
                        // und dann noch favorites wie in TodayView an den Anfang
                        
                        let stationReply: [String: AnyObject] =  [
                            "name": station.name,
                            "st_id": station.st_id,
                            "latitude": station.coord!.coordinate.latitude.description,
                            "longitude": station.coord!.coordinate.longitude.description
                        ]
                        
                        stationDict[station.st_id] = stationReply;
                    }
                    self.replyNearby!(stationDict)
                }
            } else {
                if (context != nil) {
                    let contextInfo = context! as Dictionary<String, contextData>
                    var reply: replyClosure?
                    switch contextInfo["reply"]! {
                    case .ValReply(let s):
                        reply = s
                    default:
                        reply = nil
                    }
                    
                    var stationName = self.getStringFromDict(contextInfo["st_name"])
                    var stationId = self.getStringFromDict(contextInfo["st_id"])
                    let station = TFCStation(name: stationName!, id: stationId!, coord: nil)
                    //let reply = contextData.ValReply(contextInfo["reply"]?)
                    let departuresObjects: [TFCDeparture]? = TFCDeparture.withJSON(results, filterStation: nil)
                    var departures: [NSDictionary] = []
                    for departure in departuresObjects! as [TFCDeparture] {
                        let d: TFCDeparture = departure
                        var f: NSDictionary = [
                            "to": d.getDestination(station),
                            "name": d.getLine(),
                            "time": d.getDepartureTime()!,
                            "minutes": d.getMinutes()!,
                            "accessible": d.accessible,
                            "colorFg": d.colorFg!,
                            "colorBg": d.colorBg!
                        ]
                        departures.append(f)
                    }
                    reply!(["departures": departures])
                }
            }

        })
    }
    
    func getStringFromDict(input: contextData?) -> String? {
        if (input == nil) {
            return nil
        }
        var value: String?
        switch input! {
        case .ValString(let s):
            value = s
        default:
            value = nil
        }
        return value
    }

}
