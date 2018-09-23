//
//  TFCDeparturePass.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 30.10.15.
//  Copyright © 2015 opendata.ch. All rights reserved.
//

import Foundation
import UIKit

open class TFCDeparturePass: NSObject {

    open var scheduled: Date?
    open var realtime: Date?
    open var platform: String?
    var accessible: Bool = false
    var outdated: Bool = false
    open var arrivalScheduled: Date?
    open var arrivalRealtime: Date?

    class func parseJsonForDeparture(_ result:JSON) -> (Date?, Date?, Date?, Date?) {

        let scheduledStr = result["departure"]["scheduled"].string
        let realtimeStr = result["departure"]["realtime"].string
        let arrivalScheduledStr = result["arrival"]["scheduled"].string
        let arrivalRealtimeStr = result["arrival"]["realtime"].string

        let scheduled = self.getDateFromString(scheduledStr)
        let realtime = self.getDateFromString(realtimeStr)
        let arrivalScheduled = self.getDateFromString(arrivalScheduledStr)
        let arrivalRealtime = self.getDateFromString(arrivalRealtimeStr)

        return (scheduled, realtime, arrivalScheduled, arrivalRealtime)
    }

    fileprivate class func getDateFromString(_ datestring:String?) -> Date? {
        if let datestring = datestring {
            return self.parseDate(datestring);
        }
        return nil
    }

    open func getDepartureTime(_ additionalInfo: Bool = true) ->
        (NSMutableAttributedString?, String?) {
            return getDepartureTime(self.scheduled, realtime: self.realtime, additionalInfo: additionalInfo)
    }
    
    open func getDepartureTime(_ scheduled: Date?, realtime: Date?, additionalInfo: Bool = true) -> (NSMutableAttributedString?, String?) {
        var realtimeStr: String = ""
        var scheduledStr: String = ""
        let attributesNoStrike = [:] as [NSAttributedString.Key : Any]
        let attributesStrike = [
            NSAttributedString.Key.strikethroughStyle: NSUnderlineStyle.single.rawValue,
            NSAttributedString.Key.strikethroughColor: UIColor.gray,
            NSAttributedString.Key.baselineOffset: 0,
            NSAttributedString.Key.foregroundColor: UIColor.gray
        ] as [NSAttributedString.Key : Any]

        let additionalInfo2:Bool = (additionalInfo && TFCSettings.sharedInstance.showRealTimeDebugInfo())

        // if you want bold and italic, do this, but the accessibility icon isn't available in italic :)
        /*let fontDescriptor = UIFontDescriptor.preferredFontDescriptorWithTextStyle(UIFontTextStyleBody)
        let bi = UIFontDescriptorSymbolicTraits.TraitItalic | UIFontDescriptorSymbolicTraits.TraitBold
        let fda = fontDescriptor.fontDescriptorWithSymbolicTraits(bi).fontAttributes()
        let fontName = fda["NSFontNameAttribute"] as String
        */
        /*  let attributesBoldItalic = [
        NSFontAttributeName: UIFont(name: "HelveticaNeue-Bold", size: 13.0)!
        ]*/

        var timestringAttr: NSMutableAttributedString?
        var timestring: String?

        if let realtime = realtime {
            realtimeStr = self.getShortDate(realtime)
        }
        if let scheduled = scheduled {
            scheduledStr = self.getShortDate(scheduled)
        }

        // we do two different approaches here, since NSMutableAttributedString seems to
        // use a lot of memory for the today widget and it's only needed, when
        // there's a delay

        if (self.realtime != nil && self.realtime != self.scheduled) {
            //the nostrike is needed due to an apple bug...
            // https://stackoverflow.com/questions/25956183/nsmutableattributedstrings-attribute-nsstrikethroughstyleattributename-doesnt

            timestringAttr = NSMutableAttributedString(string: "", attributes: attributesStrike)
            timestringAttr?.append(NSAttributedString(string: "\(realtimeStr) ", attributes: attributesNoStrike))
            timestringAttr?.append(NSAttributedString(string: "\(scheduledStr)", attributes: attributesStrike))
        } else {
            timestring = "\(scheduledStr)"
        }

        if (accessible) {
            if (timestringAttr != nil) {
                timestringAttr?.append(NSAttributedString(string: " ♿︎"))
            } else {
                timestring? += " ♿︎"
            }
        }
        if (additionalInfo2) {
            if (realtime == nil) {
                if (timestringAttr != nil) {
                    timestringAttr?.append(NSAttributedString(string: " (no real-time data)", attributes: attributesNoStrike))
                } else {
                    timestring? += " (no real-time data)"
                }
            } else if (self.outdated) {
                if (timestringAttr != nil) {
                    timestringAttr?.append(NSAttributedString(string: " (not updated)", attributes: attributesNoStrike))
                } else {
                    timestring? += " (not updated)"
                }
            }
        }

        if let platform = self.platform {
            if (timestringAttr != nil) {
                timestringAttr?.append(NSAttributedString(string: " - Pl: \(platform)", attributes: attributesNoStrike))
            } else {
                timestring? += " - Pl: \(platform)"
            }
        }
        return (timestringAttr, timestring)
    }

    static let ShortDateFormatter:DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "de_CH")
        return formatter
    }()

    static let LongDateFormatter:DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.'000'ZZZZZ"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "de_CH")
        return formatter
    }()

    static let LongDateFormatterTransport:DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "de_CH")
        return formatter
    }()

    func getShortDate(_ date:Date) -> String {
        return TFCDeparturePass.ShortDateFormatter.string(from: date)
    }

    fileprivate class func parseDate(_ dateStr:String) -> Date? {
        if let date = LongDateFormatter.date(from: dateStr) {
            return date
        }
        //used by transport.opendata.ch, if the one above fails
        return LongDateFormatterTransport.date(from: dateStr)
    }

    open func getMinutesAsInt(_ from:Date = Date()) -> Int? {
        var timeInterval: TimeInterval?

        if let realdeparture = self.getRealDepartureDate() {
            timeInterval = realdeparture.timeIntervalSinceReferenceDate - from.timeIntervalSinceReferenceDate
        }
        if (timeInterval != nil) {
            return Int(ceil(timeInterval! / 60));
        }
        return nil
    }

    open func getRealDepartureDate() -> Date? {

        if let realtime = self.realtime {
            return realtime
        }
        return scheduled
    }

    open func getRealDepartureDateAsShortDate() -> String? {
        if let date = getRealDepartureDate() {
            return getShortDate(date)
        }
        return nil
    }

}
