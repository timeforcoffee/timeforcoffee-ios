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
    static let FrequencyOfTimelineUpdate = TimeInterval(30*60) // 30 minutes
    static let TimelineUpdateMinutesBeforeEnd = TimeInterval(-15*60) // 15 minutes
}

public final class TFCWatchData: NSObject, TFCLocationManagerDelegate,  TFCStationsUpdatedProtocol {

    fileprivate var networkErrorMsg: String?

    public var noCrunchQueue = false
    fileprivate var replyNearby: replyClosure?
    fileprivate lazy var stations: TFCStations? =  {return TFCStations(delegate: self)}()
    fileprivate lazy var locManager: TFCLocationManager? = self.lazyInitLocationManager()
    static  var crunchQueue:DispatchQueue = {
        return DispatchQueue(label: "ch.opendata.timeforcoffee.crunch", attributes: DispatchQueue.Attributes.concurrent)
    }()

    fileprivate struct replyContext {
        var reply: replyStations?
        var errorReply: ((String) -> Void)?
    }

    public override init () {
        super.init()
    }
    
    fileprivate func lazyInitLocationManager() -> TFCLocationManager? {
        return TFCLocationManager(delegate: self)
    }

    public func locationFixed(_ loc: CLLocation?) {
        if let coord = loc?.coordinate {
            DLog("location fixed \(String(describing: loc))", toFile: true)
            replyNearby!(["lat" : coord.latitude, "long": coord.longitude]);
        } 
    }

    public func locationDenied(_ manager: CLLocationManager, err:Error) {
        DLog("location DENIED \(err)", toFile: true)
        replyNearby!(["error": err]);
    }

    public func locationStillTrying(_ manager: CLLocationManager, err: Error) {
        DLog("location still trying \(err)")
    }

    public func getLocation(_ reply: replyClosure?) {
        // this is a not so nice way to get the reply Closure to later when we actually have
        // the data from the API... (in locationFixed)
        DLog("get new location in watch", toFile: true)
        self.replyNearby = reply
        locManager?.refreshLocation()
    }

