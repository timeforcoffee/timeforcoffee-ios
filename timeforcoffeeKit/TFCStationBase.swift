//
//  Album.swift
//  nextMigros
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit
import UIKit
import CoreData

public class TFCStationBase: NSObject, NSCoding, APIControllerProtocol {

    public var name: String {
        get {
            if (_name == nil) {
                _name = self.realmObject?.name
                if (_name == "" || _name == nil) {
                    _name = "unknown"
                }
            }
            return _name!
        }
        set(name) {
            if (name != self.realmObject?.name) {
                var name2 = name
                if (name2 == "") {
                    name2 = "unknown"
                }
                DLog("set new name in DB for \(name2) \(st_id)")
                self.realmObject?.name = name2
                self.realmObject?.lastUpdated = NSDate()
                _name = name2
            }
        }
    }
    #if DEBUG
    static var InstanceCounter:Int = 0
    static var instances:[String:Int] = [:]
    #endif

    static var stationsCache:[String:WeakBox<TFCStation>] = [:]
    private var _name: String?

    public var coord: CLLocation? {
        get {
            if (self._coord != nil) {
                return self._coord
            }
            self._coord = CLLocation(latitude: (self.realmObject?.latitude?.doubleValue)!, longitude: (self.realmObject?.longitude?.doubleValue)!)
            return self._coord
        }
        set(location) {
            self._coord = location
            if let lat = location?.coordinate.latitude, let lon = location?.coordinate.longitude {
                if (self.realmObject?.latitude  == nil ||
                    self.realmObject?.longitude == nil ||
                    coord?.distanceFromLocation(CLLocation(latitude: self.realmObject?.latitude as! Double , longitude: self.realmObject?.longitude as! Double)) > 10) {
                        self.realmObject?.latitude = lat
                        self.realmObject?.longitude = lon
                        self.realmObject?.lastUpdated = NSDate()
                        DLog("updateGeolocationInfo for \(self.name)")
                        self.updateGeolocationInfo()
                }

            }
        }
    }

    private var _coord: CLLocation?

    public var st_id: String

    private var departures: [String:TFCDeparture]? = nil {
        didSet {
            filteredDepartures = nil
            departuresSorted = nil
            needsCacheSave = true
        }
    }

    public var needsCacheSave:Bool = false
    private var departuresSorted: [TFCDeparture]?
    private var filteredDepartures: [TFCDeparture]?

