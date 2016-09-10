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
    static let DepartureDuration = NSTimeInterval(60) // 1 minute
    static let ComplicationColor = UIColor.orangeColor()
}

class ComplicationController: NSObject, CLKComplicationDataSource, TFCDeparturesUpdatedProtocol {
    
    // MARK: - Timeline Configuration
    
    lazy var watchdata: TFCWatchData = { 
        return TFCWatchData()
        }()

    func getSupportedTimeTravelDirectionsForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationTimeTravelDirections) -> Void) {
        handler([.Forward]) // supports only forward time travel
    }
    
    func getTimelineStartDateForComplication(complication: CLKComplication, withHandler handler: (NSDate?) -> Void) {
        DLog("getTimelineStartDateForComplication", toFile: true)
        func handleReply(stations: TFCStations?) {
            if let station = stations?.first {
                func handleReply2(station: TFCStation?) {
                    if let departure = station?.getFilteredDepartures()?.first {
                        let startDate = timelineEntryDateForDeparture(departure, previousDeparture: nil)
                        DLog("startDate: \(startDate)", toFile: true)
                        handler(startDate)
                    } else {
                        DLog("no Departure, startDate: \(NSDate())", toFile: true)
                        handler(NSDate())
                    }
                }
                self.updateDepartures(station, context: handleReply2)
            }
        }
        watchdata.getStations(handleReply, errorReply: nil, stopWithFavorites: true)
    }
    
    func getTimelineEndDateForComplication(complication: CLKComplication, withHandler handler: (NSDate?) -> Void) {
        DLog("getTimelineEndDateForComplication", toFile: true)
        func handleReply(stations: TFCStations?) {
            if let station = stations?.first {
                DLog("firstStation: \(station.name)", toFile: true)
                func handleReply2(station: TFCStation?) {
                    if let endDate = station?.getFilteredDepartures()?.last?.getScheduledTimeAsNSDate() {
                        DLog("last Departure: \(endDate)", toFile: true)
                        handler(endDate.dateByAddingTimeInterval(70))
                    } else {
                        let endDate = NSDate().dateByAddingTimeInterval(60)
                        DLog("no last Departure, set it to \(endDate)", toFile: true)
                        handler(endDate)
                    }
                }
                self.updateDepartures(station, context: handleReply2)
            }
        }
        self.watchdata.getStations(handleReply, errorReply: nil, stopWithFavorites: true)
    }
    
    func getPrivacyBehaviorForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.ShowOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntryForComplication(complication: CLKComplication, withHandler handler: ((CLKComplicationTimelineEntry?) -> Void)) {
        // Take the first entry before the current date
        getTimelineEntriesForComplication(complication, beforeDate: NSDate(), limit: 1) { (entries) -> Void in
            handler(entries?.first)
        }
    }
    
    func getTimelineEntriesForComplication(complication: CLKComplication, beforeDate date: NSDate, limit: Int, withHandler handler: (([CLKComplicationTimelineEntry]?) -> Void)) {
        // Call the handler with the timeline entries after to the given date
        DLog("getTimelineEntriesForComplication beforeDate", toFile: true)
        func handleReply(stations: TFCStations?) {
            var entries = [CLKComplicationTimelineEntry]()
            
            if let station = stations?.first { // corresponds to the last favorited station or closest station
                func handleReply2(station:TFCStation?) {
                    //just take the first entry here... It's the one we want to display
                    if let departures = station?.getFilteredDepartures(),
                        departure = departures.first {
                        let thisEntryDate = timelineEntryDateForDeparture(departure, previousDeparture: nil)
                        let nextDeparture: TFCDeparture? = (departures.count >= 2) ? departures[1] : nil
                        if let station = station, tmpl = templateForStationDepartures(station, departure: departure, nextDeparture: nextDeparture, complication: complication) {
                            let entry = CLKComplicationTimelineEntry(date: thisEntryDate, complicationTemplate: tmpl)
                            entries.append(entry)
                        }
                    }
                    handler(entries)
                }
                self.updateDepartures(station, context: handleReply2)
            } else {
                handler(entries)
            }
        }
        
        watchdata.getStations(handleReply, errorReply: nil, stopWithFavorites: true)
    }
    
    func getTimelineEntriesForComplication(complication: CLKComplication, afterDate date: NSDate, limit: Int, withHandler handler: (([CLKComplicationTimelineEntry]?) -> Void)) {
        // Call the handler with the timeline entries after to the given date
        DLog("getTimelineEntriesForComplication afterDate: \(date)", toFile: true)
        func handleReply(stations: TFCStations?) {
            var entries = [CLKComplicationTimelineEntry]()
            if let station = stations?.first { // corresponds to the favorited/closest station
                func handleReply2(station: TFCStation?) {
                    if let station = station,
                        departures = station.getFilteredDepartures(limit) {

                            var index = 0
                            var previousDeparture: TFCDeparture? = nil
                            var departure: TFCDeparture? = departures.first
                            var nextDeparture: TFCDeparture? = (departures.count >= 2) ? departures[1] : nil
                            var lastDepartureTimeNew:NSDate? = departure?.getScheduledTimeAsNSDate()
                            while let thisDeparture = departure {
                                let thisEntryDate = timelineEntryDateForDeparture(thisDeparture, previousDeparture: previousDeparture)
                                if date.compare(thisEntryDate) == .OrderedAscending { // check if the entry date is "correctly" after the given date
                                    if let tmpl = templateForStationDepartures(station, departure: thisDeparture, nextDeparture: nextDeparture, complication: complication) {
                                        let entry = CLKComplicationTimelineEntry(date: thisEntryDate, complicationTemplate: tmpl)
                                        entries.append(entry)
                                    }
                                    lastDepartureTimeNew = thisEntryDate
                                    if entries.count >= limit {break} // break if we reached the limit of entries
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
                                    entries.popLast()
                                }
                                if let lastDepartureTimeNew = lastDepartureTimeNew, tmpl = templateForStationDepartures(station, departure: nil, nextDeparture: nil, complication: complication) {
                                    let entry = CLKComplicationTimelineEntry(date: (lastDepartureTimeNew.dateByAddingTimeInterval(60)), complicationTemplate: tmpl)
                                    entries.append(entry)
                                }
                            }
                            if let ud =  NSUserDefaults(suiteName: "group.ch.opendata.timeforcoffee") {
                                ud.setValue(station.st_id, forKey: "lastFirstStationId")
                            }
                            if (lastDepartureTimeNew != nil) {
                                NSUserDefaults().setValue(lastDepartureTimeNew, forKey: "lastDepartureTime")
                                DLog("lastDepartureTime: \(lastDepartureTimeNew)", toFile: true)
                            }
                    } else {
                        NSUserDefaults().setValue(nil, forKey: "lastDepartureTime")
                    }
                    handler(entries)
                }
                self.updateDepartures(station, context: handleReply2)
            } else {
                NSUserDefaults().setValue(nil, forKey: "lastDepartureTime")
                handler(entries)
            }
        }
        watchdata.getStations(handleReply, errorReply: nil, stopWithFavorites: true)
    }
    
    // MARK: - Update Scheduling
    
    func getNextRequestedUpdateDateWithHandler(handler: (NSDate?) -> Void) {
        // Call the handler with the date when you would next like to be given the opportunity to update your complication content

        let nextUpdateDate = watchdata.getNextUpdateTime()
        DLog("getNextRequestedUpdateDateWithHandler: \(nextUpdateDate)", toFile: true)
        handler(nextUpdateDate);
    }
    
    // MARK: - Placeholder Templates
    
    func getPlaceholderTemplateForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationTemplate?) -> Void) {

        let templ = getPlaceholderTemplateForComplication(complication.family)
        handler(templ)

    }

    private func getPlaceholderTemplateForComplication(family: CLKComplicationFamily) -> CLKComplicationTemplate {
        switch family {

        case CLKComplicationFamily.ModularLarge:
            let tmpl = CLKComplicationTemplateModularLargeTable()

            tmpl.headerTextProvider = CLKSimpleTextProvider(text: "Station")
            tmpl.row1Column1TextProvider = CLKSimpleTextProvider(text: "--: ------", shortText: nil)
            tmpl.row1Column2TextProvider = CLKSimpleTextProvider(text: "--", shortText: nil)
            tmpl.row2Column1TextProvider = CLKSimpleTextProvider(text: "--: ------", shortText: nil)
            tmpl.row2Column2TextProvider = CLKSimpleTextProvider(text: "--", shortText: nil)
            return tmpl
        case CLKComplicationFamily.ModularSmall:
            let tmpl = CLKComplicationTemplateModularSmallStackText()
            tmpl.line1TextProvider = CLKSimpleTextProvider(text: "--:");
            tmpl.line2TextProvider = CLKSimpleTextProvider(text: "-");
            return tmpl
        case CLKComplicationFamily.UtilitarianLarge:
            let tmpl = CLKComplicationTemplateUtilitarianLargeFlat()
            tmpl.textProvider = CLKSimpleTextProvider(text: "--: --:-- ------")
            return tmpl
        case CLKComplicationFamily.UtilitarianSmall:
            let tmpl = CLKComplicationTemplateUtilitarianSmallFlat()
            tmpl.textProvider = CLKSimpleTextProvider(text: "--: -");
            return tmpl
        case CLKComplicationFamily.CircularSmall:
            let tmpl = CLKComplicationTemplateCircularSmallStackText()
            tmpl.line1TextProvider = CLKSimpleTextProvider(text: "--:");
            tmpl.line2TextProvider = CLKSimpleTextProvider(text: "-");
            return tmpl
        default:
            let tmpl = CLKComplicationTemplateCircularSmallStackText()
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
    
    private func templateForStationDepartures(station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?, complication: CLKComplication) -> CLKComplicationTemplate? {

        switch (complication.family) {
        case CLKComplicationFamily.ModularLarge:
            return getModularLargeTemplate(station, departure: departure, nextDeparture: nextDeparture)
        case CLKComplicationFamily.ModularSmall:
            return getModularSmallTemplate(station, departure: departure, nextDeparture: nextDeparture)
        case CLKComplicationFamily.UtilitarianLarge:
            return getUtilitarianLargeTemplate(station, departure: departure, nextDeparture: nextDeparture)
        case CLKComplicationFamily.UtilitarianSmall:
            return getUtilitarianSmallTemplate(station, departure: departure, nextDeparture: nextDeparture)
        case CLKComplicationFamily.CircularSmall:
            return getCircularSmallTemplate(station, departure: departure, nextDeparture: nextDeparture)
        default:
            return getCircularSmallTemplate(station, departure: departure, nextDeparture: nextDeparture)
        }
    }


    private func getCircularSmallTemplate(station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateCircularSmallStackText {

        if let departure = departure, departureTime = departure.getScheduledTimeAsNSDate() {
            let tmpl = CLKComplicationTemplateCircularSmallStackText()
            tmpl.tintColor = Constants.ComplicationColor
            let departureLine = departure.getLine()
            tmpl.line1TextProvider = CLKSimpleTextProvider(text: "\(departureLine):")
            tmpl.line2TextProvider = getDateProvider(departureTime)
            return tmpl

        }
        return getPlaceholderTemplateForComplication(CLKComplicationFamily.CircularSmall) as! CLKComplicationTemplateCircularSmallStackText
    }

    private func getUtilitarianLargeTemplate(station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateUtilitarianLargeFlat {

        if let departure = departure, departureTime = departure.getScheduledTime() {

            let tmpl = CLKComplicationTemplateUtilitarianLargeFlat()
            tmpl.tintColor = Constants.ComplicationColor

            let departureLine = departure.getLine()
            let departureDestination = departure.getDestination(station)
            tmpl.textProvider = CLKSimpleTextProvider(text: "\(departureLine): \(departureTime) \(departureDestination)")
            return tmpl
        }
        return getPlaceholderTemplateForComplication(CLKComplicationFamily.UtilitarianLarge) as! CLKComplicationTemplateUtilitarianLargeFlat

    }

    private func getUtilitarianSmallTemplate(station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateUtilitarianSmallFlat {

        if let departure = departure, departureTime = departure.getScheduledTime() {
            let tmpl = CLKComplicationTemplateUtilitarianSmallFlat()
            tmpl.tintColor = Constants.ComplicationColor
            let departureLine = departure.getLine()
            tmpl.textProvider = CLKSimpleTextProvider(text: "\(departureLine): \(departureTime)")
            return tmpl
        }
        return getPlaceholderTemplateForComplication(CLKComplicationFamily.UtilitarianSmall) as! CLKComplicationTemplateUtilitarianSmallFlat
    }

    private func getModularSmallTemplate(station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateModularSmallStackText {

        if let  departure = departure, departureTime = departure.getScheduledTimeAsNSDate() {
            let tmpl = CLKComplicationTemplateModularSmallStackText()
            tmpl.tintColor = Constants.ComplicationColor
            let departureLine = departure.getLine()
            tmpl.line1TextProvider = CLKSimpleTextProvider(text: "\(departureLine):")
            tmpl.line2TextProvider = getDateProvider(departureTime)
            return tmpl
        }
        return getPlaceholderTemplateForComplication(CLKComplicationFamily.ModularSmall) as! CLKComplicationTemplateModularSmallStackText

    }

    private func getModularLargeTemplate(station: TFCStation, departure: TFCDeparture?, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateModularLargeTable {

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
        return getPlaceholderTemplateForComplication(CLKComplicationFamily.ModularLarge) as! CLKComplicationTemplateModularLargeTable

    }

    private func getDateProvider(date: NSDate) -> CLKRelativeDateTextProvider {
        let units: NSCalendarUnit = [.Minute, .Hour]
        let style: CLKRelativeDateStyle = .Natural
        return CLKRelativeDateTextProvider(date: date, style: style, units: units)
    }

    private func timelineEntryDateForDeparture(departure: TFCDeparture, previousDeparture: TFCDeparture?) -> NSDate {
       
        // If previous departure, show the next scheduled departure 1 minute after the last scheduled departure
        // => If a bus is scheduled at 13:00, it will be displayed till 13:01
        if let pd = previousDeparture, let date = pd.getScheduledTimeAsNSDate() {
            return date.dateByAddingTimeInterval(Constants.DepartureDuration)
        } else {
            if let schedTime = departure.getScheduledTimeAsNSDate() {
                return schedTime.dateByAddingTimeInterval(-6*60*60) // If no previous departure, show the departure 6 hours in advance
            }
        }
        return NSDate()
    }

    func departuresUpdated(error: NSError?, context: Any?, forStation: TFCStation?) {
        departuresUpdatedCallback(context, forStation: forStation)
    }
    func departuresStillCached(context: Any?, forStation: TFCStation?) {
        departuresUpdatedCallback(context, forStation: forStation)
    }

    private func departuresUpdatedCallback(context: Any?, forStation: TFCStation?) {
        if let reply = context as? replyStation {
            reply(forStation)
        }
    }

    private func getShortDate(date:NSDate) -> String {
        let format = "HH:mm"
        let dateFmt = NSDateFormatter()
        dateFmt.timeZone = NSTimeZone.defaultTimeZone()
        dateFmt.locale = NSLocale(localeIdentifier: "de_CH")
        dateFmt.dateFormat = format
        return dateFmt.stringFromDate(date)
    }

    private func getDepartureTTL(station: TFCStation) -> Int {
        if (watchdata.needsDeparturesUpdate(station)) {
            return 20 //default
        }
        return 6 * 3600
    }

    private func updateDepartures(station: TFCStation, context: Any) {
        station.updateDepartures(self, context: context, cachettl: self.getDepartureTTL(station))
    }

}
