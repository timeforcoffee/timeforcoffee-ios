//
//  TFCStations.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 25.02.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation

public class TFCStations: NSObject, TFCLocationManagerDelegate, APIControllerProtocol {

    private weak var delegate: TFCStationsUpdatedProtocol?

    var stations:[TFCStation]? {
        get {

            if  let nearbyFavorites = nearbyFavorites {
                if let _stations = _stations {
                    return nearbyFavorites + _stations
                }
                return nearbyFavorites
            }
            return _stations
        }
    }

    private var _stations:[TFCStation]?
    private var nearbyFavorites:[TFCStation]?
    private var inStationsArrayAsFavorite: [String: Bool] = [:]

    //struct here, because "class var" is not yet supported
    private struct favorite {
        static var s: TFCFavorites = TFCFavorites.sharedInstance
        static var userDefaults: NSUserDefaults? = TFCDataStore.sharedInstance.getUserDefaults()
    }

    public var networkErrorMsg: String?
    public var loadingMessage: String?
    public var isLoading: Bool = false {
        didSet { if (isLoading == true) {
                self.networkErrorMsg = nil
                self.loadingMessage = nil
            }
        }
    }
    private var lastRefreshLocation: NSDate?

    private lazy var locManager: TFCLocationManager? = { return TFCLocationManager(delegate: self)}()
    private lazy var api : APIController = { return APIController(delegate: self)}()

    public override init() {
        // can be removed, when everyone moved to the new way of storing favorites
        favorite.s.repopulateFavorites()
    }

    public init(delegate: TFCStationsUpdatedProtocol) {
        self.delegate = delegate
        favorite.s.repopulateFavorites()
    }

    public func count() -> Int? {
        if let stations = stations {
            return stations.count
        }
        return nil
    }

    public func empty() {
        _stations = []
        nearbyFavorites = []
    }

    public func addWithJSON(allResults: JSON) {
        // Create an empty array of Albums to append to from this list
        // Store the results in our table data array
        if allResults["stations"].array?.count>0 {
            var newStations:[TFCStation] = []
            // to prevent double entries, the api sometimes returns more than one with the same id
            var stationsAdded:[String: Bool] = [:]
            if let results = allResults["stations"].array {
                for result in results {
                    var id = String(result["id"].int!)
                    if (inStationsArrayAsFavorite[id] == nil && stationsAdded[id] == nil) {
                        var name = result["name"].string
                        var longitude: Double? = nil
                        var latitude: Double? = nil
                        if (result["coordinate"]["y"].double != nil) {
                            longitude = result["coordinate"]["y"].double
                            latitude = result["coordinate"]["x"].double
                        } else {
                            longitude = result["location"]["lng"].double
                            latitude = result["location"]["lat"].double
                        }
                        var Clocation: CLLocation?
                        if (longitude != nil && latitude != nil) {
                            Clocation = CLLocation(latitude: latitude!, longitude: longitude!)
                        }
                        var newStation = TFCStation.initWithCache(name!, id: id, coord: Clocation)
                        stationsAdded[id] = true
                        newStations.append(newStation)
                    }
                }
            }
            _stations = newStations
        }
    }

    public func getStation(index: Int) -> TFCStation? {
        if let stations = stations {
            if (index < stations.count) {
                return stations[index]
            }
        }
        return nil
    }

    class func isFavoriteStation(index: String) -> Bool {
        if (favorite.s.stations[index] != nil) {
            return true
        }
        return false
    }

