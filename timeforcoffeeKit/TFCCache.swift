//
//  TFCCache.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 10.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation

class TFCCache {
    struct objects {
        static var stations: NSCache = NSCache()
        static var apicalls: NSCache = NSCache()
    }

}