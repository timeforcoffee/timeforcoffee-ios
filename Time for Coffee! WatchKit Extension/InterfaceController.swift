//
//  InterfaceController.swift
//  Time for Coffee! WatchKit Extension
//
//  Created by Christian Stocker on 02.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved
//

import WatchKit
import Foundation
import timeforcoffeeWatchKit

class InterfaceController: WKInterfaceController {

    @IBOutlet weak var infoLabel: WKInterfaceLabel!
    @IBOutlet weak var infoGroup: WKInterfaceGroup!

    var userActivity: [String:String]?

    override init () {
        super.init()
        print("init InterfaceController")
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            TFCDataStore.sharedInstance.registerForNotifications()
            TFCDataStore.sharedInstance.synchronize()
        }

    }

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "reloadPages:",
            name: "TFCWatchkitReloadPages",
            object: nil)
        // Configure interface objects here.
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        func handleReply(stations: TFCStations?) {
            infoGroup.setHidden(true)
            if (stations == nil) {
                return
            }
            var pages = [String]()
            var pageContexts = [AnyObject]()
            if let station = stations?[0] {
                var station2 = station
                if let uA = self.userActivity {
                    station2 = TFCStation.initWithCache(uA["name"]!, id: uA["st_id"]!, coord: nil)
                    self.userActivity = nil
                }
                pages.append("StationPage")
                let pc = TFCPageContext()
                pc.station = station2
                pc.pageNumber = 0
                pageContexts.append(pc)
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
                    station2.updateDepartures(nil)
                    return
                }
            }
            pages.append("StationsOverviewPage")
            pageContexts.append("")
            WKInterfaceController.reloadRootControllersWithNames(pages, contexts: pageContexts)
        }
        func errorReply(text: String) {
            infoGroup.setHidden(false)
            infoLabel.setText(text)
        }

        TFCWatchData.sharedInstance.getStations(handleReply, errorReply: errorReply, stopWithFavorites: false)
    }
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    func reloadPages(notification: NSNotification) {
        NSLog("foo")
    }

    override func handleUserActivity(userInfo: [NSObject : AnyObject]!) {
        let uI:[String:String]? = userInfo as? [String:String]
        NSLog("handleUserActivity controller")
        self.userActivity = uI
    }

}
