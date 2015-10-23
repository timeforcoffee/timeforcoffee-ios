//
//  Logging.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 23.10.15.
//  Copyright © 2015 opendata.ch. All rights reserved.
//

import Foundation

// from http://stackoverflow.com/questions/28489227/swift-ios-dates-and-times-in-different-format
extension NSDate {
    func formattedWith(format:String) -> String {
        let formatter = NSDateFormatter()
        formatter.dateFormat = format
        return formatter.stringFromDate(self)
    }
    func formattedWithDateFormatter(formatter:NSDateFormatter) -> String {
        return formatter.stringFromDate(self)
    }
}

/**
Prints the filename, function name, line number and textual representation of `object` and a newline character into
the standard output if the build setting for "Other Swift Flags" defines `-D DEBUG`.

The current thread is a prefix on the output. <UI> for the main thread, <BG> for anything else.

Only the first parameter needs to be passed to this funtion.

The textual representation is obtained from the `object` using its protocol conformances, in the following
order of preference: `CustomDebugStringConvertible` and `CustomStringConvertible`. Do not overload this function for
your type. Instead, adopt one of the protocols mentioned above.

:param: object   The object whose textual representation will be printed. If this is an expression, it is lazily evaluated.
:param: file     The name of the file, defaults to the current file without the ".swift" extension.
:param: function The name of the function, defaults to the function within which the call is made.
:param: line     The line number, defaults to the line number within the file that the call is made.
*/

let DLogDateFormatter:NSDateFormatter = {
    let formatter = NSDateFormatter()
    formatter.dateFormat = "H:mm:ss.SSS"
    return formatter
}()

func DLog<T>(@autoclosure object: () -> T, _ file: String = __FILE__, _ function: String = __FUNCTION__, _ line: Int = __LINE__) {
    #if DEBUG
        let value = object()
        let stringRepresentation: String

        if let value = value as? CustomDebugStringConvertible {
            stringRepresentation = value.debugDescription
        } else if let value = value as? CustomStringConvertible {
            stringRepresentation = value.description
        } else {
            fatalError("loggingPrint only works for values that conform to CustomDebugStringConvertible or CustomStringConvertible")
        }
        let fileEscaped = file.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLPathAllowedCharacterSet())
        let fileURL = NSURL(string: fileEscaped!)?.lastPathComponent ?? "Unknown file"

        let queue = NSThread.isMainThread() ? "UI" : "BG"

        //print("\(NSDate().formattedWithDateFormatter(DLogDateFormatter)) <\(queue)> \(fileURL) \(function)[\(line)] - " + stringRepresentation)
        NSLog("<\(queue)> %@  (\(fileURL) \(function)[\(line)])", stringRepresentation)
    #endif
}