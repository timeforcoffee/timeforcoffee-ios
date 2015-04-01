//
//  TFCCache.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 10.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import PINCache

class TFCCache {
    struct objects {
        static var apicalls: PINCache = {
            var p = TFCCache.getCacheInstance("apicalls")
            // cache for max 7 days
            p.diskCache.ageLimit = 60 * 60 * 24 * 7 // 7 days
            p.diskCache.byteLimit = 5 * 1024 * 1024 // 5 MB
            return p
            }()
        static var stations: PINCache = {
            var p = TFCCache.getCacheInstance("stations")
            // cache for max 24 hours
            p.diskCache.ageLimit = 60 * 60 * 24 // 1 day
            p.diskCache.byteLimit = 5 * 1024 * 1024 // 5 MB
            NSLog("diskByteCount stations: \(p.diskByteCount)")
            return p
        }()
    }

    private class func getRootDirectory() -> String? {
        let manager = NSFileManager.defaultManager()
        let documentsDirectory2 = manager.containerURLForSecurityApplicationGroupIdentifier("group.ch.liip.timeforcoffee")
        return (documentsDirectory2?.path)
    }

    private class func getCacheInstance(name: String) -> PINCache {
        let rootDir = getRootDirectory()
        // to make sure that cache still works, even if we can't get a shared directory
        //  the cache won't be shared then between app and extensions, but it still works
        if (rootDir == nil) {
            return PINCache(name: name)
        }
        return PINCache(name: name, rootPath: rootDir)
    }
}