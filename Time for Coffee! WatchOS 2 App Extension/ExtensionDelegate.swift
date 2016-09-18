//
//  ExtensionDelegate.swift
//  Time for Coffee! WatchOS 2 App Extension
//
//  Created by Christian Stocker on 11.09.15.
//  Copyright © 2015 Christian Stocker. All rights reserved.
//

import WatchKit
import Foundation
import WatchConnectivity

class ExtensionDelegate: NSObject, WKExtensionDelegate {

    override init() {
        super.init()
        WKExtension.sharedExtension().delegate = self
    }

    lazy var watchdata: TFCWatchData = {
        return TFCWatchData()
    }()

    func applicationDidFinishLaunching() {
        DLog("__", toFile: true)

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            TFCDataStore.sharedInstance.registerWatchConnectivity()
            /* Request for all Favorite Data every 24 hours (or if never done)
                I'm not sure, how reliable the WatchConnectivity is and if never
                gets a message lost, so let's sync every 24 hours. Shouldn't be
                that much data anyway
            
                Or if we never did get a allDataResponse, do it every time until we get one.
            */

            let lastRequest = self.lastRequestForAllData()
            let allDataResponseSent = TFCDataStore.sharedInstance.getUserDefaults()?.boolForKey("allDataResponseSent")
            if (allDataResponseSent != true || lastRequest == nil || lastRequest < -(24 * 60 * 60)) {
                var delayItBy = 1.0
                /* if it's a daily update, delay it by 10 seconds, to have other requests (like location updates from the phone) give some time to be handled before */
                if (lastRequest != nil) {
                    delayItBy = 10.0
                }
                delay(delayItBy, closure: {
                    TFCDataStore.sharedInstance.requestAllDataFromPhone()
                })
                TFCDataStore.sharedInstance.getUserDefaults()?.setObject(NSDate(), forKey: "lastRequestForAllData")
            }

        }
    }

    func applicationDidBecomeActive() {
        DLog("__", toFile: true)
        TFCWatchDataFetch.sharedInstance.fetchDepartureData()
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            TFCDataStore.sharedInstance.registerWatchConnectivity()
        }

    }

    func applicationWillResignActive() {
        DLog("__", toFile: true)
        TFCDataStore.sharedInstance.saveContext()
        SendLogs2Phone()
    }

    private func lastRequestForAllData() -> NSTimeInterval? {
        if let lastUpdate = TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("lastRequestForAllData") as? NSDate { 
            return lastUpdate.timeIntervalSinceNow
        }
        return nil
    }

    func handleUserActivity(userInfo: [NSObject : AnyObject]?) {
        DLog("handleUserActivity \(userInfo)", toFile: true)

        if let userInfo = userInfo {
            var uI:[String:String]? = nil
            if (userInfo.keys.first == "CLKLaunchedTimelineEntryDateKey") {
                //TFCURLSession.sharedInstance.cancelURLSession()
                if let lastId = NSUserDefaults(suiteName: "group.ch.opendata.timeforcoffee")?.stringForKey("lastFirstStationId") {
                    uI = ["st_id": lastId]
                    DLog("\(uI)", toFile: true)
                    TFCWatchDataFetch.sharedInstance.fetchDepartureDataForStation(TFCStation.initWithCacheId(lastId))
                }
            } else {
                uI = userInfo as? [String:String]
                DLog("handleUserActivity StationViewController")
            }
            NSNotificationCenter.defaultCenter().postNotificationName("TFCWatchkitSelectStation", object: nil, userInfo: uI)
        }
    }


    @available(watchOSApplicationExtension 3.0, *)
    func handleBackgroundTasks(backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task : WKRefreshBackgroundTask in backgroundTasks {
            DLog("received background task: \(task)" , toFile: true)
            if let arTask = task as? WKApplicationRefreshBackgroundTask {
                TFCWatchDataFetch.sharedInstance.fetchDepartureData(task: arTask)
            } else if let urlTask = task as? WKURLSessionRefreshBackgroundTask {
                TFCWatchDataFetch.sharedInstance.rejoinURLSession(urlTask)
            } else if let wcBackgroundTask = task as? WKWatchConnectivityRefreshBackgroundTask {
                //just wait 15 seconds and assume it's finished FIXME. Could be improved, but it's hard to keep track and sometimes there's just nothing to do.
                delay(15.0, closure: {
                    wcBackgroundTask.setTaskCompleted()
                })
                TFCDataStore.sharedInstance.registerWatchConnectivity()
            } else if let snapshotTask = task as? WKSnapshotRefreshBackgroundTask {
                //just wait 5 seconds and assume it's finished
                delay(5.0, closure: {
                    let nextDate = self.watchdata.getNextUpdateTime(noBackOffIncr: true)
                    DLog("finished \(snapshotTask) Backgroundtask, next \(nextDate)", toFile: true)

                    let ud = TFCDataStore.sharedInstance.getUserDefaults()
                    let lastBackgroundRefreshDate = ud?.objectForKey("lastBackgroundRefreshDate") as? NSDate
                    if (lastBackgroundRefreshDate == nil || lastBackgroundRefreshDate < NSDate()) {
                        DLog("lastBackgroundRefreshDate \(lastBackgroundRefreshDate) older than now. set new schedule ", toFile: true)
                        self.watchdata.scheduleNextUpdate()
                    }
                    snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: nextDate, userInfo: nil)
                })
            } else {
                //DLog("received something else...", toFile: true)
                // make sure to complete all tasks, even ones you don't handle
                task.setTaskCompleted()
            }
        }
    }
}

