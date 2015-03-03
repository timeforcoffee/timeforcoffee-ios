//
//  InterfaceController.swift
//  Time for Coffee! WatchKit Extension
//
//  Created by Christian Stocker on 02.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import WatchKit
import Foundation


class StationViewController: WKInterfaceController {
    @IBOutlet weak var stationsTable: WKInterfaceTable!
    var stationName: String = ""
    var data2: Int = 1
    var stationInfo: AnyObject?
    
    override init () {
        super.init()
        println("init page")
        
    }
    override func awakeWithContext(context: AnyObject?) {
      super.awakeWithContext(context)
        
        if let contextDict:Dictionary = context as Dictionary<String,AnyObject>!
        {
            stationInfo = contextDict
            
            stationName = contextDict["name"] as String
        }
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        println("willActivate")
        self.setTitle(stationName)
        func handleReply(replyInfo: [NSObject : AnyObject]!, error: NSError!) {
            var i = 0;
            stationsTable.setNumberOfRows(replyInfo.count, withRowType: "station")
            println(replyInfo);
            for (st_id, station) in replyInfo {
                let sr = stationsTable.rowControllerAtIndex(i) as StationRow?
                
                println(station["name"])
                let name = station["name"] as String
                sr?.destinationLabel.setText(name)
                let helvetica = UIFont(name: "HelveticaNeue-Bold", size: 18.0)!
                var fontAttrs = [NSFontAttributeName : helvetica]
                var attrString = NSAttributedString(string: "12", attributes: fontAttrs)
                
                // Set the text on the label object
            
                sr?.numberLabel.setAttributedText(attrString)

                
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
