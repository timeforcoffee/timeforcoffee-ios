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
    private var idsWereTrimmed = false

    override init() {
        super.init()
    }

    func repopulateFavorites() {
        temporarlyRemovedStations = false
        self.stations = getCurrentFavoritesFromDefaults()
        //the following trimmed can be removed later, maybe in 1.7 or so (needed in 1.5)
        if (idsWereTrimmed) {
            saveFavorites()
            idsWereTrimmed = false
        }
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
            st = NSKeyedUnarchiver.unarchiveObjectWithData(unarchivedObject) as? [String: TFCStation]
        }
        let cache = TFCCache.objects.stations
        if (st != nil) {
            // get if from the cache, if it's already there.
            for (st_id, _) in st! {
                // trim id since we sometimes saved this wrong

                let trimmed_id = st_id.replace("^0*", template: "")
                if (trimmed_id != st_id) {
                    NSLog("Trim favourite ID \(st_id)")
                    st![trimmed_id] = st![st_id]
                    st![trimmed_id]!.st_id = trimmed_id
                    st!.removeValueForKey(st_id)
                    idsWereTrimmed = true
                }
                let newStation: TFCStation? = cache.objectForKey(trimmed_id) as? TFCStation
                if (newStation != nil && newStation?.coord != nil) {
                    st![trimmed_id] = newStation
                }
            }
            return st!
        } else {
            return [:]
        }
    }

    func removeTemporarly(st_id: String) {
        temporarlyRemovedStations = true
        stations.removeValueForKey(st_id)
    }

    func unset(st_id: String?) {
        if (st_id == nil) {
            return
        }
        if (temporarlyRemovedStations) {
            repopulateFavorites()
        }
        stations.removeValueForKey(st_id!)
        self.saveFavorites()
    }

    func unset(station station: TFCStation?) {
        unset(station?.st_id)
    }

    func set(station: TFCStation?) {
        if (station != nil) {
            if (temporarlyRemovedStations) {
                repopulateFavorites()
            }
            stations[(station?.st_id)!] = station!
            self.saveFavorites()
        }
    }

    func isFavorite(st_id: String?) -> Bool {
        if (st_id != nil) {
            if (self.stations[st_id!] != nil) {
                let res: Bool? = (self.stations[st_id!]! as TFCStation).isFavorite()

                if (res != nil || res == true) {
                    return true
                }
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