//
//  GATracker.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 15.09.16.
//  Copyright © 2016 opendata.ch. All rights reserved.
//

import Foundation
import timeforcoffeeKit

class GATracker {

    /*class var sharedInstance: GATracker? {
        struct Static {
            static var instance: GATracker = GATracker()
        }
     //   return nil
        return Static.instance
    }*/

    static var sharedInstance:GATracker? = GATracker()

    var gtracker:GAI? = nil
    var toBeSentCustomDimensions:[String:String] = [:]

    init() {
        gtracker = GAI.sharedInstance()
        gtracker?.trackUncaughtExceptions = false
        gtracker?.dispatchInterval = 30;
        //GAI.sharedInstance().logger.logLevel = GAILogLevel.Verbose
        let _ = gtracker?.tracker(withTrackingId: "UA-37092982-2")
    }

    func deinitTracker() {
        DLog("deinit GATracker", toFile: true)
        gtracker?.dispatchInterval = -1;
        gtracker = nil
        GATracker.sharedInstance = nil
    }

    func setCustomDimension(_ index:UInt, value:String) {
        if let field = GAIFields.customDimension(for: index) {
            gtracker?.defaultTracker.set(field, value: value)
            toBeSentCustomDimensions[field] = value
        }
    }

    func sendScreenName(_ name:String) {
        DispatchQueue.global(qos: .utility).async {
            /*
             # FIXME: Threw segfault in iOS 13.. check how to fix
             self.gtracker?.defaultTracker.set(kGAIScreenName, value: name)
            var s = GAIDictionaryBuilder.createScreenView()
            for (key, value) in self.toBeSentCustomDimensions {
                s = s?.set(value, forKey: key)
            }
            self.toBeSentCustomDimensions.removeAll()
            if let builder = s?.build() {
                self.gtracker?.defaultTracker.send(builder as [NSObject : AnyObject])
            }*/
        }

    }

}
