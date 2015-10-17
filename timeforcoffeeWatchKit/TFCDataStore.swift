//
//  TFCDataStore.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 14.09.15.
//  Copyright © 2015 Christian Stocker. All rights reserved.
//

import Foundation
import ClockKit

public class TFCDataStore: TFCDataStoreBase {
    // not supported in watchOS yet, set it to nil
    override var keyvaluestore: NSUbiquitousKeyValueStore? {
        return nil
    }

    override func updateComplicationData() {
        TFCWatchData.sharedInstance.updateComplicationData()
    }
}