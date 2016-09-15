//
//  GATracker.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 15.09.16.
//  Copyright © 2016 opendata.ch. All rights reserved.
//

import Foundation

class GATracker {

    class var sharedInstance: GATracker {
        struct Static {
            static let instance: GATracker = GATracker()
        }
        return Static.instance
    }


    let gtracker = GAI.sharedInstance()
    var toBeSentCustomDimensions:[String:String] = [:]

    init() {
        gtracker.trackUncaughtExceptions = true
        gtracker.dispatchInterval = 20;
        //GAI.sharedInstance().logger.logLevel = GAILogLevel.Verbose
        gtracker.trackerWithTrackingId("UA-37092982-2")
    }
    func setCustomDimension(index:UInt, value:String) {
        let field = GAIFields.customDimensionForIndex(index)
        gtracker.defaultTracker.set(field, value: value)
        toBeSentCustomDimensions[field] = value
    }

    func sendScreenName(name:String) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            self.gtracker.defaultTracker.set(kGAIScreenName, value: name)
            var s = GAIDictionaryBuilder.createScreenView()
            for (key, value) in self.toBeSentCustomDimensions {
                s = s.set(value, forKey: key)
            }
            self.toBeSentCustomDimensions.removeAll()
            DLog("\(s.build() as [NSObject : AnyObject])")
            self.gtracker.defaultTracker.send(s.build() as [NSObject : AnyObject]!)
        }

    }

}
