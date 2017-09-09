//
//  TFCDataStore.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 14.09.15.
//  Copyright © 2015 Christian Stocker. All rights reserved.
//

import Foundation
import ClockKit

open class TFCDataStore: TFCDataStoreBase {

    open static let sharedInstance = TFCDataStore()

    fileprivate override init() {
        super.init()
    }

    lazy var watchdata: TFCWatchData = {
        return TFCWatchData()
    }()

    // not supported in watchOS yet, set it to nil
    override var keyvaluestore: AnyObject? {
        return nil
    }
    
    override func fetchDepartureData() {
        TFCWatchDataFetch.sharedInstance.fetchDepartureData()
    }

    override func updateComplicationData() {
        DLog("updateComplicationData", toFile: true)
        watchdata.updateComplicationData()
    }
}
