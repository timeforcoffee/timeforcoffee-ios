//
//  TFCSessionURL.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 30.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation


public final class TFCURLSession: NSObject {

    public static let sharedInstance = TFCURLSession()

    override private init() {
        super.init()
    }

    lazy var session: NSURLSession = {
        [unowned self] in
        return self.getSession()
    }()

    public func cancelURLSession() {
        DLog("cancelURLSession")
        session.invalidateAndCancel()
        self.session = getSession()
    }

    private func getSession() -> NSURLSession {
        //let config = NSURLSessionConfiguration.ephemeralSessionConfiguration()
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 10.0
        return NSURLSession(configuration: config)
    }

}
