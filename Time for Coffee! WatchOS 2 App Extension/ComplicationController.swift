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
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        DLog("started getTimelineEndDateForComplication", toFile: true)
        func handleReply(_ stations: TFCStations?) {
            if let station = stations?.getStation(0) {
                //FIXME: this should go into complicationdata
                let departures = station.getScheduledFilteredDepartures()
                DLog("firstStation: \(station.name) with \(String(describing: departures?.count)) filtered departures", toFile: true)
                func handleReply2(_ station: TFCStation?) {
                    let departures = station?.getScheduledFilteredDepartures()
                    //FIXME: this should go into complicationdata
                    if let endDate = departures?.last?.getScheduledTimeAsNSDate() {
                        DLog("last Departure: \(endDate)", toFile: true)
                        handler(endDate.addingTimeInterval(70))
                    } else {
                        let endDate = Date().addingTimeInterval(60)
                        DLog("no last Departure, set it to \(endDate)", toFile: true)
                    }
                    
                    if let station = station {
                        let _ = station.removeObsoleteDepartures()
                        let cmpldata = ComplicationData.initWithCache(station: station)
                        let endDate = cmpldata.getEndDate()
                        let storedData = cmpldata.copy() as! ComplicationData
                        storedData.setIsDisplayedOnWatch()
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
        let cmpldata = ComplicationData.initDisplayed()
        let entries = cmpldata?.getTimelineEntries(for: complication, after: nil, limit: 1)
        handler(entries)
        DLog("finished getTimelineEntriesForComplication beforeDate count: \(String(describing: entries?.count))", toFile: true)
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: (@escaping ([CLKComplicationTimelineEntry]?) -> Void)) {
        // Call the handler with the timeline entries after to the given date
        DLog("started getTimelineEntriesForComplication afterDate: \(date)", toFile: true)
        let cmpldata = ComplicationData.initDisplayed()
        let entries = cmpldata?.getTimelineEntries(for: complication, after: date, limit: limit)
        handler(entries)
        #if DEBUG
            if let entries = entries, (entries.count > 0) {
            TFCDataStore.sharedInstance.sendData(["__complicationUpdateReceived__": "\(Date().formattedWithDateFormatter(ShortDateFormatter)): Updated \(entries.count) entries on Complication for \(String(describing: cmpldata?.getStation().name))"])
            }
        #endif
        DLog("finished getTimelineEntriesForComplication afterDate. count \(String(describing: entries?.count))", toFile: true)
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
        if let filteredDeparturesCount = station.getFilteredDepartures(nil, fallbackToAll: true)?.count {
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


    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        DLog("getLocalizableSampleTemplate", toFile: true)
        let template = ComplicationData.getTemplateForComplication(complication.family)
        DLog("template: \(template.debugDescription)", toFile: true);
        handler(template);
    }
}
