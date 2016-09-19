//
//  Album.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import Foundation
import UIKit

public final class TFCDeparture: TFCDeparturePass, NSCoding, APIControllerProtocol {
    private var name: String
    public var type: String
    private var to: String
    private var destination_id: String?
    public var colorFg: String?
    public var colorBg: String?
    public var st_id: String?
    public var sortTime: NSDate?
    public var sortOrder: Int?
    public var key: String?
    private var _station: TFCStation?
    var passlist: [TFCPass]? = nil

    struct contextData {
        var completionDelegate: TFCPasslistUpdatedProtocol? = nil
        var context: Any? = nil
        var url: String? = nil
    }

    private lazy var api : APIController = {
        [unowned self] in
        return APIController(delegate: self)
        }()

    init(name: String, type: String, accessible: Bool, to: String, destination_id: String?, scheduled: NSDate?, realtime: NSDate?, arrivalRealtime: NSDate?, arrivalScheduled: NSDate?, sortTime: NSDate, sortOrder: Int, colorFg: String?, colorBg: String?, platform: String?, st_id: String? ) {
        // TODO: strip "Zurich, " from name
        self.name = name
        self.type = type
        self.to = to
        self.destination_id = destination_id
        self.colorFg = colorFg
        self.colorBg = colorBg
        self.st_id = st_id
        super.init()
        self.accessible = accessible
        self.platform = platform
        self.scheduled = scheduled
        self.realtime = realtime
        self.arrivalScheduled = arrivalScheduled
        self.arrivalRealtime = arrivalRealtime
        self.sortTime = sortTime
        self.sortOrder = sortOrder
        self.key = self.getKey()
    }

    required public init?(coder aDecoder: NSCoder) {
        self.name = aDecoder.decodeObjectForKey("name") as! String
        self.type = aDecoder.decodeObjectForKey("type") as! String
        self.to = aDecoder.decodeObjectForKey("to") as! String
        self.destination_id = aDecoder.decodeObjectForKey("destination_id") as? String
        self.colorFg = aDecoder.decodeObjectForKey("colorFg") as? String
        self.colorBg = aDecoder.decodeObjectForKey("colorBg") as? String
        self.st_id = aDecoder.decodeObjectForKey("st_id") as? String
        super.init()
        self.accessible = aDecoder.decodeBoolForKey("accessible")
        self.platform = aDecoder.decodeObjectForKey("platform") as? String
        self.scheduled = aDecoder.decodeObjectForKey("scheduled") as? NSDate
        self.realtime = aDecoder.decodeObjectForKey("realtime") as? NSDate
        self.sortTime = aDecoder.decodeObjectForKey("sortTime") as? NSDate
        self.sortOrder = aDecoder.decodeObjectForKey("sortOrder") as? Int
        self.key = aDecoder.decodeObjectForKey("key") as? String
        self.arrivalScheduled = aDecoder.decodeObjectForKey("arrivalScheduled") as? NSDate
        self.arrivalRealtime = aDecoder.decodeObjectForKey("arrivalRealtime") as? NSDate

    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(name, forKey: "name")
        aCoder.encodeObject(type, forKey: "type")
        aCoder.encodeBool(accessible, forKey: "accessible")
        aCoder.encodeObject(to, forKey: "to")
        aCoder.encodeObject(destination_id, forKey: "destination_id")
        aCoder.encodeObject(scheduled, forKey: "scheduled")
        aCoder.encodeObject(realtime, forKey: "realtime")
        aCoder.encodeObject(colorFg, forKey: "colorFg")
        aCoder.encodeObject(colorBg, forKey: "colorBg")
        aCoder.encodeObject(platform, forKey: "platform")
        aCoder.encodeObject(st_id, forKey: "st_id")
        aCoder.encodeObject(sortTime, forKey: "sortTime")
        aCoder.encodeObject(sortOrder, forKey: "sortOrder")
        aCoder.encodeObject(key, forKey: "key")
        aCoder.encodeObject(arrivalScheduled, forKey: "arrivalScheduled")
        aCoder.encodeObject(arrivalRealtime, forKey: "arrivalRealtime")
    }

