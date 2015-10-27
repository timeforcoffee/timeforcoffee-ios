//
//  Album.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import Foundation
import UIKit

public final class TFCDeparture: NSObject, NSCoding, APIControllerProtocol {
    private var name: String
    public var type: String
    private var accessible: Bool
    private var to: String
    private var scheduled: NSDate?
    private var realtime: NSDate?
    public var colorFg: String?
    public var colorBg: String?
    public var platform: String?
    public var st_id: String?
    private var _station: TFCStation?
    private var destination_id: String?
    var outdated: Bool = false
    var passlist: [TFCPass]? = nil

    struct contextData {
        var completionDelegate: TFCPasslistUpdatedProtocol? = nil
        var context: Any? = nil
    }

    private lazy var api : APIController = {
        [unowned self] in
        return APIController(delegate: self)
        }()

    init(name: String, type: String, accessible: Bool, to: String, scheduled: NSDate?, realtime: NSDate?, colorFg: String?, colorBg: String?, platform: String?, st_id: String? ) {
        // TODO: strip "Zurich, " from name
        self.name = name
        self.type = type
        self.accessible = accessible
        self.to = to
        self.scheduled = scheduled
        self.realtime = realtime
        self.colorFg = colorFg
        self.colorBg = colorBg
        self.platform = platform
        self.st_id = st_id
        
    }

    required public init?(coder aDecoder: NSCoder) {
        self.name = aDecoder.decodeObjectForKey("name") as! String
        self.type = aDecoder.decodeObjectForKey("type") as! String
        self.accessible = aDecoder.decodeBoolForKey("accessible")
        self.to = aDecoder.decodeObjectForKey("to") as! String
        self.scheduled = aDecoder.decodeObjectForKey("scheduled") as! NSDate?
        self.realtime = aDecoder.decodeObjectForKey("realtime") as! NSDate?
        self.colorFg = aDecoder.decodeObjectForKey("colorFg") as! String?
        self.colorBg = aDecoder.decodeObjectForKey("colorBg") as! String?
        self.platform = aDecoder.decodeObjectForKey("platform") as? String
        self.st_id = aDecoder.decodeObjectForKey("st_id") as? String
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(name, forKey: "name")
        aCoder.encodeObject(type, forKey: "type")
        aCoder.encodeBool(accessible, forKey: "accessible")
        aCoder.encodeObject(to, forKey: "to")
        aCoder.encodeObject(scheduled, forKey: "scheduled")
        aCoder.encodeObject(realtime, forKey: "realtime")
        aCoder.encodeObject(colorFg, forKey: "colorFg")
        aCoder.encodeObject(colorBg, forKey: "colorBg")
        aCoder.encodeObject(platform, forKey: "platform")
        aCoder.encodeObject(st_id, forKey: "st_id")
    }

    
    public class func getStationNameFromJson(result: JSON) -> String? {
        if let name = result["meta"]["station_name"].string {
            return name
        }
        return ""
    }
    
    public class func withJSON(allResults: JSON?, st_id: String) -> [TFCDeparture]? {
        // Create an empty array of Albums to append to from this list
        // Store the results in our table data array
        var departures: [TFCDeparture]?
        if (allResults == nil) {
            return nil
        }

        if (allResults?["stationboard"].array != nil) {
            return TFCDeparture.withJSONFromTransport2TFC(allResults, st_id: st_id)
        }
        if let results = allResults?["departures"].array {
            departures = [TFCDeparture]()
            for result in results {
                let name = result["name"].stringValue
                let type = result["type"].stringValue
                let accessibleOpt = result["accessible"].bool
                var accessible = true
                if (accessibleOpt == nil || accessibleOpt == false) {
                    accessible = false
                }
                let to = result["to"].stringValue
                let scheduledStr = result["departure"]["scheduled"].string
                let realtimeStr = result["departure"]["realtime"].string
                var colorFg = result["colors"]["fg"].string
                colorFg = colorFg == nil ? "#000000" : colorFg

                var colorBg = result["colors"]["bg"].string
                colorBg = colorBg == nil ? "#ffffff" : colorBg
                
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

                let platform = result["platform"].string
                
                let newDeparture = TFCDeparture(name: name, type: type, accessible: accessible, to: to, scheduled: scheduled, realtime: realtime, colorFg: colorFg, colorBg: colorBg, platform: platform, st_id: st_id)
                departures?.append(newDeparture)
            }
            return departures
        }
        return nil
    }


    private class func withJSONFromTransport2TFC(allResults: JSON?, st_id: String) -> [TFCDeparture]? {
        var newResults:[String: AnyObject] = [String: AnyObject]()

