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

    public override init () {
        super.init()
        stations =  TFCStations()
        api = APIController(delegate: self)
    }
    
    public func getDepartures(st_id: String, reply: (([NSObject : AnyObject]!) -> Void)?) {
        self.api?.getDepartures(st_id, context: reply)
    }
 
    public func didReceiveAPIResults(results: JSONValue, error: NSError?, context: Any?) {
        dispatch_async(dispatch_get_main_queue(), {
            if (error != nil && error?.code != -999) {
                //   self.networkErrorMsg = "Network error. Please try again"
            } else {
                //   self.networkErrorMsg = nil
            }
            if (context != nil) {
                let reply = context as (([NSObject : AnyObject]!) -> Void)
                let departuresObjects: [TFCDeparture]? = TFCDeparture.withJSON(results, filterStation: nil)
                var departures: [NSDictionary] = []
                    for departure in departuresObjects! as [TFCDeparture] {
                        let d: TFCDeparture = departure
                        var f: NSDictionary = [ "to": d.to,
                            "name": d.getLine(),
                            "time": d.getTimeString(),
                            "minutes": d.getMinutes()!,
                            "accessible": d.accessible,
                            "colorFg": d.colorFg!,
                            "colorBg": d.colorBg!
                        ]
                        departures.append(f)
                    }
                reply(["departures": departures])
            }

        })
    }

}
