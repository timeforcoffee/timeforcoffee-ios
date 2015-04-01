//
//  GlanceController.swift
//  Time for Coffee! WatchKit Extension
//
//  Created by Christian Stocker on 02.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import WatchKit
import Foundation


class GlanceController: WKInterfaceController {

    @IBOutlet weak var minutesLabel: WKInterfaceLabel!
    @IBOutlet weak var destinationLabel: WKInterfaceLabel!
    @IBOutlet weak var numberGroup: WKInterfaceGroup!
    @IBOutlet weak var depatureLabel: WKInterfaceLabel!
    @IBOutlet weak var numberLabel: WKInterfaceLabel!
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
    }


    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        
        minutesLabel.setText("6'")
        destinationLabel.setText("Röntgenstrasse");
        depatureLabel.setText("In 6' / 16:59");
        numberLabel.setText("12")
        numberLabel.setTextColor(UIColor.whiteColor())
        numberGroup.setBackgroundColor(UIColor.greenColor())
        
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

}