        if let results = allResults {
            newResults["meta"] = ["station_id": results["station"]["id"].stringValue, "station_name": results["station"]["name"].stringValue]

            var departures = [AnyObject]()
            for (_,subJson):(String, JSON) in results["stationboard"] {
                //Do something you want
                if let stop = subJson["stop"].dictionary {
                    var newstop:[String: AnyObject] = [String: AnyObject]()
                    if (subJson["categoryCode"] < 5) {
                        newstop["name"] = subJson["category"].stringValue

                    } else if (subJson["categoryCode"] == 5) {
                        newstop["name"] = subJson["name"].stringValue
                    } else {
                        newstop["name"] = subJson["number"].stringValue

                    }
                    newstop["type"] = subJson["category"].string
                    newstop["accessible"] = false
                    newstop["color"] = ["fg": "#000000", "bg":  "#FFFFFF"]
                    newstop["to"] = subJson["to"].string
                    newstop["departure"] = [];
                    var departure:[String: AnyObject] = [String: AnyObject]()
                    departure["scheduled"] = stop["departure"]?.string
                    departure["realtime"] = stop["prognosis"]?["departure"].string;
                    if let platform = stop["prognosis"]?["platform"].string {
                        departure["platform"] = platform
                    } else {
                        departure["platform"] = stop["platform"]?.string
                    }
                    newstop["departure"] = departure
                    departures.append(newstop)
                }
            }
            newResults["departures"] = departures as [AnyObject]
            return TFCDeparture.withJSON(JSON(newResults), st_id: st_id)
        }

        return nil
/*
        $data["meta"] = ["station_id" => $data["station"]["id"], "station_name" => $data["station"]["name"]];
        $data["departures"] = array();
        foreach ($data["stationboard"] as $stop) {
            $newstop = array();
            $newstop["name"] = $stop["name"];
            $newstop["name"] = trim(str_replace($stop["subcategory"],"",$newstop["name"]));
            $newstop["type"] = $stop["category"];
            $newstop["accessible"] = false;
            $newstop["colors"] = array("fg" =>"#000000", "bg" => "#FFFFFF");
            $newstop["to"] = $stop["to"];
            $newstop["departure"] = array();
            $newstop["departure"]["scheduled"] = $stop["stop"]["departure"];
            $newstop["departure"]["realtime"] = null;
            $data["departures"][] = $newstop;
        }
        unset($data["stationboard"]);
        unset($data["station"]);*/
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

