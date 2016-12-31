import Foundation


public class TFCStationCollection: NSObject, SequenceType, CollectionType, RangeReplaceableCollectionType {

    typealias Element = TFCStation
    
    private var stationIds:[String] = []

    private var cache:PINCache? = TFCCache.objects.stations

    public func empty() {
        stationIds = []
    }

    override public required init() {
        super.init()
    }

    init(values: [TFCStation]) {
        super.init()
        self.stationIds = self.getStationIds(values)
    }

    init(strings: [String]) {
        super.init()
        self.stationIds = strings
    }

    private func getStation(id: String) -> TFCStation {
        if let station = cache?.memoryCache.objectForKey(id) as? TFCStation {
            return station
        }
        return TFCStation.initWithCacheId(id)
    }

    public func getStationIfExists(id: String) -> TFCStation? {
        if (stationIds.indexOf(id) != nil) {
            return getStation(id)
        }
        return nil
    }

    public func getStations() -> [TFCStation] {
        var stations:[TFCStation] = []
        for (id) in self.stationIds {
            stations.append(self.getStation(id))
        }
        return stations
    }

    public func getStationIds() -> [String] {
        return stationIds
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
    }

    public func appendContentsOf<S : SequenceType where S.Generator.Element == TFCStationCollection.Generator.Element>(newElements: S) {
        stationIds.appendContentsOf(self.getStationIds(Array(newElements)))
    }

    public func insert(newElement: TFCStation, atIndex i: TFCStationCollection.Index) {
        stationIds.insert(newElement.st_id, atIndex: i)
    }

    public func insertContentsOf<C : CollectionType where C.Generator.Element == TFCStationCollection.Generator.Element>(newElements: C, at i: TFCStationCollection.Index) {
        stationIds.insertContentsOf(self.getStationIds(Array(newElements)), at: i)
    }

    public func removeAtIndex(index: TFCStationCollection.Index) -> TFCStationCollection.Generator.Element {
        let id = stationIds.removeAtIndex(index)
        return getStation(id)
    }

    public func removeLast() -> TFCStationCollection.Generator.Element {
        let last = stationIds.removeLast()
        return getStation(last)
    }

    public func removeLast(n: Int) {
        stationIds.removeLast(n)
    }

    public func removeFirst() -> TFCStationCollection.Generator.Element {
        let id = stationIds.removeFirst()
        return getStation(id)
    }

    public func removeFirst(n: Int) {
        stationIds.removeFirst(n)
    }

    public func removeRange(subRange: Range<TFCStationCollection.Index>) {
        stationIds.removeRange(subRange)
    }

    public func removeAll(keepCapacity keepCapacity: Bool) {
        stationIds.removeAll(keepCapacity: keepCapacity)
    }

    public func reserveCapacity(n: TFCStationCollection.Index.Distance) {
        stationIds.reserveCapacity(n)
    }

    public func replace(stations:[TFCStation]) {
        stationIds = self.getStationIds(stations)
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
