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
    var stations:[TFCStation]?

    //struct here, because "class var" is not yet supported
    private struct favorite {
        static var s: TFCFavorites = TFCFavorites.sharedInstance
        static var inStationsArray: [String: Bool] = [:]
        static var userDefaults: NSUserDefaults? = TFCDataStore.sharedInstance.getUserDefaults()
    }

    public var networkErrorMsg: String?
    public var isLoading: Bool = false {
        didSet { if (isLoading == true) {
                self.networkErrorMsg = nil
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
        if (stations == nil) {
            return nil
        }
        return stations!.count
    }

    public func clear() {
        stations = nil
    }
    public func empty() {
        stations = []
    }

    public func addWithJSON(allResults: JSONValue) {
        addWithJSON(allResults, append: false)
    }

    public func addWithJSON(allResults: JSONValue, append: Bool) {
        if (!append || stations == nil) {
            stations = []
            favorite.inStationsArray = [:]
        }
        // Create an empty array of Albums to append to from this list
        // Store the results in our table data array
        if allResults["stations"].array?.count>0 {
            if let results = allResults["stations"].array {
                for result in results {
                    var id = String(result["id"].integer!)
                    if (favorite.inStationsArray[id] == nil) {
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
                        stations!.append(newStation)
                    }
                }
            }
        }
    }

    public func getStation(index: Int) -> TFCStation {
        if (stations == nil || index + 1 > stations!.count) {
            return TFCStation()
        }
        return stations![index]
    }

    class func isFavoriteStation(index: String) -> Bool {
        if (favorite.s.stations[index] != nil) {
            return true
        }
        return false
    }

    public func addNearbyFavorites(location: CLLocation) -> Bool {
        if (self.stations == nil) {
            self.stations = []
            favorite.inStationsArray = [:]
        }
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
                if (favorite.inStationsArray[station.st_id] != true) {
                    station.calculatedDistance = Int(distance)
                    self.stations!.append(station)
                    favorite.inStationsArray[station.st_id] = true
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
            self.stations!.sort({ $0.calculatedDistance < $1.calculatedDistance })
            return true
        }
        return false
    }

    public func loadFavorites() {
        loadFavorites(locManager?.currentLocation)
    }

    public func loadFavorites(location: CLLocation?) {
        self.stations = []
        for (st_id, station) in favorite.s.stations {
            if (location != nil) {
                let distance = Int(location?.distanceFromLocation(station.coord) as Double!)
                station.calculatedDistance = distance
            }
            self.stations?.append(station)
        }
        if (location != nil) {
            self.stations!.sort({ $0.calculatedDistance < $1.calculatedDistance })
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

    public func locationFixed(coord: CLLocationCoordinate2D?) {
        if (coord != nil) {
            self.addNearbyFavorites((locManager?.currentLocation)!)
            self.api.searchFor(coord!)
        }
    }

    public func locationDenied(manager: CLLocationManager) {
        replyCompletion("Location not available")
    }

    public func didReceiveAPIResults(results: JSONValue, error: NSError?, context: Any?) {
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
            self.replyCompletion(err)
        }
    }

    private func replyCompletion(err: String?) {
        if (!(self.stations?.count > 0)) {
            self.empty()
        }
        self.networkErrorMsg = err
        if let dele = self.delegate {
            dele.stationsUpdated(self.networkErrorMsg, favoritesOnly: false)
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
