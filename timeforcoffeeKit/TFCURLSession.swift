//
//  TFCSessionURL.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 30.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation


public final class TFCURLSession: NSObject {

    public class var sharedInstance: TFCURLSession {
        struct Static {
            static let instance: TFCURLSession = TFCURLSession()
        }
        return Static.instance
    }

    lazy var session: NSURLSession = {
        [unowned self] in
        return self.getSession()
    }()

    public func cancelURLSession() {
        NSLog("cancelURLSession")
        session.invalidateAndCancel()
        self.session = getSession()
    }

    private func getSession() -> NSURLSession {
        let config = NSURLSessionConfiguration.ephemeralSessionConfiguration()
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 10.0
        return NSURLSession(configuration: config)
    }

}
