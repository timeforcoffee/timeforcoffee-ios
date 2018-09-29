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
        if (intent.stationObj == nil && intent.closest == nil) {
            completion(NextDeparturesIntentResponse(code: .continueInApp, userActivity: nil))
            return
        } 
        completion(NextDeparturesIntentResponse(code: .ready, userActivity: nil))
    }
    
    fileprivate func updateDepartures(_ station: TFCStation,  _ completion: @escaping (NextDeparturesIntentResponse) -> Void) {
        #if os(watchOS)
        let _ = station.removeObsoleteDepartures(true)
        //check if we have at least 2 minute fresh data. Good enough for this usecas
        if let lDU = station.lastDepartureUpdate,
            lDU.addingTimeInterval(120) > Date()
        {
            if let departures = station.getFilteredDepartures(nil, fallbackToAll: true) {
                // if we already do have departures, we don't need to update them on watchOS
                if (departures.count > 0) {
                    departuresUpdated(nil, context: ["completion": completion], forStation: station)
                    return
                }
            }
        }
        #endif
        station.updateDepartures(self, context: ["completion": completion])
    }
    
    public func handle(intent: NextDeparturesIntent, completion: @escaping (NextDeparturesIntentResponse) -> Void) {
        
        if let st_id = intent.stationObj?.identifier {
            if let station = TFCStation.initWithCache(id: st_id) {
                return updateDepartures(station, completion)
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

    
    fileprivate func getResponseForNextDeparture(_ forStation: TFCStation?, _ completion: @escaping ((NextDeparturesIntentResponse) -> Void)) {
        if let station = forStation {
            let _ = station.removeObsoleteDepartures(true)
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

                    #if !os(watchOS)
                    if let currentLoc = TFCLocationManager.getCurrentLocation(ttl: 90),
                        let distance = station.getDistanceInMeter(currentLoc),
                        distance < 5000 {
                        if ("" != station.getDistanceForDisplay(currentLoc, completion: { (text: String?) in
                            if let text = text {
                                if (text.match("([0-9]+) min")) {
                                    let minutes = text.replace(".* ([0-9]+) .*min.*", template: "$1")
                                    var code = NextDeparturesIntentResponseCode.successWithWalkingTime
                                    if let departureTimeString = response.departureTime,
                                        
                                        let minutesInt = Int(minutes),
                                        let departureTime = Int(departureTimeString)
                                    {
                                        if (minutesInt > departureTime) {
                                            code = NextDeparturesIntentResponseCode.successWithWalkingTimeHurry
                                        }
                                    }
                                    let responseWith = NextDeparturesIntentResponse(code: code, userActivity: nil)
                                    DLog("Distance: \(String(describing: minutes))")
                                    
                                    responseWith.departureTime = response.departureTime ?? ""
                                    responseWith.departureLine = response.departureLine ?? ""
                                    responseWith.endStation = response.endStation ?? ""
                                    responseWith.departureStation = response.departureStation ?? ""
                                    responseWith.walkingTime = minutes
                                    
                                    completion(responseWith)
                                    return
                                }
                                
                                
                            }
                            completion(response)
                        })) {
                            return
                        }
                    }
                    #endif
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

