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

private struct Constants {
    static let DepartureDuration = TimeInterval(60) // 1 minute
    static let ComplicationColor = UIColor.orange
}

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
                    let _ = station?.removeObsoleteDepartures()
                    if let departure = station?.getScheduledFilteredDepartures()?.first {
                        let startDate = timelineEntryDateForDeparture(departure, previousDeparture: nil)
                        DLog("startDate: \(startDate)", toFile: true)
                        handler(startDate)
                    } else {
                        DLog("no Departure, startDate: \(Date())", toFile: true)
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
                let departures = station.getScheduledFilteredDepartures()
                DLog("firstStation: \(station.name) with \(String(describing: departures?.count)) filtered departures", toFile: true)
                if let ud =  UserDefaults(suiteName: "group.ch.opendata.timeforcoffee") {
                    ud.set(Date(), forKey: "lastComplicationUpdate")
                    ud.setValue(station.st_id, forKey: "lastComplicationStationId")
                }

                func handleReply2(_ station: TFCStation?) {
                    let departures = station?.getScheduledFilteredDepartures()

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
                        handler(endDate)
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
                    let _ = station?.removeObsoleteDepartures()
                    if let departures = station?.getScheduledFilteredDepartures(),
                        let departure = departures.first {
                        DLog("firstStation: \(String(describing: station?.name)) with \(departures.count) filtered departures", toFile: true)

                        let thisEntryDate = timelineEntryDateForDeparture(departure, previousDeparture: nil)
                        let nextDeparture: TFCDeparture? = (departures.count >= 2) ? departures[1] : nil
                        if let station = station, let tmpl = templateForStationDepartures(station, departure: departure, nextDeparture: nextDeparture, complication: complication) {
                            let entry = CLKComplicationTimelineEntry(date: thisEntryDate, complicationTemplate: tmpl)
                            DLog("tl 0: \(thisEntryDate)"   )
                            DLog("tl 1: \(departure.getLine()): \(departure.getDestination()) \(departure.getScheduledTime()!)")
                            if let nextDeparture = nextDeparture {
                                DLog("tl 2: \(nextDeparture.getLine()): \(nextDeparture.getDestination()) \(nextDeparture.getScheduledTime()!) ")
                            }
                            entries.append(entry)
                        }
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
                    if let station = station,
                        let departures = station.getScheduledFilteredDepartures() {
                        DLog("firstStation: \(station.name) with \(departures.count) filtered departures", toFile: true)

                            var index = 0
                            var previousDeparture: TFCDeparture? = nil
                            var departure: TFCDeparture? = departures.first
                            var nextDeparture: TFCDeparture? = (departures.count >= 2) ? departures[1] : nil
                            var lastDepartureTimeNew:Date? = departure?.getScheduledTimeAsNSDate()
                            while let thisDeparture = departure {
                                let thisEntryDate = timelineEntryDateForDeparture(thisDeparture, previousDeparture: previousDeparture)
                                if date.compare(thisEntryDate) == .orderedAscending { // check if the entry date is "correctly" after the given date
                                    // only add it, if previous departure is before this departure (when they are the same, it was added with the previous one (or if we have more than 2, then nr 3+ won't be added, which is fine)
                                    if (previousDeparture == nil ||
                                        previousDeparture?.getScheduledTime() == nil ||
                                        thisDeparture.getScheduledTime() == nil ||
                                        previousDeparture!.getScheduledTime()! < thisDeparture.getScheduledTime()!) {
                                        if let tmpl = templateForStationDepartures(station, departure: thisDeparture, nextDeparture: nextDeparture, complication: complication) {
                                            let entry = CLKComplicationTimelineEntry(date: thisEntryDate, complicationTemplate: tmpl)
                                            DLog("tl 0: \(thisEntryDate)"   )
                                            DLog("tl 1: \(thisDeparture.getLine()): \(thisDeparture.getDestination()) \(thisDeparture.getScheduledTime()!)")
                                            if let nextDeparture = nextDeparture {
                                                DLog("tl 2: \(nextDeparture.getLine()): \(nextDeparture.getDestination()) \(nextDeparture.getScheduledTime()!) ")
                                            }
                                            entries.append(entry)
                                        }
                                    }
                                    lastDepartureTimeNew = thisDeparture.getScheduledTimeAsNSDate()
                                    if entries.count >= (limit - 1) {break} // break if we reached the limit of entries
                                }
                                index += 1
                                previousDeparture = thisDeparture
                                departure = (departures.count - 1 >= index) ? departures[index] : nil
                                nextDeparture = (departures.count > index + 1) ? departures[index + 1] : nil
                            }
                            //append a last entry with no departure info one minute later
                            DLog("entries count: \(entries.count) limit \(limit)", toFile: true)
                            if (entries.count > 0) {
                                //remove all entries until we're one below the limit
                                while (entries.count >= limit) {                                
                                    let _ = entries.popLast()
                                }
                            }
                            if let lastDepartureTimeNew = lastDepartureTimeNew, let tmpl = templateForStationDepartures(station, departure: nil, nextDeparture: nil, complication: complication) {
                                    let entry = CLKComplicationTimelineEntry(date: (lastDepartureTimeNew.addingTimeInterval(60)), complicationTemplate: tmpl)
                                    entries.append(entry)
                            }
                    }
                    handler(entries)
                    DLog("finished getTimelineEntriesForComplication afterDate", toFile: true)
                }
                self.updateDepartures(station, context: handleReply2)
            } else {
                handler(entries)
                DLog("finished getTimelineEntriesForComplication afterDate", toFile: true)
            }
        }
        watchdata.getStations(handleReply, errorReply: nil, stopWithFavorites: true)
    }
    
    // MARK: - Update Scheduling
    
    func getNextRequestedUpdateDate(handler: @escaping (Date?) -> Void) {
        // Call the handler with the date when you would next like to be given the opportunity to update your complication content

        let nextUpdateDate = watchdata.getNextUpdateTime()
        DLog("getNextRequestedUpdateDateWithHandler: \(nextUpdateDate)", toFile: true)
        handler(nextUpdateDate);
    }
    
    // MARK: - Placeholder Templates
    
    func getPlaceholderTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {

        let templ = getPlaceholderTemplateForComplication(complication.family)
        handler(templ)

    }

    fileprivate func getPlaceholderTemplateForComplication(_ family: CLKComplicationFamily) -> CLKComplicationTemplate {
        switch family {

        case CLKComplicationFamily.modularLarge:
            let tmpl = CLKComplicationTemplateModularLargeTable()

            tmpl.headerTextProvider = CLKSimpleTextProvider(text: "Station")
            tmpl.row1Column1TextProvider = CLKSimpleTextProvider(text: "--: ------", shortText: nil)
            tmpl.row1Column2TextProvider = CLKSimpleTextProvider(text: "--", shortText: nil)
            tmpl.row2Column1TextProvider = CLKSimpleTextProvider(text: "--: ------", shortText: nil)
            tmpl.row2Column2TextProvider = CLKSimpleTextProvider(text: "--", shortText: nil)
            return tmpl
        case CLKComplicationFamily.modularSmall:
            let tmpl = CLKComplicationTemplateModularSmallStackText()
            tmpl.line1TextProvider = CLKSimpleTextProvider(text: "--:");
            tmpl.line2TextProvider = CLKSimpleTextProvider(text: "-");
            return tmpl
        case CLKComplicationFamily.utilitarianLarge:
            let tmpl = CLKComplicationTemplateUtilitarianLargeFlat()
            tmpl.textProvider = CLKSimpleTextProvider(text: "--: --:-- ------")
            return tmpl
        case CLKComplicationFamily.utilitarianSmallFlat:
            let tmpl = CLKComplicationTemplateUtilitarianSmallFlat()
            tmpl.textProvider = CLKSimpleTextProvider(text: "--: -");
            return tmpl
        case CLKComplicationFamily.utilitarianSmall:
            let tmpl = CLKComplicationTemplateUtilitarianSmallFlat()
            tmpl.textProvider = CLKSimpleTextProvider(text: "--: -");
            return tmpl
        case CLKComplicationFamily.circularSmall:
            let tmpl = CLKComplicationTemplateCircularSmallStackText()
            tmpl.line1TextProvider = CLKSimpleTextProvider(text: "--:");
            tmpl.line2TextProvider = CLKSimpleTextProvider(text: "-");
            return tmpl
        case CLKComplicationFamily.extraLarge:
            let tmpl = CLKComplicationTemplateExtraLargeStackText()
            tmpl.line1TextProvider = CLKSimpleTextProvider(text: "--:");
            tmpl.line2TextProvider = CLKSimpleTextProvider(text: "-");
            return tmpl
        }
    }
    
    func requestedUpdateDidBegin() {
        // get the shared instance
        DLog("requestedUpdateDidBegin", toFile: true)
        // delay by 3 seconds, so it may have some time to fetch the userInfo about locaton from
        // the iphone when called via transferCurrentComplicationUserInfo()

        //self.watchdata.waitForNewLocation(within: 5)
        DLog("updateComplicationData", toFile: true)

        self.watchdata.updateComplicationData()
    }


    func requestedUpdateBudgetExhausted() {
        // get the shared instance
        DLog("requestedUpdateBudgetExhausted", toFile: true)
        // delay by 3 seconds, so it may have some time to fetch the userInfo about locaton from
        // the iphone when called via transferCurrentComplicationUserInfo()
       // self.watchdata.waitForNewLocation(within: 5)
        DLog("updateComplicationData", toFile: true)

        self.watchdata.updateComplicationData()
     }

    //MARK: - Convenience
    
    fileprivate func templateForStationDepartures(_ station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?, complication: CLKComplication) -> CLKComplicationTemplate? {

        switch (complication.family) {
        case CLKComplicationFamily.modularLarge:
            return getModularLargeTemplate(station, departure: departure, nextDeparture: nextDeparture)
        case CLKComplicationFamily.modularSmall:
            return getModularSmallTemplate(station, departure: departure, nextDeparture: nextDeparture)
        case CLKComplicationFamily.utilitarianLarge:
            return getUtilitarianLargeTemplate(station, departure: departure, nextDeparture: nextDeparture)
        case CLKComplicationFamily.utilitarianSmall:
            return getUtilitarianSmallTemplate(station, departure: departure, nextDeparture: nextDeparture)
        case CLKComplicationFamily.utilitarianSmallFlat:
            return getUtilitarianSmallTemplate(station, departure: departure, nextDeparture: nextDeparture)
        case CLKComplicationFamily.circularSmall:
            return getCircularSmallTemplate(station, departure: departure, nextDeparture: nextDeparture)
        case CLKComplicationFamily.extraLarge:
            return getExtraLargeTemplate(station, departure: departure, nextDeparture: nextDeparture)
        }
    }


    fileprivate func getCircularSmallTemplate(_ station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateCircularSmallStackText {

        if let departure = departure, let departureTime = departure.getScheduledTimeAsNSDate() {
            let tmpl = CLKComplicationTemplateCircularSmallStackText()
            tmpl.tintColor = Constants.ComplicationColor
            let departureLine = departure.getLine()
            tmpl.line1TextProvider = CLKSimpleTextProvider(text: "\(departureLine):")
            tmpl.line2TextProvider = getDateProvider(departureTime)
            return tmpl

        }
        return getPlaceholderTemplateForComplication(CLKComplicationFamily.circularSmall) as! CLKComplicationTemplateCircularSmallStackText
    }

    fileprivate func getExtraLargeTemplate(_ station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateExtraLargeStackText {

        if let departure = departure, let departureTime = departure.getScheduledTimeAsNSDate() {
            let tmpl = CLKComplicationTemplateExtraLargeStackText()

            tmpl.tintColor = Constants.ComplicationColor
            tmpl.highlightLine2 = false
            let departureLine = departure.getLine()
            tmpl.line1TextProvider = CLKSimpleTextProvider(text: "\(departureLine):")
            tmpl.line2TextProvider = getDateProvider(departureTime)
            return tmpl

        }
        return getPlaceholderTemplateForComplication(CLKComplicationFamily.extraLarge) as! CLKComplicationTemplateExtraLargeStackText
    }

    fileprivate func getUtilitarianLargeTemplate(_ station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateUtilitarianLargeFlat {

        if let departure = departure, let departureTime = departure.getScheduledTime() {

            let tmpl = CLKComplicationTemplateUtilitarianLargeFlat()
            tmpl.tintColor = Constants.ComplicationColor

            let departureLine = departure.getLine()
            let departureDestination = departure.getDestination(station)
            tmpl.textProvider = CLKSimpleTextProvider(text: "\(departureLine): \(departureTime) \(departureDestination)")
            return tmpl
        }
        return getPlaceholderTemplateForComplication(CLKComplicationFamily.utilitarianLarge) as! CLKComplicationTemplateUtilitarianLargeFlat

    }

    fileprivate func getUtilitarianSmallTemplate(_ station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateUtilitarianSmallFlat {

        if let departure = departure, let departureTime = departure.getScheduledTime() {
            let tmpl = CLKComplicationTemplateUtilitarianSmallFlat()
            tmpl.tintColor = Constants.ComplicationColor
            let departureLine = departure.getLine()
            tmpl.textProvider = CLKSimpleTextProvider(text: "\(departureLine): \(departureTime)")
            return tmpl
        }
        return getPlaceholderTemplateForComplication(CLKComplicationFamily.utilitarianSmall) as! CLKComplicationTemplateUtilitarianSmallFlat
    }

    fileprivate func getModularSmallTemplate(_ station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateModularSmallStackText {

        if let  departure = departure, let departureTime = departure.getScheduledTimeAsNSDate() {
            let tmpl = CLKComplicationTemplateModularSmallStackText()
            tmpl.tintColor = Constants.ComplicationColor
            let departureLine = departure.getLine()
            tmpl.line1TextProvider = CLKSimpleTextProvider(text: "\(departureLine):")
            tmpl.line2TextProvider = getDateProvider(departureTime)
            return tmpl
        }
        return getPlaceholderTemplateForComplication(CLKComplicationFamily.modularSmall) as! CLKComplicationTemplateModularSmallStackText

    }

    fileprivate func getModularLargeTemplate(_ station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateModularLargeTable {

        if let departure = departure {
            let tmpl = CLKComplicationTemplateModularLargeTable() // Currently supports only ModularLarge

            tmpl.headerTextProvider = CLKSimpleTextProvider(text: station.getName(true))
            tmpl.tintColor = Constants.ComplicationColor // affect only complications setup that allow custom colors

            let departureLine = departure.getLine()
            let nextDepartureLine = nextDeparture?.getLine() ?? "-"

            var departureDestination = "-"
            var nextDepartureDestination = "-"
            departureDestination = departure.getDestination(station)
            if let nextDeparture = nextDeparture {
                nextDepartureDestination = nextDeparture.getDestination(station)
            }

            tmpl.row1Column1TextProvider = CLKSimpleTextProvider(text: "\(departureLine): \(departureDestination)")

            if let departureDate = departure.getScheduledTimeAsNSDate() {
                tmpl.row1Column2TextProvider = getDateProvider(departureDate)
            } else {
                tmpl.row1Column2TextProvider = CLKSimpleTextProvider(text: "-")
            }

            tmpl.row2Column1TextProvider = CLKSimpleTextProvider(text: "\(nextDepartureLine): \(nextDepartureDestination)")

            if let nextDepartureDate = nextDeparture?.getScheduledTimeAsNSDate() {
                tmpl.row2Column2TextProvider = getDateProvider(nextDepartureDate)
            } else {
                tmpl.row2Column2TextProvider = CLKSimpleTextProvider(text: "-")
            }
            return tmpl
        }
        return getPlaceholderTemplateForComplication(CLKComplicationFamily.modularLarge) as! CLKComplicationTemplateModularLargeTable

    }

    fileprivate func getDateProvider(_ date: Date) -> CLKRelativeDateTextProvider {
        let units: NSCalendar.Unit = [.minute, .hour]
        let style: CLKRelativeDateStyle = .natural
        return CLKRelativeDateTextProvider(date: date, style: style, units: units)
    }

    fileprivate func timelineEntryDateForDeparture(_ departure: TFCDeparture, previousDeparture: TFCDeparture?) -> Date {
       
        // If previous departure, show the next scheduled departure 1 minute after the last scheduled departure
        // => If a bus is scheduled at 13:00, it will be displayed till 13:01
        if let pd = previousDeparture, let date = pd.getScheduledTimeAsNSDate() {
            return date.addingTimeInterval(Constants.DepartureDuration)
        } else {
            if let schedTime = departure.getScheduledTimeAsNSDate() {
                return schedTime.addingTimeInterval(-6*60*60) // If no previous departure, show the departure 6 hours in advance
            }
        }
        return Date()
    }

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

    fileprivate func getShortDate(_ date:Date) -> String {
        return ShortDateFormatter.string(from: date)
    }

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
