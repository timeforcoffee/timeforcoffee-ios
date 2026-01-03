//
//  TFCNotification.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 24.09.16.
//  Copyright © 2016 opendata.ch. All rights reserved.
//

import Foundation
import UserNotifications

class TFCNotification {
    func send(_ text:String?) {
        #if DEBUG
            if let text = text {
                let content = UNMutableNotificationContent()
                content.body = text
                content.sound = .default
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request)
            }
        #endif
    }
}
