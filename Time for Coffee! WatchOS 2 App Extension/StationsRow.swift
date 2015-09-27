//
//  StationsRow.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 13.04.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import WatchKit

class StationsRow: NSObject {

    weak var station: TFCStation?

    @IBOutlet weak var topGroup: WKInterfaceGroup!
    @IBOutlet weak var stationLabel: WKInterfaceLabel!

    func drawCell(station: TFCStation) {
        self.station = station
        let name = station.getName(true)
        self.stationLabel.setText(name)
        if (topGroup != nil) {
            topGroup.setHidden(false)
        }
    }
    
}