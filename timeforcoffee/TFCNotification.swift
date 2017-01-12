//
//  TFCNotification.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 24.09.16.
//  Copyright © 2016 opendata.ch. All rights reserved.
//

import Foundation

class TFCNotification {
    func send(text:String?) {
        #if DEBUG
            if let text = text {
                let noti = UILocalNotification()
                noti.alertBody = text
                noti.soundName = UILocalNotificationDefaultSoundName
                UIApplication.sharedApplication().presentLocalNotificationNow(noti)
                DLog("Sent notification: \(text)", toFile: true)
            }
        #endif
    }
}
