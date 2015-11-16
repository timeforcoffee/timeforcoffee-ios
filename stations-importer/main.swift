//
//  main.swift
//  stations-importer
//
//  Created by Christian Stocker on 10.10.15.
//  Copyright © 2015 opendata.ch. All rights reserved.
//

/* This is a very ugly "script" to import the station data from
   http://www.fahrplanfelder.ch/ with it's geolocation and then
   reverse lookup those coordinates to store, in which country
   and county those stations are. So that we later can query the
   correct source (currently it's about getting data from 
   transport.opendata.ch for stations not in switzerland)
*/

import Foundation
import CoreData
let doReadImportFile = true
let StationsPlainTextFile = "/opt/git/timeforcoffee/stations-importer/BFKOORD_GEO"

func getPart(line: String, start: Int, end: Int) -> String {
    let part:String
    if (end > 0) {
        part = line.substringWithRange(Range<String.Index>(start: line.startIndex.advancedBy(start), end: line.startIndex.advancedBy(end)))
    } else {
        part = line.substringWithRange(Range<String.Index>(start: line.startIndex.advancedBy(start), end: line.endIndex.advancedBy(end)))
    }
    return part.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
}

if (doReadImportFile) {
    if let aStreamReader = StreamReader(path: StationsPlainTextFile) {
        defer {
            aStreamReader.close()
        }
        while let line = aStreamReader.nextLine() {
            print(line)
            let id = getPart(line, start: 0, end: 8).replace("^0*", template: "")
            let obj = getCDObject(id)
            let lon = Double(getPart(line, start: 8, end: 19))
            if (lon != obj.longitude) {
                obj.longitude = lon
                obj.countryISO = nil
                obj.lastUpdated = NSDate()
            }
            let lat = Double(getPart(line, start: 19, end: 30))
            if (lat != obj.latitude) {
                obj.latitude = lat
                obj.countryISO = nil
                obj.lastUpdated = NSDate()
            }
            let name = getPart(line, start: 39, end: 0)
            if (name != obj.name) {
                obj.name = name
                obj.lastUpdated = NSDate()
            }
            saveContext()

        }
    }

}


func processFirst(var results: [TFCStationModel]?) {
    if results?.count > 0 {
        if let first = results?.removeFirst() {
            updateGeolocationInfo(first, callback: {processFirst(results)})
        }
    }
    //try again from start
    NSLog("try again from start")
    doUpdateGeolocations()

}
func doUpdateGeolocations() {
    let fetchRequest = NSFetchRequest(entityName: "TFCStationModel")
    do {
        let pred = NSPredicate(format: "countryISO == NIL")
        fetchRequest.predicate = pred
        if let results = try TFCDataStore.sharedInstance.managedObjectContext.executeFetchRequest(fetchRequest) as? [TFCStationModel] {
            NSLog("Found \(results.count) without geolocation info")
            if (results.count > 0) {
                processFirst(results)
            }
        }
        exit(0)
    } catch let error as NSError {
        print("Could not fetch \(error), \(error.userInfo)")
    }
}

doUpdateGeolocations()

CFRunLoopRun()



NSBundle.mainBundle().bundlePath