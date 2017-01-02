//
//  TFCDataStore.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 14.09.15.
//  Copyright © 2015 Christian Stocker. All rights reserved.
//

import Foundation

public class TFCDataStore: TFCDataStoreBase {
    
    public static let sharedInstance = TFCDataStore()

    override var keyvaluestore: NSUbiquitousKeyValueStore? {
        return NSUbiquitousKeyValueStore.defaultStore()
    }

    private override init() {
        super.init()
    }

    override public func getTFCID() -> String? {

        let uid = super.getTFCID()
        if uid == nil  {
            if let uid = UIDevice.currentDevice().identifierForVendor?.UUIDString {
                let userdefaults = self.getUserDefaults()
                userdefaults?.setValue(uid, forKey: "TFCID")
                return uid
            }
        }
        return uid
    }
}

