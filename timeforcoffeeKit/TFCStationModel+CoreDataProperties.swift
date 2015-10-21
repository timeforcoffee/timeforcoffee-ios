//
//  TFCStationModel+CoreDataProperties.swift
//  
//
//  Created by Christian Stocker on 14.10.15.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension TFCStationModel {

    @NSManaged var city: String?
    @NSManaged var countryISO: String?
    @NSManaged var county: String?
    @NSManaged var departuresURL: String?
    @NSManaged var id: String?
    @NSManaged var lastUpdated: NSDate?
    @NSManaged var latitude: NSNumber?
    @NSManaged var longitude: NSNumber?
    @NSManaged var name: String
    @NSManaged var apiKey: String?
    @NSManaged var apiId: String?

}
