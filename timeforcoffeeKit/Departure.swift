//
//  Album.swift
//  nextMigros
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import Foundation

public class Departure {
    public var name: String
    public var type: String
    public var accessible: Bool?
    public var to: String
    public var scheduled: NSDate?
    public var realtime: NSDate?

    init(name: String, type: String, accessible: Bool?, to: String, scheduled: NSDate?, realtime: NSDate? ) {
        self.name = name
        self.type = type
        self.accessible = accessible
        self.to = to
        self.scheduled = scheduled
        self.realtime = realtime
        
    }
    public class func withJSON(allResults: JSONValue) -> [Departure] {
        
        // Create an empty array of Albums to append to from this list
        var departures = [Departure]()
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
                    
                    var newDeparture = Departure(name: name!, type: type!, accessible: accessible, to: to!, scheduled: scheduled, realtime: realtime)
                    departures.append(newDeparture)
                }
            }
            
            
        }
        return departures
    }
    class func parseDate(dateStr:String) -> NSDate? {
        let format = "yyyy-MM-dd'T'HH:mm:ss.'000'ZZZZZ"
        var dateFmt = NSDateFormatter()
        dateFmt.timeZone = NSTimeZone.defaultTimeZone()
        dateFmt.dateFormat = format
        return dateFmt.dateFromString(dateStr)
    }
}