    public func isRealTime() -> Bool {
        if (realtime == nil) {
            return false
        }
        return true
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

    public func getDepartureTime() ->  (NSMutableAttributedString?, String?) {
        return getDepartureTime(true)
    }

    public func getScheduledTime() -> String? {
        if let scheduled = self.scheduled {
            return self.getShortDate(scheduled)
        }
        return nil
    }
    
    public func getScheduledTimeAsNSDate() -> NSDate? {
        if let scheduled = self.scheduled {
            return scheduled
        }
        return nil
    }

    public func getDepartureTime(additionalInfo: Bool) -> (NSMutableAttributedString?, String?) {
        var realtimeStr: String = ""
        var scheduledStr: String = ""
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
      /*  let attributesBoldItalic = [
            NSFontAttributeName: UIFont(name: "HelveticaNeue-Bold", size: 13.0)!
        ]*/

        var timestringAttr: NSMutableAttributedString?
        var timestring: String?

        if let realtime = self.realtime {
            realtimeStr = self.getShortDate(realtime)
        }
        if let scheduled = self.scheduled {
            scheduledStr = self.getShortDate(scheduled)
        }

        // we do two different approaches here, since NSMutableAttributedString seems to
        // use a lot of memory for the today widget and it's only needed, when 
        // there's a delay

        if (self.realtime != nil && self.realtime != self.scheduled) {
            timestringAttr = NSMutableAttributedString(string: "")

            //the nostrike is needed due to an apple bug...
            // https://stackoverflow.com/questions/25956183/nsmutableattributedstrings-attribute-nsstrikethroughstyleattributename-doesnt
            timestringAttr?.appendAttributedString(NSAttributedString(string: "\(realtimeStr) ", attributes: attributesNoStrike))

            timestringAttr?.appendAttributedString(NSAttributedString(string: "\(scheduledStr)", attributes: attributesStrike))
        } else {
            timestring = "\(scheduledStr)"
        }

        if (accessible) {
            if (timestringAttr != nil) {
                timestringAttr?.appendAttributedString(NSAttributedString(string: " ♿︎"))
            } else {
                timestring? += " ♿︎"
            }
        }
        if (additionalInfo) {
            if (self.realtime == nil) {
                if (timestringAttr != nil) {
                    timestringAttr?.appendAttributedString(NSAttributedString(string: " (no real-time data)"))
                } else {
                    timestring? += " (no real-time data)"
                }
            } else if (self.outdated) {
                if (timestringAttr != nil) {
                    timestringAttr?.appendAttributedString(NSAttributedString(string: " (not updated)"))
                } else {
                    timestring? += " (not updated)"
                }
            }
        }

        if let platform = self.platform {
            if (timestringAttr != nil) {
                timestringAttr?.appendAttributedString(NSAttributedString(string: " - Pl: \(platform)"))
            } else {
                timestring? += " - Pl: \(platform)"
            }

        }
        return (timestringAttr, timestring)
    }
    
    public func getMinutesAsInt() -> Int? {
        var timeInterval: NSTimeInterval?
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
        if let station = station {
            let destination: String = getDestination(station, unabridged: unabridged)
            if (station.showAsFavoriteDeparture(self)) {
                return "\(destination) ★"
            }
            return destination
        }
        return getDestination()
    }

    public func getDestination(station: TFCStation?, unabridged: Bool) -> String {
        if let station = station {
            var destination: String = ""
            if (unabridged) {
                destination = getDestination()
            } else {
                destination = getDestination(station)
            }
            return destination
        }
        return getDestination()
    }

    public func isFavorite(station: TFCStation? = nil) -> Bool {
        if let isfav = self.getStation(station)?.showAsFavoriteDeparture(self) {
            return isfav
        }
        return false
    }

    public func setFavorite(station: TFCStation? = nil) {
        self.getStation(station)?.setFavoriteDeparture(self)
    }

    public func unsetFavorite(station: TFCStation? = nil) {
        self.getStation(station)?.unsetFavoriteDeparture(self)
    }

    public func toggleFavorite(station: TFCStation? = nil) {
        if (self.isFavorite(station) == true) {
            self.unsetFavorite(station)
        } else {
            self.setFavorite(station)
        }
    }

    private class func parseDate(dateStr:String) -> NSDate? {
        var format = "yyyy-MM-dd'T'HH:mm:ss.'000'ZZZZZ"
        let dateFmt = NSDateFormatter()
        dateFmt.timeZone = NSTimeZone.defaultTimeZone()
        dateFmt.locale = NSLocale(localeIdentifier: "de_CH")
        dateFmt.dateFormat = format
        if let date =  dateFmt.dateFromString(dateStr) {
            return date
        }
        //used by transport.opendata.ch, if the one above fails
        format = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        dateFmt.dateFormat = format
        return dateFmt.dateFromString(dateStr)
    }
    
    private func getShortDate(date:NSDate) -> String {
        let format = "HH:mm"
        let dateFmt = NSDateFormatter()
        dateFmt.timeZone = NSTimeZone.defaultTimeZone()
        dateFmt.locale = NSLocale(localeIdentifier: "de_CH")
        dateFmt.dateFormat = format
        return dateFmt.stringFromDate(date)
    }

    private func getDateForPasslist() -> String? {
        return self.scheduled?.formattedWith("yyyy-MM-dd'T'HH:mm")
    }

    public func didReceiveAPIResults(results: JSON?, error: NSError?, context: Any?) {
        let contextInfo: contextData? = context as! contextData?
/*        if (results == nil || (error != nil && self.departures != nil && self.departures?.count > 0)) {
            self.setDeparturesAsOutdated()
        } else {*/
            self.addPasslist(TFCPass.withJSON(results))
  //      }
        dispatch_async(dispatch_get_main_queue(), {
            contextInfo?.completionDelegate?.passlistUpdated(error, context: context, forDeparture: self)
        })
    }

    func addPasslist(passlist: [TFCPass]?) {
        self.passlist = passlist
    }

    public func getPasslist() -> [TFCPass]? {
        return self.passlist
    }

    public func updatePasslist(completionDelegate: TFCPasslistUpdatedProtocol?, context: Any? = nil)  {
        var context2: contextData = contextData()
        context2.completionDelegate = completionDelegate
        context2.context = context
        if let url = self.getPasslistUrl() {
            self.api.getPasslist(url, context: context2)
        } else {
            self.passlist = []
            completionDelegate?.passlistUpdated(NSError(domain: "ch.opendata.timeforcoffee", code: 6, userInfo: nil), context: context, forDeparture: nil)
        }

    }

    func getPasslistUrl() -> String? {
        if let st_id = st_id, date = getDateForPasslist() {
            var dest_name:String?
            if let destination_id = self.destination_id {
                dest_name = destination_id
            } else {
                dest_name = getDestination().stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
            }
        return "http://tfc.chregu.tv/api/ch/connections/\(st_id)/\(dest_name!)/\(date)"
        }
        return nil
    }

    public func getStation(station: TFCStation? = nil) -> TFCStation? {
        if let station = station {
            _station = station
            return _station
        }
        if let station = _station {
            return station
        }
        if let st_id = st_id {
            _station = TFCStation.initWithCacheId(st_id)
        }
        return _station
    }
}


public protocol TFCPasslistUpdatedProtocol {
    func passlistUpdated(error: NSError?, context: Any?, forDeparture: TFCDeparture?)
}

