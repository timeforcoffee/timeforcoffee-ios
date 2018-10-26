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

    fileprivate weak var delegate: TFCStationsUpdatedProtocol?

    fileprivate var _stations:TFCStationCollection = TFCStationCollection()
    fileprivate var nearbyFavorites:TFCStationCollection = TFCStationCollection()
    fileprivate var inStationsArrayAsFavorite: [String: Bool] = [:]
    fileprivate var maxStations:Int = 100

    //struct here, because "class var" is not yet supported
    fileprivate struct favorite {
        static var s: TFCFavorites = TFCFavorites.sharedInstance
        static var userDefaults: UserDefaults? = TFCDataStore.sharedInstance.getUserDefaults()
    }

    fileprivate var lastFirstStationId:String? = nil
    public var networkErrorMsg: String?
    public var loadingMessage: String?
    public var isLoading: Bool = false {
        didSet { if (isLoading == true) {
                self.networkErrorMsg = nil
                self.loadingMessage = nil
            }
        }
    }
    fileprivate var lastRefreshLocation: Date?

    fileprivate lazy var locManager: TFCLocationManager? = { return TFCLocationManager(delegate: self)}()
    fileprivate lazy var api : APIController = { return APIController(delegate: self)}()

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

    public func removeDeparturesFromMemory() {
        self._stations.removeDeparturesFromMemory()
    }

    public func addWithJSON(_ allResults: JSON?) {
        // Store the results in our table data array
        if let c = allResults?["stations"].array?.count, c > 0 {
            var newStations:[TFCStation] = []
            // to prevent double entries, the api sometimes returns more than one with the same id
            var stationsAdded:[String: Int] = [:]
            if let results = allResults?["stations"].array {
                var results2:[JSON] = []
                // First filter out all double entries (multiple entries for same stationy
                for result in results {
                    let id = String(result["id"].stringValue)
                    //don't add stations with no id
                    if (id == "") {
                        continue;
                    }
                    if let name = result["name"].string {
                        // the DB has all the uppercased short Strings as well, we don't want to display them
                        // just don't add them
                        if (name == name.uppercased()) {
                            continue
                        }
                        if (inStationsArrayAsFavorite[id] == nil && (stationsAdded[id] == nil || stationsAdded[id]! < name.count)) {
                            // if we have a station with the same id but shorter name, remove it
                            // eg. Rappi
                            if (stationsAdded[id] != nil && stationsAdded[id]! < name.count) {
                                if let i = results2.indexOf({$0["id"].stringValue == id}) {
                                    results2.remove(at: i)
                                }
                            }

                            stationsAdded[id] = name.count
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
                        if let newStation = TFCStation.initWithCacheId(id, name: name, coord: Clocation) {
                            newStations.append(newStation)
                        }
                    }
                }
            }
            _stations.replace(newStations)
        }
    }

    public func getStation(_ index: Int) -> TFCStation? {
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

    class func isFavoriteStation(_ index: String) -> Bool {
        if (favorite.s.stations.indexOf(index) != nil) {
            return true
        }
        return false
    }

    public func initWithNearbyFavorites(_ location: CLLocation) -> Bool {
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
            if let c = station.calculatedDistance(location), c < favDistance {
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
            favs.sort(by: {
                if ($0.calculatedDistance() == nil || $1.calculatedDistance() == nil) {
                    return false
                }
                return $0.calculatedDistance(location)! < $1.calculatedDistance(location)!
            })
            self.nearbyFavorites.replace(favs)
            return true
        }
        self.nearbyFavorites.empty()
        return false
    }

    public func loadFavorites() {
        loadFavorites(locManager?.currentLocation)
    }

    public func sortStations(_ location: CLLocation?) {
        if (location != nil) {
            self._stations.sortInPlace({
                if ($0.calculatedDistance() == nil || $1.calculatedDistance() == nil) {
                    return false
                }
                return $0.calculatedDistance()! < $1.calculatedDistance()!
            })
        }
    }
    
    public func loadFavorites(_ location: CLLocation?) {
        self._stations.empty()
        TFCFavorites.sharedInstance.repopulateFavorites()
        self._stations = favorite.s.stations
        sortStations(location)
        #if os(iOS)
            DLog("just before updateGeofences", toFile:true)
            TFCFavorites.sharedInstance.updateGeofences(force: false)
        #endif
    }

    public func updateStations(searchFor: String) -> Bool {
        isLoading = true
        self.api.searchFor(searchFor)
        return true
    }

    public func updateStations(_ force: Bool = false) -> Bool {
        // dont refresh location within 5 seconds..
        if (force ||
            lastRefreshLocation == nil ||
            lastRefreshLocation!.timeIntervalSinceNow < -5
            ) {
            lastRefreshLocation = Date()
            isLoading = true
            DispatchQueue.main.async(execute: {
                self.locManager?.refreshLocation()
                return
            })
            return true
        }
        return false
    }

    public func locationFixed(_ loc: CLLocation?) {
        initStationsByLocation(loc, currentRealLocation: true)
    }
    
    public func initStationsByLocation(_ loc: CLLocation?, currentRealLocation: Bool = true) {
        if let loc = loc {
            if (self.initWithNearbyFavorites(loc)) {
                self.callStationsUpdatedDelegate(nil, favoritesOnly: true, currentRealLocation: currentRealLocation)
            }
            let coord = loc.coordinate
            if (TFCLocationManager.getISOCountry() == "CH") {
                self.searchForStationsInDB(loc, currentRealLocation: currentRealLocation)
            } else {
                self.api.searchFor(coord)
            }
        }
    }

    public func locationDenied(_ manager: CLLocationManager, err: Error) {
            favorite.s.repopulateFavorites()
            self.nearbyFavorites = TFCFavorites.sharedInstance.stations
            callStationsUpdatedDelegate("Location not available")
    }

    public func locationStillTrying(_ manager: CLLocationManager, err: Error) {
            callStationsUpdatedDelegate(TFCLocationManager.k.AirplaneMode)
    }
    
    public func searchForStationsInDB(_ coord: CLLocation, distance: Double = 1500.0, context: Any? = nil,
                                      currentRealLocation:Bool = true) {

        var err:String?

        let ids = getStationIdsForCoord(coord.coordinate, distance: distance)

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
            .map({(id: String) -> TFCStation? in
                if let station = TFCStation.initWithCache(id: id) {
                    return station
                }
                return nil
            })
            //remove stations not within distance
            .filter({(station: TFCStation?) in
                if (station?.calculatedDistance(coord) == nil || station!.calculatedDistance(coord)! > distance) {
                    return false
                }
                return true
            }).compactMap {$0} // remove all optionals
        //sort by distance
        stations.sort(by: {
            if ($0.calculatedDistance(coord) == nil || $1.calculatedDistance(coord) == nil) {
                return false
            }
            return $0.calculatedDistance(coord)! < $1.calculatedDistance(coord)!
        })

        self._stations.replace(Array(stations.prefix(self.maxStations))) //only add max stations

        if (!(self._stations.count > 0)) {
            //this can happen, when we filter out station above, so increase the search radius
            if (distance < 50000) {
                return searchForStationsInDB(coord, distance: distance * 2, context: context)
            }
            err = self.getReasonForNoStationFound()
        }
        callStationsUpdatedDelegate(err, favoritesOnly: false, context: context, currentRealLocation: currentRealLocation)
    }

    fileprivate func getStationIdsForCoord(_ coord: CLLocationCoordinate2D, distance: Double) -> [String]
    {
        let region = MKCoordinateRegion(center: coord, latitudinalMeters: distance, longitudinalMeters: distance);

        let latMin = region.center.latitude - 0.5 * region.span.latitudeDelta;
        let latMax = region.center.latitude + 0.5 * region.span.latitudeDelta;
        let lonMin = region.center.longitude - 0.5 * region.span.longitudeDelta;
        let lonMax = region.center.longitude + 0.5 * region.span.longitudeDelta;
        var resultValue:[String] = []
        TFCDataStore.sharedInstance.managedObjectContext.performAndWait {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TFCStationModel")
            do {
                let pred = NSPredicate(format: "latitude BETWEEN {\(latMin), \(latMax)} AND  longitude BETWEEN {\(lonMin), \(lonMax)}")

                fetchRequest.predicate = pred
                if let results = try TFCDataStore.sharedInstance.managedObjectContext.fetch(fetchRequest) as? [TFCStationModel] {
                    resultValue = results.filter({ (row) -> Bool in
                        return (row.id != nil)
                    }).map({ (row) -> String in
                        return row.id!})
                }
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
        }
        return resultValue
    }

    public func didReceiveAPIResults(_ results: JSON?, error: Error?, context: Any?) {
        isLoading = false
        var err: String? = nil
        DispatchQueue.global(qos: .default).async {
            if (error != nil && (error! as NSError).code != -999 || results == nil) {
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

    fileprivate func callStationsUpdatedDelegate(_ err: String?) {
        callStationsUpdatedDelegate(err, favoritesOnly: false, context: nil)
    }

    fileprivate func callStationsUpdatedDelegate(_ err: String?, favoritesOnly: Bool, context: Any? = nil, currentRealLocation:Bool = true) {
        DispatchQueue.global(qos: .default).async {
            if (err == TFCLocationManager.k.AirplaneMode) {
                self.loadingMessage = "Airplane Mode?"
            } else {
                let c = self.count()
                if (c == nil || c == 0) {
                    self.empty()
                }
                self.networkErrorMsg = err
            }
            if currentRealLocation, let firstStation = self.getStation(0) {
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
                dele.stationsUpdated(self.networkErrorMsg, favoritesOnly: favoritesOnly, context: context, stations: self)
            }
        }
    }

    public func getReasonForNoStationFound() -> String? {

        if (TFCLocationManager.getISOCountry() != "CH") {
            return "Not in Switzerland?"
        }
        
        if let distanceFromSwitzerland = locManager?.currentLocation?.distance(from: CLLocation(latitude: 47, longitude: 8)), distanceFromSwitzerland > 1000000 {
                return "Not in Switzerland?"
        }

        return nil

    }

    public func getStationsAsArray(_ limit: Int = 1000) -> [TFCStation] {
        var stations = nearbyFavorites.getStations(limit)
        if (stations.count < limit) {
            for (station) in _stations.getStations(limit - stations.count) {
                stations.append(station)
            }
        }
        return stations
    }

    public func populateWithIds(_ favorites: [String]?, nonfavorites: [String]?) {
        if let favorites = favorites {
            self.nearbyFavorites.replace(stationIds: favorites)
        }
        if let nonfavorites = nonfavorites {
            self._stations.replace(stationIds: nonfavorites)
        }
    }
}

public protocol TFCStationsUpdatedProtocol: class {
    func stationsUpdated(_ error: String?, favoritesOnly: Bool, context: Any?, stations: TFCStations)
}
