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

public class TFCDataStoreBase: NSObject, WCSessionDelegate, NSFileManagerDelegate, TFCDeparturesUpdatedProtocol {

    override init() {
        super.init()
        DLog("init DataStoreBase", toFile: true)
    }

    let lockQueue = dispatch_queue_create("group.ch.opendata.timeforcoffee.notificationLock", DISPATCH_QUEUE_SERIAL)

    private let userDefaults: NSUserDefaults? = NSUserDefaults(suiteName: "group.ch.opendata.timeforcoffee")
    private let localUserDefaults: NSUserDefaults? = NSUserDefaults(suiteName: "ch.opendata.timeforcoffee.local")
    var keyvaluestore: NSUbiquitousKeyValueStore? { return nil}
    private var notificationObserver: AnyObject?

    public var localNotificationCallback:((String?) -> Void)? = nil

    @available(iOSApplicationExtension 9.0, *)
    public lazy var session: WCSession? = {
        if (WCSession.isSupported()) {
            return WCSession.defaultSession()
        }
        return nil
    }()


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
        if let ud = NSUserDefaults(suiteName: "group.ch.opendata.timeforcoffee"),
            lastComplicationStationId = ud.stringForKey("lastComplicationStationId")
        {
            if (forKey == "favorite\(lastComplicationStationId)") {
                DLog("updateComplicationData for \(forKey) since favorites changed")
                if let st = TFCStation.initWithCacheId(lastComplicationStationId) {
                    st.repopulateFavoriteLines()
                    st.needsCacheSave = true
                    TFCStationBase.saveToPincache(st)
                }
                //delay the complication update by 5 seconds to give other tasks some room to breath
                delay(5.0, closure: { self.updateComplicationData() })                
            }
        }
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

