//
//  TFCCache.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 10.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation

public final class TFCCache {
    struct objects {
        static var apicalls: PINCache = {
            let p = TFCCache.getCacheInstance("apicalls")
            // cache for max 7 days
            p.diskCache.ageLimit = 60 * 60 * 24 * 7 // 7 days
            p.diskCache.byteLimit = 5 * 1024 * 1024 // 5 MB
            return p
            }()
        static var stations: PINCache = {
            let p = TFCCache.getCacheInstance("stations")
            // cache for max 24 hours
            #if os(watchOS)
                p.diskCache.byteLimit = 2 * 1024 * 1024 // 2 MB
            #else
                p.diskCache.ageLimit = 60 * 60 * 24 // 1 day
                p.diskCache.byteLimit = 5 * 1024 * 1024 // 5 MB
            #endif
            DLog("diskByteCount stations: \(p.diskByteCount)")
            return p
        }()
    }

    private class func getRootDirectory() -> String? {
        let manager = NSFileManager.defaultManager()
        let documentsDirectory2 = manager.containerURLForSecurityApplicationGroupIdentifier("group.ch.opendata.timeforcoffee")
        return (documentsDirectory2?.path)
    }

    private class func getCacheInstance(name: String) -> PINCache {
        // to make sure that cache still works, even if we can't get a shared directory
        //  the cache won't be shared then between app and extensions, but it still works
        if let rootDir = getRootDirectory() {
            return PINCache(name: name, rootPath: rootDir)
        }
        return PINCache(name: name)
    }

    public class func clearMemoryCache() {
        TFCCache.objects.stations.memoryCache.removeAllObjects()
        TFCCache.objects.apicalls.memoryCache.removeAllObjects()
    }
}
