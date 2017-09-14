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

open class TFCDataStoreBase: NSObject, WCSessionDelegate, FileManagerDelegate, TFCDeparturesUpdatedProtocol {

    override init() {
        super.init()
        DLog("init DataStoreBase", toFile: true)
    }

    let lockQueue = DispatchQueue(label: "group.ch.opendata.timeforcoffee.notificationLock", attributes: [])

    fileprivate let userDefaults: UserDefaults? = UserDefaults(suiteName: "group.ch.opendata.timeforcoffee")
    fileprivate let localUserDefaults: UserDefaults? = UserDefaults(suiteName: "ch.opendata.timeforcoffee.local")
    var keyvaluestore: AnyObject? { return nil}
    fileprivate var notificationObserver: AnyObject?

    open var localNotificationCallback:((String?) -> Void)? = nil

    @available(iOSApplicationExtension 9.0, *)
    open lazy var session: WCSession? = {
        if (WCSession.isSupported()) {
            return WCSession.default
        }
        return nil
    }()


    func setObject(_ anObject: Any?, forKey: String, withWCTransfer: Bool = true) {
        userDefaults?.set(anObject , forKey: forKey)
        keyvaluestore?.set(anObject, forKey: forKey)
        if #available(iOS 9, *) {
            if (withWCTransfer != false) {
                let applicationDict = [forKey: anObject!]
                sendData(applicationDict)
            }
        }
        // make sure complications are updated as soon as possible with the new values
        #if os(watchOS)
            let cmpldata = ComplicationData.initDisplayed()
            cmpldata?.clearLastUpdate()
            if let lastComplicationStationId = cmpldata?.getStation().st_id
            {
                if (forKey == "favorite\(lastComplicationStationId)") {
                    DLog("updateComplicationData for \(forKey) since favorites changed", toFile: true)
                    if let st = TFCStation.initWithCacheId(lastComplicationStationId) {
                        st.repopulateFavoriteLines()
                        st.needsCacheSave = true
                        TFCStationBase.saveToPincache(st)
                    }
                    //delay the complication update by 5 seconds to give other tasks some room to breath
                    delay(5.0, closure: { self.updateComplicationData() })
                }
            }
        #endif
    }

    func objectForKey(_ forKey: String) -> AnyObject? {
        return userDefaults?.object(forKey: forKey) as AnyObject
    }

    func removeObjectForKey(_ forKey: String, withWCTransfer: Bool = true) {
        userDefaults?.removeObject(forKey: forKey)
        keyvaluestore?.removeObject(forKey: forKey)
        if #available(iOS 9, *) {
            if (withWCTransfer != false) {
                let applicationDict = ["___remove___": forKey]
                sendData(applicationDict as [String : Any])
            }
        }
        #if os(watchOS)
            // make sure complications are updated as soon as possible with the new values
            let cmpldata = ComplicationData.initDisplayed()
            cmpldata?.clearLastUpdate()
        #endif
    }

    open func synchronize() {
        userDefaults?.synchronize()
        #if os(iOS)
            (keyvaluestore as? NSUbiquitousKeyValueStore)?.synchronize()
        #endif
    }

    open func registerWatchConnectivity() {
        if #available(iOS 9, *) {
            if (WCSession.isSupported()) {
                var activate = true
                if #available(iOSApplicationExtension 9.3, *) {
                    if (session?.activationState == .activated) {
                        activate = false
                    }
                }
                session?.delegate = self
                if activate {
                    session?.activate()
                }
            }
        }
    }

    open func registerForNotifications() {
        if (keyvaluestore != nil) {
            lockQueue.sync {
                if (self.notificationObserver != nil) {
                    return
                }
                self.notificationObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "NSUbiquitousKeyValueStoreDidChangeExternallyNotification"), object: self.keyvaluestore, queue: nil, using: { (notification: Notification!) -> Void in
                    let userInfo: NSDictionary? = notification.userInfo as NSDictionary?
                    let reasonForChange: NSNumber? = userInfo?.object(forKey: NSUbiquitousKeyValueStoreChangeReasonKey) as! NSNumber?
                    if (reasonForChange == nil) {
                        return
                    }
                    DLog("got icloud sync")

                    let reason = reasonForChange?.intValue
                    if ((reason == NSUbiquitousKeyValueStoreServerChange) ||
                        (reason == NSUbiquitousKeyValueStoreInitialSyncChange)) {
                            let changedKeys: [String]? = userInfo?.object(forKey: NSUbiquitousKeyValueStoreChangedKeysKey) as! [String]?
                            if (changedKeys != nil) {
                                for (key) in changedKeys! {
                                    // legacy, can be removed later
                                    if (key == "favoriteStations") {
                                        self.keyvaluestore?.removeObject(forKey: "favoriteStations")
                                    } else {
                                        if let value = self.keyvaluestore?.object(forKey: key) {
                                            self.userDefaults?.set(value, forKey: key)
                                        } else {
                                            self.userDefaults?.removeObject(forKey: key)
                                        }
                                        if (key == "favorites3") {
                                            TFCFavorites.sharedInstance.repopulateFavorites()
                                        } else if (key.hasPrefix("favorite") && key != "favorites2") {
                                            let st_id = key.replace("favorite", template: "")
                                            if let inMemoryObj = TFCStationBase.getFromMemoryCaches(st_id) {
                                                inMemoryObj.repopulateFavoriteLines()
                                            }
                                        }
                                        if #available(iOS 9, *) {
                                            if let value = self.keyvaluestore?.object(forKey: key) {
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

    open func removeNotifications() {
        if (keyvaluestore != nil) {
            lockQueue.sync {
                if (self.notificationObserver != nil) {
                    NotificationCenter.default.removeObserver(self.notificationObserver!)
                    self.notificationObserver = nil
                }
            }
        }
    }

    open func getUserDefaults() -> UserDefaults? {
        return userDefaults
    }

    @available(iOSApplicationExtension 9.0, *)
    open func requestAllDataFromPhone() {
        DLog("__giveMeTheData__ sent", toFile: true)
        sendData(["__giveMeTheData__": Date() as AnyObject], trySendMessage: true)
    }
    #if os(iOS)

    @available(iOS 9.3, *)
    public func sessionDidBecomeInactive(_ session: WCSession) {

    }
    @available(iOS 9.3, *)
    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    @available(iOSApplicationExtension 9.0, *)
    open func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        for (myKey,_) in message {
            if (myKey != "__logThis__") {
                DLog("didReceiveMessage: \(myKey)", toFile: true)
            }
        }
        parseReceiveInfo(message)
    }

    @available(iOSApplicationExtension 9.0, *)
    open func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        parseReceiveInfo(userInfo)
    }

    @available(iOSApplicationExtension 9.0, *)
    open func session(_ session: WCSession, didReceive file: WCSessionFile) {
        if let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.ch.opendata.timeforcoffee")?.appendingPathComponent("Documents") {
            let fileManager = FileManager.default
            do {
                if let url = file.fileURL as URL? {
                    let filename = url.lastPathComponent
                    let moveTo = iCloudDocumentsURL.appendingPathComponent(filename)
                    DLog("received file \(filename)", toFile: true)
                    if fileManager.fileExists(atPath: moveTo.path) {
                        try fileManager.removeItem(at: moveTo)
                    }
                    try fileManager.moveItem(at: url, to: moveTo)
                }
            }
            catch let error {
                DLog("Ooops! Something went wrong: \(error)")
            }
        }

    }


    @available(iOSApplicationExtension 9.0, *)
    open func sendData(_ message: [String: Any], trySendMessage: Bool = false, retryCounter:Int = 0) {
        // if we have too many outstandingUserInfoTransfers, something is wrong, try to send as sendMessage as alternative

        var sessionActive = true
        if #available(iOSApplicationExtension 9.3, *) {
            sessionActive = (self.session?.activationState == .activated)
        }
        if (sessionActive) {
            let transferCount = self.session?.outstandingUserInfoTransfers.count
            if (self.session?.isReachable == true && (trySendMessage || (transferCount != nil && transferCount! > 10))) {
                DLog("outstanding UserInfoTransfers \(String(describing: transferCount))")
                self.session?.sendMessage(message, replyHandler: nil, errorHandler: {(error: Error) in
                    DLog("sendMessage failed due to error \(error): Send via transferUserInfo")
                    self.session?.transferUserInfo(message)
                })
            } else {
                self.session?.transferUserInfo(message)
            }
        }
    }

    @available(iOSApplicationExtension 9.0, *)
    func parseReceiveInfo(_ message: [String: Any]) {
        for (myKey,myValue) in message {
            if (myKey != "__logThis__") {
                DLog("parseReceiveInfo: \(myKey)", toFile: true)
            }
            if (myKey == "__updateComplicationData__") {
                if let value = myValue as? [String: AnyObject], let coordinates = value["coordinates"] as? [String: AnyObject], let lng = coordinates["longitude"] as? CLLocationDegrees, let lat = coordinates["latitude"] as? CLLocationDegrees {
                    TFCLocationManagerBase.setCurrentLocation(CLLocation(latitude: lat, longitude: lng ), time: coordinates["time"] as? Date)
                    DLog("coord was sent with __updateComplicationData__ \(lat), \(lng)", toFile: true)
                    NSKeyedUnarchiver.setClass(TFCStation.classForKeyedUnarchiver(), forClassName: "timeforcoffeeKit.TFCStation")
                    if let station = value["station"] as? Data, let sentStationDict = NSKeyedUnarchiver.unarchiveObject(with: station) as? [String:String] {
                        if let sentStation = TFCStation.initWithCache(sentStationDict), let departures = value["departures"] as? Data {
                            NSKeyedUnarchiver.setClass(TFCDeparture.classForKeyedUnarchiver(), forClassName: "timeforcoffeeKit.TFCDeparture")
                            let sentDepartures = NSKeyedUnarchiver.unarchiveObject(with: departures) as? [TFCDeparture]
                            DLog("station sent with __updateComplicationData__: \(sentStation.name) id: \(sentStation.st_id) with \(String(describing: sentDepartures?.count)) departures")
                            sentStation.addDepartures(sentDepartures)
                            sentStation.lastDepartureUpdate = Date()
                            #if DEBUG
                                self.sendData(["__complicationUpdateReceived__": "Received Complication update on watch for \(sentStation.name)"])
                            #endif
                            #if os(watchOS)
                                if (sentStation.st_id == TFCWatchDataFetch.sharedInstance.getLastViewedStation()?.st_id) {
                                    NotificationCenter.default.post(name: Notification.Name(rawValue: "TFCWatchkitUpdateCurrentStation"), object: nil, userInfo: nil)
                                }
                                if let defaults = TFCDataStore.sharedInstance.getUserDefaults() {
                                    defaults.setValue(sentStation.st_id, forKey: "lastFirstStationId")
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
                self.userDefaults?.set(true, forKey: "allDataResponseSent")
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
    open func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DLog("activationDidCompleteWithState. state \(activationState) error \(String(describing: error))")
    }

    @available(iOSApplicationExtension 9.0, *)
    open func sessionReachabilityDidChange(_ session: WCSession) {
        DLog("sessionReachabilityDidChange to \(session.isReachable) ")
    }

    @available(iOSApplicationExtension 9.0, *)
    fileprivate func sendAllData() {
        if let allData = userDefaults?.dictionaryRepresentation() {
            // only send allData if the last request was longer than 1 minute ago
            // This prevents multiple data sends, when requests for it pile up in the queue
            let lastRequest = self.lastRequestForAllData()
            if (lastRequest == nil || lastRequest! < -60) {
                TFCDataStore.sharedInstance.getUserDefaults()?.set(Date(), forKey: "lastRequestForAllDataToBeSent")
                var allDataDict:[String:Any] = [:]
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

    fileprivate func lastRequestForAllData() -> TimeInterval? {
        let lastUpdate: Date? = TFCDataStore.sharedInstance.getUserDefaults()?.object(forKey: "lastRequestForAllDataToBeSent") as! Date?
        return lastUpdate?.timeIntervalSinceNow
    }

    lazy var applicationDocumentsDirectory: URL = {
        let urls = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.ch.opendata.timeforcoffee")
        return urls!
        }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = Bundle(for: TFCDataStore.self).url(forResource: "DataModels", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
        }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("SingleViewCoreData.sqlite")
        let whichBundle:Bundle?
        if (Bundle.main.bundleIdentifier == "ch.opendata.timeforcoffee.watchkitapp.watchkitextension") {
            whichBundle = Bundle.main;
        } else {
            whichBundle = Bundle(identifier: "ch.opendata.timeforcoffee.timeforcoffeeKit" )
        }
        if let bundle = whichBundle {

            let filePath = bundle.path(forResource: "TFC", ofType: "plist")!
            var forceInstall = false
            let neededDBVersion = NSDictionary(contentsOfFile:filePath)?.value(forKey: "dbVersion") as? Int
            if let neededDBVersion = neededDBVersion {
                var installedDBVersion = self.localUserDefaults?.integer(forKey: "installedDBVersion")
                if (installedDBVersion == nil || neededDBVersion != installedDBVersion) {
                    forceInstall = true
                }
            }
            let filemanager = FileManager.default;
            if (forceInstall || !filemanager.fileExists(atPath: url.path)) {

                // delete old files
                let deleteSqliteURLs = [self.applicationDocumentsDirectory.appendingPathComponent("SingleViewCoreData.sqlite"),
                                        self.applicationDocumentsDirectory.appendingPathComponent("SingleViewCoreData.sqlite-wal"),
                                        self.applicationDocumentsDirectory.appendingPathComponent("SingleViewCoreData.sqlite-shm")]

                for index in 0 ..< deleteSqliteURLs.count {
                    let sqliteURL = deleteSqliteURLs[index]
                    do {
                        try filemanager.removeItem(at: sqliteURL)
                        DLog("Removed \(sqliteURL.absoluteString)")
                    } catch {
                        DLog("error deleting \(error)")
                    }
                }

                let sourceSqliteURLs = [bundle.url(forResource: "SingleViewCoreData", withExtension: "sqlite")!]
                let destSqliteURLs = [self.applicationDocumentsDirectory.appendingPathComponent("SingleViewCoreData.sqlite")]

                var error:NSError? = nil
                filemanager.delegate = self
                for index in 0 ..< sourceSqliteURLs.count {
                    do {
                        try filemanager.copyItem(at: sourceSqliteURLs[index], to: destSqliteURLs[index])
                        DLog("SingleViewCoreData.sqlite copied")
                    } catch {
                        DLog("error copying \(error)")
                    }
                    let _ = try? (destSqliteURLs[index] as NSURL).setResourceValue(true, forKey: URLResourceKey.isExcludedFromBackupKey)

                }
                if let neededDBVersion = neededDBVersion {
                    self.localUserDefaults?.set(neededDBVersion, forKey: "installedDBVersion")
                }

            }
        }
        var error: NSError? = nil
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true ]
            )
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data" as AnyObject
            dict[NSLocalizedFailureReasonErrorKey] = failureReason as AnyObject

            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            DLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)", toFile: true)
            abort()
        }
        
        return coordinator
    }()

    lazy open var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        DLog("start new managedObjectContext", toFile: true)
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        managedObjectContext.undoManager = nil
        DLog("end   new managedObjectContext", toFile: true)
        return managedObjectContext
        }()

    func updateComplicationData() {
    }

    func updateWatchNow() {
    }

    open func departuresStillCached(_ context: Any?, forStation: TFCStation?) {
        departuresUpdated(nil, context: context, forStation: forStation)
    }

    open func departuresUpdated(_ error: Error?, context: Any?, forStation: TFCStation?) {
        var coord:CLLocationCoordinate2D? = nil
        if let coordDict = context as? [String:CLLocationCoordinate2D?] {
            if let coord2 = coordDict["coordinates"] {
                coord = coord2
            }
        }
        sendComplicationUpdate2(forStation, coord: coord)
    }

    open func sendComplicationUpdate(_ station: TFCStation?, coord: CLLocationCoordinate2D? = nil) {
        #if os(iOS)
            if #available(iOS 9, *) {
                if (WCSession.isSupported()) {
                    if (self.session?.isComplicationEnabled == true) {
                        if let firstStation = station, let ud = TFCDataStore.sharedInstance.getUserDefaults() {
                            if (ud.string(forKey: "lastFirstStationId") != firstStation.st_id) {
                                DLog("update Departures for \(firstStation.name)")
                                firstStation.updateDepartures(self, context: ["coordinates": coord])
                            }
                        }
                    }
                }
            }
        #endif
    }

    fileprivate func sendComplicationUpdate2(_ station: TFCStation?, coord: CLLocationCoordinate2D? = nil) {
        #if os(iOS)
            if #available(iOS 9, *) {
                if let firstStation = station, let ud = TFCDataStore.sharedInstance.getUserDefaults() {
                    if (ud.string(forKey: "lastFirstStationId") != firstStation.st_id) {
                        var useComplicationTransfer = true
                        var remaining:Int? = nil
                        if #available(iOSApplicationExtension 10.0, *) {
                            remaining = self.session?.remainingComplicationUserInfoTransfers
                            if (remaining == nil || !(remaining! > 0)) {
                                useComplicationTransfer = false
                            }
                            DLog("remainingComplicationUserInfoTransfers: \(String(describing: remaining))", toFile: true)
                        }
                        var data:[String:Any] = [:]

                        if let coord = coord {
                            DLog("send __updateComplicationData__ \(coord) (triggered for \(String(describing: station?.name))) id: \(String(describing: station?.st_id))", toFile: true)
                            data["coordinates"] = [ "longitude": coord.longitude, "latitude": coord.latitude, "time": Date()]
                        } else if let coord = firstStation.coord?.coordinate {
                            DLog("send __updateComplicationData__ with \(coord) for \(String(describing: station?.name)) id: \(String(describing: station?.st_id))", toFile: true)
                            data["coordinates"] = [ "longitude": coord.longitude, "latitude": coord.latitude]
                        }
                        #if DEBUG
                            if let name = station?.name {
                                self.localNotificationCallback?("Complication sent for \(name). Remaining: \(String(describing: remaining))")
                            }
                        #endif
                        data["station"] =  NSKeyedArchiver.archivedData(withRootObject: firstStation.getAsDict())
                        if let filteredDepartures = firstStation.getFilteredDepartures() {
                            data["departures"] =  NSKeyedArchiver.archivedData(withRootObject: Array(filteredDepartures.prefix(10)))
                        }

                        let dict:[String:[String:Any]] = ["__updateComplicationData__": data]

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

    open func saveContext () {
        TFCDataStore.sharedInstance.managedObjectContext.perform {
            if TFCDataStore.sharedInstance.managedObjectContext.hasChanges {
                do {
                    DLog("saveContext")
                    try TFCDataStore.sharedInstance.managedObjectContext.save()
                } catch let error as NSError {
                    // Replace this implementation with code to handle the error appropriately.
                    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    DLog("WARN: Unresolved nserror \(error), \(error.userInfo)", toFile: true)
                } catch let error {
                    DLog("WARN: Unresolved error \(error), \((error as NSError).userInfo)", toFile: true)
                }
            }
        }
    }

    func fetchDepartureData() {
    }

    open func complicationEnabled() -> Bool {
        #if os(iOS)
            if #available(iOS 9, *) {
                if (WCSession.isSupported()) {
                    if (self.session?.isComplicationEnabled == true) {
                        userDefaults?.set(Date(), forKey: "lastComplicationEnabled")
                        return true
                    }
                    if let lastComplicationEnabled = userDefaults?.object(forKey: "lastComplicationEnabled") as? Date {
                        // if we had complications enabled in the last 24 hours, assume it's enabled
                        // so to not loose the fences, when we switch faces temporarly
                        if lastComplicationEnabled.addingTimeInterval(24 * 3600) > Date() {
                            return true
                        }
                    }
                }
            }
        #endif
        return false
    }

    open func getTFCID() -> String? {
        return self.objectForKey("TFCID") as? String
    }
}
