//
//  InterfaceController.swift
//  Time for Coffee! WatchKit Extension
//
//  Created by Christian Stocker on 02.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import WatchKit
import Foundation
import timeforcoffeeKit


class StationViewController: WKInterfaceController {
    @IBOutlet weak var stationsTable: WKInterfaceTable!
    var stationName: String = ""
    var stationId: String = ""
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
            stationId = contextDict["st_id"] as String
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
            /*if (stationsTable.numberOfRows != replyInfo.count) {
                //not sure why this is even needed.... and it doesn't fix an issue I have with updating
                if (stationsTable.numberOfRows > 0) {
                    stationsTable.removeRowsAtIndexes(NSIndexSet(indexesInRange: NSMakeRange(0, stationsTable.numberOfRows - 1)))
                }
                stationsTable.setNumberOfRows(replyInfo.count, withRowType: "station")
            } */
            let departures:[NSDictionary] = replyInfo["departures"] as [NSDictionary]
            stationsTable.setNumberOfRows(departures.count, withRowType: "station")
            println(replyInfo);
            for (station) in departures {
                let sr = stationsTable.rowControllerAtIndex(i) as StationRow?
                println(station["name"])
                let to = station["to"] as String
                let name = station["name"] as String
                // doesn't work yet  with the font;(
                let helvetica = UIFont(name: "HelveticaNeue-Bold", size: 18.0)!
                var fontAttrs = [NSFontAttributeName : helvetica]
                var attrString = NSAttributedString(string: name, attributes: fontAttrs)
                sr?.numberLabel.setAttributedText(attrString)
                sr?.destinationLabel.setText(to)
                sr?.numberGroup.setBackgroundColor(UIColor(netHexString:(station["colorBg"] as String)))
                sr?.numberLabel.setTextColor(UIColor(netHexString:(station["colorFg"] as String)))
                i++
            }
        }
        WKInterfaceController.openParentApplication(["module":"departures", "st_id": stationId, "st_name": stationName], handleReply)
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    
    
}
