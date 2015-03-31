//
//  TFCSessionURL.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 30.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation


public class TFCURLSession: NSObject {

    public class var sharedInstance: TFCURLSession {
        struct Static {
            static let instance: TFCURLSession = TFCURLSession()
        }
        return Static.instance
    }

    public lazy var session: NSURLSession = {
        [unowned self] in
        NSLog("session init")
        return self.getSession()
    }()

    public func cancelURLSession() {
        NSLog("cancelURLSession")
        session.invalidateAndCancel()
        self.session = getSession()
    }

    func getSession() -> NSURLSession {
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 10.0
        return NSURLSession(configuration: config)
    }

}
