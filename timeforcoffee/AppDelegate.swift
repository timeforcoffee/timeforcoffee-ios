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



@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    // when the app starts from scratch, we can't move to favorites
    //  from the AppDelegate but have to do it later in the ViewController
    //
    var startedWithShortcut: String?
    var launchedShortcutItem: AnyObject?
    fileprivate var visits: TFCVisits?
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
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        DLog("WARNING: applicationDidReceiveMemoryWarning", toFile: true)
        TFCFavorites.sharedInstance.clearStationCache()
        GATracker.sharedInstance?.deinitTracker()
        TFCDataStore.sharedInstance.saveContext()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Override point for customization after application launch.
        var shouldPerformAdditionalDelegateHandling = true

        // If a shortcut was launched, display its information and take the appropriate action
        if #available(iOS 9.0, *) {
            if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
    
                launchedShortcutItem = shortcutItem
    
                // This will block "performActionForShortcutItem:completionHandler" from being called.
                shouldPerformAdditionalDelegateHandling = false
            }
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




            let gtracker = GATracker.sharedInstance
            gtracker?.setCustomDimension(7, value: "yes")
            gtracker?.setCustomDimension(9, value: UIDevice.current.systemVersion)

            TFCCrashlytics.sharedInstance.initCrashlytics()
            if let lO = launchOptions?[UIApplication.LaunchOptionsKey.location] {
                DLog("app launched with UIApplicationLaunchOptionsLocationKey: \(lO)", toFile: true)
            }

            #if !(targetEnvironment(simulator))
                let settings = SKTSettings(appId: "55169650985288160008b0ca")
                //            settings.knowledgeBaseURL = "https://timeforcoffee.zendesk.com"

                DispatchQueue.main.async {
                    Smooch.initWith(settings)
                }
            #endif
            let userdefaults = TFCDataStore.sharedInstance.getUserDefaults()
            let lastusedTodayScreen: Date? = userdefaults?.object(forKey: "lastUsedViewUpdate") as! Date?
            /* var recommendations: [String] = []
             recommendations.append("https://timeforcoffee.zendesk.com/hc/en-us/articles/202701502-How-to-use-the-favourite-station-feature-")
             recommendations.append("https://timeforcoffee.zendesk.com/hc/en-us/articles/202701512-Can-I-exclude-some-destinations-from-a-station-")
             recommendations.append("https://timeforcoffee.zendesk.com/hc/en-us/articles/202775921-Is-there-a-map-view-somewhere-")
             recommendations.append("https://timeforcoffee.zendesk.com/hc/en-us/articles/202772511-Who-is-behind-Time-for-Coffee-")
             */
            if let currentUser = SKTUser.current() {
                if (userdefaults?.object(forKey: "favorites3") != nil) {
                    currentUser.addProperties(["usedFavorites": true])
                    gtracker?.setCustomDimension(4, value: "yes")
                } else {
                    currentUser.addProperties(["usedFavorites": false])
                    gtracker?.setCustomDimension(4, value: "no")
                }
                if (lastusedTodayScreen != nil) {
                    currentUser.addProperties(["lastUsedTodayScreen": lastusedTodayScreen!])
                    currentUser.addProperties(["usedTodayScreen": true])
                    gtracker?.setCustomDimension(3, value: "yes")
                } else {
                    currentUser.addProperties(["usedTodayScreen": false])
                    gtracker?.setCustomDimension(3, value: "no")
                }

                if let uid = TFCDataStore.sharedInstance.getTFCID() {
                    currentUser.addProperties(["TFCID": uid])
                }
                if (currentUser.signedUpAt == nil) {
                    currentUser.signedUpAt = Date()
                    currentUser.addProperties(["signedUpDate" : Date()])
                    if let lang =  Locale.preferredLanguages.first {
                        let langSplit = lang.components(separatedBy: "-")
                        currentUser.addProperties(["language": langSplit[0]])
                        gtracker?.setCustomDimension(5, value: langSplit[0])
                    }

                }
                if #available(iOS 9.0, *) {
                    delay(5.0, closure: {
                        if let wcsession = TFCDataStore.sharedInstance.session {
                            if (wcsession.isPaired) {
                                currentUser.addProperties(["hasWatch": true])
                                gtracker?.setCustomDimension(8, value: "yes")
                                if (wcsession.isWatchAppInstalled) {
                                    currentUser.addProperties(["hasWatchAppInstalled": true])
                                    gtracker?.setCustomDimension(2, value: "yes")

                                } else {
                                    currentUser.addProperties(["hasWatchAppInstalled": false])
                                    gtracker?.setCustomDimension(2, value: "no")
                                }
                                if (wcsession.isComplicationEnabled == true) {
                                    currentUser.addProperties(["hasComplicationsEnabled": true])
                                    gtracker?.setCustomDimension(1, value: "yes")

                                } else {
                                    currentUser.addProperties(["hasComplicationsEnabled": false])
                                    gtracker?.setCustomDimension(1, value: "no")
                                }
                            }
                        }
                    })
                }
            }
            /*            Smooch.setDefaultRecommendations(recommendations)
             if (lastusedTodayScreen == nil) {
             Smooch.setTopRecommendation("https://timeforcoffee.zendesk.com/hc/en-us/articles/202698032-How-to-add-Time-for-Coffee-to-the-Today-Screen-")

             }
             */
        }
        return shouldPerformAdditionalDelegateHandling
    }

    func receivedNewVisit(_ text: String) {
        #if DEBUG
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
        if #available(iOS 9.0, *) {
            guard let shortcut = launchedShortcutItem else { return }
            let _ = handleShortCutItem(shortcut as! UIApplicationShortcutItem)
            launchedShortcutItem = nil
        }
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

    @available(iOS 9.0, *)
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {

        let handledShortCutItem = handleShortCutItem(shortcutItem)
        completionHandler(handledShortCutItem)
    }

    @available(iOS 9.0, *)
    func handleShortCutItem(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        // Verify that the provided `shortcutItem`'s `type` is one handled by the application.
        var handled = false
        guard ShortcutIdentifier(fullType: shortcutItem.type) != nil else { return false }

        guard let shortCutType = shortcutItem.type as String? else { return false }
        startedWithShortcut = shortCutType
        switch (shortCutType) {
        case ShortcutIdentifier.favorites.type:
            // Handle shortcut 1 (static).
            if let rootView = self.window?.rootViewController as! UINavigationController? {
                rootView.dismiss(animated: false, completion: nil)
                rootView.popToRootViewController(animated: true)
                if let pagedView:PagedStationsViewController = rootView.viewControllers.first as! PagedStationsViewController? {
                    pagedView.moveToFavorites()
                }
            }
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

        } else if (url.host == "station" && url.query != nil) {
         
            var queryStrings = [String: String]()
            if let query = url.query {
                for qs in query.components(separatedBy: "&") {
                    // Get the parameter name
                    let key = qs.components(separatedBy: "=")[0]
                    // Get the parameter name
                    var value = qs.components(separatedBy: "=")[1]
                    value = value.replacingOccurrences(of: "+", with: " ")
                    value = value.removingPercentEncoding!
                    queryStrings[key] = value
                }
            }
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
        if #available(iOS 9, *) {

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
                        if let st_id = intent.st_id {
                            if let station = TFCStation.initWithCache("", id: st_id, coord: nil) {
                                popUpStation(station)
                            }
                        } else {
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
                    }
                }
            }
        }
        return true

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
