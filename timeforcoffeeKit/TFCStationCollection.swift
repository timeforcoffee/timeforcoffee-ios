import Foundation


public class TFCStationCollection: NSObject, SequenceType, CollectionType, RangeReplaceableCollectionType {

    typealias Element = TFCStation
    
    private var stationIds:[String] = []

    private var stationCache:[String:TFCStation] = [:]

    private var cache:PINCache? = TFCCache.objects.stations

    public func empty() {
        stationIds = []
        stationCache = [:]
    }

    override public required init() {
        super.init()
    }

    init(values: [TFCStation]) {
        super.init()
        self.replace(values)
    }

    init(strings: [String]) {
        super.init()
        self.stationIds = strings
    }

    init(strings: [String], stationsCache: [String:TFCStation]) {
        super.init()
        self.stationIds = strings
        self.stationCache = stationsCache
    }


    private func getStation(id: String) -> TFCStation {
        if let station = stationCache[id] {
            return station
        }
        let station = TFCStation.initWithCacheId(id)
        stationCache[id] = station
        return station
    }

    public func getStationIfExists(id: String) -> TFCStation? {
        if (stationIds.indexOf(id) != nil) {
            return getStation(id)
        }
        return nil
    }

    public func getStations(limit: Int = 1000) -> [TFCStation] {
        var stations:[TFCStation] = []
        var c = 0
        for (id) in self.stationIds {
            stations.append(self.getStation(id))
            c += 1
            if (c >= limit) {
                break
            }
        }
        return stations
    }

    public func getStationIds() -> [String] {
        return stationIds
    }

    public func getStationsCached() -> [String:TFCStation] {
        return stationCache
    }

    public func clearStationCache() {
        stationCache = [:]
    }

    private func getStationIds(stations: [TFCStation]) -> [String] {
        var ids:[String] = []
        for (station) in stations {
            ids.append(station.st_id)
        }
        return ids
    }

    public func indexOf(element: String) -> TFCStationCollection.Index? {
        return stationIds.indexOf(element)
    }

    public func removeValue(element:String) {
        if let index = stationIds.indexOf(element) {
            stationIds.removeAtIndex(index)
            stationCache.removeValueForKey(element)
        }
    }

    public func sortInPlace(isOrderedBefore: (TFCStationCollection.Generator.Element, TFCStationCollection.Generator.Element) -> Bool)
    {
        var stations = getStations()
        stations.sortInPlace(isOrderedBefore)
        stationIds = getStationIds(stations)
    }

    public func append(newElement: TFCStation) {
        stationIds.append(newElement.st_id)
        stationCache[newElement.st_id] = newElement
    }

    public func appendContentsOf<S : SequenceType where S.Generator.Element == TFCStationCollection.Generator.Element>(newElements: S) {
        stationIds.appendContentsOf(self.getStationIds(Array(newElements)))
    }

    public func insert(newElement: TFCStation, atIndex i: TFCStationCollection.Index) {
        stationIds.insert(newElement.st_id, atIndex: i)
        stationCache[newElement.st_id] = newElement
    }

    public func insertContentsOf<C : CollectionType where C.Generator.Element == TFCStationCollection.Generator.Element>(newElements: C, at i: TFCStationCollection.Index) {
        stationIds.insertContentsOf(self.getStationIds(Array(newElements)), at: i)
    }

    public func removeAtIndex(index: TFCStationCollection.Index) -> TFCStationCollection.Generator.Element {
        let id = stationIds.removeAtIndex(index)
        let station = getStation(id)
        stationCache.removeValueForKey(station.st_id)
        return station
    }

    public func removeLast() -> TFCStationCollection.Generator.Element {
        let last = stationIds.removeLast()
        let station = getStation(last)
        stationCache.removeValueForKey(station.st_id)
        return station
    }

    public func removeLast(n: Int) {
        stationIds.removeLast(n)
    }

    public func removeFirst() -> TFCStationCollection.Generator.Element {
        let id = stationIds.removeFirst()
        let station = getStation(id)
        stationCache.removeValueForKey(station.st_id)
        return station
    }

    public func removeFirst(n: Int) {
        stationIds.removeFirst(n)
    }

    public func removeRange(subRange: Range<TFCStationCollection.Index>) {
        stationIds.removeRange(subRange)
    }

    public func removeAll(keepCapacity keepCapacity: Bool) {
        stationIds.removeAll(keepCapacity: keepCapacity)
        stationCache.removeAll()
    }

    public func reserveCapacity(n: TFCStationCollection.Index.Distance) {
        stationIds.reserveCapacity(n)
    }

    public func replace(stations:[TFCStation]) {
        //make it in two variables, so we don't loose any references and it gets deleted by
        // "GC"
        var stationCacheNew:[String:TFCStation] = [:]
        var stationIdsNew:[String] = []
        for (station) in stations {
            stationIdsNew.append(station.st_id)
            stationCacheNew[station.st_id] = station
        }
        self.stationIds = stationIdsNew
        self.stationCache = stationCacheNew
    }

    public func replace(stationIds stationIds:[String]) {
        self.stationIds = stationIds
        self.stationCache = [:]
    }

    public func replaceRange<C : CollectionType where C.Generator.Element ==  TFCStationCollection.Generator.Element>(subRange: Range<TFCStationCollection.Index>, with newElements: C) {
        stationIds.replaceRange(subRange, with: self.getStationIds(Array(newElements)))
    }

    public func generate() -> TFCStationCollectionGenerator {
        return TFCStationCollectionGenerator(value: self)
    }

    public var startIndex: Int {
        return 0
    }

    public var endIndex: Int {
       return stationIds.count
    }

    public subscript(i: Int) -> TFCStation {
        return self.getStation(stationIds[i])
    }

    internal subscript(range: ClosedInterval<Int>) -> ArraySlice<TFCStation> {
        var stations:[TFCStation] = []

        for (id) in stationIds[range.start...range.end] {
            stations.append(self.getStation(id))
        }
        return ArraySlice(stations)
    }


}

public func +(left: TFCStationCollection, right: TFCStationCollection) -> TFCStationCollection {

    return TFCStationCollection(strings: left.getStationIds() + right.getStationIds())
}

public func += (inout left: TFCStationCollection, right: TFCStationCollection) {
    left = left + right
}

public struct TFCStationCollectionGenerator: GeneratorType {
    let value: TFCStationCollection
    var indexInSequence = 0

    init(value: TFCStationCollection) {
        self.value = value
    }

    mutating public func next() -> TFCStation? {
        if (indexInSequence < self.value.count) {
            let val = value[indexInSequence]
            indexInSequence += 1;
            return val
        }
        return nil
    }
}

//struct TFCStationCollectionType
