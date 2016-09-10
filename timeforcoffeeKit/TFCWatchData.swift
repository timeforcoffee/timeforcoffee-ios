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
import ClockKit

private struct Constants {
    static let FrequencyOfTimelineUpdate = NSTimeInterval(30*60) // 45 minutes
    static let TimelineUpdateMinutesBeforeEnd = NSTimeInterval(-15*60) // 15 minutes
}

public final class TFCWatchData: NSObject, TFCLocationManagerDelegate,  TFCStationsUpdatedProtocol {

    private var networkErrorMsg: String?

    private var replyNearby: replyClosure?
    private lazy var stations: TFCStations? =  {return TFCStations(delegate: self)}()
    private lazy var locManager: TFCLocationManager? = self.lazyInitLocationManager()

    private struct replyContext {
        var reply: replyStations?
        var errorReply: ((String) -> Void)?
    }

    public override init () {
        super.init()
    }
    
    private func lazyInitLocationManager() -> TFCLocationManager? {
        return TFCLocationManager(delegate: self)
    }

    public func locationFixed(loc: CLLocation?) {
        if let coord = loc?.coordinate {
            DLog("location fixed \(loc)", toFile: true)
            replyNearby!(["lat" : coord.latitude, "long": coord.longitude]);
        } 
    }

    public func locationDenied(manager: CLLocationManager, err:NSError) {
        DLog("location DENIED \(err)", toFile: true)
        replyNearby!(["error": err]);
    }

    public func locationStillTrying(manager: CLLocationManager, err: NSError) {
        DLog("location still trying \(err)")
    }

    public func getLocation(reply: replyClosure?) {
        // this is a not so nice way to get the reply Closure to later when we actually have
        // the data from the API... (in locationFixed)
        DLog("get new location in watch", toFile: true)
        self.replyNearby = reply
        locManager?.refreshLocation()
    }

    public func updateComplication(stations: TFCStations) {
        if let firstStation = stations.first {
            if self.needsTimelineDataUpdate(firstStation) {
                DLog("updateComplicationData", toFile: true)
                updateComplicationData()
            }
        }
    }

    /*
     * sometimes we want to wait a few seconds to see, if there's a new current location before we
     * start the complication update
     * This especially happens, when we call from the iPhone for a new update and send
     * data as userInfo, which usually happens a little bit later
     */

    public func waitForNewLocation(within seconds:Int, callback: () -> Void) {

        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        dispatch_async(queue) {
            self.waitForNewLocation(within: seconds, counter: 0, queue: queue, callback: callback)
        }
    }


    private func waitForNewLocation(within seconds:Int, counter:Int = 0, queue:dispatch_queue_t? = nil, callback: () -> Void) {
        DLog("\(counter)")

        if (counter > seconds || self.locManager?.getLastLocation(seconds) != nil) {
            callback()
            return
        }
        delay(1.0, closure: {self.waitForNewLocation(within: seconds, counter: (counter + 1), queue: queue, callback: callback)}, queue: queue)
    }

    public func updateComplicationData() {
        // reload the timeline for all complications
        let server = CLKComplicationServer.sharedInstance()
        if let activeComplications = server.activeComplications {
            if (activeComplications.count > 0) {
                for complication in activeComplications {
                    DLog("Reload Complications", toFile: true)
                    server.reloadTimelineForComplication(complication)
                }
            }
        }
    }

