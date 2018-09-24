//
//  TFCStation.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 21.06.15.
//  Copyright © 2015 Christian Stocker. All rights reserved.
//

import Foundation
import Intents

open class TFCStation: TFCStationBase {
    lazy open var activity : NSUserActivity = {
        [unowned self] in
        NSUserActivity(activityType: "ch.opendata.timeforcoffee.station")
        }()
}
