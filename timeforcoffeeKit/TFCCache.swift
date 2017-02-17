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
            p.diskCache.ageLimit = TimeInterval(60 * 60 * 24 * 7) // 7 days
            p.diskCache.byteLimit = UInt(5 * 1024 * 1024) // 5 MB
            return p
            }()
        static var stations: PINCache = {
            let p:PINCache = TFCCache.getCacheInstance("stations")
            #if DEBUG
            p.memoryCache.didRemoveAllObjectsBlock = {
                (cache) in
                DLog("did remove all objects in pinmemcache \(TFCStationBase.countStationsCache()) memsize: \(String(describing: TFCCache.getMemorySize()))", toFile: true)
            }
            #endif
            #if os(watchOS)
                // It's reduced on resign
                // p.diskCache.byteLimit = UInt(3 * 1024 * 1024) // 2 MB
            #else
                // cache for max 24 hours
                p.diskCache.ageLimit = TimeInterval(60 * 60 * 24) // 1 day
                p.diskCache.byteLimit = UInt(5 * 1024 * 1024) // 5 MB
            #endif
            DLog("diskByteCount stations: \(p.diskByteCount)")
            return p
        }()
    }

    fileprivate class func getRootDirectory() -> String? {
        let manager = FileManager.default
        let documentsDirectory2 = manager.containerURL(forSecurityApplicationGroupIdentifier: "group.ch.opendata.timeforcoffee")
        return (documentsDirectory2?.path)
    }

    fileprivate class func getCacheInstance(_ name: String) -> PINCache {
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

    public class func getMemoryCacheCount() -> UInt {
        let cache = TFCCache.objects.stations
        return cache.memoryCache.count
    }
    public class func allKeys() -> [NSString]? {
        let cache = TFCCache.objects.stations
        return cache.memoryCache.allKeys as? [NSString]
    }

    public class func getMemorySize() -> Float? {
        #if DEBUG
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

            let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(mach_task_self_,
                              task_flavor_t(MACH_TASK_BASIC_INFO),
                              $0,
                              &count)
                }
            }

            if kerr == KERN_SUCCESS {
                return Float(info.resident_size) / (1024 * 1024)
            }
        #endif
        return nil
    }
}
