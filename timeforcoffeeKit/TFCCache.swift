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
            let p:PINCache = TFCCache.getCacheInstance("stations")
            #if DEBUG
            p.memoryCache.didRemoveAllObjectsBlock = {
                (cache) in
                DLog("did remove all objects in pinmemcache \(TFCStationBase.countStationsCache()) memsize: \(TFCCache.getMemorySize())", toFile: true)
            }
            #endif
            #if os(watchOS)
                p.diskCache.byteLimit = 3 * 1024 * 1024 // 2 MB
            #else
                // cache for max 24 hours
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
            let MACH_TASK_BASIC_INFO_COUNT = (sizeof(mach_task_basic_info_data_t) / sizeof(natural_t))

            // prepare parameters
            let name   = mach_task_self_
            let flavor = task_flavor_t(MACH_TASK_BASIC_INFO)
            var size   = mach_msg_type_number_t(MACH_TASK_BASIC_INFO_COUNT)

            // allocate pointer to mach_task_basic_info
            let infoPointer = UnsafeMutablePointer<mach_task_basic_info>.alloc(1)

            // call task_info - note extra UnsafeMutablePointer(...) call
            let kerr = task_info(name, flavor, UnsafeMutablePointer(infoPointer), &size)

            // get mach_task_basic_info struct out of pointer
            let info = infoPointer.move()

            // deallocate pointer
            infoPointer.dealloc(1)
            if kerr == KERN_SUCCESS {
                return Float(info.resident_size) / (1024 * 1024)
            }
        #endif
        return nil
    }
}
