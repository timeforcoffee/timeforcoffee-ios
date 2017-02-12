//
//  ComplicationController.swift
//  timeforcoffee
//
//  Created by Raphael Neuenschwander on 11.10.15.
//  Copyright © 2015 opendata.ch. All rights reserved.
//

// create the timeline entries (departures) to populate the complication

import ClockKit

//MARK: - Constants

class ComplicationController: NSObject, CLKComplicationDataSource, TFCDeparturesUpdatedProtocol {
    
    // MARK: - Timeline Configuration
    
    lazy var watchdata: TFCWatchData = { 
        let watchdata = TFCWatchData()
        watchdata.noCrunchQueue = true
        return watchdata
        }()

    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([.forward]) // supports only forward time travel
    }
    
    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        DLog("started getTimelineStartDateForComplication", toFile: true)
        func handleReply(_ stations: TFCStations?) {
            if let station = stations?.getStation(0) {
                func handleReply2(_ station: TFCStation?) {
                    if let station = station {
                        let _ = station.removeObsoleteDepartures()
                        let cmpldata = ComplicationData.initWithCache(station: station)
                        let startDate = cmpldata.getStartDate()
                        DLog("startDate: \(startDate)", toFile: true)
                        handler(startDate)
                    } else {
                        handler(Date())
                    }
                    DLog("finished getTimelineStartDateForComplication", toFile: true)
                }
                self.updateDepartures(station, context: handleReply2)
            }
        }
        watchdata.getStations(handleReply, errorReply: nil, stopWithFavorites: true)
    }
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        DLog("started getTimelineEndDateForComplication", toFile: true)
        func handleReply(_ stations: TFCStations?) {
            if let station = stations?.getStation(0) {
                //FIXME: this should go into complicationdata
                let departures = station.getScheduledFilteredDepartures()
                DLog("firstStation: \(station.name) with \(String(describing: departures?.count)) filtered departures", toFile: true)
                if let ud =  UserDefaults(suiteName: "group.ch.opendata.timeforcoffee") {
                    ud.set(Date(), forKey: "lastComplicationUpdate")
                    ud.setValue(station.st_id, forKey: "lastComplicationStationId")
                }

                func handleReply2(_ station: TFCStation?) {
                    let departures = station?.getScheduledFilteredDepartures()
                    //FIXME: this should go into complicationdata
                    if let endDate = departures?.last?.getScheduledTimeAsNSDate() {
                        if let ud =  UserDefaults(suiteName: "group.ch.opendata.timeforcoffee") {
                            ud.set(endDate, forKey: "lastDepartureTime")
                        }
                        DLog("last Departure: \(endDate)", toFile: true)
                        handler(endDate.addingTimeInterval(70))
                    } else {
                        if let ud =  UserDefaults(suiteName: "group.ch.opendata.timeforcoffee") {
                            ud.set(nil, forKey: "lastDepartureTime")
                        }
                        let endDate = Date().addingTimeInterval(60)
                        DLog("no last Departure, set it to \(endDate)", toFile: true)
                    }
                    
                    if let station = station {
                        let _ = station.removeObsoleteDepartures()
                        let cmpldata = ComplicationData.initWithCache(station: station)
                        let endDate = cmpldata.getEndDate()
                        DLog("endDate: \(endDate)", toFile: true)
                        handler(endDate)
                    } else {
                        handler(Date().addingTimeInterval(60))
                    }

                    DLog("finished getTimelineEndDateForComplication", toFile: true)
                }
                self.updateDepartures(station, context: handleReply2)
            }
        }
        self.watchdata.getStations(handleReply, errorReply: nil, stopWithFavorites: true)
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: (@escaping (CLKComplicationTimelineEntry?) -> Void)) {
        DLog("started getCurrentTimelineEntryForComplication", toFile: true)
        // Take the first entry before the current date
        getTimelineEntries(for: complication, before: Date(), limit: 1) { (entries) -> Void in
            handler(entries?.first)
        }
        DLog("finished getCurrentTimelineEntryForComplication", toFile: true)
    }
    
    func getTimelineEntries(for complication: CLKComplication, before date: Date, limit: Int, withHandler handler: (@escaping ([CLKComplicationTimelineEntry]?) -> Void)) {
        // Call the handler with the timeline entries after to the given date
        DLog("started getTimelineEntriesForComplication beforeDate \(date)", toFile: true)
        func handleReply(_ stations: TFCStations?) {
            var entries = [CLKComplicationTimelineEntry]()
            
            if let station = stations?.getStation(0) { // corresponds to the last favorited station or closest station
                func handleReply2(_ station:TFCStation?) {
                    //just take the first entry here... It's the one we want to display
                    if let station = station {
                        let _ = station.removeObsoleteDepartures()
                        let cmpldata = ComplicationData.initWithCache(station: station)
                        entries = cmpldata.getTimelineEntries(for: complication, after: nil, limit: 1)
                    }
                    DLog("entries count: \(entries.count) limit \(limit)", toFile: true)

                    handler(entries)
                    DLog("finished getTimelineEntriesForComplication beforeDate", toFile: true)

                }
                self.updateDepartures(station, context: handleReply2)
            } else {
                DLog("entries count: \(entries.count) limit \(limit)", toFile: true)

                handler(entries)
                DLog("finished getTimelineEntriesForComplication beforeDate", toFile: true)
            }
        }
        
        watchdata.getStations(handleReply, errorReply: nil, stopWithFavorites: true)
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: (@escaping ([CLKComplicationTimelineEntry]?) -> Void)) {
        // Call the handler with the timeline entries after to the given date
        DLog("started getTimelineEntriesForComplication afterDate: \(date)", toFile: true)
        func handleReply(_ stations: TFCStations?) {
            var entries = [CLKComplicationTimelineEntry]()
            if let station = stations?.getStation(0) { // corresponds to the favorited/closest station
                func handleReply2(_ station: TFCStation?) {
                    if let station = station {
                        let cmpldata = ComplicationData.initWithCache(station: station)
                        entries = cmpldata.getTimelineEntries(for: complication, after: date, limit: limit)
                    }
                    handler(entries)
                    DLog("finished getTimelineEntriesForComplication afterDate. count \(entries.count)", toFile: true)
                }
                self.updateDepartures(station, context: handleReply2)
            } else {
                handler(entries)
                DLog("finished getTimelineEntriesForComplication afterDate. empty entries", toFile: true)
            }
        }
        watchdata.getStations(handleReply, errorReply: nil, stopWithFavorites: true)
    }

    //MARK: - Convenience

    func departuresUpdated(_ error: Error?, context: Any?, forStation: TFCStation?) {
        departuresUpdatedCallback(context, forStation: forStation)
    }
    func departuresStillCached(_ context: Any?, forStation: TFCStation?) {
        departuresUpdatedCallback(context, forStation: forStation)
    }

    fileprivate func departuresUpdatedCallback(_ context: Any?, forStation: TFCStation?) {
        if let reply = context as? replyStation {
            reply(forStation)
        }
    }
    let ShortDateFormatter:DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "de_CH")
        return formatter
    }()


    fileprivate func getDepartureTTL(_ station: TFCStation) -> Int {
        if (watchdata.needsDeparturesUpdate(station)) {
            return 10 * 60 //default
        }
        return 6 * 3600
    }

    fileprivate func updateDepartures(_ station: TFCStation, context: Any) {
        let _ = station.removeObsoleteDepartures()
        // if we have at least 4 departures, that's enough to update the complications
        // the data will be updated somewhere else later
        if let filteredDeparturesCount = station.getFilteredDepartures()?.count {
            if (filteredDeparturesCount > 3) {
                if let reply = context as? replyStation {
                    DLog("we already have \(filteredDeparturesCount) departures for a complication update, dont get new ones")
                    reply(station)
                    return
                }
            }
        }
        station.updateDepartures(self, context: context, cachettl: self.getDepartureTTL(station))
    }
}