    public func registerWatchConnectivity() {
        if #available(iOS 9, *) {
            if (WCSession.isSupported()) {
                var activate = true
                if #available(iOSApplicationExtension 9.3, *) {
                    if (session?.activationState == .Activated) {
                        activate = false
                    }
                }
                session?.delegate = self
                if activate {
                    session?.activateSession()
                }
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
                                        if (key == "favorites3") {
                                            TFCFavorites.sharedInstance.repopulateFavorites()
                                        } else if (key.hasPrefix("favorite")) {
                                            let st_id = key.replace("favorite", template: "")
                                            if let inMemoryObj = TFCStationBase.getFromMemoryCaches(st_id) {
                                                inMemoryObj.repopulateFavoriteLines()
                                            }
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
        DLog("__giveMeTheData__ sent", toFile: true)
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
        parseReceiveInfo(userInfo)
    }

    @available(iOSApplicationExtension 9.0, *)
    public func session(session: WCSession, didReceiveFile file: WCSessionFile) {
        if let iCloudDocumentsURL = NSFileManager.defaultManager().URLForUbiquityContainerIdentifier("iCloud.ch.opendata.timeforcoffee")?.URLByAppendingPathComponent("Documents") {
            let fileManager = NSFileManager.defaultManager()
            do {
                if let url = file.fileURL as NSURL?, filename = url.lastPathComponent, moveTo = iCloudDocumentsURL.URLByAppendingPathComponent(filename) {
                    DLog("received file \(filename)", toFile: true)
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
        if (sessionActive) {
            if (self.session?.reachable == true && (trySendMessage || self.session?.outstandingUserInfoTransfers.count > 10)) {
                DLog("outstanding UserInfoTransfers \(self.session?.outstandingUserInfoTransfers.count )")
                self.session?.sendMessage(message, replyHandler: nil, errorHandler: {(error: NSError) in
                    DLog("sendMessage failed due to error \(error): Send via transferUserInfo")
                    self.session?.transferUserInfo(message)
                })
            } else {
                self.session?.transferUserInfo(message)
            }
        }
    }

    @available(iOSApplicationExtension 9.0, *)
    func parseReceiveInfo(message: [String: AnyObject]) {
        for (myKey,myValue) in message {
            if (myKey != "__logThis__") {
                DLog("parseReceiveInfo: \(myKey)", toFile: true)
            }
            if (myKey == "__updateComplicationData__") {
                if let value = myValue as? [String: AnyObject], coordinates = value["coordinates"] as? [String: AnyObject], lng = coordinates["longitude"] as? CLLocationDegrees, lat = coordinates["latitude"] as? CLLocationDegrees {
                    TFCLocationManagerBase.setCurrentLocation(CLLocation(latitude: lat, longitude: lng ), time: coordinates["time"] as? NSDate)
                    DLog("coord was sent with __updateComplicationData__ \(lat), \(lng)", toFile: true)
                    if let station = value["station"] as? NSData, let sentStationDict = NSKeyedUnarchiver.unarchiveObjectWithData(station) as? [String:String] {
                        if let sentStation = TFCStation.initWithCache(sentStationDict), let departures = value["departures"] as? NSData {
                            NSKeyedUnarchiver.setClass(TFCDeparture.classForKeyedUnarchiver(), forClassName: "timeforcoffeeKit.TFCDeparture")
                            let sentDepartures = NSKeyedUnarchiver.unarchiveObjectWithData(departures) as? [TFCDeparture]
                            DLog("station sent with __updateComplicationData__: \(sentStation.name) id: \(sentStation.st_id) with \(sentDepartures?.count) departures")
                            sentStation.addDepartures(sentDepartures)
                            sentStation.lastDepartureUpdate = NSDate()
                            #if DEBUG
                                self.sendData(["__complicationUpdateReceived__": "Received Complication update on watch for \(sentStation.name)"])
                            #endif
                            #if os(watchOS)
                                if (sentStation.st_id == TFCWatchDataFetch.sharedInstance.getLastViewedStation()?.st_id) {
                                    NSNotificationCenter.defaultCenter().postNotificationName("TFCWatchkitUpdateCurrentStation", object: nil, userInfo: nil)
                                }
                                if let defaults = TFCDataStore.sharedInstance.getUserDefaults() {
                                    defaults.setValue(sentStation.st_id, forKey: "lastFirstStationId")
                                    if let departures = sentStation.getFilteredDepartures() {
                                        defaults.setObject(departures.first?.getScheduledTimeAsNSDate(), forKey: "firstDepartureTime")
                                    } else {
                                        defaults.setObject(nil, forKey: "firstDepartureTime")
                                    }
                                }
                                updateComplicationData()
                            #endif
                        }
                    }

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
            } else if (myKey == "__sendLogs__") {
                DLog("Got __sendLogs__");
                SendLogs2Phone()
            } else if (myKey == "___remove___") {
                if let key = myValue as? String {
                    self.removeObjectForKey(key, withWCTransfer: false)
                }
            } else if (myKey == "__allDataResponseSent__") {
                DLog("Got __allDataResponseSent__");
                self.userDefaults?.setBool(true, forKey: "allDataResponseSent")
            } else if (myKey == "__complicationUpdateReceived__") {
                #if DEBUG
                    self.localNotificationCallback?(myValue as? String)
                    DLog("\(myValue)", toFile: true)
                #endif
            } else {
                self.setObject(myValue, forKey: myKey, withWCTransfer: false)
                if (myKey == "favoritesVersion") {
                    //do nothing in this case
                } else if (myKey == "favorites3") {
                    TFCFavorites.sharedInstance.repopulateFavorites()
                } else if (myKey.hasPrefix("favorite")) {
                    let st_id = myKey.replace("favorite", template: "")
                    if let inMemoryObj = TFCStationBase.getFromMemoryCaches(st_id) {
                        inMemoryObj.repopulateFavoriteLines()
                    }
                }
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
        //self.registerWatchConnectivity()
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
                    if (myKey != "favorites2" && (myKey.hasPrefix("favorite") || myKey.hasPrefix("filtered"))) {
                        allDataDict[myKey] = myValue
                    }
                }
                // this is so that we can check, if an allData request was sent to the watch
                //  until this is done, the watch will keep asking for it
                //  This is to avoid haveing no favourites on the watch to start with
                allDataDict["TFCID"] = self.getTFCID()
                sendData(allDataDict)
                sendData(["__allDataResponseSent__": true])

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
        DLog("new managedObjectContext", toFile: true)
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

    public func departuresStillCached(context: Any?, forStation: TFCStation?) {
        departuresUpdated(nil, context: context, forStation: forStation)
    }

    public func departuresUpdated(error: NSError?, context: Any?, forStation: TFCStation?) {
        var coord:CLLocationCoordinate2D? = nil
        if let coordDict = context as? [String:CLLocationCoordinate2D?] {
            if let coord2 = coordDict["coordinates"] {
                coord = coord2
            }
        }
        sendComplicationUpdate2(forStation, coord: coord)
    }

    public func sendComplicationUpdate(station: TFCStation?, coord: CLLocationCoordinate2D? = nil) {
        #if os(iOS)
            if #available(iOS 9, *) {
                if (WCSession.isSupported()) {
                    if (self.session?.complicationEnabled == true) {
                        if let firstStation = station, ud = TFCDataStore.sharedInstance.getUserDefaults() {
                            if (ud.stringForKey("lastFirstStationId") != firstStation.st_id) {
                                DLog("update Departures for \(firstStation.name)")
                                firstStation.updateDepartures(self, context: ["coordinates": coord])
                            }
                        }
                    }
                }
            }
        #endif
    }

    private func sendComplicationUpdate2(station: TFCStation?, coord: CLLocationCoordinate2D? = nil) {
        #if os(iOS)
            if #available(iOS 9, *) {
                if let firstStation = station, ud = TFCDataStore.sharedInstance.getUserDefaults() {
                    if (ud.stringForKey("lastFirstStationId") != firstStation.st_id) {
                        var useComplicationTransfer = true
                        var remaining:Int? = nil
                        if #available(iOSApplicationExtension 10.0, *) {
                            remaining = self.session?.remainingComplicationUserInfoTransfers
                            if (!(remaining > 0)) {
                                useComplicationTransfer = false
                            }
                            DLog("remainingComplicationUserInfoTransfers: \(remaining)", toFile: true)
                        }
                        var data:[String:AnyObject] = [:]

                        if let coord = coord {
                            DLog("send __updateComplicationData__ \(coord) (triggered for \(station?.name)) id: \(station?.st_id)", toFile: true)
                            data["coordinates"] = [ "longitude": coord.longitude, "latitude": coord.latitude, "time": NSDate()]
                        } else if let coord = firstStation.coord?.coordinate {
                            DLog("send __updateComplicationData__ with \(coord) for \(station?.name) id: \(station?.st_id)", toFile: true)
                            data["coordinates"] = [ "longitude": coord.longitude, "latitude": coord.latitude]
                        }
                        #if DEBUG
                            if let name = station?.name {
                                self.localNotificationCallback?("Complication sent for \(name). Remaining: \(remaining)")
                            }
                        #endif
                        data["station"] =  NSKeyedArchiver.archivedDataWithRootObject(firstStation.getAsDict())
                        if let filteredDepartures = firstStation.getFilteredDepartures() {
                            data["departures"] =  NSKeyedArchiver.archivedDataWithRootObject(Array(filteredDepartures.prefix(10)))
                        }

                        let dict:[String:[String:AnyObject]] = ["__updateComplicationData__": data]

                        if (useComplicationTransfer) {
                            self.session?.transferCurrentComplicationUserInfo(dict)
                        } else {
                            sendData(dict)
                        }
                        
                        ud.setValue(firstStation.st_id, forKey: "lastFirstStationId")
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
                        userDefaults?.setObject(NSDate(), forKey: "lastComplicationEnabled")
                        return true
                    }
                    if let lastComplicationEnabled = userDefaults?.objectForKey("lastComplicationEnabled") as? NSDate {
                        // if we had complications enabled in the last 24 hours, assume it's enabled
                        // so to not loose the fences, when we switch faces temporarly
                        if lastComplicationEnabled.dateByAddingTimeInterval(24 * 3600) > NSDate() {
                            return true
                        }
                    }
                }
            }
        #endif
        return false
    }

    public func getTFCID() -> String? {
        return self.objectForKey("TFCID") as! String?
    }
}