    public func updateComplication(_ stations: TFCStations) {
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

    public func waitForNewLocation(within seconds:Int, callback: @escaping () -> Void) {

        let queue = DispatchQueue.global(qos: .default)
        queue.async {
            self.waitForNewLocation(within: seconds, counter: 0, queue: queue, callback: callback)
        }
    }


    fileprivate func waitForNewLocation(within seconds:Int, counter:Int = 0, queue:DispatchQueue? = nil, callback: @escaping () -> Void) {
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

                    if let lastComplicationUpdate = ud?.object(forKey: "lastComplicationUpdate") as? Date,
                        let lastComplicationStationId = ud?.string(forKey: "lastComplicationStationId"),
                        let lastFirstStationId = ud?.string(forKey: "lastFirstStationId")
                    {
                        // if last Complication update is less than 5 minutes ago
                        if (lastComplicationUpdate.addingTimeInterval(300) > Date() &&
                        lastComplicationStationId == lastFirstStationId) {
                            DLog("complication was updated less than 5 minutes ago (\(lastComplicationUpdate)) with the same id \(lastFirstStationId), dont reload in this case")
                            return
                        }
                    }
                    DLog("Reload Complications", toFile: true)
                    server.reloadTimeline(for: complication)
                }
            }
        }
    }
    static var crunchQueueTasks = 0

    public func startCrunchQueue(_ closure: @escaping (() -> Void)) {
        let queue:DispatchQueue
        if self.noCrunchQueue {
            closure()
        } else {
            #if DEBUG
                let stacktrace = Thread.callStackSymbols
                if (stacktrace.count > 1) {
                    let first = stacktrace[1]

                    DLog("startCrunchQueue called from \(first)")
                }
            #endif

            queue = TFCWatchData.crunchQueue
            TFCWatchData.crunchQueueTasks += 1
            queue.async(execute: {
                DLog("crunchQueue started")
                closure()
                TFCWatchData.crunchQueueTasks -= 1
            })

        }
    }

    public func getStations(_ reply: replyStations?, errorReply: ((String) -> Void)?, stopWithFavorites: Bool?, favoritesOnly: Bool? = false) {

        #if DEBUG
            let stacktrace = Thread.callStackSymbols
        #else
            let stacktrace:[String] = []
        #endif
        func handleReply(_ replyInfo: [AnyHashable: Any]!) {
            startCrunchQueue {
                DLog("searchForStationsInDB handleReply getStations \(replyInfo) \(String(describing: reply))", toFile: true)
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
                    let _ = self.stations?.initWithNearbyFavorites(loc)
                    if (stopWithFavorites == true) {
                        if let stationCount = self.stations?.count() {
                            if (stationCount > 0 && reply != nil ) {
                                DLog("searchForStationsInDB stopWithFavorites", toFile: true)
                                reply!(self.stations)
                                return
                            }
                        }
                    }
                    var replyC:replyContext = replyContext()
                    replyC.reply = reply
                    replyC.errorReply = errorReply
                    DLog("searchForStationsInDB before", toFile: true)
                    self.stations?.searchForStationsInDB(loc.coordinate, context: replyC)
                } else {
                    if let err = replyInfo["error"] as? NSError {
                        if (err.code == CLError.Code.locationUnknown.rawValue) {
                            self.networkErrorMsg = "Airplane mode?"
                        } else {
                            self.networkErrorMsg = "Location not available"
                        }
                        if let errorReply = errorReply, let networkErrorMsg = self.networkErrorMsg {
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

    public func stationsUpdated(_ error: String?, favoritesOnly: Bool, context: Any?) {
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

    public func getBackOffTime(noBackOffIncr:Bool? = false) -> Date {
        var backoffCount = TFCDataStore.sharedInstance.getUserDefaults()?.double(forKey: "backoffCount")
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
        TFCDataStore.sharedInstance.getUserDefaults()?.set(backoffCount!, forKey: "backoffCount")
        DLog("Backoff time: \(backoffTime)")
        return Date().addingTimeInterval(Double(backoffTime) * 60)
    }

    func clearBackOffTime() {
        TFCDataStore.sharedInstance.getUserDefaults()?.set(nil, forKey: "backoffCount")
    }

    public func getNextUpdateTime(noBackOffIncr:Bool? = false, minTime:Int? = 0) -> Date {
        var nextUpdateDate:Date?        
        var maxNextUpdateDate = Date().addingTimeInterval(Constants.FrequencyOfTimelineUpdate)
        // if the next first departure Time is further away than usual, wait until that comes and update 15 minutes before
        if let firstDepartureTime = TFCDataStore.sharedInstance.getUserDefaults()?.object(forKey: "firstDepartureTime") as? Date {
            if firstDepartureTime.addingTimeInterval(-15 * 60) > maxNextUpdateDate {
                maxNextUpdateDate = firstDepartureTime.addingTimeInterval(-15 * 60)
            }
        }
        if let nextUpdate = TFCDataStore.sharedInstance.getUserDefaults()?.object(forKey: "lastDepartureTime") as? Date {
            let lastEntryDate = nextUpdate.addingTimeInterval(Constants.TimelineUpdateMinutesBeforeEnd)
            //if lastEntryDate is before now, update again in 5 minutes
            if (lastEntryDate.timeIntervalSinceNow < Date().timeIntervalSinceNow) {
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
        if (nextUpdateDate == nil || nextUpdateDate! < Date()) {
            DLog("WARNING: \(String(describing: nextUpdateDate)) < \(Date())")
            nextUpdateDate = getBackOffTime(noBackOffIncr: true)
        }
        if let minTime = minTime {
            let minDate = Date().addingTimeInterval(Double(minTime))
            nextUpdateDate = max(minDate, nextUpdateDate!)
        }
        return nextUpdateDate!
    }

    public func scheduleNextUpdate(noBackOffIncr:Bool? = false) {
            let nextUpdate:Date
            if let c = CLKComplicationServer.sharedInstance().activeComplications?.count, c > 0 {
                nextUpdate = self.getNextUpdateTime(noBackOffIncr: noBackOffIncr)
            } else {
                nextUpdate = Date().addingTimeInterval(30 * 60)
            }
        if #available(watchOSApplicationExtension 3.0, *) {
            let ud = TFCDataStore.sharedInstance.getUserDefaults()

            ud?.set(nextUpdate, forKey: "lastBackgroundRefreshDate")
            WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: nextUpdate, userInfo: nil) { (error) in
                DLog("updated next schedule at \(nextUpdate.formattedWithDateFormatter(DLogDateFormatter)) error: \(String(describing: error))", toFile: true)
            }
        }        
    }
    public func needsTimelineDataUpdate(_ station: TFCStation) -> Bool {
        let ud = TFCDataStore.sharedInstance.getUserDefaults()

        DLog("lastDepartureTime:NSDate = \(String(describing: ud?.object(forKey: "lastDepartureTime") as? Date))", toFile: true)
        DLog("lastFirstStationId = \(String(describing: ud?.string(forKey: "lastFirstStationId")))", toFile: true)
        DLog("departures = \(String(describing: station.getFilteredDepartures()?.count)))", toFile: true)

        if let ud = ud, let lastDepartureTime:Date = ud.object(forKey: "lastDepartureTime") as? Date,
            let lastFirstStationId = ud.string(forKey: "lastFirstStationId"),
            let departures = station.getFilteredDepartures() {
            DLog("\(String(describing: departures.last?.getScheduledTimeAsNSDate())) <= \(lastDepartureTime)", toFile: true)

            let backthreehours = Date().addingTimeInterval(-3600 * 3)
            // if complication code didn't run for thre hours, try it
            if let lastComplicationUpdate = ud.object(forKey: "lastComplicationUpdate") as? Date {
                if lastComplicationUpdate < backthreehours {
                    DLog("complication not updated for three hours, do it . return true", toFile: true)
                    return true
                }
            } else { // never updated  complications
                DLog("no lastComplicationUpdate data. return true", toFile: true)
                return true
            }
            let inthreehours = Date().addingTimeInterval(3600 * 3)
            if (lastFirstStationId == station.st_id) {
                // if we have more than 3 hours in store still (to avoid too frequent updates)
                if (lastDepartureTime > inthreehours) {
                    DLog("more than 3 hours in store \(lastDepartureTime). return false")
                    return false
                // else if we don't have a newer than the current last one
                } else if (departures.last?.getScheduledTimeAsNSDate() != nil &&
                    departures.last!.getScheduledTimeAsNSDate()! <= lastDepartureTime) {
                    DLog("no new data. return false.", toFile: true)
                    return false
                }
            }
        }
        DLog("return true", toFile: true)
        return true
    }

    public func needsDeparturesUpdate(_ station: TFCStation) -> Bool {
        if let lastDepartureTime = TFCDataStore.sharedInstance.getUserDefaults()?.object(forKey: "lastDepartureTime") as? Date,
            let lastFirstStationId = TFCDataStore.sharedInstance.getUserDefaults()?.string(forKey: "lastFirstStationId"),
            let departures = station.getFilteredDepartures() {
            // if lastDepartureTime is more than 4 hours away and we're in the same place
            // and we still have at least 5 departures, just use the departures from the cache
            if ((lastDepartureTime.addingTimeInterval(4 * -3600).timeIntervalSinceNow > 0)
                && lastFirstStationId == station.st_id
                && departures.count > 5
                ) {
                return false
            }
            DLog("timeIntervalSinceNow \(lastDepartureTime.addingTimeInterval(4 * -3600).timeIntervalSinceNow)")
            DLog("lastDepartureTime: \(lastDepartureTime)")
            DLog("lastFirstStationId: \(lastFirstStationId)")
            DLog("station.getFilteredDepartures()?.count: \(String(describing: station.getFilteredDepartures()?.count))")

        }
        return true
    }
}

open class TFCPageContext: NSObject {

    public override init() {
        super.init()
    }

    open var station:TFCStation?
    open var pageNumber:Int?
}
