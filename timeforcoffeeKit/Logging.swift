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

let logQueue:dispatch_queue_t = {
    return dispatch_queue_create("ch.opendata.timeforcoffee.log", DISPATCH_QUEUE_SERIAL)
}()

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

let DLogShortFormatter:NSDateFormatter = {
    let formatter = NSDateFormatter()
    formatter.dateFormat = "d-H:m"
    formatter.timeZone = NSTimeZone(name: "Europe/Zurich")
    return formatter
}()

func DLog<T>(@autoclosure object: () -> T, toFile: Bool = false, sync:Bool = false, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
    #if DEBUG
        let value = object()
        let queueLabel = String(UTF8String: dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL))
        let currentThread = "\(NSThread.currentThread())"
        let date = NSDate().formattedWithDateFormatter(DLogDateFormatter)
        func logIt() {
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
            //  <NSThread: 0x17066e7c0>{number = 11, name = (null)}
            var matches:String = ""
            if let queueLabel = queueLabel {
                if queueLabel == "ch.opendata.timeforcoffee.crunch" {
                    matches = "CQ"
                } else if (queueLabel == "com.apple.main-thread") {
                    matches = "UI"
                } else if (queueLabel.containsString("NSOperationQueue")) {
                    matches = queueLabel.replace("NSOperationQueue (.+) :: .*QOS: (.*)\\)", template: "$1 $2")
                } else {
                    matches = "\(queueLabel)"
                }
            } else {
                let pattern = ".* 0x(.*)>\\{number = ([0-9]+).*"
                matches = currentThread.replace(pattern, template: "$1 #$2")
            }

            let queue = matches
            //print("\(NSDate().formattedWithDateFormatter(DLogDateFormatter)) <\(queue)> \(fileURL) \(function)[\(line)] - " + stringRepresentation)
            NSLog("<\(queue)> %@ (\(fileURL) \(function)[\(line)])", stringRepresentation)
            #if os(watchOS)
                let alwaysLogToFile = true
            #else
                let alwaysLogToFile = false
            #endif
            if (toFile || alwaysLogToFile) {
                let text = "\(date) <\(queue)> \(stringRepresentation)  (\(fileURL) \(function)[\(line)])"
                /*  #if os(watchOS)
                 DLog2WatchConnectivity(text)
                 #endif
                 */
                DLog2File(text)
            }
        }
        if (sync) {
            dispatch_sync(logQueue) {
                logIt()
            }
        } else {
            dispatch_async(logQueue) {
                logIt()
            }
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
                    for file in logFiles {
                        let nowFile = getWatchLogFileName()
                        if let name = file.lastPathComponent {
                            if (name != nowFile) {
                                //move to old dir, if not current anymore
                                if let moveTo = oldUrl!.URLByAppendingPathComponent(name) {
                                    do {
                                        if filemanager.fileExistsAtPath(moveTo.path!) {
                                            try filemanager.removeItemAtURL(moveTo)
                                        }
                                        try filemanager.moveItemAtURL(file, toURL: moveTo)
                                        WCSession.defaultSession().transferFile(moveTo, metadata: nil)
                                    } catch let error as NSError {
                                        DLog("\(#function) Error: \(error)", toFile: true)
                                    }
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
        let file:String
        if NSBundle.mainBundle().bundleIdentifier == "ch.opendata.timeforcoffee.timeforcoffee" {
            file = "today-log-\(NSDate().formattedWithDateFormatter(DLogDayHourFormatter))-\(UIDevice.currentDevice().name).txt"
        } else {
            file = "log-\(NSDate().formattedWithDateFormatter(DLogDayHourFormatter))-\(UIDevice.currentDevice().name).txt"
        }
        let iCloudDocumentsURL = NSFileManager.defaultManager().URLForUbiquityContainerIdentifier("iCloud.ch.opendata.timeforcoffee")?.URLByAppendingPathComponent("Documents")!
    #endif

    if  let iCloudDocumentsURL = iCloudDocumentsURL {
        do {
            if (!NSFileManager.defaultManager().fileExistsAtPath(iCloudDocumentsURL.path!, isDirectory: nil)) {
                try! NSFileManager.defaultManager().createDirectoryAtURL(iCloudDocumentsURL, withIntermediateDirectories: true, attributes: nil)
            }
            if let url = iCloudDocumentsURL.URLByAppendingPathComponent(file) {
                let dtext = "\(text)"
                let _ = try? url.setResourceValue(true, forKey: NSURLIsExcludedFromBackupKey)
                try dtext.appendLineToURL(url)
            }
        } catch {
            // just ignore
        }
    }
}
