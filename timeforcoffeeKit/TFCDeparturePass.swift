//
//  TFCDeparturePass.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 30.10.15.
//  Copyright © 2015 opendata.ch. All rights reserved.
//

import Foundation
import UIKit

public class TFCDeparturePass: NSObject {

    public var scheduled: NSDate?
    public var realtime: NSDate?
    public var platform: String?
    var accessible: Bool = false
    var outdated: Bool = false
    public var arrivalScheduled: NSDate?
    public var arrivalRealtime: NSDate?

    class func parseJsonForDeparture(result:JSON) -> (NSDate?, NSDate?, NSDate?, NSDate?) {

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

    private class func getDateFromString(datestring:String?) -> NSDate? {
        if let datestring = datestring {
            return self.parseDate(datestring);
        }
        return nil
    }

    public func getDepartureTime(additionalInfo: Bool = true) ->
        (NSMutableAttributedString?, String?) {
            return getDepartureTime(self.scheduled, realtime: self.realtime, additionalInfo: additionalInfo)
    }
    
    public func getDepartureTime(scheduled: NSDate?, realtime: NSDate?, additionalInfo: Bool = true) -> (NSMutableAttributedString?, String?) {
        var realtimeStr: String = ""
        var scheduledStr: String = ""
        let attributesNoStrike = [
            NSStrikethroughStyleAttributeName: 0,
        ]
        let attributesStrike = [
            NSStrikethroughStyleAttributeName: 1,
            NSForegroundColorAttributeName: UIColor.grayColor()
        ]

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
            timestringAttr = NSMutableAttributedString(string: "")

            //the nostrike is needed due to an apple bug...
            // https://stackoverflow.com/questions/25956183/nsmutableattributedstrings-attribute-nsstrikethroughstyleattributename-doesnt
            timestringAttr?.appendAttributedString(NSAttributedString(string: "\(realtimeStr) ", attributes: attributesNoStrike))

            timestringAttr?.appendAttributedString(NSAttributedString(string: "\(scheduledStr)", attributes: attributesStrike))
        } else {
            timestring = "\(scheduledStr)"
        }

        if (accessible) {
            if (timestringAttr != nil) {
                timestringAttr?.appendAttributedString(NSAttributedString(string: " ♿︎"))
            } else {
                timestring? += " ♿︎"
            }
        }
        if (additionalInfo2) {
            if (realtime == nil) {
                if (timestringAttr != nil) {
                    timestringAttr?.appendAttributedString(NSAttributedString(string: " (no real-time data)"))
                } else {
                    timestring? += " (no real-time data)"
                }
            } else if (self.outdated) {
                if (timestringAttr != nil) {
                    timestringAttr?.appendAttributedString(NSAttributedString(string: " (not updated)"))
                } else {
                    timestring? += " (not updated)"
                }
            }
        }

        if let platform = self.platform {
            if (timestringAttr != nil) {
                timestringAttr?.appendAttributedString(NSAttributedString(string: " - Pl: \(platform)"))
            } else {
                timestring? += " - Pl: \(platform)"
            }
            
        }
        return (timestringAttr, timestring)
    }

    func getShortDate(date:NSDate) -> String {
        let format = "HH:mm"
        let dateFmt = NSDateFormatter()
        dateFmt.timeZone = NSTimeZone.defaultTimeZone()
        dateFmt.locale = NSLocale(localeIdentifier: "de_CH")
        dateFmt.dateFormat = format
        return dateFmt.stringFromDate(date)
    }

    private class func parseDate(dateStr:String) -> NSDate? {
        var format = "yyyy-MM-dd'T'HH:mm:ss.'000'ZZZZZ"
        let dateFmt = NSDateFormatter()
        dateFmt.timeZone = NSTimeZone.defaultTimeZone()
        dateFmt.locale = NSLocale(localeIdentifier: "de_CH")
        dateFmt.dateFormat = format
        if let date =  dateFmt.dateFromString(dateStr) {
            return date
        }
        //used by transport.opendata.ch, if the one above fails
        format = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        dateFmt.dateFormat = format
        return dateFmt.dateFromString(dateStr)
    }

    public func getMinutesAsInt(from:NSDate = NSDate()) -> Int? {
        var timeInterval: NSTimeInterval?

        if let realdeparture = self.getRealDepartureDate() {
            timeInterval = realdeparture.timeIntervalSinceReferenceDate - from.timeIntervalSinceReferenceDate
        }
        if (timeInterval != nil) {
            return Int(ceil(timeInterval! / 60));
        }
        return nil
    }

    public func getRealDepartureDate() -> NSDate? {

        if let realtime = self.realtime {
            return realtime
        }
        return scheduled
    }

    public func getRealDepartureDateAsShortDate() -> String? {
        if let date = getRealDepartureDate() {
            return getShortDate(date)
        }
        return nil
    }

}
