//
//  TFCStations.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 25.02.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation
import WatchConnectivity
import CoreData
import MapKit

public final class TFCStations: NSObject, TFCLocationManagerDelegate, APIControllerProtocol {

    private weak var delegate: TFCStationsUpdatedProtocol?

    private var _stations:TFCStationCollection = TFCStationCollection()
    private var nearbyFavorites:TFCStationCollection = TFCStationCollection()
    private var inStationsArrayAsFavorite: [String: Bool] = [:]
    private var maxStations:Int = 100

    //struct here, because "class var" is not yet supported
    private struct favorite {
        static var s: TFCFavorites = TFCFavorites.sharedInstance
        static var userDefaults: NSUserDefaults? = TFCDataStore.sharedInstance.getUserDefaults()
    }

    private var lastFirstStationId:String? = nil
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

    public init(delegate: TFCStationsUpdatedProtocol, maxStations: Int = 100) {
        self.delegate = delegate
        self.maxStations = maxStations
        favorite.s.repopulateFavorites()
    }

    public func count() -> Int? {
        return nearbyFavorites.count + _stations.count
    }

    public func empty() {
        _stations.empty()
        nearbyFavorites.empty()
    }

    public func getNearbyFavoriteIds() -> [String] {
        return nearbyFavorites.getStationIds()
    }

    public func getNearbyNonFavoriteIds() -> [String] {
        return _stations.getStationIds()
    }

    public func addWithJSON(allResults: JSON?) {
        // Create an empty array of Albums to append to from this list
        // Store the results in our table data array
        if (allResults != nil && allResults?["stations"].array?.count>0) {
            var newStations:[TFCStation] = []
            // to prevent double entries, the api sometimes returns more than one with the same id
            var stationsAdded:[String: Int] = [:]
            if let results = allResults?["stations"].array {
                var results2:[JSON] = []
                // First filter out all double entries (multiple entries for same stationy
                for result in results {
                    let id = String(result["id"].stringValue)
                    if let name = result["name"].string {
                        // the DB has all the uppercased short Strings as well, we don't want to display them
                        // just don't add them
                        if (name == name.uppercaseString) {
                            continue
                        }
                        if (inStationsArrayAsFavorite[id] == nil && (stationsAdded[id] == nil || stationsAdded[id] < name.characters.count)) {
                            // if we have a station with the same id but shorter name, remove it
                            // eg. Rappi
                            if (stationsAdded[id] < name.characters.count) {
                                if let i = results2.indexOf({$0["id"].stringValue == id}) {
                                    results2.removeAtIndex(i)
                                }
                            }

                            stationsAdded[id] = name.characters.count
                            results2.append(result)
                        }
                    }
                }

                for result in results2 {
                    let id = String(result["id"].stringValue).replace("^0*", template: "")
                    let name = result["name"].string
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
                    if let name = name {
                        let newStation = TFCStation.initWithCacheId(id, name: name, coord: Clocation)
                        newStations.append(newStation)
                    }
                }
            }
            _stations.replace(newStations)
        }
    }

    public func getStation(index: Int) -> TFCStation? {
        let nearbyFavoritesCount = nearbyFavorites.count
        if index < nearbyFavoritesCount {
            return nearbyFavorites[index]
        }
        let stationCount = _stations.count

        if index < nearbyFavoritesCount + stationCount {
            return _stations[index - nearbyFavoritesCount]
        }
        return nil
    }

    class func isFavoriteStation(index: String) -> Bool {
        if (favorite.s.stations.indexOf(index) != nil) {
            return true
        }
        return false
    }

    public func initWithNearbyFavorites(location: CLLocation) -> Bool {
//        self._stations.empty()

        inStationsArrayAsFavorite = [:]
        var hasNearbyFavs = false
        var removeFromFavorites: [String] = []
        var favDistance = Double(TFCFavorites.sharedInstance.getSearchRadius())
        if (location.horizontalAccuracy > favDistance - 500.0) {
            DLog("horizontalAccuracy > \(favDistance - 500.0): \(location.horizontalAccuracy)")
            favDistance = location.horizontalAccuracy + 500.0
        }
        favorite.s.repopulateFavorites()
        var favs:[TFCStation] = []
        for (station) in favorite.s.stations {
            if (station.calculatedDistance < favDistance) {
                hasNearbyFavs = true
                if (inStationsArrayAsFavorite[station.st_id] != true) {
                    favs.append(station)
                    inStationsArrayAsFavorite[station.st_id] = true
                }
            } else {
                removeFromFavorites.append(station.st_id)
            }
        }

        if (hasNearbyFavs) {
            favs.sortInPlace({ $0.calculatedDistance < $1.calculatedDistance })
            self.nearbyFavorites.replace(favs)
            return true
        }
        self.nearbyFavorites.empty()
        return false
    }

    public func loadFavorites() {
        loadFavorites(locManager?.currentLocation)
    }

    public func loadFavorites(location: CLLocation?) {
        self._stations.empty()
        TFCFavorites.sharedInstance.repopulateFavorites()
        self._stations = favorite.s.stations

        if (location != nil) {
            self._stations.sortInPlace({ $0.calculatedDistance < $1.calculatedDistance })
        }
        #if os(iOS)
            DLog("just before updateGeofences", toFile:true)
            TFCFavorites.sharedInstance.updateGeofences(force: false)
        #endif
    }