    func getKey() -> String {
        if let key = self.key {
            return key
        }
        return "name=\(self.getDestination()),scheduled=\(self.getScheduledTimeAsNSDate()),line=\(self.getLine())"
    }

    public func getSignature() -> String {
        var props:[String:AnyObject] = ["type": type, "accessible": accessible]

        props["isFavorite"] = isFavorite()


        if let sortTime = sortTime {
            props["sortTime"] = sortTime
        }

        if let sortOrder = sortOrder {
            props["sortOrder"] = sortOrder
        }

        if let destination_id = destination_id {
            props["destination_id"] = destination_id
        }
        if let colorFg = colorFg {
            props["colorFg"] = colorFg
        }
        if let colorBg = colorBg {
            props["colorBg"] = colorBg
        }
        if let platform = platform {
            props["platform"] = platform
        }

        if let realtime = realtime {
            props["realtime"] = realtime
        }
        if let arrivalRealtime = arrivalRealtime {
            props["arrivalRealtime"] = arrivalRealtime
        }
        if let arrivalScheduled = arrivalScheduled {
            props["arrivalScheduled"] = arrivalScheduled
        }
        return props.description
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
            var sortOrder = 1
            var sortTimeBefore:NSDate? = nil
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
                let destination_id = result["id"].string
                var colorFg = result["colors"]["fg"].string
                colorFg = colorFg == nil ? "#000000" : colorFg

                var colorBg = result["colors"]["bg"].string
                colorBg = colorBg == nil ? "#ffffff" : colorBg

                let (scheduled, realtime, arrivalScheduled, arrivalRealtime) = self.parseJsonForDeparture(result)

                let platform = result["platform"].string

                if let scheduled = scheduled {
                    let sortTime:NSDate
                    if let realtime = realtime {
                        sortTime = realtime
                    } else {
                        sortTime = scheduled
                    }

                    if (sortTime == sortTimeBefore) {
                        sortOrder += 1
                    } else {
                        sortOrder = 1
                    }
                    sortTimeBefore = sortTime
                    let newDeparture = TFCDeparture(name: name, type: type, accessible: accessible, to: to, destination_id: destination_id, scheduled: scheduled, realtime: realtime, arrivalRealtime: arrivalRealtime, arrivalScheduled: arrivalScheduled, sortTime: sortTime, sortOrder: sortOrder, colorFg: colorFg, colorBg: colorBg, platform: platform, st_id: st_id)
                    departures?.append(newDeparture)
                }
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
    }


    public func getDestination(station: TFCStation) -> String {
        let fullName = self.to
        if (fullName.match(", *") && station.name.match(", *")) {
            let destinationStationName = fullName.replace(".*, *", template: "")
            let destinationCityName = fullName.replace(", *.*", template: "")
            let stationCityName = station.name.replace(", *.*", template: "")
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

    public func getDestinationWithSign(station: TFCStation?, unabridged: Bool = false) -> String {
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

    private func getDateForPasslist() -> String? {
        if let arrival = arrivalScheduled, scheduled = scheduled {
            return scheduled.formattedWith("yyyy-MM-dd'T'HH:mm") + "/" + arrival.formattedWith("yyyy-MM-dd'T'HH:mm")
        }
        return self.scheduled?.formattedWith("yyyy-MM-dd'T'HH:mm")
    }

    public func didReceiveAPIResults(results: JSON?, error: NSError?, context: Any?) {
        let contextInfo: contextData? = context as! contextData?
/*        if (results == nil || (error != nil && self.departures != nil && self.departures?.count > 0)) {
            self.setDeparturesAsOutdated()
        } else {*/
            self.addPasslist(TFCPass.withJSON(results))
  //      }

        if (self.getPasslist()?.count == 0) {
            DLog("Passlist didn't have results for \(contextInfo?.url) - error was \(error)")
        }
        dispatch_async(dispatch_get_main_queue(), {
            contextInfo?.completionDelegate?.passlistUpdated(error, context: contextInfo?.context, forDeparture: self)
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
            context2.url = url
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
        return "https://tfc.chregu.tv/api/ch/connections/\(st_id)/\(dest_name!)/\(date)"
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

