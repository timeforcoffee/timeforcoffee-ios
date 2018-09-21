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

open class TFCStationBase: NSObject, NSCoding, APIControllerProtocol {

    open var name: String {
        get {
            if (self._name == nil) {
                TFCDataStore.sharedInstance.managedObjectContext.performAndWait {
                    self._name = self.realmObject?.name
                    if (self._name == "" || self._name == nil) {
                        self._name = "unknown"
                    }
                }
            }
            return _name!
        }
        set(name) {
            self._name = name
            TFCDataStore.sharedInstance.managedObjectContext.perform {
                if (name != self.realmObject?.name) {
                    var name2 = name
                    if (name2 == "") {
                        name2 = "unknown"
                    }
                    DLog("set new name in DB for \(name2) \(self.st_id)")
                    self.realmObject?.name = name2
                    self.realmObject?.lastUpdated = Date()
                    self._name = name2
                }
            }
        }
    }

    fileprivate lazy var activity : NSUserActivity = {
        [unowned self] in
        NSUserActivity(activityType: "ch.opendata.timeforcoffee.station")
        }()
    
    #if DEBUG
    static var InstanceCounter:Int = 0
    static var instances:[String:Int] = [:]
    #endif

    static var stationsCache:[String:WeakBox<TFCStation>] = [:]
    fileprivate var _name: String?

    open var coord: CLLocation? {
        get {
            if (self._coord != nil) {
                return self._coord
            }
            TFCDataStore.sharedInstance.managedObjectContext.performAndWait {
                if let lat = self.realmObject?.latitude?.doubleValue,
                    let lon = self.realmObject?.longitude?.doubleValue {
                    self._coord = CLLocation(latitude: lat, longitude: lon)
                }
            }
            return self._coord
        }
        set(location) {
            self._coord = location
            if let lat = location?.coordinate.latitude, let lon = location?.coordinate.longitude {
                TFCDataStore.sharedInstance.managedObjectContext.perform {
                    if (self.realmObject?.latitude  == nil ||
                        self.realmObject?.longitude == nil ||
                        self.coord == nil ||
                        self.coord!.distance(from: CLLocation(latitude: self.realmObject!.latitude as! Double , longitude: self.realmObject!.longitude as! Double)) > 10) {
                        self.realmObject?.latitude = lat as NSNumber
                        self.realmObject?.longitude = lon as NSNumber
                        self.realmObject?.lastUpdated = Date()
                        DLog("updateGeolocationInfo for \(self.name)")
                        self.updateGeolocationInfo()
                    }
                }
            }
        }
    }

    fileprivate var _coord: CLLocation?

    open var st_id: String

    fileprivate var _departures: [String:TFCDeparture]? = nil
    fileprivate var _departuresObsolete:Bool = true
    fileprivate var lastRemovedDepartures:Double? = nil
    fileprivate var departures: [String:TFCDeparture]? {
        get {
            if (_departuresObsolete) {
                let cache = TFCCache.objects.stations
                _departures = cache.object(forKey: "dept_\(st_id)") as! [String:TFCDeparture]?
                _departuresObsolete = false
            }
            return _departures
        }
        set {
            filteredDepartures = nil
            departuresSorted = nil
            _departures = newValue
        }
    }

    open var needsCacheSave:Bool = false
    fileprivate var departuresSorted: [TFCDeparture]?
    fileprivate var filteredDepartures: [TFCDeparture]?

    open var calculatedDistance: Double? {
        get {
            guard let currentLoc = TFCLocationManager.getCurrentLocation() else { return nil }
            // recalculate distance when we're more than 50m away
            if (_calculatedDistanceLastCoord == nil || _calculatedDistanceLastCoord!.distance(from: currentLoc) > 50.0) {
                _calculatedDistanceLastCoord = currentLoc
                if let coord = self.coord {
                    _calculatedDistance = currentLoc.distance(from: coord)
                    // don't store it on watchOS, it's slower than calculating it on startup
                    #if os(watchOS)
                    #else
                        DispatchQueue.global(qos: .utility).async {
                            let cache: PINCache = TFCCache.objects.stations
                            cache.setObject(self, forKey: self.st_id)
                        }
                    #endif
                }

            }
            return _calculatedDistance
        }
    }

