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

class InterfaceController: WKInterfaceController, APIControllerProtocol {

    lazy var stations: TFCStations? =  {return TFCStations()}()
    lazy var api : APIController? = {
        [unowned self] in
        return APIController(delegate: self)
        }()
    var networkErrorMsg: String?

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
        func handleReply(replyInfo: [NSObject : AnyObject]!, error: NSError!) {
            if(replyInfo["lat"] != nil) {
                let loc = CLLocation(latitude: replyInfo["lat"] as Double, longitude: replyInfo["long"] as Double)
                self.stations?.clear()
                self.stations?.addNearbyFavorites(loc)
                self.api?.searchFor(loc.coordinate)
            }
        }
        WKInterfaceController.openParentApplication(["module":"location"], handleReply)

    }

    func didReceiveAPIResults(results: JSONValue, error: NSError?, context: Any?) {
        if (!(error != nil && error?.code == -999)) {
            if (error != nil) {
                self.networkErrorMsg = NSLocalizedString("Network error. Please try again", comment: "")
            } else {
                self.networkErrorMsg = nil
            }
            if (TFCStation.isStations(results)) {
                self.stations?.addWithJSON(results, append: true)
                let ctxStations = self.stations?[0...5]
                var pages = [String]()
                var pageContexts = [AnyObject]()
                NSLog("Start reloadRootControllersWithNames")
                for (station) in ctxStations! {
                    pages.append("StationPage")
                    pageContexts.append(station)
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
                        station.updateDepartures(nil, maxDepartures: 10)
                        return
                    }

                }

                WKInterfaceController.reloadRootControllersWithNames(pages, contexts: pageContexts)
                NSLog("End reloadRootControllersWithNames")
            }
        }
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
}
