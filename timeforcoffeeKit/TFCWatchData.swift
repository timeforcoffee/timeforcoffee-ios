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

public class TFCWatchData: NSObject, TFCLocationManagerDelegate, APIControllerProtocol {

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

    /* USED FROM THE APP */
    public func locationFixed(loc: CLLocation?) {
        //do nothing here, you have to overwrite that
        if let coord = loc?.coordinate {
            replyNearby!(["lat" : coord.latitude, "long": coord.longitude]);
        } else {
            replyNearby!(["coord" : "none"]);
        }
    }

    public func locationDenied(manager: CLLocationManager, err:NSError) {

    }

    public func locationStillTrying(manager: CLLocationManager, err: NSError) {
        
    }

    public func getLocation(reply: replyClosure?) {
        // this is a not so nice way to get the reply Closure to later when we actually have
        // the data from the API... (in locationFixed)
        self.replyNearby = reply
        locManager?.refreshLocation()
    }
    /* END USED FROM THE APP */

    /* USED FROM THE WATCHKIT EXTENSION */
    public func getStations(reply: replyStations, stopWithFavorites: Bool?) {
        func handleReply(replyInfo: [NSObject : AnyObject]!, error: NSError!) {
            if(replyInfo["lat"] != nil) {
                let loc = CLLocation(latitude: replyInfo["lat"] as Double, longitude: replyInfo["long"] as Double)
                self.stations?.initWithNearbyFavorites(loc)
                if (stopWithFavorites == true && self.stations?.count() > 0 ) {
                    reply(self.stations?)
                    return
                }
                self.api?.searchFor(loc.coordinate, context: reply)
            }
        }
        WKInterfaceController.openParentApplication(["module":"location"], handleReply)
    }

    public func didReceiveAPIResults(results: JSONValue, error: NSError?, context: Any?) {
        if (!(error != nil && error?.code == -999)) {
            if (error != nil) {
                self.networkErrorMsg = NSLocalizedString("Network error. Please try again", comment: "")
            } else {
                self.networkErrorMsg = nil
            }
            if (TFCStation.isStations(results)) {
                self.stations?.addWithJSON(results)
            }
            if let reply:replyStations = context as? replyStations {
                reply(self.stations)
            }
        }
    }
}