    fileprivate var _calculatedDistance: Double? = nil

    var _calculatedDistanceLastCoord: CLLocation? = nil

    var walkingDistanceString: String? = nil {
        didSet {
            self.needsCacheSave = true
        }
    }
    var walkingDistanceLastCoord: CLLocation? = nil
    open var lastDepartureUpdate: Date? = nil
    fileprivate var lastDepartureCount: Int? = nil

    fileprivate var lastSettingsRead: Date

    fileprivate var departureUpdateDownloading: Date? = nil

    open var isLastUsed: Bool = false

    fileprivate struct objects {
        static let  dataStore: TFCDataStore? = TFCDataStore.sharedInstance
    }

    fileprivate lazy var api : APIController = {
        [unowned self] in
        return APIController(delegate: self)
    }()

    struct contextData {
        var completionDelegate: TFCDeparturesUpdatedProtocol? = nil
        var hasStartTime: Bool = false
        var onlyFirstDownload: Bool = false
        var context: Any? = nil
    }

    fileprivate lazy var filteredLines:[String: [String: Bool]] = {
        [unowned self] in
        return self.getFilteredLines()
    }()

    fileprivate lazy var favoriteLines:[String: [String: Bool]] = {
        [unowned self] in
        return self.getFavoriteLines()
    }()


    fileprivate lazy var realmObject:TFCStationModel? = {
        [unowned self] in
        var result:TFCStationModel? = nil
        TFCDataStore.sharedInstance.managedObjectContext.performAndWait {

            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TFCStationModel")
            do {
                let pred = NSPredicate(format: "id == %@", self.st_id)
                fetchRequest.predicate = pred
                if let results = try TFCDataStore.sharedInstance.managedObjectContext.fetch(fetchRequest) as? [TFCStationModel] {
                    if let first = results.first {
                        result = first
                        return
                    }
                }
            } catch let error as NSError {
                DLog("Could not fetch \(error), \(error.userInfo)")
            }

            if let obj = NSEntityDescription.insertNewObject(forEntityName: "TFCStationModel", into: TFCDataStore.sharedInstance.managedObjectContext) as? TFCStationModel {
                obj.id = self.st_id
                result = obj
                return
            }
            #if DEBUG
                DLog("WARNING: realmObject IS NIL!!!! ", toFile: true)
            #endif
        }
        return result
    }()



    public init(name: String, id: String, coord: CLLocation?) {
        self.st_id = id
        self.lastSettingsRead = Date()
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
        self.lastSettingsRead = Date()
        super.init()
        self.instanceCounter("id")

    }

    fileprivate func instanceCounter(_ name: String) {
        #if DEBUG
        TFCStationBase.InstanceCounter += 1;
        //DLog("init stationbase \(name) \(self.st_id) \(TFCStationBase.InstanceCounter)");

        if let count = TFCStationBase.instances[self.st_id] {
            TFCStationBase.instances[self.st_id] = count + 1
        } else {
            TFCStationBase.instances[self.st_id] = 1
        }
        if (TFCStationBase.instances[self.st_id]! > 1) {
            DLog("WARN: init of \(self.st_id) \(self.name) has \(String(describing: TFCStationBase.instances[self.st_id])) instances ", toFile: true)
/*           let stacktrace = Thread.callStackSymbols
            DLog("stacktrace start", toFile: true)
            for line in stacktrace {
                DLog("stack \(line)", toFile: true)
            }
            DLog("stacktrace end", toFile: true)*/
        }
        #endif
    }

