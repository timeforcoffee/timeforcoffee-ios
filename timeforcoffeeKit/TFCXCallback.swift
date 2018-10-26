//
//  TFCXCallback.swift
//  timeforcoffeeKit
//
//  Created by Christian Stocker on 26.10.18.
//  Copyright © 2018 opendata.ch. All rights reserved.
//

import Foundation
import CoreLocation

public final class TFCXCallback:NSObject {
    
    var stationsUpdate:TFCStationsUpdate? = nil
    
    
    public func handleCall(url: URL, callback: @escaping ((URL?) -> Void)) {
        DLog("x-callback-url: \(url)")
        
        let queryStrings = TFCXCallback.getQueryParameters(url)
        if let xSuccessUrl = queryStrings["x-success"] {
            DLog("x-callback-url path: \(url.path)")
            if (url.path == "/closest") {
                func stationsUpdateCompletion(stations:TFCStations?, error: String? = nil, context: Any? = nil) {
                    if let stations = stations {
                        if let station = stations.getStation(0) {
                            let params:[String:String?]
                            
                            if (queryStrings["latlonOnly"] == "true") {
                                params = [
                                    "latlon": "\(station.getLatitude()?.description ?? "0"),\(station.getLongitude()?.description ?? "0")"
                                ]
                                
                            } else {
                                params = [
                                    "id": station.getId(),
                                    "name": station.getName(false),
                                    "nameCityAfter": station.getName(true),
                                    "latlon": "\(station.getLatitude()?.description ?? "0"),\(station.getLongitude()?.description ?? "0")"
                                ]
                            }
                            self.callXCallBack(queryParams: params, xCallbackUrl: xSuccessUrl, callback: callback)
                        }
                    }
                }
                if let from = queryStrings["from"] {
                
                    let fromDate:Date?
                    if #available(iOSApplicationExtension 10.0, *) {
                        let dateFormatter = ISO8601DateFormatter()
                        fromDate = dateFormatter.date(from: from) // "Jun 5, 2016, 4:56 PM"
                    } else {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
                        fromDate = dateFormatter.date(from: from) // "Jun 5, 2016, 4:56 PM"
                    }

                    DLog("\(String(describing: fromDate))")
                }
                if let lat = queryStrings["lat"],
                    let lon = queryStrings["lon"],
                    let dlat = Double(lat),
                    let dlon = Double(lon)
                {
                    let loc = CLLocation(latitude: dlat, longitude: dlon)
                    let stations = TFCStations()
                    stations.initStationsByLocation(loc, currentRealLocation: false)
                    stationsUpdateCompletion(stations: stations)
                } else {
                    self.stationsUpdate = TFCStationsUpdate(completion: stationsUpdateCompletion)
                    self.stationsUpdate?.update(maxStations: 1)
                }
            }
        }
    }
    
    fileprivate func callXCallBack(queryParams: [String: String?], xCallbackUrl: String, callback:((URL?) -> Void)) {
        var components = URLComponents()
        components.queryItems = queryParams.map {
            URLQueryItem(name: $0, value: $1)
        }
        
        if let callBackUrl = URL(string: "\(xCallbackUrl)\(components.url?.absoluteString ?? "")") {
            DLog("Call x-callback-url: \(callBackUrl)")
            callback(callBackUrl)
        }
    }
    open class func getQueryParameters(_ url: URL) -> [String: String] {
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
        return queryStrings
    }
}
