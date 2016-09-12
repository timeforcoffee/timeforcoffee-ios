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
    formatter.dateFormat = "YYYY-MM-dd HH:mm:ss.SSS"
    formatter.timeZone = NSTimeZone(name: "Europe/Zurich")
    return formatter
}()

let DLogDayHourFormatter:NSDateFormatter = {
    let formatter = NSDateFormatter()
    formatter.dateFormat = "YYYY-MM-dd-HH"
    formatter.timeZone = NSTimeZone(name: "Europe/Zurich")
    return formatter
}()


let DLogDayHourMinuteFormatter:NSDateFormatter = {
    let formatter = NSDateFormatter()
    formatter.dateFormat = "YYYY-MM-dd-HH-mm"
    formatter.timeZone = NSTimeZone(name: "Europe/Zurich")
    return formatter
}()

func DLog<T>(@autoclosure object: () -> T, toFile: Bool = false, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
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
            #endif
            DLog2File(text)
        }
    #endif
}

func SendLogs2Phone() {
    #if DEBUG
        if #available(iOS 9.0, *) {
            let filemanager = NSFileManager.defaultManager()

            if let path = filemanager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first {

                let oldUrl = path.URLByAppendingPathComponent("old", isDirectory: true)
                if (!filemanager.fileExistsAtPath(oldUrl!.path!, isDirectory: nil)) {
                    try! filemanager.createDirectoryAtURL(oldUrl!, withIntermediateDirectories: true, attributes: nil)
                }

                if let directoryContents = try? filemanager.contentsOfDirectoryAtURL( path, includingPropertiesForKeys: nil, options: []) {
                    let logFiles = directoryContents.filter{ $0.pathExtension == "txt"}
                    let nowFile = getWatchLogFileName()
                    for file in logFiles {
                        if let name = file.lastPathComponent {
                            if (name != nowFile) {
                                //move to old dir, if not current anymore
                                if let moveTo = oldUrl!.URLByAppendingPathComponent(name) {
                                    if filemanager.fileExistsAtPath(moveTo.path!) {
                                        let _ = try? filemanager.removeItemAtURL(moveTo)
                                    }
                                    let _ = try? filemanager.moveItemAtURL(file, toURL: moveTo)
                                    WCSession.defaultSession().transferFile(moveTo, metadata: nil)
                                }
                            } else {
                                WCSession.defaultSession().transferFile(file, metadata: nil)
                            }
                        }

                    }
                }
                //delete files older than a day
                if let directoryContents = try? filemanager.contentsOfDirectoryAtURL( oldUrl!, includingPropertiesForKeys: nil, options: []) {
                    let logFiles = directoryContents.filter{ $0.pathExtension == "txt"}
                    for file in logFiles {
                        var modified: AnyObject?
                        do {
                            try file.getResourceValue(&modified, forKey: NSURLContentModificationDateKey)
                            let mod = modified as? NSDate
                            if mod?.dateByAddingTimeInterval(24 * 3600) < NSDate() {
                                DLog("\(file.lastPathComponent!) is older than a day, delete it", toFile: true)
                                try filemanager.removeItemAtURL(file)
                            }

                        } catch let error as NSError {
                            DLog("\(#function) Error: \(error)", toFile: true)
                        }
                    }
                }
            }


        }
    #endif
}


//we can't read the file from the Watch, so send it to the iPhone to be read from there
private func DLog2WatchConnectivity(text:String) {
    if #available(iOS 9.0, *) {
        let message = ["__logThis__": text]
        let session = WCSession.defaultSession()
        if (session.reachable == true) {
            session.sendMessage(message, replyHandler: nil, errorHandler: {(error: NSError) in
                DLog("send Log Message failed due to error \(error): Send via transferUserInfo")
                session.transferUserInfo(message)
            })
        } else {
            session.transferUserInfo(message)
        }
    }
}
private func getWatchLogFileName() -> String {
    return "watch-log-\(NSDate().formattedWithDateFormatter(DLogDayHourMinuteFormatter)).txt"
}

private func DLog2File(text:String) {
    #if os(watchOS)
        let file = getWatchLogFileName()
        let iCloudDocumentsURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first
    #else
        let file = "log-\(NSDate().formattedWithDateFormatter(DLogDayHourFormatter)).txt"
        let iCloudDocumentsURL = NSFileManager.defaultManager().URLForUbiquityContainerIdentifier("iCloud.ch.opendata.timeforcoffee")?.URLByAppendingPathComponent("Documents")!
    #endif

    if  let iCloudDocumentsURL = iCloudDocumentsURL {
        if (!NSFileManager.defaultManager().fileExistsAtPath(iCloudDocumentsURL.path!, isDirectory: nil)) {
            try! NSFileManager.defaultManager().createDirectoryAtURL(iCloudDocumentsURL, withIntermediateDirectories: true, attributes: nil)
        }
        if let url = iCloudDocumentsURL.URLByAppendingPathComponent(file) {
            let dtext = "\(text)"
            let _ = try? url.setResourceValue(true, forKey: NSURLIsExcludedFromBackupKey)
            try! dtext.appendLineToURL(url)
        }
    }
}
