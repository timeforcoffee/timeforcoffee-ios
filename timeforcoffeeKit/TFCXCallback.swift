//
//  TFCXCallback.swift
//  timeforcoffeeKit
//
//  Created by Christian Stocker on 26.10.18.
//  Copyright © 2018 opendata.ch. All rights reserved.
//

import Foundation
import CoreLocation

public final class TFCXCallback:NSObject, TFCDeparturesUpdatedProtocol{

    
    
    var stationsUpdate:TFCStationsUpdate? = nil
    
    
    public func handleCall(queryStrings: [String:String], callback: @escaping ((String?, TFCXCallbackObject) -> Void)) {
        let cbObject = TFCXCallbackObject()
        if (queryStrings["method"] == "station") {
            func stationsUpdateCompletion(stations:TFCStations?, error: String? = nil, context: Any? = nil) {
                if let stations = stations {
                    if let station = stations.getStation(0) {
                        cbObject.station = station
                        if (queryStrings["latlonOnly"] == "true") {
                         
                            cbObject.latlonOnly = true
                            
                        } else {
                            cbObject.yourLatLon = self.getYourLatLon(station, queryStrings: queryStrings)
                        }
                        callback(nil, cbObject)
                        return
                        
                    }
                }
                callback("Something went wrong with getting the station", cbObject)
                return
            }
            if let loc = getCurrentAskedLoc(queryStrings)
            {
                let stations = TFCStations()
                stations.initStationsByLocation(loc, currentRealLocation: false)
                stationsUpdateCompletion(stations: stations)
            } else {
                self.stationsUpdate = TFCStationsUpdate(completion: stationsUpdateCompletion)
                self.stationsUpdate?.update(maxStations: 1)
            }
            
        } else if (queryStrings["method"] == nil || queryStrings["method"] == "departure") {
            var fromDate:Date? = Date()
            if let from = queryStrings["time"]?.replace(" ([0-9]{2}:[0-9]{2})", template: "+$1") {
                if #available(iOSApplicationExtension 10.0, *) {
                    let dateFormatter = ISO8601DateFormatter()
                    fromDate = dateFormatter.date(from: from) // "Jun 5, 2016, 4:56 PM"
                } else {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
                    fromDate = dateFormatter.date(from: from) // "Jun 5, 2016, 4:56 PM"
                }
                //FIXME: add error, when fromDate == nil
                
                DLog("fromDate: \(String(describing: fromDate))")
            }
            func departuresUpdatedCallback(_ forStation: TFCStation?) {
                if let forStation = forStation,
                    let filteredDeparters = forStation.getFilteredDepartures() {
                    var firstDept:TFCDeparture? = filteredDeparters.first
                    if let fromDate = fromDate {
                        for dept in filteredDeparters {
                            if let deptTime = dept.getRealDepartureDate() {
                                if fromDate.timeIntervalSince1970 <= deptTime.timeIntervalSince1970 {
                                    firstDept = dept
                                    break
                                }
                            }
                        }
                    }
                    cbObject.station = forStation
                    cbObject.yourLatLon = self.getYourLatLon(forStation, queryStrings: queryStrings)
                    if let firstDept = firstDept {
                        cbObject.departure = firstDept
                    }
                    callback(nil, cbObject)
                    return
                }
                callback("Something went wrong with getting departures", cbObject)
                return
            }
            
            if let id = queryStrings["id"] {
                if let station = TFCStation.initWithCacheId(id) {
                    station.updateDepartures(self, context: ["callback" : departuresUpdatedCallback], onlyFirstDownload: true)
                    return
                }
            } else {
                if let loc = getCurrentAskedLoc(queryStrings) {
                    let stations = TFCStations()
                    stations.initStationsByLocation(loc, currentRealLocation: false)
                    if let station = stations.getStation(0) {
                        station.updateDepartures(self, context: ["callback" : departuresUpdatedCallback], onlyFirstDownload: true)
                        return
                    }
                    callback("Something went wrong with getting the station", cbObject)
                    return
                } else {
                    func stationsUpdateCompletion(stations:TFCStations?, error: String? = nil, context: Any? = nil) {
                        if let stations = stations {
                            if let station = stations.getStation(0) {
                                station.updateDepartures(self, context: ["callback" : departuresUpdatedCallback], onlyFirstDownload: true)
                                
                            }
                        }
                    }
                    self.stationsUpdate = TFCStationsUpdate(completion: stationsUpdateCompletion)
                    self.stationsUpdate?.update(maxStations: 1)
                }
            }
        }
    }
    
    fileprivate func getCurrentAskedLoc(_ queryStrings: [String: String]) -> CLLocation? {
        if let lat = queryStrings["lat"],
            let lon = queryStrings["lon"],
            let dlat = Double(lat),
            let dlon = Double(lon)
        {
            return CLLocation(latitude: dlat, longitude: dlon)
        }
        return nil
    }
    
    func getYourLatLon(_ station: TFCStation, queryStrings:[String:String]?) -> CLLocation? {
        var loc = TFCLocationManager.getCurrentLocation(ttl: 5)
        if let askedLoc = getCurrentAskedLoc(queryStrings ?? [:]) {
            loc = askedLoc
        }
        return loc
        
    }
    
 
    public func departuresUpdated(_ error: Error?, context: Any?, forStation: TFCStation?) {
        if let context = context as? [String: ((TFCStation?) -> Void)],
            let callback = context["callback"] {
            callback(forStation)
        }
    }
    
    public func departuresStillCached(_ context: Any?, forStation: TFCStation?) {
        departuresUpdated(nil, context: context, forStation: forStation)
    }
    
    
    
    public class func fillParametersFromDict(_ dict: String?, _ queryStrings: inout [String : String]) {
        var result = JSON()
        if let dict = dict {
            result = JSON(parseJSON: dict)
        }
        for (key, value) in result {
            queryStrings[key] = value.string
        }
    }
    
    public class func getQueryParameters(_ url: URL) -> [String: String] {
        var queryStrings = [String: String]()
        if let query = url.query {
            for qs in query.components(separatedBy: "&") {
                // Get the parameter name
                let key = qs.components(separatedBy: "=")[0]
                // Get the parameter name
                var value = qs.components(separatedBy: "=")[1]
                value = value.replacingOccurrences(of: "+", with: " ")
                value = value.removingPercentEncoding!
                queryStrings[key] = value
            }
        }
        if let dict = queryStrings["dict"] {
            fillParametersFromDict(dict, &queryStrings)
        }

        return queryStrings
    }
}
