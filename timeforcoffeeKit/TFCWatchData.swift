//
//  TFCWatchData.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 04.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation

public class TFCWatchData: NSObject, APIControllerProtocol {

    var api : APIController?
    var stations: TFCStations!

    enum contextData {
        case ValString(String)
        case ValReply(replyClosure?)
    }
    
    
    public override init () {
        super.init()
        stations =  TFCStations()
        api = APIController(delegate: self)
    }
    
  
    
    public func getDepartures(info: NSDictionary, reply: replyClosure?) {
        let context: Dictionary<String, contextData> = [
                "reply": .ValReply(reply),
                "st_id": .ValString(info["st_id"] as String),
                "st_name": .ValString(info["st_name"] as String)
                    ]
        self.api?.getDepartures(info["st_id"] as String, context: context)
    }
 
    public func didReceiveAPIResults(results: JSONValue, error: NSError?, context: Any?) {
        dispatch_async(dispatch_get_main_queue(), {
            if (error != nil && error?.code != -999) {
                //   self.networkErrorMsg = "Network error. Please try again"
            } else {
                //   self.networkErrorMsg = nil
            }
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
