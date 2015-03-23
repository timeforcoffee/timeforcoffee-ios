//
//  TFCDataStore.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 23.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation


public class TFCDataStore {

    private struct objects {
        static var favorites: TFCFavorites =  TFCFavorites()
        static let  userDefaults: NSUserDefaults? = NSUserDefaults(suiteName: "group.ch.liip.timeforcoffee")
    }

    func setObject(anObject: AnyObject, forKey: String) {
        objects.userDefaults?.setObject(anObject , forKey: forKey)
    }

    func objectForKey(forKey: String) -> AnyObject? {
        return objects.userDefaults?.objectForKey(forKey)
    }

    func removeObjectForKey(forKey: String) {
        objects.userDefaults?.removeObjectForKey(forKey)
    }

}