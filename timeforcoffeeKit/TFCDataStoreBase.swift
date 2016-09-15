//
//  TFCDataStore.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 23.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import WatchConnectivity
import CoreData
import MapKit

public class TFCDataStoreBase: NSObject, WCSessionDelegate, NSFileManagerDelegate {

    public class var sharedInstance: TFCDataStore {
        struct Static {
            static let instance: TFCDataStore = TFCDataStore()
        }
        return Static.instance
    }

    let lockQueue = dispatch_queue_create("group.ch.opendata.timeforcoffee.notificationLock", DISPATCH_QUEUE_SERIAL)

    private let userDefaults: NSUserDefaults? = NSUserDefaults(suiteName: "group.ch.opendata.timeforcoffee")
    private let localUserDefaults: NSUserDefaults? = NSUserDefaults(suiteName: "ch.opendata.timeforcoffee.local")
    var keyvaluestore: NSUbiquitousKeyValueStore? { return nil}
    private var notificationObserver: AnyObject?
    @available(iOSApplicationExtension 9.0, *)
    public var session: WCSession? {
        if (WCSession.isSupported()) {
            return WCSession.defaultSession()
        }
        return nil
    }


    func setObject(anObject: AnyObject?, forKey: String, withWCTransfer: Bool = true) {
        userDefaults?.setObject(anObject , forKey: forKey)
        keyvaluestore?.setObject(anObject, forKey: forKey)
        if #available(iOS 9, *) {
            if (withWCTransfer != false) {
                let applicationDict = [forKey: anObject!]
                sendData(applicationDict)
            }
        }
        // make sure complications are updated as soon as possible with the new values
        userDefaults?.setObject(nil, forKey: "lastComplicationUpdate")
    }

    func objectForKey(forKey: String) -> AnyObject? {
        return userDefaults?.objectForKey(forKey)
    }

    func removeObjectForKey(forKey: String, withWCTransfer: Bool = true) {
        userDefaults?.removeObjectForKey(forKey)
        keyvaluestore?.removeObjectForKey(forKey)
        if #available(iOS 9, *) {
            if (withWCTransfer != false) {
                let applicationDict = ["___remove___": forKey]
                sendData(applicationDict)
            }
        }
        // make sure complications are updated as soon as possible with the new values
        userDefaults?.setObject(nil, forKey: "lastComplicationUpdate")
    }

    public func synchronize() {
        userDefaults?.synchronize()
        keyvaluestore?.synchronize()
    }

    public func registerWatchConnectivity(observeClass: NSObject? = nil) {
        if #available(iOS 9, *) {
            if (WCSession.isSupported()) {
                session?.delegate = self
                if let observeClass = observeClass {
                    session?.addObserver(observeClass, forKeyPath: "activationState", options: [], context: nil)
                    session?.addObserver(observeClass, forKeyPath: "hasContentPending", options: [], context: nil)
                }

                session?.activateSession()
            }
        }
    }

    public func registerForNotifications() {
        if (keyvaluestore != nil) {
            dispatch_sync(lockQueue) {
                if (self.notificationObserver != nil) {
                    return
                }
                self.notificationObserver = NSNotificationCenter.defaultCenter().addObserverForName("NSUbiquitousKeyValueStoreDidChangeExternallyNotification", object: self.keyvaluestore, queue: nil, usingBlock: { (notification: NSNotification!) -> Void in
                    let userInfo: NSDictionary? = notification.userInfo as NSDictionary?
                    let reasonForChange: NSNumber? = userInfo?.objectForKey(NSUbiquitousKeyValueStoreChangeReasonKey) as! NSNumber?
                    if (reasonForChange == nil) {
                        return
                    }
                    DLog("got icloud sync")

                    let reason = reasonForChange?.integerValue
                    if ((reason == NSUbiquitousKeyValueStoreServerChange) ||
                        (reason == NSUbiquitousKeyValueStoreInitialSyncChange)) {
                            let changedKeys: [String]? = userInfo?.objectForKey(NSUbiquitousKeyValueStoreChangedKeysKey) as! [String]?
                            if (changedKeys != nil) {
                                for (key) in changedKeys! {
                                    // legacy, can be removed later
                                    if (key == "favoriteStations") {
                                        self.keyvaluestore?.removeObjectForKey("favoriteStations")
                                    } else {
                                        if let value = self.keyvaluestore?.objectForKey(key) {
                                            self.userDefaults?.setObject(value, forKey: key)
                                        } else {
                                            self.userDefaults?.removeObjectForKey(key)
                                        }
                                        if (key == "favorites2") {
                                            TFCFavorites.sharedInstance.repopulateFavorites()
                                        }
                                        if #available(iOS 9, *) {
                                            if let value = self.keyvaluestore?.objectForKey(key) {
                                                self.sendData([key: value])
                                            } else {
                                                self.sendData(["___remove___": key])
                                            }
                                        }
                                    }
                                }
                            }
                    }
                    
                })
            }
        }
    }

    public func removeNotifications() {
        if (keyvaluestore != nil) {
            dispatch_sync(lockQueue) {
                if (self.notificationObserver != nil) {
                    NSNotificationCenter.defaultCenter().removeObserver(self.notificationObserver!)
                    self.notificationObserver = nil
                }
            }
        }
    }

    public func getUserDefaults() -> NSUserDefaults? {
        return userDefaults
    }

    @available(iOSApplicationExtension 9.0, *)
    public func requestAllDataFromPhone() {
        sendData(["__giveMeTheData__": NSDate()], trySendMessage: true)
    }

    @available(iOSApplicationExtension 9.0, *)
    public func session(session: WCSession, didReceiveMessage message: [String : AnyObject]) {
        for (myKey,_) in message {
            if (myKey != "__logThis__") {
                DLog("didReceiveMessage: \(myKey)", toFile: true)
            }
        }
        parseReceiveInfo(message)
    }

    @available(iOSApplicationExtension 9.0, *)
    public func session(session: WCSession, didReceiveUserInfo userInfo: [String : AnyObject]) {
        for (myKey,_) in userInfo {
            if (myKey != "__logThis__") {
                DLog("didReceiveUserInfo: \(myKey)", toFile: true)
            }
        }
        parseReceiveInfo(userInfo)
    }

    @available(iOSApplicationExtension 9.0, *)
    public func session(session: WCSession, didReceiveFile file: WCSessionFile) {
        if let iCloudDocumentsURL = NSFileManager.defaultManager().URLForUbiquityContainerIdentifier("iCloud.ch.opendata.timeforcoffee")?.URLByAppendingPathComponent("Documents") {
            let fileManager = NSFileManager.defaultManager()
            DLog("received file \(file.fileURL.absoluteString!)", toFile: true)
            do {
                let url = file.fileURL
                if let filename = url.lastPathComponent, moveTo = iCloudDocumentsURL.URLByAppendingPathComponent(filename) {
                    if fileManager.fileExistsAtPath(moveTo.path!) {
                        try fileManager.removeItemAtURL(moveTo)
                    }
                    try fileManager.moveItemAtURL(url, toURL: moveTo)
                }
            }
            catch let error as NSError {
                DLog("Ooops! Something went wrong: \(error)")
            }
        }

    }


    @available(iOSApplicationExtension 9.0, *)
    public func sendData(message: [String: AnyObject], trySendMessage: Bool = false, retryCounter:Int = 0) {
        // if we have too many outstandingUserInfoTransfers, something is wrong, try to send as sendMessage as alternative

        var sessionActive = true

        if #available(iOSApplicationExtension 9.3, *) {
            sessionActive = (self.session?.activationState == .Activated)
        }

        if (sessionActive || retryCounter > 15) {
            if (self.session?.reachable == true && (trySendMessage || self.session?.outstandingUserInfoTransfers.count > 10)) {
                DLog("outstanding UserInfoTransfers \(self.session?.outstandingUserInfoTransfers.count )")
                self.session?.sendMessage(message, replyHandler: nil, errorHandler: {(error: NSError) in
                    DLog("sendMessage failed due to error \(error): Send via transferUserInfo")
                    self.session?.transferUserInfo(message)
                })
            } else {
                self.session?.transferUserInfo(message)
            }
        } else {
            delay(3.0, closure: {
                let newCounter = retryCounter + 1
                if (retryCounter > 7) {
                    self.session?.activateSession()
                }
                DLog("Session not active, retry #\(newCounter)", toFile: true)
                self.sendData( message, trySendMessage: trySendMessage, retryCounter: newCounter)
            })
        }
    }

    @available(iOSApplicationExtension 9.0, *)
    func parseReceiveInfo(message: [String: AnyObject]) {
        for (myKey,myValue) in message {
            if (myKey != "__logThis__") {
                DLog("parseReceiveInfo: \(myKey)", toFile: true)
            }
            if (myKey == "__updateComplicationData__") {
                if let value = myValue as? [String: CLLocationDegrees], lng = value["longitude"], lat = value["latitude"] {
                    TFCLocationManagerBase.setCurrentLocation(CLLocation(latitude: lat, longitude: lng))
                    DLog("coord was sent with __updateComplicationData__ \(lat), \(lng)", toFile: true)
                } else {
                    DLog("no coord was sent with __updateComplicationData__ ", toFile: true)
                }
                self.fetchDepartureData()
            } else if (myKey == "__logThis__") {
                if let value = myValue as? String {
                    DLog("Watch: " + value, toFile: true)
                }
            } else if (myKey == "__giveMeTheData__") {
                DLog("Got __giveMeTheData__");
                sendAllData()
            } else if (myKey == "___remove___") {
                if let key = myValue as? String {
                    self.removeObjectForKey(key, withWCTransfer: false)
                }
            } else if (myKey == "__allDataResponseSent__") {
                DLog("Got __allDataResponseSent__");
                self.userDefaults?.setBool(true, forKey: "allDataResponseSent")
            } else {
                self.setObject(myValue, forKey: myKey, withWCTransfer: false)
            }
        }
    }

    @available(iOSApplicationExtension 9.3, *)
    @available(watchOSApplicationExtension 2.2, *)
    public func session(session: WCSession, activationDidCompleteWithState activationState: WCSessionActivationState, error: NSError?) {
        DLog("activationDidCompleteWithState. state \(activationState) error \(error)")
    }

    @available(iOSApplicationExtension 9.0, *)
    public func sessionDidBecomeInactive(session: WCSession) {
    }

    @available(iOSApplicationExtension 9.0, *)
    public func sessionDidDeactivate(session: WCSession) {
        DLog("sessionDidDeactivate")
        self.registerWatchConnectivity()
    }

    @available(iOSApplicationExtension 9.0, *)
    public func sessionReachabilityDidChange(session: WCSession) {
        DLog("sessionReachabilityDidChange to \(session.reachable) ")
    }

    @available(iOSApplicationExtension 9.0, *)
    private func sendAllData() {
        if let allData = userDefaults?.dictionaryRepresentation() {
            // only send allData if the last request was longer than 1 minute ago
            // This prevents multiple data sends, when requests for it pile up in the queue
            let lastRequest = self.lastRequestForAllData()
            if (lastRequest == nil || lastRequest < -60) {
                TFCDataStore.sharedInstance.getUserDefaults()?.setObject(NSDate(), forKey: "lastRequestForAllDataToBeSent")
                var allDataDict:[String:AnyObject] = [:]
                for (myKey, myValue) in allData {
                    // only send key starting with favorite
                    if (myKey.hasPrefix("favorite") || myKey.hasPrefix("filtered")) {
                        allDataDict[myKey] = myValue
                    }
                }
                // this is so that we can check, if an allData request was sent to the watch
                //  until this is done, the watch will keep asking for it
                //  This is to avoid haveing no favourites on the watch to start with
                allDataDict["__allDataResponseSent__"] = true
                sendData(allDataDict)
            }
        }
    }

    private func lastRequestForAllData() -> NSTimeInterval? {
        let lastUpdate: NSDate? = TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("lastRequestForAllDataToBeSent") as! NSDate?
        return lastUpdate?.timeIntervalSinceNow
    }

    lazy var applicationDocumentsDirectory: NSURL = {
        let urls = NSFileManager.defaultManager().containerURLForSecurityApplicationGroupIdentifier("group.ch.opendata.timeforcoffee")
        return urls!
        }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle(forClass: TFCDataStore.self).URLForResource("DataModels", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
        }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("SingleViewCoreData.sqlite")
        let whichBundle:NSBundle?
        if (NSBundle.mainBundle().bundleIdentifier == "ch.opendata.timeforcoffee.watchkitapp.watchkitextension") {
            whichBundle = NSBundle.mainBundle();
        } else {
            whichBundle = NSBundle(identifier: "ch.opendata.timeforcoffee.timeforcoffeeKit" )
        }
        if let bundle = whichBundle {

            let filePath = bundle.pathForResource("TFC", ofType: "plist")!
            var forceInstall = false
            let neededDBVersion = NSDictionary(contentsOfFile:filePath)?.valueForKey("dbVersion") as? Int
            if let neededDBVersion = neededDBVersion {
                var installedDBVersion = self.localUserDefaults?.integerForKey("installedDBVersion")
                if (installedDBVersion == nil || neededDBVersion != installedDBVersion) {
                    forceInstall = true
                }
            }
            let filemanager = NSFileManager.defaultManager();
            if (forceInstall || !filemanager.fileExistsAtPath(url!.path!)) {

                let sourceSqliteURLs = [bundle.URLForResource("SingleViewCoreData", withExtension: "sqlite")!, bundle.URLForResource("SingleViewCoreData", withExtension: "sqlite-wal")!, bundle.URLForResource("SingleViewCoreData", withExtension: "sqlite-shm")!]
                let destSqliteURLs = [self.applicationDocumentsDirectory.URLByAppendingPathComponent("SingleViewCoreData.sqlite"),
                    self.applicationDocumentsDirectory.URLByAppendingPathComponent("SingleViewCoreData.sqlite-wal"),
                    self.applicationDocumentsDirectory.URLByAppendingPathComponent("SingleViewCoreData.sqlite-shm")]

                var error:NSError? = nil
                filemanager.delegate = self
                for index in 0 ..< sourceSqliteURLs.count {
                    try! filemanager.copyItemAtURL(sourceSqliteURLs[index], toURL: destSqliteURLs[index]!)
                    let _ = try? destSqliteURLs[index]!.setResourceValue(true, forKey: NSURLIsExcludedFromBackupKey)

                }
                if let neededDBVersion = neededDBVersion {
                    self.localUserDefaults?.setInteger(neededDBVersion, forKey: "installedDBVersion")
                }

            }
        }
        var error: NSError? = nil
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true ]
            )
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason

            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            DLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)", toFile: true)
            abort()
        }
        
        return coordinator
    }()

    lazy public var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        managedObjectContext.undoManager = nil
        return managedObjectContext
        }()

    // MARK: - Core Data Saving support

    public func fileManager(fileManager: NSFileManager, shouldProceedAfterError error: NSError, copyingItemAtPath srcPath: String, toPath dstPath: String) -> Bool {
        if error.code == NSFileWriteFileExistsError {
            do
            {
                try fileManager.removeItemAtPath(dstPath)
                try fileManager.copyItemAtPath(srcPath, toPath: dstPath)
            } catch {
                DLog("\((error as NSError).localizedDescription) in \(srcPath)")
            }

            return true
        } else {
            return false
        }
    }

    func updateComplicationData() {
    }

    func updateWatchNow() {
    }

    public func sendComplicationUpdate(station: TFCStation?, coord: CLLocationCoordinate2D? = nil) {
        #if os(iOS)
            if #available(iOS 9, *) {
                if (WCSession.isSupported()) {
                    if (self.session?.complicationEnabled == true) {
                        if let firstStation = station, ud = TFCDataStore.sharedInstance.getUserDefaults() {
                            if (ud.stringForKey("lastFirstStationId") != firstStation.st_id) {
                                var useComplicationTransfer = true
                                if #available(iOSApplicationExtension 10.0, *) {
                                    if (!(self.session?.remainingComplicationUserInfoTransfers > 0)) {
                                        useComplicationTransfer = false
                                    }
                                    DLog("remainingComplicationUserInfoTransfers: \(self.session?.remainingComplicationUserInfoTransfers)", toFile: true)
                                }
                                var dict:[String:AnyObject] = ["__updateComplicationData__": "doit"]
                                if let coord = coord {
                                    dict  = ["__updateComplicationData__": [ "longitude": coord.longitude, "latitude": coord.latitude]]
                                } else if let coord = station?.coord?.coordinate {
                                    DLog("send __updateComplicationData__ with \(coord) for \(station?.name)", toFile: true)
                                    dict  = ["__updateComplicationData__": [ "longitude": coord.longitude, "latitude": coord.latitude]]
                                }
                                if (useComplicationTransfer) {
                                    self.session?.transferCurrentComplicationUserInfo(dict)
                                } else {
                                    sendData(dict)
                                }

                                ud.setValue(firstStation.st_id, forKey: "lastFirstStationId")
                            }
                        }
                    }
                }
            }
        #endif
    }

    public func saveContext () {
        if TFCDataStore.sharedInstance.managedObjectContext.hasChanges {
            do {
                try TFCDataStore.sharedInstance.managedObjectContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                DLog("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    func fetchDepartureData() {
    }

    public func complicationEnabled() -> Bool {
        #if os(iOS)
            if #available(iOS 9, *) {
                if (WCSession.isSupported()) {
                    if (self.session?.complicationEnabled == true) {
                        return true
                    }
                }
            }
        #endif
        return false
    }

}
