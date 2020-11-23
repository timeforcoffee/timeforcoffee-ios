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
extension Date {
    public func formattedWith(_ format:String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "de_CH")
        return formatter.string(from: self)
    }
    public func formattedWithDateFormatter(_ formatter:DateFormatter) -> String {
        return formatter.string(from: self)
    }
}

extension String {
    func appendLineToURL(_ fileURL: URL) throws {
        try ("\(self)\n").appendToURL(fileURL)
    }

    func appendToURL(_ fileURL: URL) throws {
        let data = self.data(using: String.Encoding.utf8)!
        try data.appendToURL(fileURL)
    }
}

extension Data {
    func appendToURL(_ fileURL: URL) throws {
        if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        }
        else {
            try write(to: fileURL, options: .atomic)
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

let logQueue:DispatchQueue = {
    return DispatchQueue(label: "ch.opendata.timeforcoffee.log", attributes: [])
}()

let DLogDateFormatter:DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "YYYY-MM-dd HH:mm:ss.SSS"
    formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
    formatter.locale = Locale(identifier: "de_CH")
    return formatter
}()

let DLogDayHourFormatter:DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "YYYY-MM-dd-HH"
    formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
    formatter.locale = Locale(identifier: "de_CH")
    return formatter
}()


let DLogDayHourMinuteFormatter:DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "YYYY-MM-dd-HH-mm"
    formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
    formatter.locale = Locale(identifier: "de_CH")
    return formatter
}()

let DLogShortFormatter:DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "d-H:m"
    formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
    formatter.locale = Locale(identifier: "de_CH")
    return formatter
}()

func print(_ item: @autoclosure () -> Any, separator: String = " ", terminator: String = "\n") {
    #if DEBUG
        Swift.print(item(), separator:separator, terminator: terminator)
    #endif
}

/*public func DLog(_ object: @autoclosure () -> Any, toFile: Bool = false) {
    NSLog("\(object)")
}*/
public func DLog(_ object: @autoclosure () -> Any, toFile: Bool = false, sync:Bool = false, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
    #if DEBUG
        let value = object()
        let queueLabel = currentQueueName()
        let currentThread = "\(Thread.current)"
        let date = Date().formattedWithDateFormatter(DLogDateFormatter)
        func getMessage() -> String {
            let stringRepresentation: String

            if let value = value as? CustomDebugStringConvertible {
                stringRepresentation = value.debugDescription
            } else if let value = value as? CustomStringConvertible {
                stringRepresentation = value.description
            } else {
                fatalError("loggingPrint only works for values that conform to CustomDebugStringConvertible or CustomStringConvertible")
            }
            let fileEscaped = file.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed)
            let fileURL = NSURL(string: fileEscaped!)?.lastPathComponent ?? "Unknown file"
            //  <NSThread: 0x17066e7c0>{number = 11, name = (null)}
            var matches:String = ""
            if let queueLabel = queueLabel {
                if queueLabel == "ch.opendata.timeforcoffee.crunch" {
                    matches = "CQ"
                } else if (queueLabel == "com.apple.main-thread") {
                    matches = "UI"
                } else if (queueLabel.contains("NSOperationQueue")) {
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
            let msg = "<\(queue)> \(stringRepresentation) (\(fileURL) \(function)[\(line)])"
            NSLog("%@", msg)
            return msg
        }

        func logIt(msg:String) {

            #if os(watchOS)
                let alwaysLogToFile = true
            #else
                
                let alwaysLogToFile = false
            #endif
            if (toFile || alwaysLogToFile) {
                let text = "\(date) \(msg)"
                /*  #if os(watchOS)
                 DLog2WatchConnectivity(text)
                 #endif
                 */
                DLog2File(text)
            }
        }
        if (sync) {
            let msg = getMessage()
            logQueue.sync() {
                logIt(msg: msg)
            }
        } else {
            logQueue.async {
                let msg = getMessage()
                logIt(msg: msg)
            }
        }
    #else
        #if os(iOS)
        if (toFile == true) {
            let value = object()
            func logIt() {
                let stringRepresentation: String

                if let value = value as? CustomDebugStringConvertible {
                    stringRepresentation = value.debugDescription
                } else if let value = value as? CustomStringConvertible {
                    stringRepresentation = value.description
                } else {
                    return
                }
                let fileEscaped = file.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed)
                let fileURL = URL(string: fileEscaped!)?.lastPathComponent ?? "Unknown file"
                let msg = "\(stringRepresentation) (\(fileURL) \(function)[\(line)])"
                DLog2CLS("%@", text: [msg])
            }
            if (sync) {
                logQueue.sync {
                    logIt()
                }
            } else {
                logQueue.async {
                    logIt()
                }
            }
        }
        #endif
    #endif
}

