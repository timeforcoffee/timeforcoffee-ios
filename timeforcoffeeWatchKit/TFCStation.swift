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
    lazy var activity : NSUserActivity = {
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
            activity.isEligibleForPrediction = true
            if let center = TFCLocationManager.getCurrentLocation()?.coordinate {
                let sc = INShortcut(userActivity: activity)
                let rsc = INRelevantShortcut(shortcut: sc)
                let region = CLCircularRegion(center: center,radius: CLLocationDistance(300), identifier: "currentLoc")
                rsc.relevanceProviders = [INLocationRelevanceProvider(region: region)]
                INRelevantShortcutStore.default.setRelevantShortcuts([rsc])
            }
            activity.persistentIdentifier = NSUserActivityPersistentIdentifier(self.st_id)
            self.setIntent()

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
