//
//  Album.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import Foundation
import UIKit
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func >= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l >= r
  default:
    return !(lhs < rhs)
  }
}


public final class TFCDeparture: TFCDeparturePass, NSCoding, APIControllerProtocol {
    fileprivate var name: String
    public var type: String
    fileprivate var to: String
    fileprivate var destination_id: String?
    public var colorFg: String?
    public var colorBg: String?
    public var st_id: String?
    public var sortTime: Date?
    public var sortOrder: Int?
    public var key: String?
    fileprivate var signature: String?
    weak fileprivate var _station: TFCStation?
    var passlist: [TFCPass]? = nil

    struct contextData {
        var completionDelegate: TFCPasslistUpdatedProtocol? = nil
        var context: Any? = nil
        var url: String? = nil
    }

    fileprivate lazy var api : APIController = {
        [unowned self] in
        return APIController(delegate: self)
        }()

    init(name: String, type: String, accessible: Bool, to: String, destination_id: String?, scheduled: Date?, realtime: Date?, arrivalRealtime: Date?, arrivalScheduled: Date?, sortTime: Date, sortOrder: Int, colorFg: String?, colorBg: String?, platform: String?, st_id: String? ) {
        // TODO: strip "Zurich, " from name
        self.name = name.replace("S +([0-9]+)", template: "S$1")
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
        self.name = aDecoder.decodeObject(forKey: "name") as! String
        self.type = aDecoder.decodeObject(forKey: "type") as! String
        self.to = aDecoder.decodeObject(forKey: "to") as! String
        self.destination_id = aDecoder.decodeObject(forKey: "destination_id") as? String
        self.colorFg = aDecoder.decodeObject(forKey: "colorFg") as? String
        self.colorBg = aDecoder.decodeObject(forKey: "colorBg") as? String
        self.st_id = aDecoder.decodeObject(forKey: "st_id") as? String
        super.init()
        self.accessible = aDecoder.decodeBool(forKey: "accessible")
        self.platform = aDecoder.decodeObject(forKey: "platform") as? String
        self.scheduled = aDecoder.decodeObject(forKey: "scheduled") as? Date
        self.realtime = aDecoder.decodeObject(forKey: "realtime") as? Date
        self.sortTime = aDecoder.decodeObject(forKey: "sortTime") as? Date
        self.sortOrder = aDecoder.decodeObject(forKey: "sortOrder") as? Int
        self.key = aDecoder.decodeObject(forKey: "key") as? String
        self.arrivalScheduled = aDecoder.decodeObject(forKey: "arrivalScheduled") as? Date
        self.arrivalRealtime = aDecoder.decodeObject(forKey: "arrivalRealtime") as? Date
        self.signature = aDecoder.decodeObject(forKey: "signature") as? String
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: "name")
        aCoder.encode(type, forKey: "type")
        aCoder.encode(accessible, forKey: "accessible")
        aCoder.encode(to, forKey: "to")
        aCoder.encode(destination_id, forKey: "destination_id")
        aCoder.encode(scheduled, forKey: "scheduled")
        aCoder.encode(realtime, forKey: "realtime")
        aCoder.encode(colorFg, forKey: "colorFg")
        aCoder.encode(colorBg, forKey: "colorBg")
        aCoder.encode(platform, forKey: "platform")
        aCoder.encode(st_id, forKey: "st_id")
        aCoder.encode(sortTime, forKey: "sortTime")
        aCoder.encode(sortOrder, forKey: "sortOrder")
        aCoder.encode(key, forKey: "key")
        aCoder.encode(arrivalScheduled, forKey: "arrivalScheduled")
        aCoder.encode(arrivalRealtime, forKey: "arrivalRealtime")
        aCoder.encode(signature, forKey: "signature")

    }

    func getKey() -> String {
        if let key = self.key {
            return key
        }
        return "name=\(self.getDestination()),scheduled=\(String(describing: self.getScheduledTimeAsNSDate())),line=\(self.getLine())"
    }

    public func getSignature(_ station:TFCStation? = nil) -> String {
        if let sig = self.signature {
            return sig
        }

        let sortOrder = self.sortOrder ?? 0
        let destination_id = self.destination_id ?? ""
        let colorFg = self.colorFg ?? ""
        let colorBg = self.colorBg ?? ""
        let platform = self.platform ?? ""

        self.signature = "\(type),\(accessible),\(isFavorite(station)),\(getDateForSig(sortTime)),\(sortOrder),\(destination_id),\(colorFg),\(colorBg),\(platform),\(getDateForSig(realtime)),\(getDateForSig(arrivalRealtime)),\(getDateForSig(arrivalScheduled))".replace("[\\\"()#]",template: "")

        return self.signature!
    }

    func getDateForSig(_ date: Date?) -> String {
        if let datestr = date?.formattedWithDateFormatter(DLogShortFormatter) {
            return datestr
        }
        return ""
    }

    public class func getStationNameFromJson(_ result: JSON) -> String? {
        if let name = result["meta"]["station_name"].string {
            return name
        }
        return ""
    }
    
    public class func withJSON(_ allResults: JSON?, st_id: String) -> [TFCDeparture]? {
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
            let station = TFCStation.initWithCacheId(st_id)
            var sortOrder = 1
            var sortTimeBefore:Date? = nil
            departures = [TFCDeparture]()
            var count = 0
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
                    let sortTime:Date
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
                    // in watchOS only add departure, if it's a favorite... and only 10
                    #if os(watchOS)
                        let maxCount = 10
                        if ((station?.hasFavoriteDepartures() == false || newDeparture.isFavorite()) && count < maxCount) {
                            DLog("add \(newDeparture.getKey())", toFile: true)
                            count += 1
                            departures?.append(newDeparture)
                            if (count >= maxCount) {
                                DLog("break", toFile: true)
                                break
                            }
                        }
                    #else
                        departures?.append(newDeparture)
                    #endif
                }
            }
            return departures
        }
        return nil
    }


    fileprivate class func withJSONFromTransport2TFC(_ allResults: JSON?, st_id: String) -> [TFCDeparture]? {
        var newResults:[String: Any] = [String: Any]()

        if let results = allResults {
            newResults["meta"] = ["station_id": results["station"]["id"].stringValue, "station_name": results["station"]["name"].stringValue]

            var departures = [Any]()
            for (_,subJson):(String, JSON) in results["stationboard"] {
                //Do something you want
                if let stop = subJson["stop"].dictionary {
                    var newstop:[String: Any?] = [String: Any?]()
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
                    var departure:[String: Any?] = [String: Any?]()
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


    public func getDestination(_ station: TFCStation) -> String {
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
    
    public func getScheduledTimeAsNSDate() -> Date? {
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

    public func getDestinationWithSign(_ station: TFCStation?, unabridged: Bool = false) -> String {
        if let station = station {
            let destination: String = getDestination(station, unabridged: unabridged)
            if (station.showAsFavoriteDeparture(self)) {
                return "\(destination) ★"
            }
            return destination
        }
        return getDestination()
    }

    public func getDestination(_ station: TFCStation?, unabridged: Bool) -> String {
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

    public func isFavorite(_ station: TFCStation? = nil) -> Bool {
        if let station = station {
            return station.showAsFavoriteDeparture(self)
        }
        if let isfav = self.getStation(station)?.showAsFavoriteDeparture(self) {
            return isfav
        }
        return false
    }

    public func setFavorite(_ station: TFCStation? = nil) {
        self.getStation(station)?.setFavoriteDeparture(self)
    }

    public func unsetFavorite(_ station: TFCStation? = nil) {
        self.getStation(station)?.unsetFavoriteDeparture(self)
    }

    public func toggleFavorite(_ station: TFCStation? = nil) {
        if (self.isFavorite(station) == true) {
            self.unsetFavorite(station)
        } else {
            self.setFavorite(station)
        }
    }

    fileprivate func getDateForPasslist() -> String? {
        if let arrival = arrivalScheduled, let scheduled = scheduled {
            return scheduled.formattedWith("yyyy-MM-dd'T'HH:mm") + "/" + arrival.formattedWith("yyyy-MM-dd'T'HH:mm")
        }
        return self.scheduled?.formattedWith("yyyy-MM-dd'T'HH:mm")
    }

    public func didReceiveAPIResults(_ results: JSON?, error: Error?, context: Any?) {
        let contextInfo: contextData? = context as! contextData?
/*        if (results == nil || (error != nil && self.departures != nil && self.departures?.count > 0)) {
            self.setDeparturesAsOutdated()
        } else {*/
            self.addPasslist(TFCPass.withJSON(results))
  //      }

        if (self.getPasslist()?.count == 0) {
            DLog("Passlist didn't have results for \(String(describing: contextInfo?.url)) - error was \(String(describing: error))")
        }
        DispatchQueue.main.async(execute: {
            contextInfo?.completionDelegate?.passlistUpdated(error, context: contextInfo?.context, forDeparture: self)
        })
    }

    func addPasslist(_ passlist: [TFCPass]?) {
        self.passlist = passlist
    }

    public func getPasslist() -> [TFCPass]? {
        return self.passlist
    }

    public func updatePasslist(_ completionDelegate: TFCPasslistUpdatedProtocol?, context: Any? = nil)  {
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
        if let st_id = st_id, let date = getDateForPasslist() {
            var dest_name:String?
            if let destination_id = self.destination_id {
                dest_name = destination_id
            } else {
                dest_name = getDestination().addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
            }
        return "https://tfc.chregu.tv/api/ch/connections/\(st_id)/\(dest_name!)/\(date)"
        }
        return nil
    }

    public func getStation(_ station: TFCStation? = nil) -> TFCStation? {
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
    func passlistUpdated(_ error: Error?, context: Any?, forDeparture: TFCDeparture?)
}