    public func initWithNearbyFavorites(location: CLLocation) -> Bool {
        self.nearbyFavorites = []
        inStationsArrayAsFavorite = [:]
        var hasNearbyFavs = false
        var removeFromFavorites: [String] = []
        var favDistance = 1000.0
        if (location.horizontalAccuracy > 500.0) {
            NSLog("horizontalAccuracy > 500: \(location.horizontalAccuracy)")
            favDistance = location.horizontalAccuracy + 500.0
        }
        for (st_id, station) in favorite.s.stations {
            var distance = location.distanceFromLocation(station.coord)
            if (distance < favDistance) {
                hasNearbyFavs = true
                if (inStationsArrayAsFavorite[station.st_id] != true) {
                    station.calculatedDistance = Int(distance)
                    self.nearbyFavorites!.append(station)
                    inStationsArrayAsFavorite[station.st_id] = true
                }
            } else {
                removeFromFavorites.append(st_id)
            }
        }
        // for memory reasons...
        for (st_id) in removeFromFavorites {
            favorite.s.removeTemporarly(st_id)
        }

        if (hasNearbyFavs) {
            self.nearbyFavorites!.sort({ $0.calculatedDistance < $1.calculatedDistance })
            return true
        }
        self.nearbyFavorites = nil
        return false
    }

    public func loadFavorites() {
        loadFavorites(locManager?.currentLocation)
    }

    public func loadFavorites(location: CLLocation?) {
        self._stations = []
        TFCFavorites.sharedInstance.repopulateFavorites()
        for (st_id, station) in favorite.s.stations {
            if (location != nil) {
                let distance = Int(location?.distanceFromLocation(station.coord) as Double!)
                station.calculatedDistance = distance
            }
            self._stations?.append(station)
        }
        if (location != nil) {
            self._stations!.sort({ $0.calculatedDistance < $1.calculatedDistance })
        }
    }

    public func updateStations(searchFor:String) -> Bool {
        isLoading = true
        self.api.searchFor(searchFor)
        return true
    }

    public func updateStations() -> Bool {
        return updateStations(false)
    }

    public func updateStations(force: Bool) -> Bool {
        // dont refresh location within 5 seconds..
        if (force || lastRefreshLocation == nil || lastRefreshLocation?.timeIntervalSinceNow < -5) {
            lastRefreshLocation = NSDate()
            isLoading = true
            dispatch_async(dispatch_get_main_queue(), {
                self.locManager?.refreshLocation()
                return
            })
            return true
        }
        return false
    }

    public func locationFixed(loc: CLLocation?) {
        if let loc = loc {
            if (self.initWithNearbyFavorites(loc)) {
                self.callStationsUpdatedDelegate(nil, favoritesOnly: true)
            }
            let coord = loc.coordinate
            self.api.searchFor(coord)
        }
    }

    public func locationDenied(manager: CLLocationManager, err: NSError) {
            callStationsUpdatedDelegate("Location not available")
    }

    public func locationStillTrying(manager: CLLocationManager, err: NSError) {
            callStationsUpdatedDelegate(TFCLocationManager.k.AirplaneMode)
    }

    public func didReceiveAPIResults(results: JSON, error: NSError?, context: Any?) {
        isLoading = false
        var err: String? = nil
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            if (error != nil && error?.code != -999) {
                err =  "Network error. Please try again"
            } else {
                self.addWithJSON(results)
                if (!(self.stations?.count > 0)) {
                    err = self.getReasonForNoStationFound()
                }
            }
            self.callStationsUpdatedDelegate(err)
        }
    }

    private func callStationsUpdatedDelegate(err: String?) {
        callStationsUpdatedDelegate(err, favoritesOnly: false)
    }

    private func callStationsUpdatedDelegate(err: String?, favoritesOnly: Bool) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            if (err == TFCLocationManager.k.AirplaneMode) {
                self.loadingMessage = "Airplane Mode?"
            } else {
                if (!(self.stations?.count > 0)) {
                    self.empty()
                }
                self.networkErrorMsg = err
            }
            if let dele = self.delegate {
                dele.stationsUpdated(self.networkErrorMsg, favoritesOnly: favoritesOnly)
            }
        }
    }

    private func getReasonForNoStationFound() -> String? {

        if let distanceFromSwitzerland = locManager?.currentLocation?.distanceFromLocation(CLLocation(latitude: 47, longitude: 8)) {
            if (distanceFromSwitzerland > 1000000) {
                return "Not in Switzerland?"
            }
        }

        return nil

    }
    

}

public protocol TFCStationsUpdatedProtocol: class {
    func stationsUpdated(error: String?, favoritesOnly: Bool)
}
