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
    
    
    var lastShortcutUpdateSent:Date? = nil
    
    open override func updateRelevantShortCuts() {
        if #available(iOSApplicationExtension 12.0, watchOSApplicationExtension 5.0, *) {
            
            // for some strange reason, when we update relevant shortcuts on watchOS, it dissapears on the siri watch face,
            // so let the phone do it
            if (self.lastShortcutUpdateSent == nil || self.lastShortcutUpdateSent!.timeIntervalSinceNow < -60) {
                let _ = TFCDataStore.sharedInstance.sendData(["__updateRelevantShortcuts__" : self.st_id], trySendMessage: true)
                self.lastShortcutUpdateSent = Date()
            }
        }
    }
       
}
