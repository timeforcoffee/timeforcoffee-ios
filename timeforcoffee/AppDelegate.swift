//
//  AppDelegate.swift
//  nextMigros
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import UIKit
import timeforcoffeeKit
import CoreLocation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var watchData: TFCWatchData?



    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        TFCDataStore.sharedInstance.registerForNotifications()
        TFCDataStore.sharedInstance.synchronize()
        
        let gtracker = GAI.sharedInstance()
        gtracker.trackUncaughtExceptions = true
        gtracker.dispatchInterval = 20;
        //GAI.sharedInstance().logger.logLevel = GAILogLevel.Verbose
        gtracker.trackerWithTrackingId("UA-37092982-2")
        gtracker.defaultTracker.set("&uid", value: UIDevice().identifierForVendor.UUIDString)

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {

            var settings = SKTSettings(appToken: "7n3aaqyp9fr5kr7y1wjssd231")
            settings.knowledgeBaseURL = "https://timeforcoffee.zendesk.com"
            SupportKit.initWithSettings(settings)
            let userdefaults = TFCDataStore.sharedInstance.getUserDefaults()
            let lastusedTodayScreen: NSDate? = userdefaults?.objectForKey("lastUsedViewUpdate") as NSDate?
            if (lastusedTodayScreen != nil) {
                SKTUser.currentUser().addProperties(["usedTodayScreen": true])
            }
            if (SKTUser.currentUser().signedUpAt == nil) {
                SKTUser.currentUser().signedUpAt = NSDate()
                SKTUser.currentUser().addProperties(["signedUpDate" : NSDate()])
                SKTUser.currentUser().addProperties(["language": NSLocale.preferredLanguages().first as NSString])
                if (userdefaults?.objectForKey("favorites2") != nil) {
                    SKTUser.currentUser().addProperties(["usedFavorites": true])
                } else {
                    SKTUser.currentUser().addProperties(["usedFavorites": false])
                }
                if (lastusedTodayScreen != nil) {
                    SKTUser.currentUser().addProperties(["lastUsedTodayScreen": lastusedTodayScreen!])
                    SKTUser.currentUser().addProperties(["usedTodayScreen": true])
                } else {
                    SKTUser.currentUser().addProperties(["usedTodayScreen": false])
                }
            }

        //    SupportKit.setDefaultRecommendations(["https://timeforcoffee.zendesk.com/hc/en-us/articles/202772601-How-to-chat-with-you-in-the-iPhone-App-"])
            if (lastusedTodayScreen == nil) {
           //     SupportKit.setTopRecommendation("https://timeforcoffee.zendesk.com/hc/en-us/articles/202698032-How-to-add-Time-for-Coffee-to-the-Today-Screen-")

            }
        }
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject?) -> Bool {

        if (url.host == "nearby") {
            let rootView = self.window?.rootViewController? as UINavigationController?
            rootView?.popToRootViewControllerAnimated(false)
            if (rootView != nil) {
                let pagedView: PagedStationsViewController? = rootView?.viewControllers.first as PagedStationsViewController?
                pagedView?.moveToNearbyStations()
            }

        } else if (url.host == "station" && url.query != nil) {
         
            var queryStrings = [String: String]()
            if let query = url.query {
                for qs in query.componentsSeparatedByString("&") {
                    // Get the parameter name
                    let key = qs.componentsSeparatedByString("=")[0]
                    // Get the parameter name
                    var value = qs.componentsSeparatedByString("=")[1]
                    value = value.stringByReplacingOccurrencesOfString("+", withString: " ")
                    value = value.stringByReplacingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
                    
                    queryStrings[key] = value
                }
            }
            let Clocation = CLLocation(latitude: NSString(string: queryStrings["lat"]!).doubleValue, longitude: NSString(string: queryStrings["long"]!).doubleValue)

            let station = TFCStation(name: queryStrings["name"]!, id: queryStrings["id"]!, coord: Clocation)
            let stations = TFCStations()
            let rootView = self.window?.rootViewController? as UINavigationController
            let detailViewController = rootView.storyboard?.instantiateViewControllerWithIdentifier("DeparturesViewController") as DeparturesViewController

            rootView.popToRootViewControllerAnimated(false)
            detailViewController.setStation(station)
            rootView.pushViewController(detailViewController, animated: false)
        }
        return true
    }
    
    func application(application: UIApplication!, handleWatchKitExtensionRequest userInfo: [NSString : NSString]!, reply: (([NSObject : AnyObject]!) -> Void)!) {
        if  (watchData == nil) {
            watchData = TFCWatchData()
        }

        if (userInfo["module"] == "favorites") {
            watchData?.getFavorites(reply)
        } else if (userInfo["module"] == "departures") {
            watchData?.getDepartures(userInfo, reply: reply!)
        } else if (userInfo["module"] == "nearby") {
            NSLog("get nearby module")
            watchData?.getNearbyStations(reply)
        } else {
            watchData?.getFavorites(reply)
        }
    }

}

