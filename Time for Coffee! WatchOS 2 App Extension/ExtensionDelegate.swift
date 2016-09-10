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

    var wcBackgroundTasks: [AnyObject] = []

    func applicationDidFinishLaunching() {

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            TFCDataStore.sharedInstance.registerWatchConnectivity(self)
            /* Request for all Favorite Data every 24 hours (or if never done)
                I'm not sure, how reliable the WatchConnectivity is and if never
                gets a message lost, so let's sync every 24 hours. Shouldn't be
                that much data anyway
            
                Or if we never did get a allDataResponse, do it every time until we get one.
            */

            let lastRequest = self.lastRequestForAllData()
            let allDataResponseSent = TFCDataStore.sharedInstance.getUserDefaults()?.boolForKey("allDataResponseSent")
            if (allDataResponseSent != true || lastRequest == nil || lastRequest < -(24 * 60 * 60)) {
                var delayItBy = 0.0
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

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        dispatch_async(dispatch_get_main_queue(), {
            self.completeAllWCTasksIfReady()
        })
    }


    func applicationDidBecomeActive() {
        DLog("__", toFile: true)
        TFCWatchDataFetch.sharedInstance.fetchDepartureData()
    }

    func applicationWillResignActive() {
        TFCDataStore.sharedInstance.saveContext()
    }

    private func lastRequestForAllData() -> NSTimeInterval? {
        if let lastUpdate = TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("lastRequestForAllData") as? NSDate { 
            return lastUpdate.timeIntervalSinceNow
        }
        return nil
    }

    func handleUserActivity(userInfo: [NSObject : AnyObject]?) {
        DLog("handleUserActivity")
        if let userInfo = userInfo {
            var uI:[String:String]? = nil
            if (userInfo.keys.first == "CLKLaunchedTimelineEntryDateKey") {
                //TFCURLSession.sharedInstance.cancelURLSession()
                if let lastId = NSUserDefaults(suiteName: "group.ch.opendata.timeforcoffee")?.stringForKey("lastFirstStationId") {
                    uI = ["st_id": lastId]
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
                TFCWatchDataFetch.sharedInstance.fetchDepartureData(arTask)
            } else if let urlTask = task as? WKURLSessionRefreshBackgroundTask {
                TFCWatchDataFetch.sharedInstance.rejoinURLSession(urlTask)
            } else if let wcBackgroundTask = task as? WKWatchConnectivityRefreshBackgroundTask {
                    // store a reference to the task objects as we might have to wait to complete them
                    self.wcBackgroundTasks.append(wcBackgroundTask)
            } else if let snapshotTask = task as? WKSnapshotRefreshBackgroundTask {
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: watchdata.getNextUpdateTime(), userInfo: nil)
            } else {
                //DLog("received something else...", toFile: true)
                // make sure to complete all tasks, even ones you don't handle
                task.setTaskCompleted()
            }
        }
    }

    func completeAllWCTasksIfReady() {
        DLog("completeAllWCTasksIfReady")
        let session = WCSession.defaultSession()        // the session's properties only have valid values if the session is activated, so check that first
        if session.activationState == .Activated && !session.hasContentPending {
            wcBackgroundTasks.forEach {
                if let bgTask = $0 as? WKWatchConnectivityRefreshBackgroundTask {
                    DLog("\(bgTask) completed", toFile: true)
                    bgTask.setTaskCompleted()
                }
            }
            wcBackgroundTasks.removeAll()
        }
    }
}

