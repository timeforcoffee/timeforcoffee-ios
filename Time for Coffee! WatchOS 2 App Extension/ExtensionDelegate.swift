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
import timeforcoffeeKitWatch
class ExtensionDelegate: NSObject, WKExtensionDelegate, URLSessionDownloadDelegate {
    
    override init() {
        super.init()
        WKExtension.shared().delegate = self
    }

    deinit {
        self.stationsUpdate = nil
    }
    
    lazy private var watchdata: TFCWatchData = {
        return TFCWatchData()
    }()

    var tickStart:Date? = nil
    var stationsUpdate:TFCStationsUpdate? = nil
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

    @objc func applicationDidBecomeActive() {
        DLog("__", toFile: true)
        //DispatchQueue.global(qos: .utility).async {
            TFCDataStore.sharedInstance.registerWatchConnectivity()
        //}
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
                TFCCache.clearDiskCacheIfBigger(maxSize: maxSize)
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
    
    func handle(_ userActivity: NSUserActivity) {
        DLog("handleUserActivity \(String(describing: userActivity ))", toFile: true)
        if #available(watchOSApplicationExtension 5.0, *) {
            if (userActivity.interaction?.intent is NextDeparturesIntent) {
                if let intent = userActivity.interaction?.intent as? NextDeparturesIntent {
                    if let st_id = intent.stationObj?.identifier {
                        let name:String
                        if let stationName = intent.stationObj?.displayString, stationName != "unknown" {
                            name = stationName
                        } else {
                            name = ""
                        }
                        
                        if let station = TFCStation.initWithCache(name, id: st_id, coord: nil) {
                            DLog("st name: \(station.getName(false))")
                            let uI = ["st_id": station.getId(), "name": station.getName(false)]
                            NotificationCenter.default.post(name: Notification.Name(rawValue: "TFCWatchkitSelectStation"), object: nil, userInfo: uI)
                        }
                    } else {
                        func stationsUpdateCompletion(stations:TFCStations?, error: String?, context: Any?) {
                            if let stations = stations {
                                if let station = stations.getStation(0) {
                                    DispatchQueue.main.async {
                                        DLog("nearest name: \(station.getName(false))")
                                        let uI = ["st_id": station.getId(), "name": station.getName(false)]
                                        NotificationCenter.default.post(name: Notification.Name(rawValue: "TFCWatchkitSelectStation"), object: nil, userInfo: uI)
                                    }
                                }
                            }
                        }
                        DLog("search nearest")
                        self.stationsUpdate = TFCStationsUpdate(completion: stationsUpdateCompletion)
                        self.stationsUpdate?.update(maxStations: 1)
                    }
                }
            }
        }

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
            let wrapper = TFCTaskWrapper(task)
            DLog("received \(wrapper.getHash()) Backgroundtask \(task)" , toFile: true)
            if let _ = task as? WKApplicationRefreshBackgroundTask {
                DLog("received WKApplicationRefreshBackgroundTask")
                DLog("fetchDepartureData")
                TFCWatchDataFetch.sharedInstance.fetchDepartureData(wrapper: wrapper)
                continue
            } else if let urlTask = task as? WKURLSessionRefreshBackgroundTask {
                DLog("received WKURLSessionRefreshBackgroundTask for \(urlTask.sessionIdentifier) with task hash \(wrapper.getHash())")
                TFCWatchDataFetch.sharedInstance.rejoinURLSession(wrapper)
                continue
            } else if let wcBackgroundTask = task as? WKWatchConnectivityRefreshBackgroundTask {
                DLog("received WKWatchConnectivityRefreshBackgroundTask")
                //just wait 15 seconds and assume it's finished FIXME. Could be improved, but it's hard to keep track and sometimes there's just nothing to do.
                delay(10.0, closure: {
                    TFCWatchData.crunchQueue.async(flags: .barrier, execute: {
                        DLog("finished WKWatchConnectivityRefreshBackgroundTask Backgroundtask part 1", toFile: true)
                        DLog("was: \(wcBackgroundTask) part 2", toFile: true)
                        wrapper.setTaskCompletedAndClear()
                    })
                })
                TFCDataStore.sharedInstance.registerWatchConnectivity()
                continue
            } else if let snapshotTask = task as? WKSnapshotRefreshBackgroundTask {

                DLog("received WKSnapshotRefreshBackgroundTask")
                #if DEBUG
                    if #available(watchOSApplicationExtension 4.0, *) {
                        if (snapshotTask.reasonForSnapshot == .appBackgrounded) {
                            DLog("received WKSnapshotRefreshBackgroundTask.appBackgrounded")
                        } else if (snapshotTask.reasonForSnapshot == .appScheduled) {
                            DLog("received WKSnapshotRefreshBackgroundTask.appScheduled")
                        } else if (snapshotTask.reasonForSnapshot == .complicationUpdate) {
                            DLog("received WKSnapshotRefreshBackgroundTask.complicationUpdate")
                        } else if (snapshotTask.reasonForSnapshot == .prelaunch) {
                            DLog("received WKSnapshotRefreshBackgroundTask.prelaunch")
                        } else if (snapshotTask.reasonForSnapshot == .returnToDefaultState) {
                            DLog("received WKSnapshotRefreshBackgroundTask.returnToDefaultState")
                        }
                    }
                #endif
               // if (snapshotTask.reasonForSnapshot == .complicationUpdate)
                delaySnapshotComplete(wrapper, startTime: Date())
                continue
            } else {
                if #available(watchOSApplicationExtension 5.0, *) {
                    DLog("received WKRelevantShortcutRefreshBackgroundTask")

                    if let _ = task as? WKRelevantShortcutRefreshBackgroundTask {
                        if let station = TFCWatchDataFetch.sharedInstance.getLastViewedStation(ttl: 120 * 60) {
                            DLog("Found station \(station.getName(false)) for WKRelevantShortcutRefreshBackgroundTask. Updating activity")
                            station.updateRelevantShortCuts()
                        }
                        delaySnapshotComplete(wrapper, startTime: Date())
                        continue
                    }
                }
            }
            DLog("received something else...\(wrapper.getHash()) \(wrapper.getTask())", toFile: true)
            // make sure to complete all tasks, even ones you don't handle
            DispatchQueue.main.async(execute: {
                wrapper.setTaskCompletedAndClear()
            })
        }
    }
    

    fileprivate func completeWrapperTaskWithData(wrapper: TFCTaskWrapper, nextDate: Date) {
        wrapper.setTaskCompletedAndClear(callback: { () -> Bool in
            if let task = wrapper.getTask() as? WKSnapshotRefreshBackgroundTask {
                
                let expirationDate:Date
                if (TFCDataStore.sharedInstance.complicationEnabled()) {
                    expirationDate = nextDate
                } else {
                    expirationDate = Date.distantFuture
                }
                WKExtension.shared()
                
                task.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: expirationDate, userInfo: nil)
                return true
            }
            return false
        })
    }
    
    fileprivate func delaySnapshotComplete(_ wrapper: TFCTaskWrapper, startTime:Date, count:Int = 0) {
        //just wait 2 seconds and assume it's finished
        // we use a queue here to let other tasks finish, before this one shoots
        let delayTime:Double = 0.5
        delay(delayTime, closure: {
            DLog("finished \(wrapper.getHash()) Backgroundtask before barrier. ")
            TFCWatchData.crunchQueue.async(flags: .barrier, execute: {
                if (TFCWatchData.crunchQueueTasks > 0) {
                    DLog("there's a new task in the crunchQueue, finish that first: \(TFCWatchData.crunchQueueTasks).")
                    let newCount = count + 1;
                    if (newCount < 10) {
                        self.delaySnapshotComplete(wrapper, startTime: startTime, count: newCount)
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
                    DLog("finished \(wrapper.getHash()) Backgroundtask, next \(nextDate)", toFile: true)

                    #if DEBUG
                        if #available(watchOSApplicationExtension 4.0, *) {
                            if let snapshotTask = wrapper.getTask() as? WKSnapshotRefreshBackgroundTask {
                                if (snapshotTask.reasonForSnapshot == .appBackgrounded) {
                                    DLog("finished WKSnapshotRefreshBackgroundTask.appBackgrounded")
                                } else if (snapshotTask.reasonForSnapshot == .appScheduled) {
                                    DLog("finished WKSnapshotRefreshBackgroundTask.appScheduled")
                                } else if (snapshotTask.reasonForSnapshot == .complicationUpdate) {
                                    DLog("finished WKSnapshotRefreshBackgroundTask.complicationUpdate")
                                } else if (snapshotTask.reasonForSnapshot == .prelaunch) {
                                    DLog("finished WKSnapshotRefreshBackgroundTask.prelaunch")
                                } else if (snapshotTask.reasonForSnapshot == .returnToDefaultState) {
                                    DLog("finished WKSnapshotRefreshBackgroundTask.returnToDefaultState")
                                }
                            }
                        }
                        SendLogs2Phone()

                        DispatchQueue.global(qos: .background).async {
                            delay(0.5, closure: {
                                self.completeWrapperTaskWithData(wrapper: wrapper, nextDate: nextDate)
                            })
                    }
                    #else
                    self.completeWrapperTaskWithData(wrapper: wrapper, nextDate: nextDate)
                    #endif
                })

            }) 
        })
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        DLog("___")
        TFCWatchDataFetch.sharedInstance.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        DLog("___")
        TFCWatchDataFetch.sharedInstance.urlSession(session, didBecomeInvalidWithError: error)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DLog("___")
        TFCWatchDataFetch.sharedInstance.urlSession(session, task: task, didCompleteWithError: error)
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DLog("___")
        TFCWatchDataFetch.sharedInstance.urlSessionDidFinishEvents(forBackgroundURLSession: session)
    }       
}


