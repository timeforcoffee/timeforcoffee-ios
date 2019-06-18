//
//  IntentHandler.swift
//  NextDeparturesIntent
//
//  Created by Christian Stocker on 21.09.18.
//  Copyright © 2018 opendata.ch. All rights reserved.
//

import Intents
import timeforcoffeeKit
@available(iOSApplicationExtension 12.0, *)
class IntentHandler: INExtension {
    
    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.
        if intent is NextDeparturesIntent  {
            return NextDeparturesIntentHandler()
        }
        if intent is ClipboardIntent  {
            return ClipboardIntentHandler()
        }
        if intent is GetStationIntent  {
            return GetStationIntentHandler()
        }
        
        fatalError("Unhandled intent type: \(intent)")

    }
    
}
