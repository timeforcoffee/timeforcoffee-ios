//
//  Album.swift
//  nextMigros
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import Foundation

public class TFCDeparture {
    public var name: String
    public var type: String
    public var accessible: Bool?
    public var to: String
    public var scheduled: NSDate?
    public var realtime: NSDate?
    public var colorFg: String?
    public var colorBg: String?

    init(name: String, type: String, accessible: Bool?, to: String, scheduled: NSDate?, realtime: NSDate?, colorFg: String?, colorBg: String? ) {
        // TODO: strip "Zurich, " from name
        self.name = name
        self.type = type
        self.accessible = accessible
        self.to = to
        self.scheduled = scheduled
        self.realtime = realtime
        self.colorFg = colorFg
        self.colorBg = colorBg
        
    }
    
    public class func getStationNameFromJson(result: JSONValue) -> String? {
        return result["meta"]["station_name"].string
    }
    
    public class func withJSON(allResults: JSONValue, filterStation: TFCStation?) -> [TFCDeparture] {
        // Create an empty array of Albums to append to from this list
        var departures = [TFCDeparture]()
        // Store the results in our table data array
        if allResults["departures"].array?.count>0 {
            
            if let results = allResults["departures"].array {
                
                for result in results {
                    var name = result["name"].string
                    var type = result["type"].string
                    var accessible = result["accessible"].bool
                    var to = result["to"].string
                    var scheduledStr = result["departure"]["scheduled"].string
                    var realtimeStr = result["departure"]["realtime"].string
                    var colorFg = result["colors"]["fg"].string
                    var colorBg = result["colors"]["bg"].string
                    var scheduled: NSDate?
                    var realtime: NSDate?
                    if (scheduledStr != nil) {
                        scheduled = self.parseDate(scheduledStr!);
                    } else {
                        scheduled = nil
                    }
                    
                    if (realtimeStr != nil) {
                        realtime = self.parseDate(realtimeStr!);
                    } else {
                        realtime = nil
                    }
                    
                    var newDeparture = TFCDeparture(name: name!, type: type!, accessible: accessible, to: to!, scheduled: scheduled, realtime: realtime, colorFg: colorFg, colorBg: colorBg)
                    if (filterStation != nil) {
                        let filterStation2 = filterStation!
                        if (filterStation2.isFiltered(newDeparture)) {
                            continue
                        }
                    }
                    departures.append(newDeparture)
                }
            }
            
            
        }
        return departures
        
    }
    
    public class func withJSON(allResults: JSONValue) -> [TFCDeparture] {
        return withJSON(allResults, filterStation: nil)
    }
    
    public func getDestination() -> String {
        return "\(self.to)"
    }
    
    public func getLine() -> String {
        return "\(self.name)"
    }
    
    
    public func getTimeString() -> String {
        var timestring = "";
        var minutes = getMinutes()
        
        if (minutes != nil) {
            timestring = "In \(minutes!) / \(getDepartureTime()!)"
        }
        return timestring

    }
    
    public func getDepartureTime() -> String? {
        var realtimeStr: String?
        var scheduledStr: String?
        var timestring = "";
        if (self.realtime != nil) {
            realtimeStr = self.getShortDate(self.realtime!)
        }
        scheduledStr = self.getShortDate(self.scheduled!)
        
        if (self.realtime != nil && self.realtime != self.scheduled) {
            timestring = "\(realtimeStr!) / \(scheduledStr!)"
        } else {
            if (self.realtime == nil) {
                timestring = "\(scheduledStr!) (no real-time data)"
            } else {
                timestring = "\(scheduledStr!)"
            }
        }
        return timestring
    }
    
    public func getMinutes() -> String? {
        var timeInterval: NSTimeInterval?
        var realtimeStr: String?
        var scheduledStr: String?
        var timestring = "";
        
        if (self.realtime != nil) {
            timeInterval = self.realtime?.timeIntervalSinceNow
        } else {
            timeInterval = self.scheduled?.timeIntervalSinceNow
        }
        if (timeInterval != nil) {
            var timediff  = Int(ceil(timeInterval! / 60));
            if (timediff < 0) {
                timediff = 0;
            }
            return "\(timediff)'"
        }
        return nil
    }
    
    public func getDestinationWithSign(station: TFCStation?) -> String {
        if (station != nil) {
            let station2 = station!
            if (station2.isFiltered(self)) {
                return "\(getDestination()) ✗"
            }
        }
        return getDestination()
    }

    class func parseDate(dateStr:String) -> NSDate? {
        let format = "yyyy-MM-dd'T'HH:mm:ss.'000'ZZZZZ"
        var dateFmt = NSDateFormatter()
        dateFmt.timeZone = NSTimeZone.defaultTimeZone()
        dateFmt.dateFormat = format
        return dateFmt.dateFromString(dateStr)
    }
    
    
    func getShortDate(date:NSDate) -> String {
        let format = "HH:mm"
        var dateFmt = NSDateFormatter()
        dateFmt.timeZone = NSTimeZone.defaultTimeZone()
        dateFmt.dateFormat = format
        return dateFmt.stringFromDate(date)
    }
}

