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
public class GetStationIntentHandler: NSObject, GetStationIntentHandling {
    @available(iOSApplicationExtension 13.0, *)
    @available(watchOSApplicationExtension 6.0, *)
    public func resolveLocation(for intent: GetStationIntent, with completion: @escaping (INPlacemarkResolutionResult) -> Void) {
        
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
    
    public func confirm(intent: GetStationIntent, completion: @escaping (GetStationIntentResponse) -> Void) {
        //FIXME: should resolve to nearest station
        if (intent.location == nil) {
            completion(GetStationIntentResponse(code: .continueInApp, userActivity: nil))
            return
        }
        
        completion(GetStationIntentResponse(code: .ready, userActivity: nil))
    }
    
    public func handle(intent: GetStationIntent, completion: @escaping (GetStationIntentResponse) -> Void) {
        
        func XCallback (error: String?, cbObject: TFCXCallbackObject) -> Void {
            //replace ? in the beginning
            //FIXME .noStationFound and such
            if let error = error {
                completion(GetStationIntentResponse(code: .failure, userActivity: nil))
                DLog(error)
                return
            }
            
            let response = GetStationIntentResponse.success(departureStation: cbObject.getDepartureStationOrUnknown(false)
            )
            
            response.responseInfo = cbObject.getJson()
            DLog(response.responseInfo)
            if (cbObject.station === nil) {
                completion(GetStationIntentResponse(code: .failure, userActivity: nil))
                
            }
           
            completion(response)
        }
        
        var queryStrings:[String:String] = [:]
        let cbx = TFCXCallback()
        if let loc = intent.location?.location {
            queryStrings = ["lat": "\(loc.coordinate.latitude)", "lon": "\(loc.coordinate.longitude)"]
        }
        
       queryStrings["method"] = "station"
        cbx.handleCall(queryStrings: queryStrings, callback: XCallback)
        
        return
    }
}

