//
//  StationRow.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 02.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import WatchKit

class StationRow: NSObject {
    
    @IBOutlet weak var destinationLabel: WKInterfaceLabel!
    @IBOutlet weak var depatureLabel: WKInterfaceLabel!
    @IBOutlet weak var minutesLabel: WKInterfaceLabel!
    
    @IBOutlet weak var numberLabel: WKInterfaceLabel!
    
    
    @IBOutlet weak var numberGroup: WKInterfaceGroup!
}