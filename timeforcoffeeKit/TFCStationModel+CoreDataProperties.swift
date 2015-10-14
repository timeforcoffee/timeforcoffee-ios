//
//  TFCStationModel+CoreDataProperties.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 09.10.15.
//  Copyright © 2015 opendata.ch. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension TFCStationModel {

    @NSManaged var name: String
    @NSManaged var latitude: NSNumber?
    @NSManaged var longitude: NSNumber?
    @NSManaged var countryISO: String?
    @NSManaged var lastUpdated: NSDate?
    @NSManaged var id: String
    @NSManaged var city: String?
    @NSManaged var county: String?
    @NSManaged var departuresURL: String?
    @NSManaged var apiKey: String?
    @NSManaged var apiId: String?

}
