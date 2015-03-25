//
//  TFCDataStore.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 23.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation


public class TFCDataStore: NSObject {

    public class var sharedInstance: TFCDataStore {
        struct Static {
            static let instance: TFCDataStore = TFCDataStore()
        }
        return Static.instance
    }

    let userDefaults: NSUserDefaults? = NSUserDefaults(suiteName: "group.ch.liip.timeforcoffee")
    let keyvaluestore: NSUbiquitousKeyValueStore? = NSUbiquitousKeyValueStore.defaultStore()
    var notificationObserver: AnyObject?

    func setObject(anObject: AnyObject?, forKey: String) {
        userDefaults?.setObject(anObject , forKey: forKey)
        keyvaluestore?.setObject(anObject, forKey: forKey)
    }

    func objectForKey(forKey: String) -> AnyObject? {
        return userDefaults?.objectForKey(forKey)
    }

    func removeObjectForKey(forKey: String) {
        userDefaults?.removeObjectForKey(forKey)
        keyvaluestore?.removeObjectForKey(forKey)
    }

    public func synchronize() {
        userDefaults?.synchronize()
        keyvaluestore?.synchronize()
    }

    public func registerForNotifications() {
        objc_sync_enter(notificationObserver)
        if (notificationObserver != nil) {
            return
        }
        notificationObserver = NSNotificationCenter.defaultCenter().addObserverForName("NSUbiquitousKeyValueStoreDidChangeExternallyNotification", object: keyvaluestore, queue: nil, usingBlock: { (notification: NSNotification!) -> Void in
            let userInfo: NSDictionary? = notification.userInfo as NSDictionary?
            let reasonForChange: NSNumber? = userInfo?.objectForKey(NSUbiquitousKeyValueStoreChangeReasonKey) as NSNumber?
            if (reasonForChange == nil) {
                return
            }
            NSLog("got icloud sync")

            let reason = reasonForChange?.integerValue
            if ((reason == NSUbiquitousKeyValueStoreServerChange) ||
                (reason == NSUbiquitousKeyValueStoreInitialSyncChange)) {
                    var changedKeys: [String]? = userInfo?.objectForKey(NSUbiquitousKeyValueStoreChangedKeysKey) as [String]?
                    if (changedKeys != nil) {
                        for (key) in changedKeys! {
                            // legacy, can be removed later
                            if (key == "favoriteStations") {
                                self.keyvaluestore?.removeObjectForKey("favoriteStations")
                            } else {
                                self.userDefaults?.setObject(self.keyvaluestore?.objectForKey(key), forKey: key)
                                if (key == "favorites2") {
                                    TFCFavorites.sharedInstance.repopulateFavorites()
                                }
                            }
                        }
                    }
            }

        })
        objc_sync_exit(notificationObserver)

    }

    public func removeNotifications() {
        objc_sync_enter(notificationObserver)
        if (notificationObserver != nil) {
        NSNotificationCenter.defaultCenter().removeObserver(notificationObserver!)
            notificationObserver = nil
        }
        objc_sync_exit(notificationObserver)
    }

    public func getUserDefaults() -> NSUserDefaults? {
        return userDefaults
    }

}