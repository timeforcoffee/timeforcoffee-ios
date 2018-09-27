import Foundation


open class TFCStationCollection: NSObject, Sequence, Collection, NSCopying {

    

    public typealias Element = TFCStation
    
    fileprivate var stationIds:[String] = []

    fileprivate var stationCache:[String:TFCStation] = [:]

    fileprivate var cache:PINCache? = TFCCache.objects.stations

    open func empty() {
        stationIds = []
        stationCache = [:]
    }

    override public required init() {
        super.init()
    }

    public func copy(with zone: NSZone? = nil) -> Any {
        let newObject = TFCStationCollection(strings: self.stationIds, stationsCache: self.stationCache)
        return newObject
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


    fileprivate func getStation(_ id: String) -> TFCStation? {
        if let station = stationCache[id] {
            return station
        }
        let station = TFCStation.initWithCacheId(id)
        stationCache[id] = station
        return station
    }

    open func getStationIfExists(_ id: String) -> TFCStation? {
        if (stationIds.index(of: id) != nil) {
            return getStation(id)
        }
        return nil
    }

    open func getStations(_ limit: Int = 1000) -> [TFCStation] {
        var stations:[TFCStation] = []
        var c = 0
        for (id) in self.stationIds {
            if let station = self.getStation(id) {
                stations.append(station)
                c += 1
                if (c >= limit) {
                    break
                }
            }
        }
        return stations
    }

    open func getStationIds() -> [String] {
        return stationIds
    }

    open func getStationsCached() -> [String:TFCStation] {
        return stationCache
    }

    open func clearStationCache() {
        stationCache = [:]
    }

    open func removeDeparturesFromMemory() {
        for (_, station) in stationCache {
            station.removeDeparturesFromMemory()
        }
    }


    fileprivate func getStationIds(_ stations: [TFCStation]) -> [String] {
        var ids:[String] = []
        for (station) in stations {
            ids.append(station.st_id)
        }
        return ids
    }

    open func indexOf(_ element: String) -> TFCStationCollection.Index? {
        return stationIds.index(of: element)
    }

    public func index(after i: Int) -> Int {
        return stationIds.index(after: i)
    }



    open func removeValue(_ element:String) {
        if let index = stationIds.index(of: element) {
            stationIds.remove(at: index)
            stationCache.removeValue(forKey: element)
        }
    }

    open func sortInPlace(_ isOrderedBefore: (TFCStationCollection.Iterator.Element, TFCStationCollection.Iterator.Element) -> Bool)
    {
        var stations = getStations()
        stations.sort(by: isOrderedBefore)
        stationIds = getStationIds(stations)
    }

    open func append(_ newElement: TFCStation) {
        stationIds.append(newElement.st_id)
        stationCache[newElement.st_id] = newElement
    }

  /*  open func append<S : Sequencehere S.Iterator.Element == TFCStationCollection.Iterator.Element {
        stationIds.append(contentsOf: self.getStationIds(Array(newElements)))
    }
*/
    open func insert(_ newElement: TFCStation, at i: TFCStationCollection.Index) {
        stationIds.insert(newElement.st_id, at: i)
        stationCache[newElement.st_id] = newElement
    }

   /* open func insert<C : CollectionnewElements: C, at i: TFCStationCollection.Index) where C.IterIteator.Element == TFCStationCollection.Iterator.Element {
        stationIds.insert(contentsOf: self.getStationIds(Array(newElements)), at: i)
    }*/

    open func remove(at index: TFCStationCollection.Index) -> TFCStationCollection.Iterator.Element {
        let id = stationIds.remove(at: index)
        let station = getStation(id)
        stationCache.removeValue(forKey: station!.st_id)
        return station!
    }

    open func removeLast() -> TFCStationCollection.Iterator.Element {
        let last = stationIds.removeLast()
        let station = getStation(last)
        stationCache.removeValue(forKey: station!.st_id)
        return station!
    }

    open func removeLast(_ n: Int) {
        stationIds.removeLast(n)
    }

    open func removeFirst() -> TFCStationCollection.Iterator.Element {
        let id = stationIds.removeFirst()
        let station = getStation(id)
        stationCache.removeValue(forKey: station!.st_id)
        return station!
    }

    open func removeFirst(_ n: Int) {
        stationIds.removeFirst(n)
    }

    open func removeSubrange(_ subRange: Range<TFCStationCollection.Index>) {
        stationIds.removeSubrange(subRange)
    }

    open func removeAll(keepingCapacity keepCapacity: Bool) {
        stationIds.removeAll(keepingCapacity: keepCapacity)
        stationCache.removeAll()
    }

  /*  open func reserveCapacity(_ n: TFCStationCollection.Index.Distance) {
        stationIds.reserveCapacity(n)
    }*/

    open func replace(_ stations:[TFCStation]) {
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

    open func replace(stationIds:[String]) {
        self.stationIds = stationIds
        self.stationCache = [:]
    }

    public func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C : Collection, TFCStation == C.Iterator.Element {
        stationIds.replaceSubrange(subrange, with: self.getStationIds(Array(newElements)))
    }

    open func makeIterator() -> TFCStationCollectionGenerator {
        return TFCStationCollectionGenerator(value: self)
    }

    open var startIndex: Int {
        return 0
    }

    open var endIndex: Int {
       return stationIds.count
    }

    open subscript(i: Int) -> TFCStation {
        return self.getStation(stationIds[i])!
    }

    internal subscript(range: ClosedRange<Int>) -> ArraySlice<TFCStation> {
        var stations:[TFCStation] = []

        for (id) in stationIds[range.lowerBound...range.upperBound] {
            if let station = self.getStation(id) {
                stations.append(station)
            }
        }
        return ArraySlice(stations)
    }


}

public struct TFCStationCollectionGenerator: IteratorProtocol {
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
