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
    static let FrequencyOfTimelineUpdate = NSTimeInterval(30*60) // 30 minutes
    static let TimelineUpdateMinutesBeforeEnd = NSTimeInterval(-15*60) // 15 minutes
}

public final class TFCWatchData: NSObject, TFCLocationManagerDelegate,  TFCStationsUpdatedProtocol {

    private var networkErrorMsg: String?

    public var noCrunchQueue = false
    private var replyNearby: replyClosure?
    private lazy var stations: TFCStations? =  {return TFCStations(delegate: self)}()
    private lazy var locManager: TFCLocationManager? = self.lazyInitLocationManager()
    static  var crunchQueue:dispatch_queue_t = {
        return dispatch_queue_create("ch.opendata.timeforcoffee.crunch", DISPATCH_QUEUE_CONCURRENT)
    }()

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
        if let firstStation = stations.getStation(0) {
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
                    let ud = TFCDataStore.sharedInstance.getUserDefaults()

                    if let lastComplicationUpdate = ud?.objectForKey("lastComplicationUpdate") as? NSDate,
                        lastComplicationStationId = ud?.stringForKey("lastComplicationStationId"),
                        lastFirstStationId = ud?.stringForKey("lastFirstStationId")
                    {
                        // if last Complication update is less than 5 minutes ago
                        if (lastComplicationUpdate.dateByAddingTimeInterval(300) > NSDate() &&
                        lastComplicationStationId == lastFirstStationId) {
                            DLog("complication was updated less than 5 minutes ago (\(lastComplicationUpdate)) with the same id \(lastFirstStationId), dont reload in this case")
                            return
                        }
                    }
                    DLog("Reload Complications", toFile: true)
                    server.reloadTimelineForComplication(complication)
                }
            }
        }
    }
    static var crunchQueueTasks = 0

    public func startCrunchQueue(closure: (() -> Void)) {
        let queue:dispatch_queue_t
        if self.noCrunchQueue {
            TFCDataStore.sharedInstance.mocObjects?.performBlockAndWait {
                closure()
            }
        } else {
            #if DEBUG
                let stacktrace = NSThread.callStackSymbols()
                if (stacktrace.count > 1) {
                    let first = stacktrace[1]

                    DLog("startCrunchQueue called from \(first)")
                }
                
                (WKExtension.sharedExtension().delegate as! ExtensionDelegate).tickDebugLog()
            #endif

            queue = TFCWatchData.crunchQueue
            TFCWatchData.crunchQueueTasks += 1
            dispatch_async(queue, {
                DLog("crunchQueue started")
                TFCDataStore.sharedInstance.mocObjects?.performBlockAndWait {
                    closure()
                }
                TFCWatchData.crunchQueueTasks -= 1
            })

        }
    }

    public func getStations(reply: replyStations?, errorReply: ((String) -> Void)?, stopWithFavorites: Bool?, favoritesOnly: Bool? = false) {

        #if DEBUG
            let stacktrace = NSThread.callStackSymbols()
        #else
            let stacktrace:[String] = []
        #endif
        func handleReply(replyInfo: [NSObject : AnyObject]!) {
            startCrunchQueue {
                DLog("searchForStationsInDB handleReply getStations \(replyInfo) \(reply)", toFile: true)
                if(replyInfo["lat"] != nil) {
                    let loc = CLLocation(latitude: replyInfo["lat"] as! Double, longitude: replyInfo["long"] as! Double)
                    if (favoritesOnly == true) {
                        DLog("Favorites only, before loadFavorites", toFile: true)

                        self.stations?.loadFavorites()
                        #if DEBUG
                        DLog("stacktrace start", toFile: true)
                        for line in stacktrace {
                            DLog("stack \(line)", toFile: true)
                        }
                        DLog("stacktrace end", toFile: true)
                        #endif

                        DLog("Favorites only, reply! \(reply.debugDescription)", toFile: true)

                        reply!(self.stations)
                        return
                    }
                    self.stations?.initWithNearbyFavorites(loc)
                    if (stopWithFavorites == true && self.stations?.count() > 0 && reply != nil ) {
                        DLog("searchForStationsInDB stopWithFavorites", toFile: true)
                        reply!(self.stations)
                        return
                    }
                    var replyC:replyContext = replyContext()
                    replyC.reply = reply
                    replyC.errorReply = errorReply
                    DLog("searchForStationsInDB before", toFile: true)
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
        }
        // check if we now a last location, and take that if it's not older than 30 seconds
        //  to avoid multiple location lookups
        DLog("_")
        self.startCrunchQueue {
            if let cachedLoc = self.locManager?.getLastLocation(30)?.coordinate {
                DLog("still cached location \(cachedLoc)", toFile: true)
                handleReply(["lat" : cachedLoc.latitude, "long": cachedLoc.longitude])
            } else {
                self.getLocation(handleReply)
            }
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
        var backoffCount = TFCDataStore.sharedInstance.getUserDefaults()?.doubleForKey("backoffCount")
        if (backoffCount == nil) {
            backoffCount = 1.0
        }
        var backoffTime = exp2(backoffCount!)
        if (backoffTime > 60) {
            backoffTime = 60
            backoffCount = 6
        } else if noBackOffIncr == false {
            backoffCount = backoffCount! + 1
        }
        TFCDataStore.sharedInstance.getUserDefaults()?.setDouble(backoffCount!, forKey: "backoffCount")
        DLog("Backoff time: \(backoffTime)")
        return NSDate().dateByAddingTimeInterval(Double(backoffTime) * 60)
    }

    func clearBackOffTime() {
        TFCDataStore.sharedInstance.getUserDefaults()?.setObject(nil, forKey: "backoffCount")
    }

    public func getNextUpdateTime(noBackOffIncr noBackOffIncr:Bool? = false, minTime:Int? = 0) -> NSDate {
        var nextUpdateDate:NSDate?        
        var maxNextUpdateDate = NSDate().dateByAddingTimeInterval(Constants.FrequencyOfTimelineUpdate)
        // if the next first departure Time is further away than usual, wait until that comes and update 15 minutes before
        if let firstDepartureTime = TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("firstDepartureTime") as? NSDate {
            if firstDepartureTime.dateByAddingTimeInterval(-15 * 60) > maxNextUpdateDate {
                maxNextUpdateDate = firstDepartureTime.dateByAddingTimeInterval(-15 * 60)
            }
        }
        if let nextUpdate = TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("lastDepartureTime") as? NSDate {
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
            nextUpdateDate =  getBackOffTime(noBackOffIncr: noBackOffIncr) // request an update in 5 minutes, if no lastDepartureTime was set.
        }
        if nextUpdateDate < NSDate() {
            DLog("WARNING: \(nextUpdateDate) < \(NSDate())")
            nextUpdateDate = getBackOffTime(noBackOffIncr: true)
        }
        if let minTime = minTime {
            let minDate = NSDate().dateByAddingTimeInterval(Double(minTime))
            nextUpdateDate = max(minDate, nextUpdateDate!)
        }
        return nextUpdateDate!
    }

    public func scheduleNextUpdate(noBackOffIncr noBackOffIncr:Bool? = false) {
            let nextUpdate:NSDate
            if (CLKComplicationServer.sharedInstance().activeComplications?.count > 0) {
                nextUpdate = self.getNextUpdateTime(noBackOffIncr: noBackOffIncr)
            } else {
                nextUpdate = NSDate().dateByAddingTimeInterval(30 * 60)
            }
        if #available(watchOSApplicationExtension 3.0, *) {
            let ud = TFCDataStore.sharedInstance.getUserDefaults()

            ud?.setObject(nextUpdate, forKey: "lastBackgroundRefreshDate")
            WKExtension.sharedExtension().scheduleBackgroundRefreshWithPreferredDate(nextUpdate, userInfo: nil) { (error) in
                DLog("updated next schedule at \(nextUpdate.formattedWithDateFormatter(DLogDateFormatter)) error: \(error)", toFile: true)
            }
        }        
    }
    public func needsTimelineDataUpdate(station: TFCStation) -> Bool {
        let ud = TFCDataStore.sharedInstance.getUserDefaults()

        DLog("lastDepartureTime:NSDate = \(ud?.objectForKey("lastDepartureTime") as? NSDate)", toFile: true)
        DLog("lastFirstStationId = \(ud?.stringForKey("lastFirstStationId"))", toFile: true)
        DLog("departures = \(station.getFilteredDepartures()?.count))", toFile: true)

        if let ud = ud, lastDepartureTime:NSDate = ud.objectForKey("lastDepartureTime") as? NSDate,
            lastFirstStationId = ud.stringForKey("lastFirstStationId"),
            departures = station.getFilteredDepartures() {
            DLog("\(departures.last?.getScheduledTimeAsNSDate()) <= \(lastDepartureTime)", toFile: true)

            let backthreehours = NSDate().dateByAddingTimeInterval(-3600 * 3)
            // if complication code didn't run for thre hours, try it
            if let lastComplicationUpdate = ud.objectForKey("lastComplicationUpdate") as? NSDate {
                if lastComplicationUpdate < backthreehours {
                    DLog("complication not updated for three hours, do it . return true", toFile: true)
                    return true
                }
            } else { // never updated  complications
                DLog("no lastComplicationUpdate data. return true", toFile: true)
                return true
            }
            let inthreehours = NSDate().dateByAddingTimeInterval(3600 * 3)
            if (lastFirstStationId == station.st_id) {
                // if we have more than 3 hours in store still (to avoid too frequent updates)
                if (lastDepartureTime > inthreehours) {
                    DLog("more than 3 hours in store \(lastDepartureTime). return false")
                    return false
                // else if we don't have a newer than the current last one
                } else if (departures.last?.getScheduledTimeAsNSDate() <= lastDepartureTime) {
                    DLog("no new data. return false.", toFile: true)
                    return false
                }
            }
        }
        DLog("return true", toFile: true)
        return true
    }

    public func needsDeparturesUpdate(station: TFCStation) -> Bool {
        if let lastDepartureTime = TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("lastDepartureTime") as? NSDate,
            lastFirstStationId = TFCDataStore.sharedInstance.getUserDefaults()?.stringForKey("lastFirstStationId"),
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
