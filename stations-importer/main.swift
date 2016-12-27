//
//  main.swift
//  stations-importer
//
//  Created by Christian Stocker on 10.10.15.
//  Copyright © 2015 opendata.ch. All rights reserved.
//

/* This is a very ugly "script" to import the station data from
   https://opentransportdata.swiss/dataset/695c7af6-d486-4cde-9bf0-a92fdd581a4e/resource/b92a372f-7843-4ddd-b1c6-c9c6397e1097/download/bfkoordgeo.csv
   with it's geolocation and then
   reverse lookup those coordinates to store, in which country
   and county those stations are. So that we later can query the
   correct source (currently it's about getting data from 
   transport.opendata.ch for stations not in switzerland)
*/

import Foundation
import CoreData
let doReadImportFile = true
let StationsPlainTextFile = "/opt/git/timeforcoffee/stations-importer/bfkoordgeo.csv"

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
            let station = line.componentsSeparatedByString(",")


            //let csv = CS

            let id = station[0].replace("^0*", template: "")
            if (id == "StationID") {
                continue;
            }
            let obj = getCDObject(id)
            let lon = Double(station[1])
            if (lon != obj.longitude) {
                obj.longitude = lon
                obj.countryISO = nil
                obj.lastUpdated = NSDate()
            }
            let lat = Double(station[2])
            if (lat != obj.latitude) {
                obj.latitude = lat
                obj.countryISO = nil
                obj.lastUpdated = NSDate()
            }
            let name = (station.suffix(station.count - 4)).joinWithSeparator(",").stringByTrimmingCharactersInSet(
                NSCharacterSet.whitespaceAndNewlineCharacterSet()
            ).stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "\""))
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
        } else {
            NSLog("try again from start")
            doUpdateGeolocations()
        }
    } else {
        exit(0)
    }
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
            } else {
                exit(0)
            }
        } else {
            exit(244)
        }
    } catch let error as NSError {
        print("Could not fetch \(error), \(error.userInfo)")
    }
}

doUpdateGeolocations()

CFRunLoopRun()



NSBundle.mainBundle().bundlePath
