//
//  TFCDataStore.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 14.09.15.
//  Copyright © 2015 Christian Stocker. All rights reserved.
//

import Foundation

open class TFCDataStore: TFCDataStoreBase {
    
    public static let sharedInstance = TFCDataStore()

    override var keyvaluestore: AnyObject? {
        return NSUbiquitousKeyValueStore.default
    }

    fileprivate override init() {
        super.init()
    }

    override open func getTFCID() -> String? {
        let uid = super.getTFCID()
        if uid == nil  {
            if let uid = UIDevice.current.identifierForVendor?.uuidString {
                self.setObject(uid as AnyObject, forKey: "TFCID");
                return uid
            }
        }
        return uid
    }
    
    @available(iOSApplicationExtension 9.3, *)
    open func isWatchAppInstalled() -> Bool {
        if let wcsession = self.session,
            wcsession.isPaired,
            wcsession.activationState == .activated
            {
                self.getUserDefaults()?.set(wcsession.isWatchAppInstalled, forKey: "isWatchAppInstalled")

        }
        DLog("isWatchAppInstalled: \(String(describing: self.getUserDefaults()?.bool(forKey: "isWatchAppInstalled")))")
        
        if let installed = self.getUserDefaults()?.bool(forKey: "isWatchAppInstalled") {
            return installed
        }
        return false
    }
}

