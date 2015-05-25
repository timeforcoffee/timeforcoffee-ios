//
//  TFCWatchData.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 04.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation
import WatchKit

public final class TFCWatchData: NSObject, TFCLocationManagerDelegate, APIControllerProtocol {

    public class var sharedInstance: TFCWatchData {
        struct Static {
            static let instance: TFCWatchData = TFCWatchData()
        }
        return Static.instance
    }
    private var networkErrorMsg: String?

    private var replyNearby: replyClosure?
    public lazy var stations: TFCStations? =  {return TFCStations()}()
    private lazy var locManager: TFCLocationManager? = self.lazyInitLocationManager()


    private lazy var api : APIController? = {
        [unowned self] in
        return APIController(delegate: self)
        }()

    public override init () {
        super.init()
    }
    
    private func lazyInitLocationManager() -> TFCLocationManager? {
        return TFCLocationManager(delegate: self)
    }

    public func locationFixed(loc: CLLocation?) {
        //do nothing here, you have to overwrite that
        if let coord = loc?.coordinate {
            replyNearby!(["lat" : coord.latitude, "long": coord.longitude]);
        } else {
            replyNearby!(["coord" : "none"]);
        }
    }

    public func locationDenied(manager: CLLocationManager, err:NSError) {
        replyNearby!(["error": err]);
    }

    public func locationStillTrying(manager: CLLocationManager, err: NSError) {
        
    }

    public func getLocation(reply: replyClosure?) {
        // this is a not so nice way to get the reply Closure to later when we actually have
        // the data from the API... (in locationFixed)
        self.replyNearby = reply
        locManager?.refreshLocation()
    }

    public func getStations(reply: replyStations?, errorReply: ((String) -> Void)?, stopWithFavorites: Bool?) {
        func handleReply(replyInfo: [NSObject : AnyObject]!) {
            if(replyInfo["lat"] != nil) {
                let loc = CLLocation(latitude: replyInfo["lat"] as! Double, longitude: replyInfo["long"] as! Double)
                self.stations?.initWithNearbyFavorites(loc)
                if (stopWithFavorites == true && self.stations?.count() > 0 && reply != nil ) {
                    reply!(self.stations)
                    return
                }
                self.api?.searchFor(loc.coordinate, context: reply)
            } else {
                if let err = replyInfo["error"] as? NSError {
                    if (err.code == CLError.LocationUnknown.rawValue) {
                        self.networkErrorMsg = "Airplane mode?"
                    } else {
                        self.networkErrorMsg = "Location not available"
                    }
                    errorReply!(self.networkErrorMsg!)
                }
            }
        }
        TFCWatchData.sharedInstance.getLocation(handleReply)
    }

    public func didReceiveAPIResults(results: JSON?, error: NSError?, context: Any?) {
        if (!(error != nil && error?.code == -999)) {
            if (error != nil || results == nil) {
                self.networkErrorMsg = NSLocalizedString("Network error. Please try again", comment: "")
            } else {
                self.networkErrorMsg = nil
            }
            if (results != nil && TFCStation.isStations(results!)) {
                self.stations?.addWithJSON(results)
            }
            if let reply:replyStations = context as? replyStations {
                reply(self.stations)
            }
        }
    }
}

public class TFCPageContext: NSObject {

    public override init() {
        super.init()
    }

    public var station:TFCStation?
    public var pageNumber:Int?
}
