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

    var tickStart:NSDate? = nil
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

    func applicationWillEnterForeground() {
        #if DEBUG
            self.tickStart = nil
        #endif
    }

    func applicationDidEnterBackground() {
        #if DEBUG
            self.tickStart = NSDate()
            self.tick()
        #endif
    }

    func applicationWillResignActive() {
        DLog("__", toFile: true)
        NSProcessInfo.processInfo().performExpiringActivityWithReason("applicationWillResignActive")
        { expired in
            if !expired {

                TFCDataStore.sharedInstance.saveContext()
                SendLogs2Phone()
            } else {
                DLog("applicationWillResignActive expired", toFile: true)
            }
        }

    }

    func tick() {
        if let tickStart = tickStart {
            let running = (NSDate().timeIntervalSinceReferenceDate - tickStart.timeIntervalSinceReferenceDate).roundToPlaces(2)
            DLog("tick running since \(running) sec", toFile: true)
            let delayTime = 1.0
            /*if (running > 27.5 && running < 32) {
                delayTime = 0.1
            }*/
            delay(delayTime, closure: {
                self.tick()
            })
        }
    }

    func tickDebugLog() {
        if #available(watchOSApplicationExtension 3.0, *) {
            DLog("Application State appstate: \(WKExtension.sharedExtension().applicationState.rawValue)")
        }
        if let tickStart = tickStart {
            let running = (NSDate().timeIntervalSinceReferenceDate - tickStart.timeIntervalSinceReferenceDate).roundToPlaces(1)

            DLog("in background since: \(running) sec. ticker.")
        } else {
            DLog("not in background. ticker.")
        }
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
            DLog("received \(task) Backgroundtask" , toFile: true)
            if let arTask = task as? WKApplicationRefreshBackgroundTask {
                TFCWatchDataFetch.sharedInstance.fetchDepartureData(task: arTask)
            } else if let urlTask = task as? WKURLSessionRefreshBackgroundTask {
                TFCWatchDataFetch.sharedInstance.rejoinURLSession(urlTask)
            } else if let wcBackgroundTask = task as? WKWatchConnectivityRefreshBackgroundTask {
                //just wait 15 seconds and assume it's finished FIXME. Could be improved, but it's hard to keep track and sometimes there's just nothing to do.
                delay(10.0, closure: {
                    dispatch_barrier_async(TFCWatchData.crunchQueue) {
                    DLog("finished WKWatchConnectivityRefreshBackgroundTask Backgroundtask part 1", toFile: true)
                    DLog("was: \(wcBackgroundTask) part 2", toFile: true)
                    dispatch_async(dispatch_get_main_queue(), {
                          wcBackgroundTask.setTaskCompleted()
                    })
                    }
                })
                TFCDataStore.sharedInstance.registerWatchConnectivity()
            } else if let snapshotTask = task as? WKSnapshotRefreshBackgroundTask {

                delaySnapshotComplete(snapshotTask,startTime: NSDate())
            } else {
                //DLog("received something else...", toFile: true)
                // make sure to complete all tasks, even ones you don't handle
                task.setTaskCompleted()
            }
        }
    }

    @available(watchOSApplicationExtension 3.0, *)
    private func delaySnapshotComplete(snapshotTask: WKSnapshotRefreshBackgroundTask, startTime:NSDate) {
        //just wait 2 seconds and assume it's finished
        // we use a queue here to let other tasks finish, before this one shoots
        let delayTime:Double = 2.0
        delay(delayTime, closure: {
            DLog("finished \(snapshotTask) Backgroundtask before barrier. ")
            dispatch_barrier_async(TFCWatchData.crunchQueue) {

/*                if (TFCWatchDataFetch.sharedInstance.downloading.count > 0) {

                    let startedSince = NSDate().timeIntervalSinceReferenceDate - startTime.timeIntervalSinceReferenceDate;
                    if (startedSince < 10) {
                        DLog("something \(TFCWatchDataFetch.sharedInstance.downloading.count) is still downloading, wait another 5 secs (waiting since \(startedSince))", toFile:true)
                        for (key, value) in TFCWatchDataFetch.sharedInstance.downloading {
                            DLog("\(key) is downloading with value: \(value)")
                        }
                        self.delaySnapshotComplete(snapshotTask, startTime: startTime)
                        return
                    } else {
                        DLog("something \(TFCWatchDataFetch.sharedInstance.downloading.count)  is still downloading, but we waited since \(startedSince) seconds, continue", toFile:true)
                        for (key, value) in TFCWatchDataFetch.sharedInstance.downloading {
                            DLog("\(key) is downloading with value: \(value)")
                        }

                    }
                }*/
                if (TFCWatchData.crunchQueueTasks > 0) {
                    DLog("there's a new task in the crunchQueue, finish that first: \(TFCWatchData.crunchQueueTasks).")
                    self.delaySnapshotComplete(snapshotTask, startTime: startTime)
                    return
                }

                let nextDate = self.watchdata.getNextUpdateTime(noBackOffIncr: true, minTime: 30 * 60)

                let ud = TFCDataStore.sharedInstance.getUserDefaults()
                let lastBackgroundRefreshDate = ud?.objectForKey("lastBackgroundRefreshDate") as? NSDate
                if (lastBackgroundRefreshDate == nil || lastBackgroundRefreshDate < NSDate()) {
                    DLog("lastBackgroundRefreshDate \(lastBackgroundRefreshDate) older than now. set new schedule ", toFile: true)
                    self.watchdata.scheduleNextUpdate(noBackOffIncr: true)
                }
                dispatch_async(dispatch_get_main_queue(), {
                    DLog("finished \(snapshotTask) Backgroundtask, next \(nextDate)", toFile: true)
                    snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: nextDate, userInfo: nil)
                })

            }
        })
    }

}

