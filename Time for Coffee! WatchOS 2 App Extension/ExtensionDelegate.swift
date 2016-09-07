//
//  ExtensionDelegate.swift
//  Time for Coffee! WatchOS 2 App Extension
//
//  Created by Christian Stocker on 11.09.15.
//  Copyright © 2015 Christian Stocker. All rights reserved.
//

import WatchKit
import Foundation

class ExtensionDelegate: NSObject, WKExtensionDelegate, NSURLSessionDownloadDelegate {

    override init() {
        super.init()
        WKExtension.sharedExtension().delegate = self
    }


    func applicationDidFinishLaunching() {

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

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
         NSNotificationCenter.defaultCenter().postNotificationName("TFCWatchkitDidBecomeActive", object: nil, userInfo: nil)
    }
    func applicationWillResignActive() {
    //    TFCURLSession.sharedInstance.cancelURLSession()

        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
        NSNotificationCenter.defaultCenter().postNotificationName("TFCWatchkitDidResignActive", object: nil, userInfo: nil)
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
            if task is WKApplicationRefreshBackgroundTask {
                func handleReply(stations: TFCStations?) {
                    DLog("handleReply", toFile: true)
                    if let station = stations?.first {

                        let sampleDownloadURL = NSURL(string: station.getDeparturesURL())!
                        DLog("Download \(sampleDownloadURL)", toFile: true)
                        let backgroundConfigObject = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("\(sampleDownloadURL) \(NSUUID().UUIDString)")
                        backgroundConfigObject.sessionSendsLaunchEvents = true
                        let backgroundSession = NSURLSession(configuration: backgroundConfigObject, delegate: self, delegateQueue: nil)

                        let downloadTask = backgroundSession.downloadTaskWithURL(sampleDownloadURL)
                        downloadTask.resume()
                    } else {
                        DLog("No station set", toFile: true)
                        // try again in 5 minutes
                        WKExtension.sharedExtension().scheduleBackgroundRefreshWithPreferredDate(NSDate(timeIntervalSinceNow: 5 * 60) , userInfo: nil) { (error) in
                            if error == nil {
                                //successful
                            }
                        }
                    }
                    task.setTaskCompleted()
                }
                func errorReply(error: String) {
                    DLog("error \(error)")
                    // try again in 5 minutes
                    WKExtension.sharedExtension().scheduleBackgroundRefreshWithPreferredDate(NSDate(timeIntervalSinceNow: 5 * 60) , userInfo: nil) { (error) in
                        if error == nil {
                            //successful
                        }
                    }
                    task.setTaskCompleted()
                }
                TFCDataStore.sharedInstance.watchdata.getStations(handleReply, errorReply: errorReply, stopWithFavorites: true)


                //TFCDataStore.sharedInstance.watchdata.updateComplicationData()
            } else if let urlTask = task as? WKURLSessionRefreshBackgroundTask {
                let backgroundConfigObject = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(urlTask.sessionIdentifier)
                let backgroundSession = NSURLSession(configuration: backgroundConfigObject, delegate: self, delegateQueue: nil)
                DLog("Rejoining session \(urlTask.sessionIdentifier) \(backgroundSession)", toFile: true)
            } else {

                //DLog("received something else...", toFile: true)
                // make sure to complete all tasks, even ones you don't handle
                task.setTaskCompleted()
            }
        }
    }

    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        DLog("downloaded \(downloadTask.taskIdentifier) to \(location)", toFile: true)
        
        TFCDataStore.sharedInstance.watchdata.updateComplicationData()
    }

    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        DLog("didCompleteWithError \(error)")
        if (error != nil) {
            TFCDataStore.sharedInstance.watchdata.scheduleNextUpdate()
        }
        session.finishTasksAndInvalidate()
    }
}

