//
//  GlanceController.swift
//  Time for Coffee! WatchKit Extension
//
//  Created by Christian Stocker on 02.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import WatchKit
import Foundation
import timeforcoffeeKit


class GlanceController: WKInterfaceController, APIControllerProtocol {
    
    @IBOutlet weak var minutesLabel: WKInterfaceLabel!
    @IBOutlet weak var destinationLabel: WKInterfaceLabel!
    @IBOutlet weak var numberGroup: WKInterfaceGroup!
    @IBOutlet weak var depatureLabel: WKInterfaceLabel!
    @IBOutlet weak var numberLabel: WKInterfaceLabel!
    
    lazy var stations: TFCStations? =  {return TFCStations()}()
    lazy var api : APIController? = {
        [unowned self] in
        return APIController(delegate: self)
        }()
    var networkErrorMsg: String?
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
        println("are we here??")
    }
    
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        
        super.willActivate()
        func handleReply(replyInfo: [NSObject : AnyObject]!, error: NSError!) {
            if(replyInfo["lat"] != nil) {
                let loc = CLLocation(latitude: replyInfo["lat"] as Double, longitude: replyInfo["long"] as Double)
                self.stations?.clear()
                self.stations?.addNearbyFavorites(loc)
                //todo only ask for one station
                self.api?.searchFor(loc.coordinate)
            }
        }
        WKInterfaceController.openParentApplication(["module":"location"], handleReply)
        
        minutesLabel.setText("6'")
        destinationLabel.setText("Röntgenstrasse");
        depatureLabel.setText("In 6' / 16:59");
        numberLabel.setText("12")
        numberLabel.setTextColor(UIColor.whiteColor())
        numberGroup.setBackgroundColor(UIColor.greenColor())
        
    }
    
    func didReceiveAPIResults(results: JSONValue, error: NSError?, context: Any?) {
        if (!(error != nil && error?.code == -999)) {
            if (error != nil) {
                self.networkErrorMsg = NSLocalizedString("Network error. Please try again", comment: "")
            } else {
                self.networkErrorMsg = nil
            }
            if (TFCStation.isStations(results)) {
                self.stations?.addWithJSON(results, append: true)
                var pages = [String]()
                var pageContexts = [AnyObject]()
                for (station) in self.stations! {
                    
                    station.removeObseleteDepartures()
                    let departures = station.getDepartures()
                    if(departures?.count > 0) {
                        //todo only ask for one depature
                        if let firstDepature = departures?[0] {
                            let to = firstDepature.getDestination(station)
                            
                            minutesLabel.setText(firstDepature.getMinutes())
                            destinationLabel.setText(to);
                            depatureLabel.setText(firstDepature.getTimeString());
                            numberLabel.setText(firstDepature.getLine())
                            numberLabel.setTextColor(UIColor(netHexString:(firstDepature.colorFg)!))
                            numberGroup.setBackgroundColor(UIColor(netHexString:(firstDepature.colorBg)!))
                            
                            println("\(to)")
                        }
                    }
                }
            }
        }
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
}