    public var calculatedDistance: Double? {
        get {
            guard let currentLoc = TFCLocationManager.getCurrentLocation() else { return nil }
            // recalculate distance when we're more than 50m away
            if (_calculatedDistanceLastCoord == nil || _calculatedDistanceLastCoord?.distanceFromLocation(currentLoc) > 50) {
                _calculatedDistanceLastCoord = currentLoc
                if let coord = self.coord {
                    _calculatedDistance = currentLoc.distanceFromLocation(coord)
                    // don't store it on watchOS, it's slower than calculating it on startup
                    #if os(watchOS)
                    #else
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
                            let cache: PINCache = TFCCache.objects.stations
                            cache.setObject(self, forKey: self.st_id)
                        }
                    #endif
                }

            }
            return _calculatedDistance
        }
    }

    private var _calculatedDistance: Double? = nil

    var _calculatedDistanceLastCoord: CLLocation? = nil

    var walkingDistanceString: String? = nil {
        didSet {
            self.needsCacheSave = true
        }
    }
    var walkingDistanceLastCoord: CLLocation? = nil
    public var lastDepartureUpdate: NSDate? = nil
    private var lastDepartureCount: Int? = nil

    private var departureUpdateDownloading: NSDate? = nil

    public var isLastUsed: Bool = false
    public var serializeDepartures: Bool = true

    private struct objects {
        static let  dataStore: TFCDataStore? = TFCDataStore.sharedInstance
    }

    private lazy var api : APIController = {
        [unowned self] in
        return APIController(delegate: self)
    }()

    struct contextData {
        var completionDelegate: TFCDeparturesUpdatedProtocol? = nil
        var hasStartTime: Bool = false
        var onlyFirstDownload: Bool = false
        var context: Any? = nil
    }

    private lazy var filteredLines:[String: [String: Bool]] = {
        [unowned self] in
        return self.getFilteredLines()
    }()

    private lazy var favoriteLines:[String: [String: Bool]] = {
        [unowned self] in
        return self.getFavoriteLines()
    }()


    private lazy var realmObject:TFCStationModel? = {
        [unowned self] in

        let fetchRequest = NSFetchRequest(entityName: "TFCStationModel")
        do {
            let pred = NSPredicate(format: "id == %@", self.st_id)
            fetchRequest.predicate = pred
            if let results = try TFCDataStore.sharedInstance.managedObjectContext.executeFetchRequest(fetchRequest) as? [TFCStationModel] {
                if let first = results.first {
                    return first
                }
            }
        } catch let error as NSError {
            DLog("Could not fetch \(error), \(error.userInfo)")
        }

        if let obj = NSEntityDescription.insertNewObjectForEntityForName("TFCStationModel", inManagedObjectContext: TFCDataStore.sharedInstance.managedObjectContext) as? TFCStationModel {
            obj.id = self.st_id
            return obj
        }
        #if DEBUG
            DLog("WARNING: realmObject IS NIL!!!! ", toFile: true)
        #endif
        return nil
    }()



    public init(name: String, id: String, coord: CLLocation?) {
        self.st_id = id
        super.init()
        self.name = name
        self.instanceCounter("coord")


        if let c = coord?.coordinate {
            // round coordinates to 6 places to make sure they are the same with different sources
            // to avoid double entries in Spotlight search
            let lat = c.latitude.roundToPlaces(6);
            let long = c.longitude.roundToPlaces(6);
            self.coord = CLLocation(latitude: lat, longitude: long)
        }
    }

    public init(id: String) {
        self.st_id = id
        super.init()
        self.instanceCounter("id")

    }

    private func instanceCounter(name: String) {
        #if DEBUG
        TFCStationBase.InstanceCounter += 1;
        DLog("init stationbase \(name) \(self.st_id) \(TFCStationBase.InstanceCounter)");

        if let count = TFCStationBase.instances[self.st_id] {
            TFCStationBase.instances[self.st_id] = count + 1
        } else {
            TFCStationBase.instances[self.st_id]  = 1
        }
        if (TFCStationBase.instances[self.st_id] > 1) {
            DLog("WARN: init of \(self.st_id) \(self.name) has \(TFCStationBase.instances[self.st_id]) instances ", toFile: true)
        }
        #endif
    }

    public required init?(coder aDecoder: NSCoder) {
        do {
            if #available(iOSApplicationExtension 9.0, *) {
                self.st_id = try aDecoder.decodeTopLevelObjectForKey("st_id") as! String
            } else {
                self.st_id = aDecoder.decodeObjectForKey("st_id") as! String
            }
            super.init()
            self.instanceCounter("coder")

        } catch let (err) {
            self.st_id = "0000"
            super.init()
            self.instanceCounter("coder error")

            DLog("Decoder error: \(err)", toFile: true)
        }

        do {
            if #available(iOSApplicationExtension 9.0, *) {
                self.departures = try aDecoder.decodeTopLevelObjectForKey("departuresDict") as! [String:TFCDeparture]?
                if (self.departures?.count == 0) {
                    self.departures = nil
                } else if (self.departures != nil) {
                    // FIXME: we changed the key (removed arrival)
                    // this can be removed some time after 1.13 is released
                    for key in self.departures!.keys {
                        if key.containsString("arrival") {
                            self.departures?.removeValueForKey(key)
                        }
                    }
                }

                self.walkingDistanceString = try aDecoder.decodeTopLevelObjectForKey("walkingDistanceString") as! String?
                self.walkingDistanceLastCoord = try aDecoder.decodeTopLevelObjectForKey("walkingDistanceLastCoord") as! CLLocation?
                self._calculatedDistance = try aDecoder.decodeTopLevelObjectForKey("_calculatedDistance") as! Double?
                self._calculatedDistanceLastCoord = try aDecoder.decodeTopLevelObjectForKey("_calculatedDistanceLastCoord") as! CLLocation?
                self.lastDepartureUpdate = try aDecoder.decodeTopLevelObjectForKey("lastDepartureUpdate") as! NSDate?

            } else {
                self.departures = aDecoder.decodeObjectForKey("departuresDict") as! [String:TFCDeparture]?
                if (self.departures?.count == 0) {
                    self.departures = nil
                }
                self.walkingDistanceString = aDecoder.decodeObjectForKey("walkingDistanceString") as! String?
                self.walkingDistanceLastCoord = aDecoder.decodeObjectForKey("walkingDistanceLastCoord") as! CLLocation?
                self._calculatedDistance = aDecoder.decodeObjectForKey("_calculatedDistance") as! Double?
                self._calculatedDistanceLastCoord = aDecoder.decodeObjectForKey("_calculatedDistanceLastCoord") as! CLLocation?
            }
        } catch let (err) {
            DLog("Decoder error: \(err)", toFile: true)
        }
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(st_id, forKey: "st_id")
        if (serializeDepartures) {
            aCoder.encodeObject(departures, forKey: "departuresDict")
        }
        aCoder.encodeObject(walkingDistanceString, forKey: "walkingDistanceString")
        aCoder.encodeObject(walkingDistanceLastCoord, forKey: "walkingDistanceLastCoord")
        aCoder.encodeObject(_calculatedDistance, forKey: "_calculatedDistance")
        aCoder.encodeObject(_calculatedDistanceLastCoord, forKey: "_calculatedDistanceLastCoord")
        aCoder.encodeObject(lastDepartureUpdate, forKey:"lastDepartureUpdate")
    }

    deinit {
        #if DEBUG
        TFCStationBase.InstanceCounter -= 1;
        if let count = TFCStationBase.instances[self.st_id] {
            TFCStationBase.instances[self.st_id] = count - 1
        }
        DLog("deinit stationbase \(self.st_id) \(self.name) \(TFCStationBase.InstanceCounter)")
        #endif
    }

    override public convenience init() {
        self.init(name: "doesn't exist", id: "0000", coord: nil)
    }

    public class func saveToPincache(saveStation: TFCStationBase) {
        if (saveStation.needsCacheSave)  {
            let cache: PINCache = TFCCache.objects.stations
            //immediatly set to memory cache
            cache.memoryCache.setObject(saveStation, forKey: saveStation.st_id)
            DLog("set PinCache for \(saveStation.name) \(saveStation.st_id)", toFile: true)

            cache.setObject(saveStation, forKey: saveStation.st_id , block: { (_) in
            })
            saveStation.needsCacheSave = false

        }
    }

    public class func initWithCache(name: String, id: String, coord: CLLocation?) -> TFCStation {
        let trimmed_id: String

        if (id.hasPrefix("0")) {
            trimmed_id = id.replace("^0*", template: "")
        } else {
            trimmed_id = id
        }
        // try to find it in the cache
        let cache: PINCache = TFCCache.objects.stations
        if let newStation = getFromMemoryCaches(trimmed_id) {
            return newStation
        }
       
        let newStation: TFCStation? = cache.objectForKey(trimmed_id) as? TFCStation
        //if not in the cache, or no coordinates set or the name is "unknown"
        if (newStation == nil || newStation?.coord == nil || newStation?.name == "unknown") {
            //if name is not set, we only have the id, try to get it from the DB or from a server
            if (name == "") {
                // try to get it from core data
                let tryStation = TFCStation(id: id)
                //if the name from the DB is not "unknown", return it
                if (tryStation.name != "unknown") {
                    //if coords are set and the id is not empty, set it to the cache
                    if (tryStation.coord != nil && tryStation.st_id != "") {
                        tryStation.setStationSearchIndex()
                        tryStation.needsCacheSave = true
                        addToStationCache(tryStation)
                        TFCStationBase.saveToPincache(tryStation)
                    }
                    return tryStation
                }
                // if we couldn't get it from the DB, fetch it from opendata
                // this is done synchronously, so butt ugly, but we have a timeout of 5 seconds
                let api = APIController(delegate: nil)
                DLog("Station Name missing. Fetch station info from opendata.ch for \(trimmed_id)")
                if let result = api.getStationInfo(trimmed_id) {
                    if let name = result["stations"][0]["name"].string {
                        if let id = result["stations"][0]["id"].string?.replace("^0*", template: "") {
                            var location:CLLocation? = nil
                            if let lat = result["stations"][0]["coordinate"]["x"].double {
                                if let long = result["stations"][0]["coordinate"]["y"].double {
                                location = CLLocation(latitude: lat, longitude: long)
                                }
                            }
                            // try again, this time with a name
                            return TFCStation.initWithCache(name, id: id, coord: location)
                        }
                    }
                }
            }
            let newStation2 = TFCStation(name: name, id: trimmed_id, coord: coord)
            //only cache it when name is != "" otherwise it comes
            // from something with only the id
            if (name != "" && newStation2.st_id != "" && newStation2.coord != nil) {
                newStation2.setStationSearchIndex()
                newStation2.needsCacheSave = true
                TFCStationBase.saveToPincache(newStation2)
            }
            addToStationCache(newStation2)
            return newStation2
        } else {
            let countBefore = newStation!.departures?.count
            if (countBefore > 0) {
                newStation!.removeObsoleteDepartures()
            }
            newStation!.filteredLines = newStation!.getFilteredLines()
            // if country is not set, try updating it
            if (newStation!.getCountryISO() == "") {
                newStation!.updateGeolocationInfo()
            }
            newStation!.favoriteLines = newStation!.getFavoriteLines()
        }
        addToStationCache(newStation!)
        return newStation!
    }

    public class func getFromMemoryCaches(id: String) -> TFCStation? {
        let cache: PINCache = TFCCache.objects.stations

        // if already in the PINCcache cache, we can just return it
        if let newStation = cache.memoryCache.objectForKey(id) as? TFCStation {
            return newStation
        }
        // check if we have it in the stationCache
        if let newStation = stationsCache[id]?.value {
            DLog("init in stationsCache \(id) ")
            cache.memoryCache.setObject(newStation, forKey: id)
            return newStation
        }
        return nil
    }

    public class func countStationsCache() -> Int {
        for (id, station) in stationsCache {
            if (station.value == nil) {
                stationsCache.removeValueForKey(id)
            }
        }
        return stationsCache.count

    }

    public class func addToStationCache(station: TFCStation) {
        TFCStationBase.stationsCache[station.st_id] = WeakBox(station)
    }

    public class func initWithCache(dict: [String: String]) -> TFCStation {
        var location: CLLocation? = nil;
        if let lat: String = (dict["latitude"] as String?),
            let long: String = (dict["longitude"] as String?) {
                location = CLLocation(latitude: (lat as NSString).doubleValue, longitude: (long as NSString).doubleValue)
        }
        let name: String
        if let name2 = dict["name"] as String? {
            name = name2
        } else {
            name = ""
        }
        let station = initWithCache(name, id: dict["st_id"] as String!, coord: location)
        return station
    }

    public class func initWithCacheId(id:String)-> TFCStation {
        return initWithCache("", id: id, coord: nil)
    }

    public class func isStations(results: JSON) -> Bool {
        if (results["stations"].array != nil) {
            return true
        }
        return false
    }
    
    public func isFavorite() -> Bool {
        return TFCStations.isFavoriteStation(self.st_id);
    }

    public func toggleFavorite() {
        if (self.isFavorite() == true) {
            self.unsetFavorite()
        } else {
            self.setFavorite()
        }
    }

    public func setFavorite() {
        TFCFavorites.sharedInstance.set(self as? TFCStation)
        DLog("just before updateGeofences", toFile:true)
        TFCFavorites.sharedInstance.updateGeofences()
    }

    public func unsetFavorite() {
        TFCFavorites.sharedInstance.unset(station: self as? TFCStation)
        DLog("just before updateGeofences", toFile:true)
        TFCFavorites.sharedInstance.updateGeofences()
    }

    public func getLongitude() -> Double? {
        return coord?.coordinate.longitude
    }

    public func getLatitude() -> Double? {
        return coord?.coordinate.latitude
    }
    
    public func getName(cityAfter: Bool) -> String {
        if (cityAfter && name.match(", *")) {
            let stationName = name.replace(".*, *", template: "")
            let cityName = name.replace(", *.*", template: "")
            return "\(stationName) (\(cityName))"
        }
        return name
    }

    public func getNameAbridged() -> String {
        return self.name.replace(".*,[ ]*", template: "")
    }

    public func getNameWithStar() -> String {
        return getNameWithStar(false)
    }
    
    public func getNameWithStar(cityAfter: Bool) -> String {
        if self.isFavorite() {
            return "\(getName(cityAfter)) ★"
        }
        return getName(cityAfter)
    }

    public func getNameWithFilters(cityAfter: Bool) -> String {
        return "\(getName(cityAfter))\(getFilterSign())"
    }

    private func getFilterSign() -> String {
        if (self.hasFilters()) {
            return " ✗"
        }
        return ""
    }

    public func getNameWithStarAndFilters() -> String {
        return getNameWithStarAndFilters(false)
    }
    
    public func getNameWithStarAndFilters(cityAfter: Bool) -> String {
        return "\(getNameWithStar(cityAfter))\(getFilterSign())"
    }
    
    public func hasFilters() -> Bool {
        return (filteredLines.count > 0 || hasFavoriteDepartures())
    }
    public func hasFavoriteDepartures() -> Bool {
        return favoriteLines.count > 0
    }

    private func getMarkedLines(favorite: Bool) -> [String: [String: Bool]] {
        if (favorite) {
            return favoriteLines
        }
        return filteredLines
    }

    private func isMarkedDeparture(departure: TFCDeparture, favorite: Bool) -> Bool {
        var lines = getMarkedLines(favorite)
        if (lines[departure.getLine()] != nil) {
            if (lines[departure.getLine()]?[departure.getDestination()] != nil) {
                return true
            }
        }
        return false
    }

    public func isFavoriteDeparture(departure: TFCDeparture) -> Bool {
        return isMarkedDeparture(departure, favorite: true)
    }

    public func isFilteredDeparture(departure: TFCDeparture) -> Bool {
        return isMarkedDeparture(departure, favorite: false)
    }

    public func showAsFavoriteDeparture(departure: TFCDeparture) -> Bool {
        if (favoriteLines.count > 0) {
            return isFavoriteDeparture(departure)
        }
        if (filteredLines.count > 0) {
            return !isFilteredDeparture(departure)
        }
        return false
    }

    private func setMarkedDeparture(departure: TFCDeparture, favorite: Bool) {
        var lines = getMarkedLines(favorite)
        if (lines[departure.getLine()] == nil) {
            lines[departure.getLine()] = [:]
        }
        lines[departure.getLine()]?[departure.getDestination()] = true
        saveMarkedLines(lines, favorite: favorite)
        // remove filtered lines once we set a favorite line
        if (favorite) {
            var filteredLines = getMarkedLines(false)
            if (filteredLines.count > 0) {
                filteredLines = [:]
                saveMarkedLines(filteredLines, favorite: false)
            }
        }
    }

    public func setFavoriteDeparture(departure: TFCDeparture) {
        setMarkedDeparture(departure, favorite: true)
    }

    public func setFilterDeparture(departure: TFCDeparture) {
        setMarkedDeparture(departure, favorite: false)
    }

    private func unsetMarkedDeparture(departure: TFCDeparture, favorite: Bool) {
        var lines = getMarkedLines(favorite)
        lines[departure.getLine()]?[departure.getDestination()] = nil
        if let l = lines[departure.getLine()] as [String: Bool]? {
            if(l.count == 0) {
                lines[departure.getLine()] = nil
            }
        } else {
            lines[departure.getLine()] = nil
        }
        saveMarkedLines(lines, favorite: favorite)

    }

    public func unsetFavoriteDeparture(departure: TFCDeparture) {
        unsetMarkedDeparture(departure, favorite: true)
    }
    
    public func unsetFilterDeparture(departure: TFCDeparture) {
        unsetMarkedDeparture(departure, favorite: false)
    }

    private func getDataStoreKey(id: String, favorite: Bool) -> String {
        if (favorite) {
            return "favorite\(id)"
        }
        return "filtered\(id)"
    }

    private func saveMarkedLines(lines: [String: [String: Bool]], favorite: Bool) {
        if (favorite) {
            favoriteLines = lines
        } else {
            filteredLines = lines
        }

        let key:String = getDataStoreKey(st_id, favorite: favorite)
        if (lines.count > 0) {
            objects.dataStore?.setObject(lines, forKey: key)
        } else {
            objects.dataStore?.removeObjectForKey(key)
        }
        objects.dataStore?.synchronize()
        self.filteredDepartures = nil
        TFCDataStore.sharedInstance.settingsLastUpdated = NSDate()
        TFCDataStore.sharedInstance.getUserDefaults()?.setObject(NSDate(), forKey: "settingsLastUpdate")

    }

    private func getMarkedLinesShared(favorite: Bool) -> [String: [String: Bool]] {
        let key = getDataStoreKey(st_id, favorite: favorite)
        let markedDestinationsShared: [String: [String: Bool]]? = objects.dataStore?.objectForKey(key)?.mutableCopy() as! [String: [String: Bool]]?

        guard let markedDestinationsShared2 = markedDestinationsShared else { return [:] }
        return markedDestinationsShared2
    }

    private func getFavoriteLines() -> [String: [String: Bool]] {
        return getMarkedLinesShared(true)
    }

    public func repopulateFavoriteLines() {
        self.favoriteLines = self.getFavoriteLines()
    }

    private func getFilteredLines() -> [String: [String: Bool]] {
        return getMarkedLinesShared(false)
    }

    func addDepartures(departures: [TFCDeparture]?) {
        // don't update departures, if we get nil
        // can happen when network request didn't work properly
        if let depts = departures {
            var count = 0;
            var newDepartures:[String:TFCDeparture] = [:]
            if let oldDepts = self.departures {
                newDepartures = oldDepts
            }
            for dept in depts {
                let key = dept.getKey()
                let oldDept = newDepartures[key]
                if let oldSig = oldDept?.getSignature(self as? TFCStation) {
                    let newSig = dept.getSignature(self as? TFCStation)
                    if (oldSig != newSig) {
                        newDepartures[key] = dept
                        count += 1
                    }
                } else {
                    newDepartures[key] = dept
                    count += 1
                }
            }
            self.departures = newDepartures
            DLog("Added \(count) depts to \(self.name)", toFile: true)
            if (count > 0) {
                self.needsCacheSave = true
                TFCStationBase.saveToPincache(self)
            }
            DLog("_", toFile: true)
        }
    }

    public func getDepartures() -> [TFCDeparture]? {
        if let alreadySorted = self.departuresSorted {
            return alreadySorted
        }
        if let depts = self.departures?.values {
            let sorted = depts.sort({ (s1, s2) -> Bool in
                if s1.sortTime == s2.sortTime {
                    return s1.sortOrder < s2.sortOrder
                }
                return s1.sortTime < s2.sortTime
            })
            self.departuresSorted = sorted
            return sorted
        }
        return nil
    }

    public func getFilteredDepartures() -> [TFCDeparture]? {
        if (!hasFilters()) {
            return getDepartures()
        }
        if (filteredDepartures != nil) {
            return filteredDepartures
        }
        if (self.departures != nil) {
            filteredDepartures = []
            for (departure) in self.getDepartures()! {
                if (self.showAsFavoriteDeparture(departure)) {
                    filteredDepartures?.append(departure)
                }
            }
            return filteredDepartures
        }
        return nil
    }

    public func getFilteredDepartures(maxDepartures: Int) -> ArraySlice<TFCDeparture>? {
        if let filteredDepartures = getFilteredDepartures() {
            let endIndex = min(maxDepartures, filteredDepartures.count)
            return filteredDepartures[0..<endIndex]
        }
        return nil
    }


    public func getScheduledFilteredDepartures(limit:Int? = nil) -> [TFCDeparture]? {
        let depts:[TFCDeparture]?
        if let limit = limit, departures = self.getFilteredDepartures(limit) {
            depts = Array(departures)
        } else {
            depts = self.getFilteredDepartures()
        }
        if let depts = depts {
            let sorted = depts.sort({ (s1, s2) -> Bool in
                return s1.getScheduledTimeAsNSDate() < s2.getScheduledTimeAsNSDate()
            })
            var i = 0
            //dont add departures which may go away pretty soon anyway again
            // that's why we only go back 50 seconds and not the full 60
            
            let aMinuteAgo = NSDate().dateByAddingTimeInterval(-50)
            var newSorted = sorted
            for departure in sorted {
                if (departure.getScheduledTimeAsNSDate() < aMinuteAgo) {
                    if (newSorted.indices.contains(i)) {
                        newSorted.removeAtIndex(i)
                    }
                    i += 1
                } else {
                    //if we find one, which is not obsolete, we can stop here
                    break
                }
            }

            if (newSorted.count > 0) {
                return newSorted
            }
        }

        return nil
    }

    public func updateDepartures(completionDelegate: TFCDeparturesUpdatedProtocol?, force: Bool = false, context: Any? = nil, cachettl:Int = 20, startTime:NSDate? = nil, onlyFirstDownload:Bool = false) {

        let removedDepartures = removeObsoleteDepartures()

        // If a download is already running for this station and it started less than 5 seconds ago, wait..
        // This way we prevent multiple parallel downloads (especially from the today extension)
        // somehow ugly, but couldn't come up with a better solution
        if let downloadingSince = self.departureUpdateDownloading {
            if (downloadingSince.timeIntervalSinceNow > -5) {
                delay(1.0, closure: {
                      self.updateDepartures(completionDelegate, force: force, context: context, cachettl: cachettl)
                    }
                    )
                return
            }
        }

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            var context2: contextData = contextData()
            context2.completionDelegate = completionDelegate
            context2.context = context
            if (startTime != nil) {
                context2.hasStartTime = true
            }
            context2.onlyFirstDownload = onlyFirstDownload

            var dontUpdate = false
            if let first = self.getDepartures()?.first {
                // don't update if the next departure is more than 30 minutes away,
                // we didn't remove any departures above
                // and this happens to be not realtime (which I assume normally isnt
                // if the first departure is that far away)
                if (!removedDepartures && first.getMinutesAsInt() > 30 && !first.isRealTime()) {
                    dontUpdate = true
                }
            }
            let settingsLastUpdated: NSDate? = TFCDataStore.sharedInstance.getUserDefaults()?.objectForKey("settingsLastUpdate") as! NSDate?
            if (force ||
                    (!dontUpdate &&
                        (self.lastDepartureUpdate == nil ||
                         (self.lastDepartureUpdate?.timeIntervalSinceNow)! < -cachettl ||
                            (settingsLastUpdated != nil &&
                             self.lastDepartureUpdate?.timeIntervalSinceDate(settingsLastUpdated!) < 0
                            )
                        )
                    )
                )
            {
                self.departureUpdateDownloading = NSDate()
                self.api.getDepartures(self as! TFCStation, context: context2, startTime: startTime)

            } else {
                dispatch_async(dispatch_get_main_queue(), {
                    completionDelegate?.departuresStillCached(context2.context, forStation: self as? TFCStation)
                    return  
                })
            }
        }
    }

    public func didReceiveAPIResults(results: JSON?, error: NSError?, context: Any?) {
        let contextInfo: contextData? = context as! contextData?
        var lastScheduledBefore:NSDate? = nil
        if (results == nil || (error != nil && self.departures != nil && self.departures?.count > 0)) {
            self.setDeparturesAsOutdated()
        } else {
            if (contextInfo?.hasStartTime == true) {
                lastScheduledBefore = self.getLastDepartureDate()
            }
            self.addDepartures(TFCDeparture.withJSON(results, st_id: self.st_id))
        }

            if (self.name == "" && results != nil) {
                self.name = TFCDeparture.getStationNameFromJson(results!)!;
            }

            self.lastDepartureUpdate = NSDate()
            self.departureUpdateDownloading = nil
            contextInfo?.completionDelegate?.departuresUpdated(error, context: contextInfo?.context, forStation: self as? TFCStation)

            if (contextInfo?.onlyFirstDownload != true) {
                // get last entry and get more data in case we want more into the future
                if let lastScheduled = self.getLastDepartureDate() {
                    //prevent loop in case we don't get new data
                    if (lastScheduledBefore == nil || lastScheduledBefore?.timeIntervalSinceReferenceDate < lastScheduled.timeIntervalSinceReferenceDate) {
                        // either go 2 hours into the future or at least until 8 o'clock in the morning (if the last one is after midnight and not more than 10 hours away)
                        if ((lastScheduled.dateByAddingTimeInterval(2 * -3600).timeIntervalSinceNow < 0) ||
                            ((lastScheduled.timeIntervalSinceDate(NSCalendar.currentCalendar().startOfDayForDate(lastScheduled)) < 3600 * 8)
                                && (lastScheduled.dateByAddingTimeInterval(10 * -3600).timeIntervalSinceNow < 0))) {
                            self.updateDepartures(contextInfo?.completionDelegate, force: true, context: contextInfo?.context, startTime: lastScheduled)
                        }
                    }
                }
            }





    }
    private func getLastDepartureDate() -> NSDate? {

        return self.getDepartures()?.last?.getScheduledTimeAsNSDate()

    }


    private func setDeparturesAsOutdated() {
        if (self.departures != nil) {
            for (departure) in self.getDepartures()! {
                departure.outdated = true
            }
        }
    }

    func clearDepartures() {
        self.departures = nil
    }

    public func removeObsoleteDepartures() -> Bool {
        if (self.departures == nil || self.departures?.count == 0) {
            return false
        }
        var i = 0;
        var someRemoved = false
        for departure in self.getDepartures()! {
            if (departure.getMinutesAsInt() < 0) {
                someRemoved = true
                departures?.removeValueForKey(departure.getKey())
            } else {
                i += 1
                //if we find one, which is not obselte, we can stop here
                break
            }
        }

        if (departures?.count == 0) {
            clearDepartures()
            someRemoved = true
        }
        if (someRemoved) {
            self.needsCacheSave = true
            TFCStationBase.saveToPincache(self)
        }
        return someRemoved
    }

    public func getAsDict() -> [String: String] {
        if (coord == nil) {
            return [
                "name": getName(false),
                "st_id": st_id,
            ]
        }
        return [
            "name": getName(false),
            "st_id": st_id,
            "latitude": coord!.coordinate.latitude.description,
            "longitude": coord!.coordinate.longitude.description
        ]
    }

    public func getIconIdentifier() -> String {
        if (isFavorite()) {
            if (st_id == "8591306") {
                return "stationicon-liip"
            }
            return "stationicon-star"
        }
        return "stationicon-pin"
    }

    public func getIcon() -> UIImage {
        return UIImage(named: getIconIdentifier())!
    }

    public func setStationActivity() {
    }

    public func setStationSearchIndex() {
    }


    public func getWebLink() -> NSURL? {
        //        {:location-id :ch_zh, :stops {"008591195" {:id "008591195", :name "Zürich, Höfliweg", :location {:lat 47.367569, :lng 8.51095}, :known-destinations ()}}, :stops-order ["008591195"]
        if (self.getCountryISO() != "CH" && self.getCountryISO() != "") {
            return NSURL(string: "http://fahrplan.sbb.ch/bin/stboard.exe/dn?input=\(self.st_id)&REQTrain_name=&boardType=dep&time=now&productsFilter=1111111111&selectDate=today&maxJourneys=20&start=yes")
        }
        if let lat = self.getLatitude() {
            let hash = "{:location-id :ch, :stops {\"\(self.st_id)\" {:id \"\", :name \"\(self.name)\", :location {:lat \(lat), :lng \(self.getLongitude()!)}, :known-destinations ()}}, :stops-order [\"\(self.st_id)\"]}"
            let utf8hash = hash.dataUsingEncoding(NSISOLatin1StringEncoding)
            if let base64 = utf8hash?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0)) {
                return NSURL(string: "http://www.timeforcoffee.ch/#/link/\(base64)")
            }
        }
        return nil
    }

    private func updateGeolocationInfo() {
        let iso = realmObject?.countryISO
        if (iso == nil || iso == "") {
            let geocoder = CLGeocoder()
            if let coordinates = self.coord {
                geocoder.reverseGeocodeLocation(coordinates) { (places:[CLPlacemark]?, error:NSError?) -> Void in
                    if let place = places?.first {
                        if self.realmObject?.fault == false {
                            if let city = place.locality {
                                self.realmObject?.city = city
                            }

                            if let county = place.administrativeArea {
                                self.realmObject?.county = county
                            }
                            if let iso = place.ISOcountryCode {
                                self.realmObject?.countryISO = iso
                            }
                        } else {
                            DLog("object \(self.name) could not be saved: \(self.realmObject?.faultingState)")
                        }
                    } else {
                        if (error != nil) {
                            DLog("\(self.name) error getting Location data: \(error!.userInfo)")
                        }
                    }
                }
            }
        }
    }

    public func getCountryISO() -> String {
        var iso = realmObject?.countryISO
        if (iso == nil) {           
            iso = ""
        }
        return iso!
    }

    public func getDeparturesURL(startTime:NSDate? = nil) -> String {
        if  let url = self.realmObject?.departuresURL {
            return url
        }

        let country = self.getCountryISO()
        if let startTime = startTime {
            let formattedDate = startTime.formattedWith("yyyy-MM-dd'T'HH:mm")
            if (country == "CH") {
                return "https://tfc.chregu.tv/api/zvv/stationboard/\(self.st_id)/\(formattedDate)"
            }
            return "https://transport.opendata.ch/v1/stationboard?id=\(self.st_id)&limit=40&datetime=\(formattedDate)"
        }
        if (country == "CH") {
            return "https://tfc.chregu.tv/api/ch/stationboard/\(self.st_id)"
        }
        return "https://transport.opendata.ch/v1/stationboard?id=\(self.st_id)&limit=40"
    }
}

public protocol TFCDeparturesUpdatedProtocol {
    func departuresUpdated(error: NSError?, context: Any?, forStation: TFCStation?)
    func departuresStillCached(context: Any?, forStation: TFCStation?)
}


