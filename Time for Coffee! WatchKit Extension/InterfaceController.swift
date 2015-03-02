//
//  InterfaceController.swift
//  Time for Coffee! WatchKit Extension
//
//  Created by Christian Stocker on 02.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import WatchKit
import Foundation


class InterfaceController: WKInterfaceController {
    @IBOutlet weak var stationsTable: WKInterfaceTable!
   
    override init () {
        super.init()
        println("init")
        
    }
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        println("willActivate")
        
        func handleReply(replyInfo: [NSObject : AnyObject]!, error: NSError!) {
            var i = 0;
            stationsTable.setNumberOfRows(replyInfo.count, withRowType: "station")
            println(replyInfo);
            for (st_id, station) in replyInfo {
                let sr = stationsTable.rowControllerAtIndex(i) as StationRow
                println(station["name"])
                let name = station["name"] as String
                sr.destinationLabel.setText(name)
                println(station)
                i++
            }
        }
        WKInterfaceController.openParentApplication(["Hello":"World"], handleReply)
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    

}
