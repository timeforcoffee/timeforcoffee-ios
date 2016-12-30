//
//  GATracker.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 15.09.16.
//  Copyright © 2016 opendata.ch. All rights reserved.
//

import Foundation

class GATracker {

    static var sharedInstance:GATracker? = GATracker()

    var gtracker:GAI? = nil
    var toBeSentCustomDimensions:[String:String] = [:]

    init() {
        gtracker = GAI.sharedInstance()
        gtracker?.trackUncaughtExceptions = true
        gtracker?.dispatchInterval = 30;
        //GAI.sharedInstance().logger.logLevel = GAILogLevel.Verbose
        gtracker?.trackerWithTrackingId("UA-37092982-2")
    }

    func deinitTracker() {
        gtracker?.dispatchInterval = -1;
        gtracker = nil
        GATracker.sharedInstance = nil
    }

    func setCustomDimension(index:UInt, value:String) {
        let field = GAIFields.customDimensionForIndex(index)
        gtracker?.defaultTracker.set(field, value: value)
        toBeSentCustomDimensions[field] = value
    }

    func sendScreenName(name:String) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            self.gtracker?.defaultTracker.set(kGAIScreenName, value: name)
            var s = GAIDictionaryBuilder.createScreenView()
            for (key, value) in self.toBeSentCustomDimensions {
                s = s.set(value, forKey: key)
            }
            self.toBeSentCustomDimensions.removeAll()
            DLog("\(s.build() as [NSObject : AnyObject])")
            self.gtracker?.defaultTracker.send(s.build() as [NSObject : AnyObject]!)
        }

    }

}
