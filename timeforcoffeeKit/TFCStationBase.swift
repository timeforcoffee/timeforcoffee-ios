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
            if let lat = location?.coordinate.latitude, lon = location?.coordinate.longitude {
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

    private var departures: [TFCDeparture]? = nil {
        didSet {
            filteredDepartures = nil
        }
    }

    private var filteredDepartures: [TFCDeparture]?

    public var calculatedDistance: Double? {
        get {
            guard let currentLoc = TFCLocationManager.getCurrentLocation() else { return nil }

            if (currentLoc.coordinate.longitude != _calculatedDistanceLastCoord?.coordinate.longitude) {
                _calculatedDistanceLastCoord = currentLoc
                if let coord = self.coord {
                    _calculatedDistance = currentLoc.distanceFromLocation(coord)
                    let cache: PINCache = TFCCache.objects.stations
                    cache.setObject(self, forKey: st_id)
                }
            }
            return _calculatedDistance
        }
    }

    private var _calculatedDistance: Double? = nil
    var _calculatedDistanceLastCoord: CLLocation?

    var walkingDistanceString: String?
    var walkingDistanceLastCoord: CLLocation?
    private var lastDepartureUpdate: NSDate?
    private var lastDepartureCount: Int?

    private var departureUpdateDownloading: NSDate?

    public var isLastUsed: Bool = false
    public var serializeDepartures: Bool = true

    private struct objects {
        static let  dataStore: TFCDataStore? = TFCDataStore()
    }

    private lazy var api : APIController = {
        [unowned self] in
        return APIController(delegate: self)
    }()

    struct contextData {
        var completionDelegate: TFCDeparturesUpdatedProtocol? = nil
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
        return nil
    }()



    public init(name: String, id: String, coord: CLLocation?) {
        self.st_id = id
        super.init()
        self.name = name

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
    }

    public required init?(coder aDecoder: NSCoder) {
        self.st_id = aDecoder.decodeObjectForKey("st_id") as! String
        super.init()
        self.departures = aDecoder.decodeObjectForKey("departures") as! [TFCDeparture]?
        if (self.departures?.count == 0) {
            self.departures = nil
        }
        self.walkingDistanceString = aDecoder.decodeObjectForKey("walkingDistanceString") as! String?
        self.walkingDistanceLastCoord = aDecoder.decodeObjectForKey("walkingDistanceLastCoord") as! CLLocation?
        self._calculatedDistance = aDecoder.decodeObjectForKey("_calculatedDistance") as! Double?
        self._calculatedDistanceLastCoord = aDecoder.decodeObjectForKey("_calculatedDistanceLastCoord") as! CLLocation?
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(st_id, forKey: "st_id")
        if (serializeDepartures) {
            aCoder.encodeObject(departures, forKey: "departures")
        }
        aCoder.encodeObject(walkingDistanceString, forKey: "walkingDistanceString")
        aCoder.encodeObject(walkingDistanceLastCoord, forKey: "walkingDistanceLastCoord")
        aCoder.encodeObject(_calculatedDistance, forKey: "_calculatedDistance")
        aCoder.encodeObject(_calculatedDistanceLastCoord, forKey: "_calculatedDistanceLastCoord")
    }

    override public convenience init() {
        self.init(name: "doesn't exist", id: "0000", coord: nil)
    }

    public class func initWithCache(name: String, id: String, coord: CLLocation?) -> TFCStation {
        let trimmed_id = id.replace("^0*", template: "")
        let cache: PINCache = TFCCache.objects.stations
        // try to find it in the cache
        var newStation: TFCStation? = cache.objectForKey(trimmed_id) as? TFCStation
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
                        cache.setObject(tryStation, forKey: tryStation.st_id)
                        tryStation.setStationSearchIndex()
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
            newStation = TFCStation(name: name, id: trimmed_id, coord: coord)
            //only cache it when name is != "" otherwise it comes
            // from something with only the id
            if (name != "" && newStation?.st_id != "" && newStation?.coord != nil) {
                    cache.setObject(newStation!, forKey: newStation!.st_id)
                    newStation!.setStationSearchIndex()
            }
        } else {
            let countBefore = newStation!.departures?.count
            if (countBefore > 0) {
                newStation!.removeObsoleteDepartures()
                if (countBefore > newStation!.departures?.count) {
                    cache.setObject(newStation!, forKey: newStation!.st_id)
                }
            }
            newStation!.filteredLines = newStation!.getFilteredLines()
            // if country is not set, try updating it
            if (newStation!.getCountryISO() == "") {
                newStation!.updateGeolocationInfo()
            }
            newStation!.favoriteLines = newStation!.getFavoriteLines()
        }
        return newStation!
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
    }

    public func unsetFavorite() {
        TFCFavorites.sharedInstance.unset(station: self as? TFCStation)
    }

    public func getLongitude() -> Double? {
        return coord?.coordinate.longitude
    }

    public func getLatitude() -> Double? {
        return coord?.coordinate.latitude
    }
    
    public func getName(cityAfter: Bool) -> String {
        if (cityAfter && name.match(", ")) {
            let stationName = name.replace(".*, ", template: "")
            let cityName = name.replace(", .*", template: "")
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

    private func getFilteredLines() -> [String: [String: Bool]] {
        return getMarkedLinesShared(false)
    }

    private func addDepartures(departures: [TFCDeparture]?) {
        // don't update departures, if we get nil
        // can happen when network request didn't work properly
        if (!(departures == nil && self.departures?.count > 0)) {
            self.departures = departures
            let cache: PINCache = TFCCache.objects.stations
            cache.setObject(self, forKey: st_id)
        }
    }

    public func getDepartures() -> [TFCDeparture]? {
        return self.departures
    }

    public func getFilteredDepartures() -> [TFCDeparture]? {
        if (!hasFilters()) {
            return departures
        }
        if (filteredDepartures != nil) {
            return filteredDepartures
        }
        if (self.departures != nil) {
            filteredDepartures = []
            for (departure) in self.departures! {
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

    public func updateDepartures(completionDelegate: TFCDeparturesUpdatedProtocol?, force: Bool = false, context: Any? = nil, cachettl:Int = 20) {

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
            var dontUpdate = false
            if let first = self.departures?.first {
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
                self.api.getDepartures(self as! TFCStation, context: context2)

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
            if (results == nil || (error != nil && self.departures != nil && self.departures?.count > 0)) {
                self.setDeparturesAsOutdated()
            } else {
                self.addDepartures(TFCDeparture.withJSON(results, st_id: self.st_id))
            }

        dispatch_async(dispatch_get_main_queue(), {
            if (self.name == "" && results != nil) {
                self.name = TFCDeparture.getStationNameFromJson(results!)!;
            }
            self.lastDepartureUpdate = NSDate()
            self.departureUpdateDownloading = nil
            contextInfo?.completionDelegate?.departuresUpdated(error, context: contextInfo?.context, forStation: self as? TFCStation)
        })
    }

    private func setDeparturesAsOutdated() {
        if (self.departures != nil) {
            for (departure) in self.departures! {
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
        for departure: TFCDeparture in self.departures! {
            if (departure.getMinutesAsInt() < 0) {
                someRemoved = true
                departures?.removeAtIndex(i)
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

    public func getDeparturesURL() -> String {

        if  let url = self.realmObject?.departuresURL {
            return url
        }

        let country = self.getCountryISO()
        if (country == "CH") {
            return "https://tfc.chregu.tv/api/ch/stationboard/\(self.st_id)"
        }
        return "http://transport.opendata.ch/v1/stationboard?id=\(self.st_id)&limit=40"
    }
}

public protocol TFCDeparturesUpdatedProtocol {
    func departuresUpdated(error: NSError?, context: Any?, forStation: TFCStation?)
    func departuresStillCached(context: Any?, forStation: TFCStation?)
}


