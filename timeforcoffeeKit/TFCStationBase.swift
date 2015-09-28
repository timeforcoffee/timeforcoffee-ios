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

public class TFCStationBase: NSObject, NSCoding, APIControllerProtocol {
    public var name: String
    public var coord: CLLocation?
    public var st_id: String

    private var departures: [TFCDeparture]? = nil {
        didSet {
            filteredDepartures = nil
        }
    }
    private var filteredDepartures: [TFCDeparture]?

    public var calculatedDistance: Int?
    var walkingDistanceString: String?
    var walkingDistanceLastCoord: CLLocation?
    private var lastDepartureUpdate: NSDate?
    private var lastDepartureCount: Int?

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
    }

    private lazy var filteredLines:[String: [String: Bool]] = {
        [unowned self] in
        return self.getFilteredLines()
    }()

    private lazy var favoriteLines:[String: [String: Bool]] = {
        [unowned self] in
        return self.getFavoriteLines()
    }()
    
    public init(name: String, id: String, coord: CLLocation?) {
        self.name = name
        self.st_id = id
        self.coord = coord
    }

    public required init?(coder aDecoder: NSCoder) {
        self.name = aDecoder.decodeObjectForKey("name") as! String
        self.st_id = aDecoder.decodeObjectForKey("st_id") as! String
        self.coord = aDecoder.decodeObjectForKey("coord") as! CLLocation?
        self.departures = aDecoder.decodeObjectForKey("departures") as! [TFCDeparture]?
        if (self.departures?.count == 0) {
            self.departures = nil
        }
        self.walkingDistanceString = aDecoder.decodeObjectForKey("walkingDistanceString") as! String?
        self.walkingDistanceLastCoord = aDecoder.decodeObjectForKey("walkingDistanceLastCoord") as! CLLocation?
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(name, forKey: "name")
        aCoder.encodeObject(st_id, forKey: "st_id")
        aCoder.encodeObject(coord, forKey: "coord")
        if (serializeDepartures) {
            aCoder.encodeObject(departures, forKey: "departures")
        }
        aCoder.encodeObject(walkingDistanceString, forKey: "walkingDistanceString")
        aCoder.encodeObject(walkingDistanceLastCoord, forKey: "walkingDistanceLastCoord")
    }

    override public convenience init() {
        self.init(name: "doesn't exist", id: "0000", coord: nil)
    }

    public class func initWithCache(name: String, id: String, coord: CLLocation?) -> TFCStation {
        let trimmed_id = id.replace("^0*", template: "")
        let cache: PINCache = TFCCache.objects.stations
        var newStation: TFCStation? = cache.objectForKey(trimmed_id) as? TFCStation
        if (newStation == nil || newStation?.coord == nil) {
            //if name is unknown, fetch it from opendata
            // this is done synchronously, so butt ugly, but we have a timeout of 5 seconds
            if (name == "") {
                let api = APIController(delegate: nil)
                NSLog("Station Name missing. Fetch station info from opendata.ch for \(trimmed_id)")
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
            if (name != "" && newStation?.coord != nil) {
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
        let station = initWithCache(dict["name"] as String!, id: dict["st_id"] as String!, coord: location)
        return station
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
        if((lines[departure.getLine()] as [String: Bool]!).count == 0) {
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
        var markedDestinationsShared: [String: [String: Bool]]? = objects.dataStore?.objectForKey(key)?.mutableCopy() as! [String: [String: Bool]]?

        if (markedDestinationsShared == nil) {
            markedDestinationsShared = [:]
        }
        return markedDestinationsShared!
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

    public func updateDepartures(completionDelegate: TFCDeparturesUpdatedProtocol?) {
        updateDepartures(completionDelegate, force: false)
    }
    
    public func updateDepartures(completionDelegate: TFCDeparturesUpdatedProtocol?, force: Bool) {

        let removedDepartures = removeObsoleteDepartures()
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            var context: contextData = contextData()

            context.completionDelegate = completionDelegate
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
                         self.lastDepartureUpdate?.timeIntervalSinceNow < -20 ||
                            (settingsLastUpdated != nil &&
                             self.lastDepartureUpdate?.timeIntervalSinceDate(settingsLastUpdated!) < 0
                            )
                        )
                    )
                )
            {
                self.lastDepartureUpdate = NSDate()
                self.api.getDepartures(self.st_id, context: context)

            } else {
                dispatch_async(dispatch_get_main_queue(), {
                    completionDelegate?.departuresStillCached(context, forStation: self as? TFCStation)
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
                self.addDepartures(TFCDeparture.withJSON(results))
            }

        dispatch_async(dispatch_get_main_queue(), {
            if (self.name == "" && results != nil) {
                self.name = TFCDeparture.getStationNameFromJson(results!)!;
            }
            contextInfo?.completionDelegate?.departuresUpdated(error, context: context, forStation: self as? TFCStation)
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

    private func removeObsoleteDepartures() -> Bool {
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
                i++
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

    public func getIcon() -> UIImage {
        if (isFavorite()) {
            return getFavoriteIcon()
        }
        return getNormalIcon()
    }

    private func getFavoriteIcon() -> UIImage {
        if (st_id == "8591306") {
            return UIImage(named: "stationicon-liip")!
        }
        return UIImage(named: "stationicon-star")!
    }

    private func getNormalIcon() -> UIImage {
        return UIImage(named: "stationicon-pin")!
    }

    public func setStationActivity() {
    }
    public func setStationSearchIndex() {
    }


    public func getWebLink() -> NSURL? {
        //        {:location-id :ch_zh, :stops {"008591195" {:id "008591195", :name "Zürich, Höfliweg", :location {:lat 47.367569, :lng 8.51095}, :known-destinations ()}}, :stops-order ["008591195"]
        if let lat = self.getLatitude() {
            let hash = "{:location-id :ch_zh, :stops {\"\(self.st_id)\" {:id \"\", :name \"\(self.name)\", :location {:lat \(lat), :lng \(self.getLongitude()!)}, :known-destinations ()}}, :stops-order [\"\(self.st_id)\"]}"
            let utf8hash = hash.dataUsingEncoding(NSISOLatin1StringEncoding)
            if let base64 = utf8hash?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0)) {
                return NSURL(string: "http://www.timeforcoffee.ch/#/link/\(base64)")
            }
        }
        return nil
    }
}

public protocol TFCDeparturesUpdatedProtocol {
    func departuresUpdated(error: NSError?, context: Any?, forStation: TFCStation?)
    func departuresStillCached(context: Any?, forStation: TFCStation?)
}