func currentQueueName() -> String? {
    let name = __dispatch_queue_get_label(nil)
    return String(cString: name, encoding: .utf8)
}

public func SendLogs2Phone() {
    #if DEBUG
    DLog("SendLogs2Phone", toFile: true)
    
    let filemanager = FileManager.default
    
    if let path = filemanager.urls(for: .documentDirectory, in: .userDomainMask).first {
        
        let oldUrl = path.appendingPathComponent("old", isDirectory: true)
        if (!filemanager.fileExists(atPath: oldUrl.path, isDirectory: nil)) {
            try! filemanager.createDirectory(at: oldUrl, withIntermediateDirectories: true, attributes: nil)
        }
        
        if let directoryContents = try? filemanager.contentsOfDirectory( at: path, includingPropertiesForKeys: nil, options: []) {
            let logFiles = directoryContents.filter{ $0.pathExtension == "txt"}
            for file in logFiles {
                let nowFile = getWatchLogFileName()
                let name = file.lastPathComponent
                if (name != nowFile) {
                    //move to old dir, if not current anymore
                    let moveTo = oldUrl.appendingPathComponent(name)
                    do {
                        if filemanager.fileExists(atPath: moveTo.path) {
                            try filemanager.removeItem(at: moveTo)
                        }
                        try filemanager.moveItem(at: file, to: moveTo)
                        WCSession.default.transferFile(moveTo, metadata: nil)
                    } catch let error as NSError {
                        DLog("\(#function) Error: \(error)", toFile: true)
                    }
                } else {
                    WCSession.default.transferFile(file, metadata: nil)
                }
                
            }
        }
        //delete files older than a day
        if let directoryContents = try? filemanager.contentsOfDirectory( at: oldUrl, includingPropertiesForKeys: nil, options: []) {
            let logFiles = directoryContents.filter{ $0.pathExtension == "txt"}
            for file in logFiles {
                do {
                    if let modified = try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                        
                        if modified.addingTimeInterval(24 * 3600) < Date() {
                            DLog("\(file.lastPathComponent) is older than a day, delete it", toFile: true)
                            try filemanager.removeItem(at: file)
                        }
                    }
                    
                } catch let error as NSError {
                    DLog("\(#function) Error: \(error)", toFile: true)
                }
            }
        }
    }
    


    #endif
}


//we can't read the file from the Watch, so send it to the iPhone to be read from there
private func DLog2WatchConnectivity(_ text:String) {
    let message = ["__logThis__": text]
    let session = WCSession.default
    if (session.isReachable == true) {
        session.sendMessage(message, replyHandler: nil, errorHandler: {(error: Error) in
            DLog("send Log Message failed due to error \(error): Send via transferUserInfo")
            session.transferUserInfo(message)
        })
    } else {
        session.transferUserInfo(message)
    }
}
private func getWatchLogFileName() -> String {
    return "watch-log-\(Date().formattedWithDateFormatter(DLogDayHourMinuteFormatter)).txt"
}

private func DLog2File(_ text:String) {


    if  let iCloudDocumentsURL = iCloudDocumentsURLPath {
        do {
            let file = getLogFileName()
            let url = iCloudDocumentsURL.appendingPathComponent(file, isDirectory: false)
            let dtext = "\(text)"
            let _ = try? (url as NSURL).setResourceValue(true, forKey: URLResourceKey.isExcludedFromBackupKey)
            try dtext.appendLineToURL(url)

        } catch {
            // just ignore
        }
    }
}

private func getLogFileName() -> String {
    #if os(watchOS)
        let file = getWatchLogFileName()
    #else
        let file:String
        if Bundle.main.bundleIdentifier == "ch.opendata.timeforcoffee.timeforcoffee" {
            file = "today-log-\(Date().formattedWithDateFormatter(DLogDayHourFormatter))-\(UIDevice.current.name).txt"
        } else {
            file = "log-\(Date().formattedWithDateFormatter(DLogDayHourFormatter))-\(UIDevice.current.name).txt"
        }
    #endif
    return file
}

private var iCloudDocumentsURLPath:URL? = {
    #if DEBUG
        #if os(watchOS)
            let iCloudDocumentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        #else
            let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.ch.opendata.timeforcoffee")?.appendingPathComponent("Documents")
        #endif
        if  let iCloudDocumentsURL = iCloudDocumentsURL {

            if (!FileManager.default.fileExists(atPath: iCloudDocumentsURL.path, isDirectory: nil)) {
                try! FileManager.default.createDirectory(at: iCloudDocumentsURL, withIntermediateDirectories: true, attributes: nil)
            }
            return iCloudDocumentsURL
        }
    #endif
    return nil

}()
