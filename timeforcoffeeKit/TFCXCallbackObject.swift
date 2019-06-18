//
//  TFCXCallbackObject.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 18.06.19.
//  Copyright © 2019 opendata.ch. All rights reserved.
//

import Foundation
import CoreLocation


public final class TFCXCallbackObject:NSObject {
    
    public var station:TFCStation? = nil
    public var departure:TFCDeparture? = nil
    public var yourLatLon:CLLocation? = nil
    public var latlonOnly:Bool = false
    
    public func getJson() -> String {
        
        let params = self.getParams()
        
        let encoder = JSONEncoder()
        do {
            if #available(watchOSApplicationExtension 4.0, *) {
                encoder.outputFormatting = .sortedKeys
            } 
            let data = try encoder.encode(params)
            return String(data:data, encoding: .utf8) ?? "{}"
        } catch _ {
        }
        return "{}"
    }
    
    public func getParams() -> [String:String?] {
        var params:[String:String?] = [:]
        if let yourlatlon = self.yourLatLon?.coordinate {
            params["yourlatlon"] =  "\(yourlatlon.latitude),\(yourlatlon.longitude)"
        }

        if let departure = self.departure {
            let time = departure.getRealDepartureDateAsShortDate()
            params["time"] = time
            params["timeScheduled"] = departure.getScheduledTime()
            params["line"] = departure.getLine()
            params["destination"] = departure.getDestination()
            params["type"] = departure.getType()
            params["isRealTime"] = departure.isRealTime() ? "true" : "false"
            params["isAccessible"] = departure.accessible ? "true" : "false"
            params["platform"] = departure.platform ?? ""
            
        }
        if let station = self.station {
            params["id"] = station.getId()
            params["name"] = station.getName(false)
            params["nameCityAfter"] = station.getName(true)
            params["latlon"] = "\(station.getLatitude()?.description ?? "0"),\(station.getLongitude()?.description ?? "0")"
        }
        
        return params
        
    }
    
    public func getDepartureTimeOrUnknown() -> String {
        if let departure = self.departure?.getRealDepartureDateAsShortDate() {
            return departure
        }
        return "unknown"
    }
    public func getDepartureTimeMinutesOrUnknown() -> String {
        if let departure = self.departure?.getMinutes() {
            return departure
        }
        return "unknown"
    }
    
    public func getDepartureLineOrUnkown() -> String {
        if let line = self.departure?.getLine() {
            return line
        }
        return "unknown"
    }
    
    public func getEndStationOrUnknown() -> String {
        if let station = self.departure?.getDestination(self.station) {
            return station
        }
        return "unknown"
    }
    
    
    public func getDepartureStationOrUnknown(_ cityAfter:Bool = false) -> String {
        if let station = self.departure?.getStation()?.getName(cityAfter) {
            return station
        }
        return "unknown"
    }
}