    public func getStations(reply: replyStations?, errorReply: ((String) -> Void)?, stopWithFavorites: Bool?) {
        func handleReply(replyInfo: [NSObject : AnyObject]!) {
            DLog("handleReply")
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
                self.stations?.searchForStationsInDB(loc.coordinate, context: replyC)
            } else {
                if let err = replyInfo["error"] as? NSError {
                    if (err.code == CLError.LocationUnknown.rawValue) {
                        self.networkErrorMsg = "Airplane mode?"
                    } else {
                        self.networkErrorMsg = "Location not available"
                    }
                    if let errorReply = errorReply, networkErrorMsg = self.networkErrorMsg {
                       errorReply(networkErrorMsg)
                    }
                }
            }
        }
        // check if we now a last location, and take that if it's not older than 30 seconds
        //  to avoid multiple location lookups
        if let cachedLoc = locManager?.getLastLocation(30)?.coordinate {
            DLog("still cached location \(cachedLoc)", toFile: true)
            handleReply(["lat" : cachedLoc.latitude, "long": cachedLoc.longitude])
        } else {
            self.getLocation(handleReply)
        }
    }

    public func stationsUpdated(error: String?, favoritesOnly: Bool, context: Any?) {
        if let reply:replyContext = context as? replyContext {
            if (error != nil) {
                if let reply = reply.errorReply {
                    reply(error!)
                }
            } else {
                if let reply:replyStations = reply.reply {
                    reply(self.stations)
                }
            }
        }
    }

    public func getBackOffTime(noBackOffIncr noBackOffIncr:Bool? = false) -> NSDate {
        var backoffCount = TFCDataStore.sharedInstance.getUserDefaults()?.integerForKey("backoffCount")
        if (backoffCount == nil) {
            backoffCount = 1
        }
        var backoffTime = 2 ^ backoffCount!
        if (backoffTime > 60) {
            backoffTime = 60
            backoffCount = 6
        } else {
            backoffCount = backoffCount! + 1
        }
        TFCDataStore.sharedInstance.getUserDefaults()?.setInteger(backoffCount!, forKey: "backoffCount")
        return NSDate().dateByAddingTimeInterval(Double(backoffTime) * 60)
    }

    func clearBackOffTime() {
        TFCDataStore.sharedInstance.getUserDefaults()?.setObject(nil, forKey: "backoffCount")
    }

    public func getNextUpdateTime(noBackOffIncr noBackOffIncr:Bool? = false) -> NSDate {
        var nextUpdateDate:NSDate?        
        let maxNextUpdateDate = NSDate().dateByAddingTimeInterval(Constants.FrequencyOfTimelineUpdate)
        if let nextUpdate =  NSUserDefaults().valueForKey("lastDepartureTime") as? NSDate {
            let lastEntryDate = nextUpdate.dateByAddingTimeInterval(Constants.TimelineUpdateMinutesBeforeEnd)
            //if lastEntryDate is before now, update again in 5 minutes
            if (lastEntryDate.timeIntervalSinceNow < NSDate().timeIntervalSinceNow) {
                nextUpdateDate = getBackOffTime(noBackOffIncr: noBackOffIncr)
                //if lastEntryDate is more in the future than 0.5 hours
            } else if (maxNextUpdateDate.timeIntervalSinceReferenceDate < lastEntryDate.timeIntervalSinceReferenceDate) {
                nextUpdateDate = maxNextUpdateDate
                clearBackOffTime()
            } else {
                nextUpdateDate = lastEntryDate
                clearBackOffTime()
            }
        } else {
            nextUpdateDate =  getBackOffTime() // request an update in 5 minutes, if no lastDepartureTime was set.
        }
        return nextUpdateDate!
    }

    public func scheduleNextUpdate() {
            let nextUpdate:NSDate
            if (CLKComplicationServer.sharedInstance().activeComplications?.count > 0) {
                nextUpdate = self.getNextUpdateTime()
            } else {
                nextUpdate = NSDate().dateByAddingTimeInterval(30 * 60)
            }
            WKExtension.sharedExtension().scheduleBackgroundRefreshWithPreferredDate(nextUpdate, userInfo: nil) { (error) in
                DLog("updated next schedule at \(nextUpdate)", toFile: true)
                if error == nil {
                    //successful
                }
            }        
    }

    public func needsTimelineDataUpdate(station: TFCStation) -> Bool {
        if let lastDepartureTime:NSDate = NSUserDefaults().valueForKey("lastDepartureTime") as? NSDate,
            lastFirstStationId = NSUserDefaults(suiteName: "group.ch.opendata.timeforcoffee")?.stringForKey("lastFirstStationId"),
            departures = station.getFilteredDepartures() {
            DLog("\(lastFirstStationId) == \(station.st_id)", toFile: true)
            DLog("\(departures.last?.getScheduledTimeAsNSDate()) <= \(lastDepartureTime.dateByAddingTimeInterval(-60))", toFile: true)
            if (lastFirstStationId == station.st_id
                && departures.last?.getScheduledTimeAsNSDate() <= lastDepartureTime.dateByAddingTimeInterval(-60)) {
                return false
            }
        }
        return true
    }

    public func needsDeparturesUpdate(station: TFCStation) -> Bool {
        if let lastDepartureTime =  NSUserDefaults().valueForKey("lastDepartureTime") as? NSDate,
            lastFirstStationId = NSUserDefaults(suiteName: "group.ch.opendata.timeforcoffee")?.stringForKey("lastFirstStationId"),
            departures = station.getFilteredDepartures() {
            // if lastDepartureTime is more than 4 hours away and we're in the same place
            // and we still have at least 5 departures, just use the departures from the cache
            if ((lastDepartureTime.dateByAddingTimeInterval(4 * -3600).timeIntervalSinceNow > 0)
                && lastFirstStationId == station.st_id
                && departures.count > 5
                ) {
                return false
            }
            DLog("timeIntervalSinceNow \(lastDepartureTime.dateByAddingTimeInterval(4 * -3600).timeIntervalSinceNow)")
            DLog("lastDepartureTime: \(lastDepartureTime)")
            DLog("lastFirstStationId: \(lastFirstStationId)")
            DLog("station.getFilteredDepartures()?.count: \(station.getFilteredDepartures()?.count)")

        }
        return true
    }
}

public class TFCPageContext: NSObject {

    public override init() {
        super.init()
    }

    public var station:TFCStation?
    public var pageNumber:Int?
}
