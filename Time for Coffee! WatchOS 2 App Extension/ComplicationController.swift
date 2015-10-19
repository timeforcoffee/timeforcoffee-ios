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
    static let FrequencyOfTimelineUpdate = NSTimeInterval(1.5*60*60) // 1.5 hour
    static let TimelineUpdateMinutesBeforeEnd = NSTimeInterval(-15*60) // 15 minutes
    static let ComplicationColor = UIColor.orangeColor()
}

class ComplicationController: NSObject, CLKComplicationDataSource, TFCDeparturesUpdatedProtocol {
    
    // MARK: - Timeline Configuration
    
    private var lastDepartureTime:NSDate?
    func getSupportedTimeTravelDirectionsForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationTimeTravelDirections) -> Void) {
        handler([.Forward]) // supports only forward time travel
    }
    
    func getTimelineStartDateForComplication(complication: CLKComplication, withHandler handler: (NSDate?) -> Void) {
        func handleReply(stations: TFCStations?) {
            if let station = stations?.stations?.first {
                func handleReply2(station: TFCStation?) {
                    if let station = station {
                        if let departure = station.getFilteredDepartures()?.first {
                            let startDate = timelineEntryDateForDeparture(departure, previousDeparture: nil)
                            handler(startDate)
                        }
                    }
                }
                station.updateDepartures(self, force: false, context: handleReply2)
            }
        }
        TFCWatchData.sharedInstance.getStations(handleReply, errorReply: nil, stopWithFavorites: true)
    }
    
    func getTimelineEndDateForComplication(complication: CLKComplication, withHandler handler: (NSDate?) -> Void) {
        func handleReply(stations: TFCStations?) {
            if let station = stations?.stations?.first {
                func handleReply2(station: TFCStation?) {
                    if let station = station {
                        let endDate = station.getFilteredDepartures()?.last?.getScheduledTimeAsNSDate()
                        handler(endDate)
                    }
                }
                station.updateDepartures(self, force: false, context: handleReply2)
            }
        }
        TFCWatchData.sharedInstance.getStations(handleReply, errorReply: nil, stopWithFavorites: true)
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
        
        func handleReply(stations: TFCStations?) {
            var entries = [CLKComplicationTimelineEntry]()
            
            if let station = stations?.stations?.first { // corresponds to the last favorited station or closest station
                func handleReply2(station:TFCStation?) {
                    if let station = station {
                        //just take the first entry here... It's the one we want to display
                        if let stations = station.getFilteredDepartures(),
                                departure = stations.first {
                            let thisEntryDate = timelineEntryDateForDeparture(departure, previousDeparture: nil)
                            let tmpl = templateForStationDepartures(station, departure: departure, nextDeparture: stations[1], complication: complication)
                            let entry = CLKComplicationTimelineEntry(date: thisEntryDate, complicationTemplate: tmpl!)
                            entries.append(entry)
                        }
                        handler(entries)
                    }
                }
                station.updateDepartures(self, force: false, context: handleReply2)
            }
        }
        
        TFCWatchData.sharedInstance.getStations(handleReply, errorReply: nil, stopWithFavorites: true)
    }
    
    func getTimelineEntriesForComplication(complication: CLKComplication, afterDate date: NSDate, limit: Int, withHandler handler: (([CLKComplicationTimelineEntry]?) -> Void)) {
        // Call the handler with the timeline entries after to the given date
        
        func handleReply(stations: TFCStations?) {
            var entries = [CLKComplicationTimelineEntry]()

            self.lastDepartureTime = nil
            if let station = stations?.stations?.first { // corresponds to the favorited/closest station
                func handleReply2(station: TFCStation?) {
                    if let station = station,
                        departures = station.getFilteredDepartures() {

                            var index = 0
                            var previousDeparture: TFCDeparture? = nil
                            var departure: TFCDeparture? = departures.first
                            var nextDeparture: TFCDeparture? = (departures.count >= 2) ? departures[1] : nil

                            while let thisDeparture = departure {
                                let thisEntryDate = timelineEntryDateForDeparture(thisDeparture, previousDeparture: previousDeparture)
                                if date.compare(thisEntryDate) == .OrderedAscending { // check if the entry date is "correctly" after the given date
                                    let tmpl = templateForStationDepartures(station, departure: thisDeparture, nextDeparture: nextDeparture, complication: complication)
                                    let entry = CLKComplicationTimelineEntry(date: thisEntryDate, complicationTemplate: tmpl!)
                                    entries.append(entry)
                                    lastDepartureTime = thisEntryDate
                                    if entries.count == limit {break} // break if we reached the limit of entries
                                }
                                index++
                                previousDeparture = thisDeparture
                                departure = (departures.count - 1 >= index) ? departures[index] : nil
                                nextDeparture = (departures.count > index + 1) ? departures[index + 1] : nil
                            }
                            if let ud =  NSUserDefaults(suiteName: "group.ch.opendata.timeforcoffee") {
                                ud.setValue(station.st_id, forKey: "lastFirstStationId")
                            }


                            handler(entries)
                    }
                    
                }
                station.updateDepartures(self, force: false, context: handleReply2)

            }
        }
        TFCWatchData.sharedInstance.getStations(handleReply, errorReply: nil, stopWithFavorites: true)
    }
    
    // MARK: - Update Scheduling
    
    func getNextRequestedUpdateDateWithHandler(handler: (NSDate?) -> Void) {
        // Call the handler with the date when you would next like to be given the opportunity to update your complication content
        let nextUpdateDate:NSDate
        let maxNextUpdateDate = NSDate().dateByAddingTimeInterval(Constants.FrequencyOfTimelineUpdate)
        if let nextUpdate =  self.lastDepartureTime {
            let lastEntryDate = nextUpdate.dateByAddingTimeInterval(Constants.TimelineUpdateMinutesBeforeEnd)
            if (maxNextUpdateDate.timeIntervalSinceReferenceDate < lastEntryDate.timeIntervalSinceReferenceDate) {
                nextUpdateDate = maxNextUpdateDate
            } else {
                nextUpdateDate = lastEntryDate
            }
        } else {
            nextUpdateDate =  maxNextUpdateDate // request an update each 1.5 hour
        }
        handler(nextUpdateDate);
    }
    
    // MARK: - Placeholder Templates
    
    func getPlaceholderTemplateForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationTemplate?) -> Void) {

        switch complication.family {
            
        case CLKComplicationFamily.ModularLarge:
            let tmpl = CLKComplicationTemplateModularLargeTable()
            
            tmpl.headerTextProvider = CLKSimpleTextProvider(text: "Station")
            tmpl.row1Column1TextProvider = CLKSimpleTextProvider(text: "29: Holzwil", shortText: nil)
            tmpl.row1Column2TextProvider = CLKSimpleTextProvider(text: "9", shortText: nil)
            tmpl.row2Column1TextProvider = CLKSimpleTextProvider(text: "29: Holzwil", shortText: nil)
            tmpl.row2Column2TextProvider = CLKSimpleTextProvider(text: "18", shortText: nil)
            
            handler(tmpl)
            break
        case CLKComplicationFamily.ModularSmall:
            let tmpl = CLKComplicationTemplateModularSmallStackText()
            tmpl.line1TextProvider = CLKSimpleTextProvider(text: "29:");
            tmpl.line2TextProvider = CLKSimpleTextProvider(text: "9");
            handler(tmpl)
            break
        case CLKComplicationFamily.UtilitarianLarge:
            let tmpl = CLKComplicationTemplateUtilitarianLargeFlat()
            let shortDate = self.getShortDate(NSDate().dateByAddingTimeInterval(9 * 60))
            tmpl.textProvider = CLKSimpleTextProvider(text: "29: \(shortDate) Holzwil")
            handler(tmpl)
            break
        case CLKComplicationFamily.UtilitarianSmall:
            let tmpl = CLKComplicationTemplateUtilitarianSmallFlat()
            tmpl.textProvider = CLKSimpleTextProvider(text: "29: 9");
            handler(tmpl)
            break
        case CLKComplicationFamily.CircularSmall:
            let tmpl = CLKComplicationTemplateCircularSmallStackText()
            tmpl.line1TextProvider = CLKSimpleTextProvider(text: "29:");
            tmpl.line2TextProvider = CLKSimpleTextProvider(text: "9");
            handler(tmpl)
            break
        }
    }
    
    func requestedUpdateDidBegin() {
        // get the shared instance
        let server = CLKComplicationServer.sharedInstance()
        
        // reload the timeline for all complications
        for complication in server.activeComplications {
            server.reloadTimelineForComplication(complication)
        }
    }
    
    func requestedUpdateBudgetExhausted() {
        // get the shared instance
        let server = CLKComplicationServer.sharedInstance()
        
        // reload the timeline for all complications
        for complication in server.activeComplications {
            server.reloadTimelineForComplication(complication)
        }
    }
    
    //MARK: - Convenience
    
    private func templateForStationDepartures(station: TFCStation, departure: TFCDeparture, nextDeparture: TFCDeparture?, complication: CLKComplication) -> CLKComplicationTemplate? {

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
        }
    }


    private func getCircularSmallTemplate(station: TFCStation, departure: TFCDeparture, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateCircularSmallStackText {
        let tmpl = CLKComplicationTemplateCircularSmallStackText()

        tmpl.tintColor = Constants.ComplicationColor

        let departureLine = departure.getLine()
        if let departureTime = departure.getScheduledTimeAsNSDate() {
            tmpl.line1TextProvider = CLKSimpleTextProvider(text: "\(departureLine):")
            tmpl.line2TextProvider = getDateProvider(departureTime)
        }
        return tmpl
    }

    private func getUtilitarianLargeTemplate(station: TFCStation, departure: TFCDeparture, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateUtilitarianLargeFlat {
            let tmpl = CLKComplicationTemplateUtilitarianLargeFlat()

            tmpl.tintColor = Constants.ComplicationColor

            let departureLine = departure.getLine()
            let departureDestination = departure.getDestination(station)
            if let departureTime = departure.getScheduledTime() {
                tmpl.textProvider = CLKSimpleTextProvider(text: "\(departureLine): \(departureTime) \(departureDestination)")
            }
            return tmpl
    }

    private func getUtilitarianSmallTemplate(station: TFCStation, departure: TFCDeparture, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateUtilitarianSmallFlat {
        let tmpl = CLKComplicationTemplateUtilitarianSmallFlat()

        tmpl.tintColor = Constants.ComplicationColor

        let departureLine = departure.getLine()
        if let departureTime = departure.getScheduledTime() {
            tmpl.textProvider = CLKSimpleTextProvider(text: "\(departureLine): \(departureTime)")
        }
        return tmpl
    }

    private func getModularSmallTemplate(station: TFCStation, departure: TFCDeparture, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateModularSmallStackText {
        let tmpl = CLKComplicationTemplateModularSmallStackText()

        tmpl.tintColor = Constants.ComplicationColor

        let departureLine = departure.getLine()
        if let departureTime = departure.getScheduledTimeAsNSDate() {
            tmpl.line1TextProvider = CLKSimpleTextProvider(text: "\(departureLine):")
            tmpl.line2TextProvider = getDateProvider(departureTime)
        }
        return tmpl
    }

    private func getModularLargeTemplate(station: TFCStation, departure: TFCDeparture, nextDeparture: TFCDeparture?) -> CLKComplicationTemplateModularLargeTable {
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

    private func getDateProvider(date: NSDate) -> CLKRelativeDateTextProvider {
        let units: NSCalendarUnit = [.Minute]
        let style: CLKRelativeDateStyle = .Timer
        return CLKRelativeDateTextProvider(date: date, style: style, units: units)
    }

    private func timelineEntryDateForDeparture(departure: TFCDeparture, previousDeparture: TFCDeparture?) -> NSDate {
       
        // If previous departure, show the next scheduled departure 1 minute after the last scheduled departure
        // => If a bus is scheduled at 13:00, it will be displayed till 13:01
        if let pd = previousDeparture, let date = pd.getScheduledTimeAsNSDate() {
            return date.dateByAddingTimeInterval(Constants.DepartureDuration)
        } else {
            return departure.getScheduledTimeAsNSDate()!.dateByAddingTimeInterval(-6*60*60) // If no previous departure, show the departure 6 hours in advance
        }
    }

    func departuresUpdated(error: NSError?, context: Any?, forStation: TFCStation?) {
        departuresUpdatedCallback(context, forStation: forStation)
    }
    func departuresStillCached(context: Any?, forStation: TFCStation?) {
        departuresUpdatedCallback(context, forStation: forStation)
    }

    private func departuresUpdatedCallback(context: Any?, forStation: TFCStation?) {
        if let contextInfo: TFCStationBase.contextData = context as! TFCStationBase.contextData? {
            if let reply = contextInfo.context as? replyStation {
                reply(forStation)
            }
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
}
