//
//  TFCStationsUpdate.swift
//  timeforcoffeeKit
//
//  Created by Christian Stocker on 23.09.18.
//  Copyright © 2018 opendata.ch. All rights reserved.
//

import Foundation

/** little wrapper class to get updated stations with a completion handler
 and not having to go through TFCSTtationsUpdateProtocol and fiddle with
 context
 */
public final class TFCStationsUpdate: TFCStationsUpdatedProtocol {
    let completion:((TFCStations?, _ error:String?, _ context:Any?) -> Void)
    var stations:TFCStations? = nil
    let context:Any?
    var completionRun = false
    public init(completion:@escaping ((TFCStations?, _ error:String?, _ context:Any?) -> Void),
                context: Any? = nil) {
        self.completion = completion
        self.context = context
    }
    
    public func update(force:Bool = false, maxStations:Int = 100) {
        self.stations = TFCStations(delegate: self, maxStations: maxStations)
        if let stations = self.stations {
            self.completionRun = false
            if (!stations.updateStations(force)) {
                self.callCompletion(stations, nil)
            }
            return
        }
        self.callCompletion(nil, "Not updated")
    }
    
    public func stationsUpdated(_ error: String?, favoritesOnly: Bool, context: Any?, stations:TFCStations) {
        callCompletion(stations, error)
    }
    
    fileprivate func callCompletion(_ stations: TFCStations?, _ error: String?) {
        if(!self.completionRun) {
            self.completion(stations?.copy() as? TFCStations, error, self.context)
            self.completionRun = true
        }
    }
    
    deinit {
        DLog("Deinit")
    }
}