    public required init?(coder aDecoder: NSCoder) {
        self.lastSettingsRead = Date()
        do {
            if #available(iOSApplicationExtension 9.0, *) {
                self.st_id = try aDecoder.decodeTopLevelObject(forKey: "st_id") as! String
            } else {
                self.st_id = aDecoder.decodeObject(forKey: "st_id") as! String
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
                self.walkingDistanceString = try aDecoder.decodeTopLevelObject(forKey: "walkingDistanceString") as! String?
                self.walkingDistanceLastCoord = try aDecoder.decodeTopLevelObject(forKey: "walkingDistanceLastCoord") as! CLLocation?
                self._calculatedDistance = try aDecoder.decodeTopLevelObject(forKey: "_calculatedDistance") as! Double?
                self._calculatedDistanceLastCoord = try aDecoder.decodeTopLevelObject(forKey: "_calculatedDistanceLastCoord") as! CLLocation?
            } else {
                self.walkingDistanceString = aDecoder.decodeObject(forKey: "walkingDistanceString") as! String?
                self.walkingDistanceLastCoord = aDecoder.decodeObject(forKey: "walkingDistanceLastCoord") as! CLLocation?
                self._calculatedDistance = aDecoder.decodeObject(forKey: "_calculatedDistance") as! Double?
                self._calculatedDistanceLastCoord = aDecoder.decodeObject(forKey: "_calculatedDistanceLastCoord") as! CLLocation?
            }
        } catch let (err) {
            DLog("Decoder error: \(err)", toFile: true)
        }
    }

    open func encode(with aCoder: NSCoder) {
        aCoder.encode(st_id, forKey: "st_id")
        aCoder.encode(walkingDistanceString, forKey: "walkingDistanceString")
        aCoder.encode(walkingDistanceLastCoord, forKey: "walkingDistanceLastCoord")
        aCoder.encode(_calculatedDistance, forKey: "_calculatedDistance")
        aCoder.encode(_calculatedDistanceLastCoord, forKey: "_calculatedDistanceLastCoord")
    }

    deinit {
        #if DEBUG
        TFCStationBase.InstanceCounter -= 1;
        if let count = TFCStationBase.instances[self.st_id] {
            TFCStationBase.instances[self.st_id] = count - 1
        }
        //DLog("deinit stationbase \(self.st_id) \(self.name) \(TFCStationBase.InstanceCounter)")
        #endif
    }

    override public convenience init() {
        self.init(name: "doesn't exist", id: "0000", coord: nil)
    }

    open class func saveToPincache(_ saveStation: TFCStationBase) {
        if (saveStation.needsCacheSave)  {
            let cache: PINCache = TFCCache.objects.stations
            //immediatly set to memory cache
            cache.memoryCache.setObject(saveStation, forKey: saveStation.st_id)
           // DLog("set PinCache for \(saveStation.name) \(saveStation.st_id)")


            cache.setObject(saveStation, forKey: saveStation.st_id , block: { (_: PINCache, _: String, _: AnyObject?) in
                } as? PINCacheObjectBlock)
            saveStation.needsCacheSave = false

        }
    }

    open func departuresSaveToPincache() {
        //immediatly set to memory cache
        let cache = TFCCache.objects.stations
        if let dept = _departures {
            cache.memoryCache.setObject(dept, forKey: "dept_\(st_id)")
           // DLog("set PinCache Departures for \(name) \(st_id)", toFile: true)
            cache.setObject(dept as NSDictionary, forKey: "dept_\(st_id)", block: { (_: PINCache, _: String, _: AnyObject?) in
                } as? PINCacheObjectBlock)
        } else {
            cache.removeObject(forKey: "dept_\(st_id)", block: {  (_: PINCache, _: String, _: AnyObject?) in
                } as? PINCacheObjectBlock)
        }
    }

    open class func initWithCache(_ name: String = "", id: String, coord: CLLocation? = nil) -> TFCStation? {
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
       
        let newStation: TFCStation? = cache.object(forKey: trimmed_id) as? TFCStation
        //if not in the cache, or no coordinates set or the name is "unknown"
        if (newStation == nil || newStation?.coord == nil || newStation?.name == "unknown") {
            //if name is not set, we only have the id, try to get it from the DB or from a server
            if (name == "") {
                let tryStation:TFCStation
                if (newStation != nil) {
                    tryStation = newStation!
                } else {
                    // try to get it from core data
                    tryStation = TFCStation(id: trimmed_id)
                }
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
                DLog("Station Name missing. Fetch station info from opendata.ch for \(trimmed_id)", toFile: true)
                api.getStationInfo(trimmed_id, callback: { (result) in
                    if let result = result, let name = result["stations"][0]["name"].string {
                        if let id = result["stations"][0]["id"].string?.replace("^0*", template: "") {
                            var location:CLLocation? = nil
                            if let lat = result["stations"][0]["coordinate"]["x"].double {
                                if let long = result["stations"][0]["coordinate"]["y"].double {
                                    location = CLLocation(latitude: lat, longitude: long)
                                }
                            }
                            // try again, this time with a name
                            DLog("Station Name missing fetched. Fetched station info from opendata.ch for \(id)", toFile: true)

                            if let newStation = getFromMemoryCaches(id) {
                                DLog("Station Name missing save. Save station info from opendata.ch for \(id)", toFile: true)
                                newStation.name = name
                                newStation.coord = location
                                newStation.needsCacheSave = true
                                addToStationCache(newStation)
                                TFCStationBase.saveToPincache(newStation)

                            } else {
                                DLog("Station Name missing not in memoryCaches. Try to save station info from opendata.ch for \(id)", toFile: true)
                                if let newStation = TFCStation.initWithCache(name, id: id, coord: location) {
                                    DLog("Station Name missing not in memoryCaches. Saved station info from opendata.ch for \(id)", toFile: true)
                                    newStation.needsCacheSave = true
                                    addToStationCache(newStation)
                                    TFCStationBase.saveToPincache(newStation)
                                } else {
                                    DLog("Station Name missing not in memoryCaches on not inited. Info from opendata.ch for \(id)", toFile: true)
                                }
                            }
                        }
                    } else {
                        DLog("Something went wrong with fetching data")
                    }
                })
                return tryStation
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
            if let newStation = newStation {
                newStation.filteredLines = newStation.getFilteredLines()
                // if country is not set, try updating it
                if (newStation.getCountryISO() == "") {
                    newStation.updateGeolocationInfo()
                }
                newStation.favoriteLines = newStation.getFavoriteLines()
            }
        }
        if let newStation = newStation {
            addToStationCache(newStation)
            return newStation
        }
        return nil
    }

    open class func getFromMemoryCaches(_ id: String) -> TFCStation? {
        let cache: PINCache = TFCCache.objects.stations

        // if already in the PINCcache cache, we can just return it
        if let newStation = cache.memoryCache.object(forKey: id as String?) as? TFCStation {
            return newStation
        }
        // check if we have it in the stationCache
        if let newStation = stationsCache[id]?.value {
            cache.memoryCache.setObject(newStation, forKey: id)
            return newStation
        }
        return nil
    }

    open class func countStationsCache() -> Int {
        for (id, station) in stationsCache {
            if (station.value == nil) {
                stationsCache.removeValue(forKey: id)
            }
        }
        return stationsCache.count

    }

    open class func addToStationCache(_ station: TFCStation) {
        TFCStationBase.stationsCache[station.st_id] = WeakBox(station)
    }

    open class func initWithCache(_ dict: [String: String]) -> TFCStation? {
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
        if let st_id = dict["st_id"] {
            return initWithCacheId(st_id, name: name, coord: location)
        }
        return initWithCacheId("", name: name, coord: location)

    }

    open class func initWithCacheId(_ id:String, name:String = "", coord: CLLocation? = nil)-> TFCStation? {
        return initWithCache(name, id: id, coord: coord)
    }

    open class func isStations(_ results: JSON) -> Bool {
        if (results["stations"].array != nil) {
            return true
        }
        return false
    }
    
    open func isFavorite() -> Bool {
        return TFCStations.isFavoriteStation(self.st_id);
    }

    open func toggleFavorite() {
        if (self.isFavorite() == true) {
            self.unsetFavorite()
        } else {
            self.setFavorite()
        }
    }

    open func setFavorite() {
        TFCFavorites.sharedInstance.set(self as? TFCStation)
        DLog("just before updateGeofences", toFile:true)
        TFCFavorites.sharedInstance.updateGeofences()
    }

    open func unsetFavorite() {
        TFCFavorites.sharedInstance.unset(station: self as? TFCStation)
        DLog("just before updateGeofences", toFile:true)
        TFCFavorites.sharedInstance.updateGeofences()
    }

    open func getLongitude() -> Double? {
        return coord?.coordinate.longitude
    }

    open func getLatitude() -> Double? {
        return coord?.coordinate.latitude
    }
    
    open func getName(_ cityAfter: Bool) -> String {
        if (cityAfter && name.matchRegex(TFCDeparture.commaStarRegex)) {
            let stationName = name.replaceRegex(TFCDeparture.starCommaStarRegex, template: "")
            let cityName = name.replaceRegex(TFCDeparture.commaSpaceStarRegex, template: "")
            return "\(stationName) (\(cityName))"
        }
        return name
    }

    open func getNameAbridged() -> String {
        return self.name.replace(".*,[ ]*", template: "")
    }

    open func getNameWithStar() -> String {
        return getNameWithStar(false)
    }
    
    open func getNameWithStar(_ cityAfter: Bool) -> String {
        if self.isFavorite() {
            return "\(getName(cityAfter)) ★"
        }
        return getName(cityAfter)
    }

    open func getNameWithFilters(_ cityAfter: Bool) -> String {
        return "\(getName(cityAfter))\(getFilterSign())"
    }

    fileprivate func getFilterSign() -> String {
        if (self.hasFilters()) {
            return " ✗"
        }
        return ""
    }

    open func getNameWithStarAndFilters() -> String {
        return getNameWithStarAndFilters(false)
    }
    
    open func getNameWithStarAndFilters(_ cityAfter: Bool) -> String {
        return "\(getNameWithStar(cityAfter))\(getFilterSign())"
    }
    
    open func hasFilters() -> Bool {
        return (filteredLines.count > 0 || hasFavoriteDepartures())
    }
    open func hasFavoriteDepartures() -> Bool {
        return favoriteLines.count > 0
    }

    fileprivate func getMarkedLines(_ favorite: Bool) -> [String: [String: Bool]] {
        if (favorite) {
            return favoriteLines
        }
        return filteredLines
    }

    fileprivate func isMarkedDeparture(_ departure: TFCDeparture, favorite: Bool) -> Bool {
        var lines = getMarkedLines(favorite)
        if (lines[departure.getLine()] != nil) {
            if (lines[departure.getLine()]?[departure.getDestination()] != nil) {
                return true
            }
        }
        return false
    }

    open func isFavoriteDeparture(_ departure: TFCDeparture) -> Bool {
        return isMarkedDeparture(departure, favorite: true)
    }

    open func isFilteredDeparture(_ departure: TFCDeparture) -> Bool {
        return isMarkedDeparture(departure, favorite: false)
    }

    open func showAsFavoriteDeparture(_ departure: TFCDeparture) -> Bool {
        if (favoriteLines.count > 0) {
            return isFavoriteDeparture(departure)
        }
        if (filteredLines.count > 0) {
            return !isFilteredDeparture(departure)
        }
        return false
    }

    fileprivate func setMarkedDeparture(_ departure: TFCDeparture, favorite: Bool) {
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

    open func setFavoriteDeparture(_ departure: TFCDeparture) {
        setMarkedDeparture(departure, favorite: true)
    }

    open func setFilterDeparture(_ departure: TFCDeparture) {
        setMarkedDeparture(departure, favorite: false)
    }

    fileprivate func unsetMarkedDeparture(_ departure: TFCDeparture, favorite: Bool) {
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

    open func unsetFavoriteDeparture(_ departure: TFCDeparture) {
        unsetMarkedDeparture(departure, favorite: true)
    }
    
    open func unsetFilterDeparture(_ departure: TFCDeparture) {
        unsetMarkedDeparture(departure, favorite: false)
    }

    fileprivate func getDataStoreKey(_ id: String, favorite: Bool) -> String {
        if (favorite) {
            return "favorite\(id)"
        }
        return "filtered\(id)"
    }

    fileprivate func saveMarkedLines(_ lines: [String: [String: Bool]], favorite: Bool) {
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
        TFCDataStore.sharedInstance.getUserDefaults()?.set(Date(), forKey: "settingsLastUpdate")

    }

    fileprivate func getMarkedLinesShared(_ favorite: Bool) -> [String: [String: Bool]] {
        let key = getDataStoreKey(st_id, favorite: favorite)
        var markedDestinationsShared: [String: [String: Bool]]? =  [:]
//FIXME: was mutableCopy before... in swift 2.3

        markedDestinationsShared = objects.dataStore?.objectForKey(key) as? [String: [String: Bool]]

        guard let markedDestinationsShared2 = markedDestinationsShared else { return [:] }
        return markedDestinationsShared2
    }

    fileprivate func getFavoriteLines() -> [String: [String: Bool]] {
        return getMarkedLinesShared(true)
    }

    open func repopulateFavoriteLines() {
        self.favoriteLines = self.getFavoriteLines()
    }

    fileprivate func getFilteredLines() -> [String: [String: Bool]] {
        return getMarkedLinesShared(false)
    }

    func addDepartures(_ departures: [TFCDeparture]?) {
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
                self.departuresSaveToPincache()
            }
        }
    }

    open func getDepartures() -> [TFCDeparture]? {
        if let alreadySorted = self.departuresSorted {
            return alreadySorted
        }
        if let depts = self.departures?.values {
            let sorted = depts.sorted(by: { (s1, s2) -> Bool in
                if s1.sortTime == s2.sortTime {
                    if (s1.sortOrder == nil) {
                        return true
                    } else if (s2.sortOrder == nil) {
                        return false
                    }
                    return s1.sortOrder! < s2.sortOrder!
                }
                if (s1.sortTime == nil || s2.sortTime == nil) {
                    return true
                }
                return s1.sortTime! < s2.sortTime!
            })
            self.departuresSorted = sorted
            return sorted
        }
        return nil
    }

    open func getFilteredDepartures(_ count:Int? = nil, fallbackToAll:Bool = false) -> [TFCDeparture]? {
        if (filteredDepartures != nil) {
            return filteredDepartures
        }
        if (!hasFilters()) {
            self.filteredDepartures = getDepartures()
        } else if (self.departures != nil) {
            filteredDepartures = []
            for (departure) in self.getDepartures()! {
                if (self.showAsFavoriteDeparture(departure)) {
                    filteredDepartures?.append(departure)
                }
            }
        }
        if (fallbackToAll == true && (self.filteredDepartures == nil || self.filteredDepartures?.count == 0)) {
            self.filteredDepartures = getDepartures()
        }

        if count != nil && filteredDepartures != nil {
            self.filteredDepartures  = Array(filteredDepartures!.prefix(count!))
        }
        return filteredDepartures
    }

    open func getScheduledFilteredDepartures() -> [TFCDeparture]? {
        let depts = self.getFilteredDepartures()
        if let depts = depts {
            let sorted = depts.sorted(by: { (s1, s2) -> Bool in
                if let t1 = s1.getScheduledTimeAsNSDate(),
                    let t2 =  s2.getScheduledTimeAsNSDate() {
                    return t1 < t2
                }
                return false
            })
            var i = 0
            //dont add departures which may go away pretty soon anyway again
            // that's why we only go back 50 seconds and not the full 60
            
            let aMinuteAgo = Date().addingTimeInterval(-50)
            var newSorted = sorted
            for departure in sorted {
                if let t = departure.getScheduledTimeAsNSDate(), t < aMinuteAgo {
                    if (newSorted.indices.contains(i)) {
                        newSorted.remove(at: i)
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

    open func updateDepartures(_ completionDelegate: TFCDeparturesUpdatedProtocol?, force: Bool = false, context: Any? = nil, cachettl:Int = 20, startTime:Date? = nil, onlyFirstDownload:Bool = false) {

        let removedDepartures = removeObsoleteDepartures()

        // If a download is already running for this station and it started less than 5 seconds ago, wait..
        // This way we prevent multiple parallel downloads (especially from the today extension)
        // somehow ugly, but couldn't come up with a better solution
        if let downloadingSince = self.departureUpdateDownloading {
            if (downloadingSince.timeIntervalSinceNow > -5) {
                let delayTime = Double.random(0.7, max: 1.2)
                delay(delayTime, closure: {
                      self.updateDepartures(completionDelegate, force: force, context: context, cachettl: cachettl, startTime: startTime, onlyFirstDownload: true)
                    }
                    )
                return
            }
        }

        DispatchQueue.global(qos: .default).async {
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
                if (!removedDepartures) {
                    if let m = first.getMinutesAsInt(), (m > 30 && !first.isRealTime()) {
                        dontUpdate = true
                    }
                }
            }
            let settingsLastUpdated: Date? = TFCDataStore.sharedInstance.getUserDefaults()?.object(forKey: "settingsLastUpdate") as! Date?
            // if settings were changed since the last DepartureUpdate, reload favorite Lines
            var settingsChanged = false
            if (settingsLastUpdated != nil && self.lastSettingsRead.timeIntervalSince(settingsLastUpdated!) < 0) {
                DLog("reload filtered Lines for \(self.name)", toFile: true)
                self.filteredLines = self.getFilteredLines()
                self.favoriteLines = self.getFavoriteLines()
                self.lastSettingsRead = Date()
                settingsChanged = true
            }
            if (force || settingsChanged ||
                    (!dontUpdate &&
                        (self.lastDepartureUpdate == nil ||
                         Int((self.lastDepartureUpdate?.timeIntervalSinceNow)!) < -cachettl)
                    )
                )
            {
                self.departureUpdateDownloading = Date()
                self.api.getDepartures(self as! TFCStation, context: context2, startTime: startTime)

            } else {
                DispatchQueue.main.async(execute: {
                    completionDelegate?.departuresStillCached(context2.context, forStation: self as? TFCStation)
                    return  
                })
            }
        }
    }

    open func didReceiveAPIResults(_ results: JSON?, error: Error?, context: Any?) {
        let contextInfo: contextData? = context as! contextData?
        var lastScheduledBefore:Date? = nil
        if (results == nil || (error != nil && self.departures != nil && self.departures!.count > 0)) {
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

            self.lastDepartureUpdate = Date()
            self.departureUpdateDownloading = nil
            contextInfo?.completionDelegate?.departuresUpdated(error, context: contextInfo?.context, forStation: self as? TFCStation)

            if (contextInfo?.onlyFirstDownload != true) {
                // get last entry and get more data in case we want more into the future
                if let lastScheduled = self.getLastDepartureDate() {
                    //prevent loop in case we don't get new data
                    if (lastScheduledBefore == nil || lastScheduledBefore!.timeIntervalSinceReferenceDate < lastScheduled.timeIntervalSinceReferenceDate) {
                        // either go 2 hours into the future or at least until 8 o'clock in the morning (if the last one is after midnight and not more than 10 hours away)
                        let hours:Double
                        let doMorning:Bool
                        var doIt:Bool = true
                        #if os(watchOS)
                            hours = 1.0
                            doMorning = false
                            // dont get more than 9 on watch to save some CPU, we don't show more anyway
                            if let c = self.getFilteredDepartures()?.count, c > 8 {
                                doIt = false
                            }
                        #else
                            hours = 2.0
                            doMorning = true
                        #endif
                        if (doIt && (
                                (lastScheduled.addingTimeInterval(hours * -3600).timeIntervalSinceNow < 0)
                                || (doMorning
                                    && ((lastScheduled.timeIntervalSince(Calendar.current.startOfDay(for: lastScheduled)) < 3600 * 8)
                                        && (lastScheduled.addingTimeInterval(10 * -3600).timeIntervalSinceNow < 0)
                                        )
                                    )
                                )
                            ) {
                            self.updateDepartures(contextInfo?.completionDelegate, force: true, context: contextInfo?.context, startTime: lastScheduled)
                        }
                    }
                }
            }





    }
    fileprivate func getLastDepartureDate() -> Date? {
        return self.getDepartures()?.last?.getScheduledTimeAsNSDate()
    }


    fileprivate func setDeparturesAsOutdated() {
        if let departures = self.getDepartures() {
            for (departure) in  departures {
                departure.outdated = true
            }
        }
    }

    func clearDepartures() {
        self.departures = nil
    }

    open func removeObsoleteDepartures(_ force:Bool = false) -> Bool {
        if (force == false && (lastRemovedDepartures != nil && floor(Date.timeIntervalSinceReferenceDate / 60) == lastRemovedDepartures)) {
            return false
        }
        if (departures == nil || departures?.count == 0) {
            return false
        }
        var i = 0;
        var someRemoved = false
        if let depts = self.getDepartures() {
            // if all are in the past, just removeAll
            if let m = depts.last?.getMinutesAsInt(), m < 0 {
                departures?.removeAll()
            } else {
                for departure in depts {
                    if let m = departure.getMinutesAsInt(), m < 0 {
                        i += 1
                        someRemoved = true
                        let _ = departures?.removeValue(forKey: departure.getKey())
                    } else {
                        //if we find one, which is not obsoelte, we can stop here
                        break
                    }
                }
            }
        }

        if (departures?.count == 0) {
            clearDepartures()
            someRemoved = true
        }
        if (someRemoved) {
            self.departuresSaveToPincache()
        }
        DLog("removeObsoleteDepartures for \(self.name) \(someRemoved)", toFile: true)
        lastRemovedDepartures = floor(Date.timeIntervalSinceReferenceDate / 60)
        return someRemoved
    }

    open func removeDeparturesFromMemory() {
        self._departuresObsolete = true
        self._departures = nil
        self.departuresSorted = nil
    }

    open func getAsDict() -> [String: String] {
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

    open func getIconIdentifier() -> String {
        if (isFavorite()) {
            if (st_id == "8591306") {
                return "stationicon-liip"
            }
            return "stationicon-star"
        }
        return "stationicon-pin"
    }

    open func getIcon() -> UIImage {
        return UIImage(named: getIconIdentifier())!
    }

    open func setStationActivity() {
    }

    open func setStationSearchIndex() {
    }

    open func getWebLink() -> URL? {
        //        {:location-id :ch_zh, :stops {"008591195" {:id "008591195", :name "Zürich, Höfliweg", :location {:lat 47.367569, :lng 8.51095}, :known-destinations ()}}, :stops-order ["008591195"]
        if (self.getCountryISO() != "CH" && self.getCountryISO() != "") {
            return URL(string: "http://fahrplan.sbb.ch/bin/stboard.exe/dn?input=\(self.st_id)&REQTrain_name=&boardType=dep&time=now&productsFilter=1111111111&selectDate=today&maxJourneys=20&start=yes")
        }
        if let lat = self.getLatitude() {
            let hash = "{:location-id :ch, :stops {\"\(self.st_id)\" {:id \"\", :name \"\(self.name)\", :location {:lat \(lat), :lng \(self.getLongitude()!)}, :known-destinations ()}}, :stops-order [\"\(self.st_id)\"]}"
            let utf8hash = hash.data(using: String.Encoding.isoLatin1)
            if let base64 = utf8hash?.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0)) {
                return URL(string: "http://www.timeforcoffee.ch/#/link/\(base64)")
            }
        }
        return nil
    }

    fileprivate func updateGeolocationInfo() {
        TFCDataStore.sharedInstance.managedObjectContext.perform {
            let iso = self.realmObject?.countryISO
            if (iso == nil || iso == "") {
                let geocoder = CLGeocoder()
                if let coordinates = self.coord {
                    geocoder.reverseGeocodeLocation(coordinates) { (places:[CLPlacemark]?, error:Error?) -> Void in
                        if let place = places?.first {
                            if self.realmObject?.isFault == false {
                                if let city = place.locality {
                                    self.realmObject?.city = city
                                }

                                if let county = place.administrativeArea {
                                    self.realmObject?.county = county
                                }
                                if let iso = place.isoCountryCode {
                                    self.realmObject?.countryISO = iso
                                }
                            } else {
                                DLog("object \(self.name) could not be saved: \(String(describing: self.realmObject?.faultingState))")
                            }
                        } else {
                            if (error != nil) {
                                DLog("\(self.name) error getting Location data: \(error!)")
                            }
                        }
                    }
                }
            }
        }
    }

    open func getCountryISO() -> String {
        var iso:String? = ""
        TFCDataStore.sharedInstance.managedObjectContext.performAndWait {
            iso = self.realmObject?.countryISO
            if (iso == nil) {
                iso = ""
            }
        }
        return iso!
    }

    open func getDeparturesURL(_ startTime:Date? = nil) -> String {
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
    func departuresUpdated(_ error: Error?, context: Any?, forStation: TFCStation?)
    func departuresStillCached(_ context: Any?, forStation: TFCStation?)
}


