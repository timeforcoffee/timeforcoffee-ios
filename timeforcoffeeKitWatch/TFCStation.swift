//
//  TFCStation.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 21.06.15.
//  Copyright © 2015 Christian Stocker. All rights reserved.
//

import Foundation
import Intents

open class TFCStation: TFCStationBase {
    lazy open var activity : NSUserActivity = {
        [unowned self] in
        NSUserActivity(activityType: "ch.opendata.timeforcoffee.station")
        }()
    
    override open func setStationActivity() {
        let uI = self.getAsDict()
        
        if (uI["st_id"] == nil) {
            DLog("station dict seems EMPTY")
            return
        }
                
        activity.title = self.getName(false)
        activity.userInfo = uI
        activity.requiredUserInfoKeys = ["st_id", "name", "longitude", "latitude"]
        activity.isEligibleForSearch = true
        activity.isEligibleForPublicIndexing = true
        activity.isEligibleForHandoff = true
        if #available(watchOSApplicationExtension 5.0, *) {
            let intent = self.setIntent()
            if let sc = INShortcut(intent: intent) {
                let rsc = INRelevantShortcut(shortcut: sc)
                if let center = TFCLocationManager.getCurrentLocation()?.coordinate {
                    DLog("setIntent with Location")
                    let region = CLCircularRegion(center: center,radius: CLLocationDistance(1000), identifier: "currentLoc")
                    rsc.relevanceProviders = [INLocationRelevanceProvider(region: region)]
                } else {
                    DLog("setIntent with Date")
                    rsc.relevanceProviders = [INDateRelevanceProvider(start: Date().addingTimeInterval(-3600), end: Date().addingTimeInterval(7200))]
                }
                INRelevantShortcutStore.default.setRelevantShortcuts([rsc])
            }

        }
        activity.webpageURL = self.getWebLink()
        let userCalendar = Calendar.current
        let OneWeekFromNow = (userCalendar as NSCalendar).date(
            byAdding: [.day],
            value: 7,
            to: Date(),
            options: [])!
        activity.expirationDate = OneWeekFromNow
        activity.becomeCurrent()
    }
}
