//
//  NextDeparturesIntentHandler.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 21.09.18.
//  Copyright © 2018 opendata.ch. All rights reserved.
//

import Foundation
#if os(watchOS)
import WatchKit
#endif
import WatchConnectivity
import Intents

@available(iOSApplicationExtension 12.0, *)
@available(watchOSApplicationExtension 5.0, *)
public class NextDeparturesIntentHandler: NSObject, NextDeparturesIntentHandling {
    
    @available(iOSApplicationExtension 13.0, *)
    @available(watchOSApplicationExtension 6.0, *)
    public func resolveTime(for intent: NextDeparturesIntent, with completion: @escaping (INDateComponentsResolutionResult) -> Void) {
        if let time =  intent.time {
            completion(INDateComponentsResolutionResult.success(with: time))
            return
        }
        completion(INDateComponentsResolutionResult.confirmationRequired(with: nil))

    }
    
    @available(iOSApplicationExtension 13.0, *)
    @available(watchOSApplicationExtension 6.0, *)
    public func resolveLocation(for intent: NextDeparturesIntent, with completion: @escaping (INPlacemarkResolutionResult) -> Void) {

        if let location =  intent.location {
            completion(INPlacemarkResolutionResult.success(with: location ))
            return
        }
        completion(INPlacemarkResolutionResult.confirmationRequired(with: nil))
    }

    public override init() {
        super.init()
    }
    
    deinit {
        DLog("Deinit")
    }
    
    public func confirm(intent: NextDeparturesIntent, completion: @escaping (NextDeparturesIntentResponse) -> Void) {
        if ((intent.stationObj == nil && intent.closest == nil && intent.location == nil)) {
            completion(NextDeparturesIntentResponse(code: .continueInApp, userActivity: nil))
            return
        }
        
        if (intent.departure?.displayString.suffix(1) == ".") {
            completion(NextDeparturesIntentResponse(code: .continueInApp, userActivity: nil))
            return
        }
        
        completion(NextDeparturesIntentResponse(code: .ready, userActivity: nil))
    }
    
    public func handle(intent: NextDeparturesIntent, completion: @escaping (NextDeparturesIntentResponse) -> Void) {
        
        func XCallback (error: String?, cbObject: TFCXCallbackObject) -> Void {
            //replace ? in the beginning
            //FIXME .noStationFound and such
            if let error = error {
                completion(NextDeparturesIntentResponse(code: .failure, userActivity: nil))
                DLog(error)
                return
            }
            
            let response = NextDeparturesIntentResponse.success(
                departureTime: cbObject.getDepartureTimeMinutesOrUnknown(),
                departureLine: cbObject.getDepartureLineOrUnkown(),
                endStation: cbObject.getEndStationOrUnknown(),
                departureStation: cbObject.getDepartureStationOrUnknown(true)
            )
            
            response.responseInfo = cbObject.getJson()
            DLog(response.responseInfo)
            if (cbObject.departure === nil) {
                completion(NextDeparturesIntentResponse.noDeparturesFound(departureStation: cbObject.getDepartureStationOrUnknown()))

            }
            #if !os(watchOS)
            if let currentLoc = TFCLocationManager.getCurrentLocation(ttl: 120),
                let station = cbObject.station,
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
                            responseWith.responseInfo = response.responseInfo
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
        }
        
        var queryStrings:[String:String] = [:]
        let cbx = TFCXCallback()
        if let st_id = intent.stationObj?.identifier {
            
            queryStrings["id"] = st_id
        } else if let loc = intent.location?.location {
            queryStrings = ["lat": "\(loc.coordinate.latitude)", "lon": "\(loc.coordinate.longitude)"]
        }
        
        if #available(iOSApplicationExtension 13.0, watchOSApplicationExtension 6.0,*) {
            if let time = intent.time?.date {
                    queryStrings["time"] = TFCDeparturePass.LongDateFormatterTransport.string(from: time)
                }
        }
        cbx.handleCall(queryStrings: queryStrings, callback: XCallback)
        
        return
    }
}