    public func updateStations(searchFor searchFor: String) -> Bool {
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
            if (TFCLocationManager.getISOCountry() == "CH") {
                self.searchForStationsInDB(coord)
            } else {
                self.api.searchFor(coord)
            }
        }
    }

    public func locationDenied(manager: CLLocationManager, err: NSError) {
            callStationsUpdatedDelegate("Location not available")
    }

    public func locationStillTrying(manager: CLLocationManager, err: NSError) {
            callStationsUpdatedDelegate(TFCLocationManager.k.AirplaneMode)
    }

    public func searchForStationsInDB(coord: CLLocationCoordinate2D, distance: Double = 1500.0, context: Any? = nil) {

        var err:String?

        let ids = getStationIdsForCoord(coord, distance: distance)

        if (ids.count < 8 && distance < 50000) {
            return searchForStationsInDB(coord, distance: distance * 2, context: context)
        }

        var stations = ids
            //remove stations already in the last as favorite
            .filter({(id:String) in
                if (inStationsArrayAsFavorite[id] == nil) {
                    return true
                }
                return false
            })
            //map the id to the actuall station object
            .map({(id: String) -> TFCStation in
                return TFCStation.initWithCacheId(id)

            })
            //remove stations not within distance
            .filter({(station: TFCStation) in
                if (station.calculatedDistance > distance) {
                    return false
                }
                return true
            })
        //sort by distance
        stations.sortInPlace({ $0.calculatedDistance < $1.calculatedDistance })

        self._stations.replace(Array(stations.prefix(self.maxStations))) //only add max stations

        if (!(self._stations.count > 0)) {
            //this can happen, when we filter out station above, so increase the search radius
            if (distance < 50000) {
                return searchForStationsInDB(coord, distance: distance * 2, context: context)
            }
            err = self.getReasonForNoStationFound()
        }
        callStationsUpdatedDelegate(err, favoritesOnly: false, context: context)
    }

    private func getStationIdsForCoord(coord: CLLocationCoordinate2D, distance: Double) -> [String]
    {
        let region = MKCoordinateRegionMakeWithDistance(coord, distance, distance);

        let latMin = region.center.latitude - 0.5 * region.span.latitudeDelta;
        let latMax = region.center.latitude + 0.5 * region.span.latitudeDelta;
        let lonMin = region.center.longitude - 0.5 * region.span.longitudeDelta;
        let lonMax = region.center.longitude + 0.5 * region.span.longitudeDelta;

        let fetchRequest = NSFetchRequest(entityName: "TFCStationModel")
        do {
            let pred = NSPredicate(format: "latitude BETWEEN {\(latMin), \(latMax)} AND  longitude BETWEEN {\(lonMin), \(lonMax)}")

            fetchRequest.predicate = pred
            if let results = try TFCDataStore.sharedInstance.mocObjects?.executeFetchRequest(fetchRequest) as? [TFCStationModel] {
                return results.filter({ (row) -> Bool in
                    return (row.id != nil)
                    }).map({ (row) -> String in
                    return row.id!})
            }
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return []
    }

    public func didReceiveAPIResults(results: JSON?, error: NSError?, context: Any?) {
        isLoading = false
        var err: String? = nil
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            if (error != nil && error?.code != -999 || results == nil) {
                err =  "Network error. Please try again"
            } else {
                self.addWithJSON(results)
                if (!(self._stations.count > 0)) {
                    err = self.getReasonForNoStationFound()
                }
            }
            self.callStationsUpdatedDelegate(err)
        }
    }

    private func callStationsUpdatedDelegate(err: String?) {
        callStationsUpdatedDelegate(err, favoritesOnly: false, context: nil)
    }

    private func callStationsUpdatedDelegate(err: String?, favoritesOnly: Bool) {
        callStationsUpdatedDelegate(err, favoritesOnly: favoritesOnly, context: nil)
    }

    private func callStationsUpdatedDelegate(err: String?, favoritesOnly: Bool, context: Any?) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            if (err == TFCLocationManager.k.AirplaneMode) {
                self.loadingMessage = "Airplane Mode?"
            } else {
                if (!(self.count() > 0)) {
                    self.empty()
                }
                self.networkErrorMsg = err
            }
            if let firstStation = self.getStation(0) {
                //only send a complication update, if it's a favorite
                if firstStation.isFavorite() {
                    TFCDataStore.sharedInstance.sendComplicationUpdate(firstStation, coord: TFCLocationManagerBase.getCurrentLocation()?.coordinate)
                }
                if (self.lastFirstStationId != firstStation.st_id) {
                    DLog("just before updateGeofences", toFile:true)
                    TFCFavorites.sharedInstance.updateGeofences(force: false)
                    self.lastFirstStationId = firstStation.st_id
                }

            }
            if let dele = self.delegate {
                dele.stationsUpdated(self.networkErrorMsg, favoritesOnly: favoritesOnly, context: context)
            }
        }
    }

    public func getReasonForNoStationFound() -> String? {

        if (TFCLocationManager.getISOCountry() != "CH") {
            return "Not in Switzerland?"
        }
        
        if let distanceFromSwitzerland = locManager?.currentLocation?.distanceFromLocation(CLLocation(latitude: 47, longitude: 8)) where distanceFromSwitzerland > 1000000 {
                return "Not in Switzerland?"
        }

        return nil

    }

    public func getStationsAsArray(limit: Int = 1000) -> [TFCStation] {
        var stations = nearbyFavorites.getStations(limit)
        if (stations.count < limit) {
            for (station) in _stations.getStations(limit - stations.count) {
                stations.append(station)
            }
        }
        return stations
    }

    public func populateWithIds(favorites: [String]?, nonfavorites: [String]?) {
        if let favorites = favorites {
            self.nearbyFavorites.replace(stationIds: favorites)
        }
        if let nonfavorites = nonfavorites {
            self._stations.replace(stationIds: nonfavorites)
        }
    }
}

public protocol TFCStationsUpdatedProtocol: class {
    func stationsUpdated(error: String?, favoritesOnly: Bool, context: Any?)
}
