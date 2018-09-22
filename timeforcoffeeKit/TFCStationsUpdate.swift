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
    public init(completion:@escaping ((TFCStations?, _ error:String?, _ context:Any?) -> Void),
         context: Any? = nil) {
        self.completion = completion
        self.context = context
    }
    
    public func update(force:Bool = false, maxStations:Int = 100) {
        self.stations = TFCStations(delegate: self, maxStations: maxStations)
        if let stations = self.stations {
            if (!stations.updateStations(force)) {
                self.completion(stations, nil, self.context)
            }
            return
        }
        self.completion(nil, "Not updated", self.context)
    }
    
    public func stationsUpdated(_ error: String?, favoritesOnly: Bool, context: Any?, stations:TFCStations) {
        self.completion(stations, error, self.context)
    }
    
    deinit {
        DLog("Deinit")
    }
}

