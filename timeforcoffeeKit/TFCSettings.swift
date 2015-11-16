//
//  TFCSettings.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 16.11.15.
//  Copyright © 2015 opendata.ch. All rights reserved.
//

import Foundation

public class TFCSettings {

    public class var sharedInstance: TFCSettings {
        struct Static {
            static let instance: TFCSettings = TFCSettings()
        }
        return Static.instance
    }

    public func showRealTimeDebugInfo() -> Bool {
        if let showIt = TFCDataStore.sharedInstance.objectForKey("showRealTimeDebugInfo") as? Bool {
            return showIt
        }
        return false
    }

    public func setRealTimeDebugInfo(showit: Bool) {
        TFCDataStore.sharedInstance.setObject(showit, forKey: "showRealTimeDebugInfo")
    }
}
