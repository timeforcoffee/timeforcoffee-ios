//
//  NextDeparturesIntentHandler.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 21.09.18.
//  Copyright © 2018 opendata.ch. All rights reserved.
//

import Foundation
import WatchKit

@available(iOSApplicationExtension 12.0, *)
@available(watchOSApplicationExtension 5.0, *)
public class NextDeparturesIntentHandler: NSObject, NextDeparturesIntentHandling, TFCDeparturesUpdatedProtocol {

    /* make sure TFCStationsUpdate is kept alive */
    var stationUpdate:TFCStationsUpdate? = nil
    
    public override init() {
        super.init()
    }
    
    deinit {
        DLog("Deinit")
        self.stationUpdate = nil
    }
    
    public func confirm(intent: NextDeparturesIntent, completion: @escaping (NextDeparturesIntentResponse) -> Void) {
        completion(NextDeparturesIntentResponse(code: .ready, userActivity: nil))
        
    }
    
    public func handle(intent: NextDeparturesIntent, completion: @escaping (NextDeparturesIntentResponse) -> Void) {
        if let st_id = intent.st_id {
            if let station = TFCStation.initWithCache(id: st_id) {
                station.updateDepartures(self, context: ["completion": completion])
                return
            }
        } else {
            func stationsUpdateCompletion(stations:TFCStations?, error: String?, context: Any?) {
                if let stations = stations {
                    if let station = stations.getStation(0) {
                        
                        station.updateDepartures(self, context: ["completion": completion])
                        return
                    }
                    completion(NextDeparturesIntentResponse(code: .noStationFound, userActivity: nil))
                }
            }
            self.stationUpdate = TFCStationsUpdate(completion: stationsUpdateCompletion)
            self.stationUpdate?.update(maxStations: 1)
            return
        }
        completion(NextDeparturesIntentResponse(code: .failure, userActivity: nil))
    }

    
    fileprivate func getResponseForNextDeparture(_ forStation: TFCStation?, _ completion: ((NextDeparturesIntentResponse) -> Void)) {
        if let station = forStation {
            let _ = station.removeObsoleteDepartures()
            if let departures = station.getFilteredDepartures(nil, fallbackToAll: true)
            {
                if let departure = departures.first {
                    let minutes:String
                    if let minutesInt = departure.getMinutesAsInt() {
                        minutes = "\(minutesInt)"
                    } else {
                        minutes = "unknown"
                    }
                    
                    let response = NextDeparturesIntentResponse.success(
                        departureTime: minutes,
                        departureLine: departure.getLine(),
                        endStation: departure.getDestination(station),
                        departureStation: "\(station.getName(true))"
                    )
                    
                    completion(response)
                    return
                } else {
                    completion(NextDeparturesIntentResponse.noDeparturesFound(departureStation: station.getName(false)))
                    return
                }
            }
        }
        completion(NextDeparturesIntentResponse(code: .failure, userActivity: nil))
    }
    
    public func departuresUpdated(_ error: Error?, context: Any?, forStation: TFCStation?) {
        if let dict = context as? [String:Any?] {
            let completion:((NextDeparturesIntentResponse) -> Void) = dict["completion"] as! ((NextDeparturesIntentResponse) -> Void)
            if (error != nil) {
                DLog("\(String(describing: error))")
                completion(NextDeparturesIntentResponse(code: .failure, userActivity: nil))
            }
            getResponseForNextDeparture(forStation, completion)
        }
    }

    public func departuresStillCached(_ context: Any?, forStation: TFCStation?) {
        self.departuresUpdated(nil,context: context, forStation: forStation)
    }
}

