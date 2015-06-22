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
    private lazy var stations: TFCStations? =  {return TFCStations()}()
    private lazy var locManager: TFCLocationManager? = self.lazyInitLocationManager()

    private struct replyContext {
        var reply: replyStations?
        var errorReply: ((String) -> Void)?
    }

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
                var replyC:replyContext = replyContext()
                replyC.reply = reply
                replyC.errorReply = errorReply
                self.api?.searchFor(loc.coordinate, context: replyC)
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
        let reply:replyContext = context as! replyContext
        if (!(error != nil && error?.code == -999)) {
            let errorReply = reply.errorReply
            if (error != nil || results == nil) {
                self.networkErrorMsg = NSLocalizedString("Network error. Please try again", comment: "")
                if (errorReply != nil) {
                    errorReply!(self.networkErrorMsg!)
                }

            } else {
                self.networkErrorMsg = nil
            }
            if (results != nil && TFCStation.isStations(results!)) {
                if let stations = self.stations {
                    stations.addWithJSON(results)
                    if (!(stations.count() > 0)) {
                        if (errorReply != nil) {
                            let reason = stations.getReasonForNoStationFound()
                            if (reason != nil)  {
                                errorReply!("No stations found. \(reason!)")
                            } else {
                                errorReply!("No stations found.")
                            }
                            return
                        }
                    }
                }

            }
            if let reply:replyStations = reply.reply {
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
