//
//  TFCPass.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 26.10.15.
//  Copyright © 2015 opendata.ch. All rights reserved.
//

import Foundation
import CoreLocation

public final class TFCPass {

    public var name: String
    public var coord: CLLocationCoordinate2D?
    public var scheduled: NSDate?
    public var realtime: NSDate?
    public var st_id: String
    public var isFirst = false
    public var isLast = false

    init(name: String, id: String, coord: CLLocationCoordinate2D?, scheduled: NSDate?, realtime: NSDate?  ) {
        self.name = name
        self.coord = coord
        self.st_id = id
        self.scheduled = scheduled
        self.realtime = realtime
    }

    public class func withJSON(allResults: JSON?) -> [TFCPass]? {
        // Create an empty array of Albums to append to from this list
        // Store the results in our table data array
        var passlist: [TFCPass]?
        if (allResults == nil) {
            return []
        }

        if let results = allResults?["passlist"][0].array {
            passlist = [TFCPass]()
            for result in results {
                let name = result["name"].stringValue
                let id = result["id"].stringValue

                let scheduledStr = result["departure"]["scheduled"].string
                let realtimeStr = result["departure"]["realtime"].string

                let scheduled: NSDate?
                let realtime: NSDate?

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

                let longitude = result["location"]["lng"].double
                let latitude = result["location"]["lat"].double
                var coord: CLLocationCoordinate2D?
                if (longitude != nil && latitude != nil) {
                    coord = CLLocationCoordinate2D(latitude: latitude!, longitude: longitude!)
                }
                let newPass = TFCPass(name: name, id: id, coord: coord, scheduled: scheduled, realtime: realtime)
                passlist?.append(newPass)
            }
            passlist?.first?.isFirst = true
            passlist?.last?.isLast = true
            return passlist
        }
        return []
    }

    public func getStation() -> TFCStation {
        return TFCStation.initWithCacheId(self.st_id)
    }

    private class func parseDate(dateStr:String) -> NSDate? {
        let format = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        let dateFmt = NSDateFormatter()
        dateFmt.timeZone = NSTimeZone.defaultTimeZone()
        dateFmt.locale = NSLocale(localeIdentifier: "de_CH")
        dateFmt.dateFormat = format
        return dateFmt.dateFromString(dateStr)
    }

    public func getMinutesAsInt(from:NSDate) -> Int? {
        if let scheduled = self.scheduled {
            let timeInterval = scheduled.timeIntervalSinceReferenceDate -  from.timeIntervalSinceReferenceDate
            return Int(ceil(timeInterval / 60));
        }
        return nil
    }

    public func getMinutes(from:NSDate) -> String? {
        var timeInterval = getMinutesAsInt(from)
        if (timeInterval != nil) {
            if (timeInterval < 0) {
                if (timeInterval > -1) {
                    timeInterval = 0;
                }
            }
            if (timeInterval >= 60) {
                let hours = Int(timeInterval! / 60)
                let minutes = String (format: "%02d", timeInterval! % 60)
                return "\(hours):\(minutes)"
            }
            return "\(timeInterval!)'"
        }
        return nil
    }

}