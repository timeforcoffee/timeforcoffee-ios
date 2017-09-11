//
//  TFCNotification.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 24.09.16.
//  Copyright © 2016 opendata.ch. All rights reserved.
//

import Foundation

class TFCNotification {
    func send(_ text:String?) {
        #if DEBUG
            if let text = text {
                DispatchQueue.main.async {
                    let noti = UILocalNotification()
                    noti.alertBody = text
                    noti.soundName = UILocalNotificationDefaultSoundName
                    UIApplication.shared.presentLocalNotificationNow(noti)
                }
            }
        #endif
    }
}
