//
//  data.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 10.10.15.
//  Copyright © 2015 opendata.ch. All rights reserved.
//

import Foundation
import CoreData
import CoreLocation

func delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}

public class TFCDataStore: NSObject {

    public class var sharedInstance: TFCDataStore {
        struct Static {
            static let instance: TFCDataStore = TFCDataStore()
        }
        return Static.instance
    }

    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "ch.opendata.timeforcoffee.timeforcoffee" in the application's documents Application Support directory.
        return NSURL(fileURLWithPath: "/opt/git/tramboard-clj/", isDirectory: true)
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
        }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.

        //    NSBundle(forClass: TFCDataStore.self)
        let modelURL = NSBundle(forClass: TFCDataStore.self).URLForResource("DataModels", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
        }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("stations.sqlite")
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason

            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort()
        }

        return coordinator
        }()

    lazy public var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
        }()

    // MARK: - Core Data Saving support
}

func getCDObject(id: String) -> TFCStationModel {

    let fetchRequest = NSFetchRequest(entityName: "TFCStationModel")
    do {
        let pred = NSPredicate(format: "id == %@", id)
        fetchRequest.predicate = pred
        if let results = try TFCDataStore.sharedInstance.managedObjectContext.executeFetchRequest(fetchRequest) as? [TFCStationModel] {
            if let first = results.first {
                return first
            }
        }
    } catch let error as NSError {
        print("Could not fetch \(error), \(error.userInfo)")
    }

    let obj = NSEntityDescription.insertNewObjectForEntityForName("TFCStationModel", inManagedObjectContext: TFCDataStore.sharedInstance.managedObjectContext) as! TFCStationModel
    obj.id = id
    return obj
}

func saveContext () {
    if TFCDataStore.sharedInstance.managedObjectContext.hasChanges {
        do {
            try TFCDataStore.sharedInstance.managedObjectContext.save()

        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nserror = error as NSError
            NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
            abort()
        }
    }
}

func updateGeolocationInfo(realmObject: TFCStationModel, callback: () -> Void) {
    let iso = realmObject.countryISO
    if (iso == nil) {
        let geocoder = CLGeocoder()
        if (realmObject.latitude == nil) {
            print ("nil")
            delay(0.2, closure: callback)
            return
        }
        let coordinates = CLLocation(latitude: Double(realmObject.latitude!), longitude: Double(realmObject.longitude!))

        geocoder.reverseGeocodeLocation(coordinates) { (places:[CLPlacemark]?, error:NSError?) -> Void in
            if let place = places?.first {
                if let iso = place.ISOcountryCode {
                    realmObject.countryISO = iso
                    print("\(realmObject.name) is \(iso)")
                }
                if let city = place.locality {
                    realmObject.city = city
                }

                if let county = place.administrativeArea {
                    realmObject.county = county
                }
                realmObject.lastUpdated = NSDate()
                saveContext()
                delay(1.2, closure: callback)
            } else {
                if (error != nil) {
                    NSLog("\(realmObject.name) error getting Location: \(error!.userInfo)")
                    delay(10.0, closure: callback)
                }
            }

        }
    }
}



struct Regex {
    var pattern: String {
        didSet {
            updateRegex()
        }
    }
    var expressionOptions: NSRegularExpressionOptions {
        didSet {
            updateRegex()
        }
    }
    var matchingOptions: NSMatchingOptions

    var regex: NSRegularExpression?

    init(pattern: String, expressionOptions: NSRegularExpressionOptions, matchingOptions: NSMatchingOptions) {
        self.pattern = pattern
        self.expressionOptions = expressionOptions
        self.matchingOptions = matchingOptions
        updateRegex()
    }

    init(pattern: String) {
        self.pattern = pattern
        expressionOptions = NSRegularExpressionOptions(rawValue: 0)
        matchingOptions = NSMatchingOptions(rawValue: 0)
        updateRegex()
    }

    mutating func updateRegex() {
        do {
            regex = try NSRegularExpression(pattern: pattern, options: expressionOptions)
        } catch _ {
            regex = nil
        }
    }
}


extension String {
    func matchRegex(pattern: Regex) -> Bool {
        let range: NSRange = NSMakeRange(0, self.characters.count)
        if pattern.regex != nil {
            let matches: [AnyObject] = pattern.regex!.matchesInString(self, options: pattern.matchingOptions, range: range)
            return matches.count > 0
        }
        return false
    }

    func match(patternString: String) -> Bool {
        return self.matchRegex(Regex(pattern: patternString))
    }

    func replaceRegex(pattern: Regex, template: String) -> String {
        if self.matchRegex(pattern) {
            let range: NSRange = NSMakeRange(0, self.characters.count)
            if pattern.regex != nil {
                return pattern.regex!.stringByReplacingMatchesInString(self, options: pattern.matchingOptions, range: range, withTemplate: template)
            }
        }
        return self
    }

    func replace(pattern: String, template: String) -> String {
        return self.replaceRegex(Regex(pattern: pattern), template: template)
    }
}

extension Double {
    /// Rounds the double to decimal places value
    func roundToPlaces(places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return round(self * divisor) / divisor
    }
}
