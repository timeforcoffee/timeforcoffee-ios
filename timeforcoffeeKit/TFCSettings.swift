//
//  TFCSettings.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 16.11.15.
//  Copyright © 2015 opendata.ch. All rights reserved.
//

import Foundation

open class TFCSettings {

    public static let sharedInstance = TFCSettings()

    fileprivate init() {
    }

    open func showRealTimeDebugInfo() -> Bool {
        if let showIt = TFCDataStore.sharedInstance.objectForKey("showRealTimeDebugInfo") as? Bool {
            return showIt
        }
        return false
    }

    open func setRealTimeDebugInfo(_ showit: Bool) {
        TFCDataStore.sharedInstance.setObject(showit as AnyObject, forKey: "showRealTimeDebugInfo")
    }
}
