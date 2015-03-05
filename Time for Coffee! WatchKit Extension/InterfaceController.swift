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
        println("willactivate")
        func handleReply(replyInfo: [NSObject : AnyObject]!, error: NSError!) {
            println("replyinfo \(replyInfo)")
            if (replyInfo != nil) {
                var pages = [String]()
                var pageContexts = [AnyObject]()
                for (st_id, station) in replyInfo {
                    
                    pages.append("StationPage");
                    pageContexts.append(station)
                }
                
                WKInterfaceController.reloadRootControllersWithNames(pages, contexts: pageContexts)
            }
        }
        
        WKInterfaceController.openParentApplication(["module":"nearby"], handleReply)

    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    

}
