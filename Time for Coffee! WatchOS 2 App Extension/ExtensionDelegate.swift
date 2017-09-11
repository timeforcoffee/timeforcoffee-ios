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
        WKExtension.shared().delegate = self
    }

    lazy private var watchdata: TFCWatchData = {
        return TFCWatchData()
    }()

    var tickStart:Date? = nil
    func applicationDidFinishLaunching() {
        DLog("__", toFile: true)
        self.askForFavoriteData()
    }


    func askForFavoriteData(_ noDelay:Bool = false) {
        DispatchQueue.global(qos: .utility).async {
            TFCDataStore.sharedInstance.registerWatchConnectivity()
            /* Request for all Favorite Data every 24 hours (or if never done)
             I'm not sure, how reliable the WatchConnectivity is and if never
             gets a message lost, so let's sync every 24 hours. Shouldn't be
             that much data anyway

             Or if we never did get a allDataResponse, do it every time until we get one.
             */

            let lastRequest = self.lastRequestForAllData()
            let allDataResponseSent = TFCDataStore.sharedInstance.getUserDefaults()?.bool(forKey: "allDataResponseSent")
            if (allDataResponseSent != true || lastRequest == nil || lastRequest! < -(24 * 60 * 60)) {
                var delayItBy = 6.0
                if (noDelay) {
                    delayItBy = 0.0
                }
                DLog("request giveMeAllTheData in \(delayItBy) seconds")
                delay(delayItBy, closure: {
                    TFCDataStore.sharedInstance.requestAllDataFromPhone()
                })
                TFCDataStore.sharedInstance.getUserDefaults()?.set(Date(), forKey: "lastRequestForAllData")
            }

        }
    }

    func applicationDidBecomeActive() {
        DLog("__", toFile: true)
        DispatchQueue.global(qos: .utility).async {
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
            self.tickStart = Date()
            //  self.tick()
        #endif
    }

    func applicationWillResignActive() {
        DLog("__", toFile: true)
        ProcessInfo.processInfo.performExpiringActivity(withReason: "applicationWillResignActive")
        { expired in
            if !expired {

                TFCDataStore.sharedInstance.saveContext()
                self.askForFavoriteData(true)
                SendLogs2Phone()
                let maxSize = UInt(2 * 1024 * 1024)
                let diskCache = TFCCache.objects.stations.diskCache
                if (diskCache.byteCount > maxSize) {
                    DLog("trim cache from \(diskCache.byteCount)")
                    diskCache.trimToSize(byDate: UInt(2 * 1024 * 1024), block: { (c) in
                        DLog("cache trimmed to \(c.byteCount)")
                    })
                }
            } else {
                DLog("applicationWillResignActive expired", toFile: true)
            }
        }

    }

    fileprivate func lastRequestForAllData() -> TimeInterval? {
        if let lastUpdate = TFCDataStore.sharedInstance.getUserDefaults()?.object(forKey: "lastRequestForAllData") as? Date { 
            return lastUpdate.timeIntervalSinceNow
        }
        return nil
    }

    func handleUserActivity(_ userInfo: [AnyHashable: Any]?) {
        DLog("handleUserActivity \(String(describing: userInfo ?? nil))", toFile: true)

        if let userInfo = userInfo {
            var uI:[String:String]? = nil
            if (userInfo.keys.first == AnyHashable("CLKLaunchedTimelineEntryDateKey")) {
                if let lastId =  ComplicationData.initDisplayed()?.getStation().st_id {
                    uI = ["st_id": lastId]
                    DLog("\(String(describing: uI))", toFile: true)
                }
            } else {
                uI = userInfo as? [String:String]
                DLog("handleUserActivity StationViewController")
            }
            NotificationCenter.default.post(name: Notification.Name(rawValue: "TFCWatchkitSelectStation"), object: nil, userInfo: uI)
        }
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task : WKRefreshBackgroundTask in backgroundTasks {
            DLog("received \(task) Backgroundtask" , toFile: true)
            if let arTask = task as? WKApplicationRefreshBackgroundTask {
                TFCWatchDataFetch.sharedInstance.fetchDepartureData(task: arTask)
            } else if let urlTask = task as? WKURLSessionRefreshBackgroundTask {
                TFCWatchDataFetch.sharedInstance.rejoinURLSession(urlTask)
            } else if let wcBackgroundTask = task as? WKWatchConnectivityRefreshBackgroundTask {
                //just wait 15 seconds and assume it's finished FIXME. Could be improved, but it's hard to keep track and sometimes there's just nothing to do.
                delay(10.0, closure: {
                    TFCWatchData.crunchQueue.async(flags: .barrier, execute: {
                    DLog("finished WKWatchConnectivityRefreshBackgroundTask Backgroundtask part 1", toFile: true)
                    DLog("was: \(wcBackgroundTask) part 2", toFile: true)
                    DispatchQueue.main.async(execute: {
                          wcBackgroundTask.setTaskCompleted()
                    })
                    }) 
                })
                TFCDataStore.sharedInstance.registerWatchConnectivity()
            } else if let snapshotTask = task as? WKSnapshotRefreshBackgroundTask {

                delaySnapshotComplete(snapshotTask,startTime: Date())
            } else {
                //DLog("received something else...", toFile: true)
                // make sure to complete all tasks, even ones you don't handle
                task.setTaskCompleted()
            }
        }
    }

    fileprivate func delaySnapshotComplete(_ snapshotTask: WKSnapshotRefreshBackgroundTask, startTime:Date, count:Int = 0) {
        //just wait 2 seconds and assume it's finished
        // we use a queue here to let other tasks finish, before this one shoots
        let delayTime:Double = 2.0
        delay(delayTime, closure: {
            DLog("finished \(snapshotTask) Backgroundtask before barrier. ")
            TFCWatchData.crunchQueue.async(flags: .barrier, execute: {

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
                    let newCount = count + 1;
                    if (newCount < 10) {
                        self.delaySnapshotComplete(snapshotTask, startTime: startTime, count: newCount)
                        return
                    }
                }

                let nextDate = self.watchdata.getNextUpdateTime(noBackOffIncr: true, minTime: 30 * 60)

                let ud = TFCDataStore.sharedInstance.getUserDefaults()
                let lastBackgroundRefreshDate = ud?.object(forKey: "lastBackgroundRefreshDate") as? Date
                if (lastBackgroundRefreshDate == nil || lastBackgroundRefreshDate! < Date()) {
                    DLog("lastBackgroundRefreshDate \(String(describing: lastBackgroundRefreshDate)) older than now. set new schedule ", toFile: true)
                    self.watchdata.scheduleNextUpdate(noBackOffIncr: true)
                }
                DispatchQueue.main.async(execute: {
                    DLog("finished \(snapshotTask) Backgroundtask, next \(nextDate)", toFile: true)
                    #if DEBUG
                        DispatchQueue.global(qos: .background).async {
                            SendLogs2Phone()
                        }
                    #endif
                    snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: nextDate, userInfo: nil)
                })

            }) 
        })
    }

}

