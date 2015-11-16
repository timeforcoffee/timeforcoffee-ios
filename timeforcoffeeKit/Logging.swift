//
//  Logging.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 23.10.15.
//  Copyright © 2015 opendata.ch. All rights reserved.
//

import Foundation
import WatchConnectivity

// from http://stackoverflow.com/questions/28489227/swift-ios-dates-and-times-in-different-format
extension NSDate {
    func formattedWith(format:String) -> String {
        let formatter = NSDateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = NSTimeZone.defaultTimeZone()
        formatter.locale = NSLocale(localeIdentifier: "de_CH")
        return formatter.stringFromDate(self)
    }
    func formattedWithDateFormatter(formatter:NSDateFormatter) -> String {
        return formatter.stringFromDate(self)
    }
}

extension String {
    func appendLineToURL(fileURL: NSURL) throws {
        try self.stringByAppendingString("\n").appendToURL(fileURL)
    }

    func appendToURL(fileURL: NSURL) throws {
        let data = self.dataUsingEncoding(NSUTF8StringEncoding)!
        try data.appendToURL(fileURL)
    }
}

extension NSData {
    func appendToURL(fileURL: NSURL) throws {
        if let fileHandle = try? NSFileHandle(forWritingToURL: fileURL) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.writeData(self)
        }
        else {
            try writeToURL(fileURL, options: .DataWritingAtomic)
        }
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
    formatter.dateFormat = "YYYY-MM-dd H:mm:ss.SSS"
    formatter.timeZone = NSTimeZone(name: "Europe/Zurich")
    return formatter
}()

func DLog<T>(@autoclosure object: () -> T, toFile: Bool = false, _ file: String = __FILE__, _ function: String = __FUNCTION__, _ line: Int = __LINE__) {
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
        NSLog("<\(queue)> %@ (\(fileURL) \(function)[\(line)])", stringRepresentation)
        if (toFile) {
            let text = "\(NSDate().formattedWithDateFormatter(DLogDateFormatter)) <\(queue)> \(stringRepresentation)  (\(fileURL) \(function)[\(line)])"
        #if os(watchOS)
            DLog2WatchConnectivity(text)
        #else
            DLog2File(text)
        #endif
        }
    #endif
}

//we can't read the file from the Watch, so send it to the iPhone to be read from there
private func DLog2WatchConnectivity(text:String) {
    if #available(iOS 9.0, *) {
        WCSession.defaultSession().transferUserInfo(["__logThis__": text])
    }
}

private func DLog2File(text:String) {
    let file = "log.txt"
    if let dir : NSString = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.AllDomainsMask, true).first {
        let path = dir.stringByAppendingPathComponent(file);
        // try! NSFileManager.defaultManager().removeItemAtPath(path)
        let dtext = "\(text)"
        let url = NSURL(fileURLWithPath: path)
        let _ = try? url.setResourceValue(true, forKey: NSURLIsExcludedFromBackupKey)
        try! dtext.appendLineToURL(url)
    }
}
