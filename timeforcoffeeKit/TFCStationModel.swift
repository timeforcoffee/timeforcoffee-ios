//
//  TFCStationModel.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 09.10.15.
//  Copyright © 2015 opendata.ch. All rights reserved.
//

import Foundation
import CoreData

class TFCStationModel: NSManagedObject {

// Insert code here to add functionality to your managed object subclass

    internal func save() {
     /*   if (self.objectID.temporaryID) {
            let privateMOC = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
            privateMOC.parentContext = TFCDataStore.sharedInstance.managedObjectContext

            privateMOC.performBlock({ () -> Void in
                do {
                    try privateMOC.save()
                } catch {
                    fatalError("Failure to save context: \(error)")
                }
            })
        }*/
    }
}
