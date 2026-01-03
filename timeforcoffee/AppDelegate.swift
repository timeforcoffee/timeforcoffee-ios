//
//  AppDelegate.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import UIKit
import timeforcoffeeKit
import CoreLocation
import CoreSpotlight
import MobileCoreServices
import CoreData
import WatchConnectivity
import Intents


@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    // when the app starts from scratch, we can't move to favorites
    //  from the AppDelegate but have to do it later in the ViewController
    //
    var startedWithShortcut: String?
    var launchedShortcutItem: AnyObject?
    fileprivate var visits: TFCVisits?
    fileprivate let localUserDefaults: UserDefaults? = UserDefaults(suiteName: "ch.opendata.timeforcoffee.local")

    var stationsUpdate:TFCStationsUpdate? = nil
    enum ShortcutIdentifier: String {
        case favorites
        case search
        case station

        // MARK: Initializers

        init?(fullType: String) {
            guard let last = fullType.components(separatedBy: ".").last else { return nil }

            self.init(rawValue: last)
        }

        // MARK: Properties

        var type: String {
            return Bundle.main.bundleIdentifier! + ".\(self.rawValue)"
        }
    }
    
    deinit {
        self.stationsUpdate = nil
    }
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        DLog("WARNING: applicationDidReceiveMemoryWarning", toFile: true)
        TFCFavorites.sharedInstance.clearStationCache()
        TFCDataStore.sharedInstance.saveContext()
    }
    
    override init() {
        super.init()
        var version = self.localUserDefaults?.integer(forKey: "applicationVersion")
        if version == nil { version = 0}
        if let version = version {
            if version < 4 {
                if version < 3 {
                    CSSearchableIndex.default().deleteAllSearchableItems()
                    
                    if #available(iOS 10.0, *) {
                        INInteraction.deleteAll(completion: { (error: Error?) in
                            TFCFavorites.sharedInstance.donateDefaultIntents()
                        }
                        )
                    }
                } else {
                    TFCFavorites.sharedInstance.donateDefaultIntents(force: true)
                }
                self.localUserDefaults?.set(4, forKey: "applicationVersion")
            }
        }
        TFCFavorites.sharedInstance.donateDefaultIntents()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Override point for customization after application launch.
        var shouldPerformAdditionalDelegateHandling = true
        
       

        // If a shortcut was launched, display its information and take the appropriate action
        if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            
            launchedShortcutItem = shortcutItem
            
            // This will block "performActionForShortcutItem:completionHandler" from being called.
            shouldPerformAdditionalDelegateHandling = false
        }

        if (TFCDataStore.sharedInstance.complicationEnabled()) {
            self.visits = TFCVisits(callback: self.receivedNewVisit)
        } else {
            let loc = CLLocationManager()
            DLog("CLLocationManager()")
            if loc.monitoredRegions.count > 0 {
                //delete all geofences, we don't need them if no complications
                for region in loc.monitoredRegions {
                    if let circularRegion = region as? CLCircularRegion {
                        loc.stopMonitoring(for: circularRegion)
                    }
                }

            }
        }
        #if DEBUG
            if (self.visits?.willReceive() == true) {
                application.registerUserNotificationSettings(UIUserNotificationSettings(types: [.alert, .sound] , categories: nil))
            }
        #endif

        DispatchQueue.global(qos:  DispatchQoS.QoSClass.utility).async {
    
            
            
            
            TFCDataStore.sharedInstance.registerWatchConnectivity()
            TFCDataStore.sharedInstance.registerForNotifications()
            TFCDataStore.sharedInstance.synchronize()
            #if DEBUG
                let noti = TFCNotification()
                TFCDataStore.sharedInstance.localNotificationCallback = noti.send
            #endif




            if let lO = launchOptions?[UIApplication.LaunchOptionsKey.location] {
                DLog("app launched with UIApplicationLaunchOptionsLocationKey: \(lO)", toFile: true)
            }

        }
        return shouldPerformAdditionalDelegateHandling
    }

    func receivedNewVisit(_ text: String) {
        #if DEBUG_NOTIFICATION
            let noti = TFCNotification()
            noti.send(text)
        #endif
    }


    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.

        TFCDataStore.sharedInstance.synchronize()

    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        TFCDataStore.sharedInstance.saveContext()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        TFCDataStore.sharedInstance.synchronize()
    }

    @objc func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        guard let shortcut = launchedShortcutItem else { return }
        let _ = handleShortCutItem(shortcut as! UIApplicationShortcutItem)
        launchedShortcutItem = nil
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        let state = UIApplication.shared.applicationState
        let stateString:String
        if state == .background {
            stateString = "Background"
        } else if state == .active {
            stateString = "Active"
        } else if state == .inactive {
            stateString = "Inactive"
        } else {
            stateString = "Unknown \(state.rawValue)"
        }
        DLog("applicationWillTerminate. State \(stateString)", toFile: true, sync: true)
        TFCDataStore.sharedInstance.saveContext()
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {

        let handledShortCutItem = handleShortCutItem(shortcutItem)
        completionHandler(handledShortCutItem)
    }

    fileprivate func openFavorites() {
        // Handle shortcut 1 (static).
        if let rootView = self.window?.rootViewController as! UINavigationController? {
            rootView.dismiss(animated: false, completion: nil)
            rootView.popToRootViewController(animated: true)
            if let pagedView:PagedStationsViewController = rootView.viewControllers.first as! PagedStationsViewController? {
                pagedView.moveToFavorites()
            }
        }
    }
    
    func handleShortCutItem(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        // Verify that the provided `shortcutItem`'s `type` is one handled by the application.
        var handled = false
        guard ShortcutIdentifier(fullType: shortcutItem.type) != nil else { return false }

        guard let shortCutType = shortcutItem.type as String? else { return false }
        startedWithShortcut = shortCutType
        switch (shortCutType) {
        case ShortcutIdentifier.favorites.type:
            openFavorites()
            handled = true
            break
        case ShortcutIdentifier.search.type:
            // Handle shortcut 2 (static).
            if let rootView = self.window?.rootViewController as! UINavigationController? {
                rootView.dismiss(animated: false, completion: nil)
                rootView.popToRootViewController(animated: true)
                if let pagedView:PagedStationsViewController = rootView.viewControllers.first as! PagedStationsViewController? {
                   pagedView.searchClicked()
                }
            }
            handled = true
            break
        case ShortcutIdentifier.station.type:
            // Handle shortcut 3 (dynamic).
            handled = true
            if let ua: [String: String] = shortcutItem.userInfo as? [String: String] {
                if (ua["st_id"] != nil) {
                    if let station = TFCStation.initWithCache(ua) {
                        popUpStation(station)
                    }
                }
            }

            break
        default:
            break
        }
        return handled

    }


    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {

        if (url.host == "nearby") {
            if let rootView = self.window?.rootViewController as! UINavigationController? {
                rootView.dismiss(animated: false, completion: nil)
                rootView.popToRootViewController(animated: false)
                if let pagedView:PagedStationsViewController = rootView.viewControllers.first as! PagedStationsViewController? {
                    pagedView.moveToNearbyStations()
                }
            }
        } else if (url.host == "x-callback-url") {
            let cb = TFCXCallback()
            var queryStrings:[String:String] = [:]
            queryStrings = TFCXCallback.getQueryParameters(url)
            if queryStrings["method"] == nil {
                queryStrings["method"] = url.path
            }
            let xErrorUrl =  queryStrings["x-error"]
            if let xCallbackUrl = queryStrings["x-success"] {
                func callUrl(_ error: String?, _ cbObject: TFCXCallbackObject) {
                    if let error = error {
                        if let callBackUrl = URL(string: "\(xErrorUrl ?? "")?errorMessage=\(error)") {
                            DLog("Call x-callback-url with error: \(callBackUrl)?errorMessage=\(error)")
                            DispatchQueue.main.async {
                                UIApplication.shared.openURL(callBackUrl)
                                DLog("Called x-callback-url with error")
                            }
                        }
                        return
                    }
                    
                    var components = URLComponents()
                    
                    
                    components.queryItems = cbObject.getParams().map {
                        URLQueryItem(name: $0, value: $1)
                    }
                    
                    if let callBackUrl = URL(string: "\(xCallbackUrl)\(components.url?.absoluteString ?? "")") {
                        DLog("Call x-callback-url: \(callBackUrl)")
                        DispatchQueue.main.async {
                            UIApplication.shared.openURL(callBackUrl)
                            DLog("Called x-callback-url")
                        }
                    }
                }
                cb.handleCall(queryStrings: queryStrings, callback: callUrl)
            }
        

        } else if (url.host == "favorites") {
            openFavorites()
        } else if (url.host == "closest") {
            openClosestStation()
        } else if (url.host == "station" && url.query != nil) {
         
            let queryStrings = TFCXCallback.getQueryParameters(url)
            if let name = queryStrings["name"] as String? {
                var Clocation: CLLocation? = nil
                if (queryStrings["lat"] != nil) {
                    Clocation = CLLocation(latitude: NSString(string: queryStrings["lat"]!).doubleValue, longitude: NSString(string: queryStrings["long"]!).doubleValue)
                }
                if let station = TFCStation.initWithCache(name, id: queryStrings["id"]!, coord: Clocation) {
                    popUpStation(station)
                }
            }
        }
        return true
    }

    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        
        if userActivity.activityType == "ch.opendata.timeforcoffee.station" {
            if let ua: [String: String] = userActivity.userInfo as? [String: String] {
                if (ua["st_id"] != nil) {
                    if let station = TFCStation.initWithCache(ua) {
                        popUpStation(station)
                    }
                }
            }
            
        }
        if userActivity.activityType == CSSearchableItemActionType {
            // This activity represents an item indexed using Core Spotlight, so restore the context related to the unique identifier.
            // Note that the unique identifier of the Core Spotlight item is set in the activity’s userInfo property for the key CSSearchableItemActivityIdentifier.
            if let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                // Next, find and open the item specified by uniqueIdentifer.
                if let station = TFCStation.initWithCache("", id: uniqueIdentifier, coord: nil) {
                    popUpStation(station)
                }
            }
        }
        if #available(iOS 12.0, *) {
            if (userActivity.interaction?.intent is NextDeparturesIntent) {
                if let intent = userActivity.interaction?.intent as? NextDeparturesIntent {
                  if let st_id = intent.stationObj?.identifier {
                        let name:String
                        if let stationName = intent.stationObj?.displayString {
                            name = stationName
                        } else {
                            name = ""
                        }
                        if let station = TFCStation.initWithCache(name, id: st_id, coord: nil) {
                            popUpStation(station)
                        }
                    } else {
                       openClosestStation()
                    }
                }
            }
        }
        return true

    }

    fileprivate func openClosestStation() {
        func stationsUpdateCompletion(stations:TFCStations?, error: String?, context: Any?) {
            if let stations = stations {
                if let station = stations.getStation(0) {
                    DispatchQueue.main.async {
                        self.popUpStation(station)
                    }
                }
            }
        }
        self.stationsUpdate = TFCStationsUpdate(completion: stationsUpdateCompletion)
        self.stationsUpdate?.update(maxStations: 1)
    }


    fileprivate func popUpStation(_ station: TFCStation) {
        let rootView = self.window?.rootViewController as! UINavigationController
        let detailViewController = rootView.storyboard?.instantiateViewController(withIdentifier: "DeparturesViewController") as! DeparturesViewController

        viewRoot()
        detailViewController.setStation(station: station)
        rootView.pushViewController(detailViewController, animated: false)

    }
    
    fileprivate func viewRoot() {
        let rootView = self.window?.rootViewController as! UINavigationController
        rootView.dismiss(animated: false, completion: nil)
        rootView.popToRootViewController(animated: false)
    }



    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        #if DEBUG
            if (application.applicationState == .active) {

                let alert = UIAlertController(title: "Notification", message: notification.alertBody, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .default))

                let rootView = self.window?.rootViewController as! UINavigationController
                rootView.present(alert, animated: false, completion: nil)
            }
        #endif
        
    }
}
