      //
//  InterfaceController.swift
//  Time for Coffee! WatchKit Extension
//
//  Created by Christian Stocker on 02.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import WatchKit
import Foundation
import timeforcoffeeKit

class InterfaceController: WKInterfaceController {

    override init () {
        super.init()
        println("init InterfaceController")
    }
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        func handleReply(stations: TFCStations?) {
            if (stations == nil) {
                return
            }
            let maxStations = min(5, (stations?.count())! - 1)
            let ctxStations = stations?[0...maxStations]
            var pages = [String]()
            var pageContexts = [AnyObject]()
            for (station) in ctxStations! {
                pages.append("StationPage")
                pageContexts.append(station)
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
                    station.updateDepartures(nil)
                    return
                }
            }
            WKInterfaceController.reloadRootControllersWithNames(pages, contexts: pageContexts)
        }
        TFCWatchData.sharedInstance.getStations(handleReply, stopWithFavorites: false)
    }
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
}
