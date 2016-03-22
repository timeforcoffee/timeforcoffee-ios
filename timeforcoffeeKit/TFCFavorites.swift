//
//  TFCFaforites.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 20.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation

final public class TFCFavorites: NSObject {

    public class var sharedInstance: TFCFavorites {
        struct Static {
            static let instance: TFCFavorites = TFCFavorites()
        }
        return Static.instance
    }

    lazy var stations: [String: TFCStation] = { [unowned self] in
        return self.getCurrentFavoritesFromDefaults()
        }()
    
    private struct objects {
        static let  dataStore: TFCDataStore? = TFCDataStore()
    }

    private var temporarlyRemovedStations = false
    private var needsSave = false

    override init() {
        super.init()
    }

    func repopulateFavorites() {
        temporarlyRemovedStations = false
        self.stations = getCurrentFavoritesFromDefaults()
    }

    public func getSearchRadius() -> Int {
        var favoritesSearchRadius =
        TFCDataStore.sharedInstance.getUserDefaults()?.integerForKey("favoritesSearchRadius")

        if (favoritesSearchRadius == nil || favoritesSearchRadius == 0) {
            favoritesSearchRadius = 1000
        }
        return favoritesSearchRadius!
    }

    private func getCurrentFavoritesFromDefaults() -> [String: TFCStation] {
        var st: [String: TFCStation]?
        if let unarchivedObject = objects.dataStore?.objectForKey("favorites2") as? NSData {
            NSKeyedUnarchiver.setClass(TFCStation.classForKeyedUnarchiver(), forClassName: "timeforcoffeeKit.TFCStation")
            NSKeyedUnarchiver.setClass(TFCStation.classForKeyedUnarchiver(), forClassName: "timeforcoffeeWatchKit.TFCStation")
            NSKeyedUnarchiver.setClass(TFCStation.classForKeyedUnarchiver(), forClassName: "Time_for_Coffee__WatchOS_2_App_Extension.TFCStation")
            st = NSKeyedUnarchiver.unarchiveObjectWithData(unarchivedObject) as? [String: TFCStation]
        }
        let cache = TFCCache.objects.stations
        guard st != nil else { return [:] }
        // get if from the cache, if it's already there.
        for (st_id, _) in st! {
            // trim id since we sometimes saved this wrong

            let trimmed_id = st_id.replace("^0*", template: "")
            if (trimmed_id != st_id) {
                DLog("Trim favourite ID \(st_id)")
                st![trimmed_id] = st![st_id]
                st![trimmed_id]?.st_id = trimmed_id
                st!.removeValueForKey(st_id)
                needsSave = true
            }
            var newStation: TFCStation? = cache.objectForKey(trimmed_id) as? TFCStation
            if (newStation?.name == "unknown") {
                newStation = TFCStation.initWithCacheId(trimmed_id)
                needsSave = true
            }
            if (newStation != nil && newStation?.coord != nil) {
                st![trimmed_id] = newStation
            }
        }
        return st!

    }

    func removeTemporarly(st_id: String) {
        temporarlyRemovedStations = true
        stations.removeValueForKey(st_id)
    }

    func unset(st_id: String?) {
        if let st_id = st_id {
            if (temporarlyRemovedStations) {
                repopulateFavorites()
            }
            stations.removeValueForKey(st_id)
            self.saveFavorites()
        }
    }

    func unset(station station: TFCStation?) {
        unset(station?.st_id)
    }

    func set(station: TFCStation?) {
        if let station = station {
            if (temporarlyRemovedStations) {
                repopulateFavorites()
            }
            stations[station.st_id] = station
            self.saveFavorites()
        }
    }

    func isFavorite(st_id: String?) -> Bool {
        if let st_id = st_id, station = self.stations[st_id] {
            if (station.isFavorite() == true) {
                return true
            }
        }
        return false
    }


    private func saveFavorites() {
        for (_, station) in stations {
            station.serializeDepartures = false
        }
        let archivedFavorites = NSKeyedArchiver.archivedDataWithRootObject(stations)
        for (_, station) in stations {
            station.serializeDepartures = true
            //make sure all favorites are indexed
            station.setStationSearchIndex()
        }
        objects.dataStore?.setObject(archivedFavorites , forKey: "favorites2")
    }

}

extension Array {
    //  stations.find{($0 as TFCStation).st_id == st_id}
    func indexOf(includedElement: Element -> Bool) -> Int? {
        for (idx, element) in self.enumerate() {
            if includedElement(element) {
                return idx
            }
        }
        return nil
    }

    func getObject(includedElement: Element -> Bool) -> Element? {
        for (_, element) in self.enumerate() {
            if includedElement(element) {
                return element
            }
        }
        return nil
    }
}