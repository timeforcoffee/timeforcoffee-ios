//
//  Album.swift
//  nextMigros
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import Foundation
import UIKit

public class TFCDeparture {
    public var name: String
    public var type: String
    public var accessible: Bool
    public var to: String
    public var scheduled: NSDate?
    public var realtime: NSDate?
    public var colorFg: String?
    public var colorBg: String?
    public var outdated: Bool = false

    init(name: String, type: String, accessible: Bool, to: String, scheduled: NSDate?, realtime: NSDate?, colorFg: String?, colorBg: String? ) {
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
    
    public class func withJSON(allResults: JSONValue, filterStation: TFCStation?) -> [TFCDeparture]? {
        return self.withJSON(allResults, filterStation: filterStation, maxDepartures: nil)
    }

    public class func withJSON(allResults: JSONValue, filterStation: TFCStation?, maxDepartures: Int?) -> [TFCDeparture]? {
        // Create an empty array of Albums to append to from this list
        // Store the results in our table data array
        var departures: [TFCDeparture]?

        departures = [TFCDeparture]()
        if let results = allResults["departures"].array {
            
            for result in results {
                var name = result["name"].string
                var type = result["type"].string
                var accessibleOpt = result["accessible"].bool
                var accessible = true
                if (accessibleOpt == nil || accessibleOpt == false) {
                    accessible = false
                }
                var to = result["to"].string
                var scheduledStr = result["departure"]["scheduled"].string
                var realtimeStr = result["departure"]["realtime"].string
                var colorFg = result["colors"]["fg"].string
                colorFg = colorFg == nil ? "#000000" : colorFg

                var colorBg = result["colors"]["bg"].string
                colorBg = colorBg == nil ? "#ffffff" : colorBg
                
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
                departures?.append(newDeparture)
                if (maxDepartures != nil && departures?.count >= maxDepartures) {
                    break
                }
            }
        }
        
        return departures
    }
    
    public class func withJSON(allResults: JSONValue) -> [TFCDeparture]? {
        return withJSON(allResults, filterStation: nil)
    }
    
    public func getDestination(station: TFCStation) -> String {
        let fullName = self.to
        if (fullName.match(", ") && station.name.match(", ")) {
            let destinationStationName = fullName.replace(".*, ", template: "")
            let destinationCityName = fullName.replace(", .*", template: "")
            let stationCityName = station.name.replace(", .*", template: "")
            if (stationCityName == destinationCityName) {
                return destinationStationName
            }
        }
        return fullName
    }
    
    public func getDestination() -> String {
        return "\(self.to)"
    }
    
    public func getLine() -> String {
        return "\(self.name)"
    }
    
    public func getType() -> String {
        return "\(self.type)"
    }
    
    
    public func getTimeString() -> String {
        var timestring = "";
        var minutes = getMinutes()
        let (departureTimeAttr, departureTimeString) = getDepartureTime(true)

        if (minutes != nil) {
            timestring = "In \(minutes!) / \(departureTimeString!)"
        }
        return timestring

    }

    public func getDepartureTime() ->  (NSMutableAttributedString?, String?) {
        return getDepartureTime(false)
    }

    public func getDepartureTime(forceString: Bool) -> (NSMutableAttributedString?, String?) {
        var realtimeStr: String?
        var scheduledStr: String?
        let attributesNoStrike = [
            NSStrikethroughStyleAttributeName: 0,
        ]
        let attributesStrike = [
            NSStrikethroughStyleAttributeName: 1,
            NSForegroundColorAttributeName: UIColor.grayColor()
        ]

        // if you want bold and italic, do this, but the accessibility icon isn't available in italic :)
        /*let fontDescriptor = UIFontDescriptor.preferredFontDescriptorWithTextStyle(UIFontTextStyleBody)
        let bi = UIFontDescriptorSymbolicTraits.TraitItalic | UIFontDescriptorSymbolicTraits.TraitBold
         let fda = fontDescriptor.fontDescriptorWithSymbolicTraits(bi).fontAttributes()
        let fontName = fda["NSFontNameAttribute"] as String
        */
        let attributesBoldItalic = [
            NSFontAttributeName: UIFont(name: "HelveticaNeue-Bold", size: 13.0)!
        ]

        var timestringAttr: NSMutableAttributedString?
        var timestring: String?

        if (self.realtime != nil) {
            realtimeStr = self.getShortDate(self.realtime!)
        }
        scheduledStr = self.getShortDate(self.scheduled!)

        // we do two different approaches here, since NSMutableAttributedString seems to
        // use a lot of memory for the today widget and it's only needed, when 
        // there's a dealy

        if (self.realtime != nil && self.realtime != self.scheduled) {
            if (forceString) {
                timestring =  "\(realtimeStr!) / \(scheduledStr!)"
            } else {
                timestringAttr = NSMutableAttributedString(string: "")

                //the nostrike is needed due to an apple bug...
                // https://stackoverflow.com/questions/25956183/nsmutableattributedstrings-attribute-nsstrikethroughstyleattributename-doesnt
                timestringAttr?.appendAttributedString(NSAttributedString(string: "\(realtimeStr!) ", attributes: attributesNoStrike))

                timestringAttr?.appendAttributedString(NSAttributedString(string: "\(scheduledStr!)", attributes: attributesStrike))
            }

        } else {
            timestring = "\(scheduledStr!)"
        }
        if (accessible) {
            if (timestringAttr != nil) {
                timestringAttr?.appendAttributedString(NSAttributedString(string: " ♿︎"))
            } else {
                timestring?.extend(" ♿︎")
            }
        }
        if (self.realtime == nil) {
            if (timestringAttr != nil) {
                timestringAttr?.appendAttributedString(NSAttributedString(string: " (no real-time data)"))
            } else {
                timestring?.extend(" (no real-time data)")
            }
        } else if (self.outdated) {
            if (timestringAttr != nil) {
                timestringAttr?.appendAttributedString(NSAttributedString(string: " (not updated)"))
            } else {
                timestring?.extend(" (not updated)")
            }
        }
        return (timestringAttr, timestring)
    }
    
    public func getMinutesAsInt() -> Int? {
        var timeInterval: NSTimeInterval?
        var realtimeStr: String?
        var scheduledStr: String?
        if (self.realtime != nil) {
            timeInterval = self.realtime?.timeIntervalSinceNow
        } else {
            timeInterval = self.scheduled?.timeIntervalSinceNow
        }
        if (timeInterval != nil) {
            return Int(ceil(timeInterval! / 60));
        }
        return nil
    }

    public func getMinutes() -> String? {
        var timestring = "";
        var timeInterval = getMinutesAsInt()
        if (timeInterval != nil) {
            if (timeInterval < 0) {
                if (timeInterval > -1) {
                    timeInterval = 0;
                }
            }
            if (timeInterval >= 60) {
                return ">59'"
            }
            return "\(timeInterval!)'"
        }
        return nil
    }

    public func getDestinationWithSign(station: TFCStation?) -> String {
        return getDestinationWithSign(station, unabridged: false)
    }
    
    public func getDestinationWithSign(station: TFCStation?, unabridged: Bool) -> String {
        if (station != nil) {
            var destination: String = ""
            let station2 = station!

            if (unabridged) {
                destination = getDestination()
            } else {
                destination = getDestination(station2)
            }
            if (station2.isFiltered(self)) {
                return "\(destination) ✗"
            }
            return destination
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
    
    public func getAsDict(station: TFCStation) -> [String: AnyObject] {
        let (departureTimeAttr, departureTimeString) = getDepartureTime(true)

        return [
            "to":         getDestination(station),
            "name":       getLine(),
            "time":       departureTimeString!,
            "minutes":    getMinutes()!,
            "accessible": accessible,
            "colorFg":    colorFg!,
            "colorBg":    colorBg!,
        ]

        
    }
}

