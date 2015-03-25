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
            var p = PINCache(name: "apicalls")
            // cache for max 7 days
            p.diskCache.ageLimit = 60 * 60 * 24 * 7 // 7 days
            p.diskCache.byteLimit = 5 * 1024 * 1024 // 5 MB
            return p
            }()
        static var stations: PINCache = {
            var p = PINCache(name: "stations")
            // cache for max 24 hours
            p.diskCache.ageLimit = 60 * 60 * 24 // 1 day
            p.diskCache.byteLimit = 5 * 1024 * 1024 // 5 MB
            NSLog("diskByteCount stations: \(p.diskByteCount)")
            return p
        }()
    }

}