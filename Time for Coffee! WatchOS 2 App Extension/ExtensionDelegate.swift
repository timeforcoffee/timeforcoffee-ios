//
//  ExtensionDelegate.swift
//  Time for Coffee! WatchOS 2 App Extension
//
//  Created by Christian Stocker on 11.09.15.
//  Copyright © 2015 Christian Stocker. All rights reserved.
//

import WatchKit
import timeforcoffeeWatchKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {

    func applicationDidFinishLaunching() {

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            TFCDataStore.sharedInstance.registerWatchConnectivity()
            /* Request for all Favorite Data every 24 hours (or if never done)
                I'm not sure, how reliable the WatchConnectivity is and if never
                gets a message lost, so let's sync every 24 hours. Shouldn't be
                that much data anyway
            */
            let lastRequest = self.lastRequestForAllData()
            if (lastRequest == nil || lastRequest < -(24 * 60 * 60)) {
                TFCDataStore.sharedInstance.requestAllDataFromPhone()
                TFCDataStore.sharedInstance.getUserDefaults()?.setObject(NSDate(), forKey: "lastRequestForAllData")
            }
        }

        // iCLoud not supported (yet?) by watchOS :(
    /*    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            TFCDataStore.sharedInstance.registerForNotifications()
            TFCDataStore.sharedInstance.synchronize()
        }*/
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    func applicationWillResignActive() {

        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }

    private func lastRequestForAllData() -> NSTimeInterval? {
        let lastUpdate: NSDate? = TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("lastRequestForAllData") as! NSDate?
        return lastUpdate?.timeIntervalSinceNow
    }
}

