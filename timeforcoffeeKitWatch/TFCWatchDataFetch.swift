//
//  TFCFetchData.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 09.09.16.
//  Copyright © 2016 opendata.ch. All rights reserved.
//

import Foundation
import WatchKit

open class TFCWatchDataFetch: NSObject, URLSessionDownloadDelegate {

    var downloading:[String:Date] = [:]
    var lastDownload:[String:Date] = [:]
    var sessionRefreshTasks:[String:TFCTaskWrapper] = [:]
    var validSessions:[String:Bool] = [:]

    public static let sharedInstance = TFCWatchDataFetch()

    override fileprivate init() {
        super.init()
    }

    open func setLastViewedStation(_ station: TFCStation?) {
        TFCDataStore.sharedInstance.getUserDefaults()?.set(station?.st_id, forKey: "lastViewedStationId")
        TFCDataStore.sharedInstance.getUserDefaults()?.set(Date(), forKey: "lastViewedStationDate")
    }

    lazy var watchdata: TFCWatchData = {
        return TFCWatchData()
    }()


    open func getLastViewedStation() -> TFCStation? {
        let defaults = TFCDataStore.sharedInstance.getUserDefaults()
        if let date = defaults?.object(forKey: "lastViewedStationDate") as? Date {
            // if not older than 50 minutes
            if date.addingTimeInterval(50 * 60) > Date() {
                if let stationId =  defaults?.object(forKey: "lastViewedStationId") as? String {
                    return TFCStation.initWithCacheId(stationId)
                }
            }
        }
        return nil
    }

    open func fetchDepartureData(wrapper: TFCTaskWrapper) {
        func handleReply() {
            //DLog("finished WKApplicationRefreshBackgroundTask \(task) before barrier", toFile: true)
            TFCWatchData.crunchQueue.async(flags: .barrier, execute: {
                DLog("finished WKRefreshBackgroundTask \(wrapper.getHash)", toFile: true)
                wrapper.setTaskCompletedAndClear()
            })
        }
        fetchDepartureData(handleReply)
    }

    open func fetchDepartureData(_ taskCallback:(() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            let lastViewedStation = self.getLastViewedStation();

            func handleReply(_ stations: TFCStations?) {
                //DLog("handleReply fetchDepartureData:", toFile: true)
                if let station = stations?.getStation(0) {
                    DLog("handleReply fetchDepartureData: \(station.name))", toFile: true)
                    if let defaults = TFCDataStore.sharedInstance.getUserDefaults() {
                        // check if new station id and make it download complication, if so, later
                        let lastFirstStationId = defaults.string(forKey: "lastFirstStationId")
                        if (lastFirstStationId != station.st_id) {
                            DLog("set lastFirstStationId to \(station.st_id) for \(station.name)", toFile: true)
                            defaults.setValue(station.st_id, forKey: "lastFirstStationId")
                            TFCDataStore.sharedInstance.getUserDefaults()?.set(0.0, forKey: "backoffCount")

                        }
                    }
                    DLog("\(String(describing: lastViewedStation?.st_id)) != \(station.st_id)")
                    if (self.watchdata.needsTimelineDataUpdate(station, checkLastDeparture: false) ) {
                        if (lastViewedStation?.st_id != station.st_id) {
                            DLog("call fetchDepartureDataForStation")
                            self.fetchDepartureDataForStation(station)
                        }
                    } else {
                        DLog("no timeline update needed", toFile: true)
                    }
                } else {
                    DLog("backoff: No station set", toFile: true)
                    // try again in 5 minutes
                    WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: self.watchdata.getBackOffTime() , userInfo: nil) { (error) in
                        if error == nil {
                            //successful
                        }
                    }
                }
                taskCallback?()
            }
            func errorReply(_ error: String) {
                DLog("backoff: error \(error)", toFile: true)
                // try again in 5 minutes
                WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: self.watchdata.getBackOffTime(), userInfo: nil) { (error) in
                    if error == nil {
                        //successful
                    }
                }
                taskCallback?()
            }
            if lastViewedStation != nil {
                DLog("call fetchDepartureDataForStation")

                self.fetchDepartureDataForStation(lastViewedStation!)
            }
            self.watchdata.startCrunchQueue {
                DLog("call getStations", toFile: true)
                TFCDataStore.sharedInstance.watchdata.getStations(handleReply, errorReply: errorReply, stopWithFavorites: true)
            }
        }
    }

    open func fetchDepartureDataForStation(_ station:TFCStation, forceFromURL:Bool = false) {
        if let downloadingSince = self.downloading[station.st_id]  {
            //if downloading since less than 30 secs. don't again.
            if downloadingSince.addingTimeInterval(30) > Date() {
                DLog("Station \(station.st_id) is already downloading since \(downloadingSince)", toFile: true)
                return
            }
        }
        self.downloading[station.st_id] = Date()
        DLog("station.lastDepartureUpdate: \(String(describing: station.lastDepartureUpdate))")
        if let lastDepartureUpdate = station.lastDepartureUpdate {
            if (lastDepartureUpdate.addingTimeInterval(60) > Date()) {
                DLog("Station \(station.st_id) was updated less than a minute ago (at \(lastDepartureUpdate))", toFile: true)
                return
            }
        }
        if (!forceFromURL && TFCDataStore.sharedInstance.updateStationFromPhone(station: station, reply: { (worked) in
            if (!worked) {
                DLog("no connection to phone apparenty, fetch with session URL")
                self.downloading.removeValue(forKey: station.st_id)
                self.fetchDepartureDataForStation(station, forceFromURL: true)
            } else {
                
            }
        })) {
            return
        }


        let sampleDownloadURL = URL(string: station.getDeparturesURL())!

        DLog("Download \(sampleDownloadURL) for \(station.name)", toFile: true)

        let backgroundConfigObject = URLSessionConfiguration.background(withIdentifier: (UUID().uuidString))
        backgroundConfigObject.requestCachePolicy = .useProtocolCachePolicy
        if let uid = TFCDataStore.sharedInstance.getTFCID() {
            backgroundConfigObject.httpAdditionalHeaders = ["TFCID": uid]

        }

        let backgroundSession = Foundation.URLSession(configuration: backgroundConfigObject, delegate: self, delegateQueue: nil)
        backgroundConfigObject.sessionSendsLaunchEvents = true

        let downloadTask = backgroundSession.downloadTask(with: sampleDownloadURL)
        downloadTask.taskDescription = station.st_id
        if WKExtension.shared().applicationState == .active {
            downloadTask.priority = 1.0
        }
        if let id = backgroundConfigObject.identifier {
            self.validSessions[id] = true
            DLog("Starting download task \(id)  for \(station.name) ")
        }
        downloadTask.resume()

    }

    fileprivate func rejoinURLSessionId(_ id: String) {
        let backgroundConfigObject = URLSessionConfiguration.background(withIdentifier: id)
        let backgroundSession = Foundation.URLSession(configuration: backgroundConfigObject, delegate: self, delegateQueue: nil)
        DLog("Rejoining session \(id)", toFile: true)
        backgroundSession.getAllTasks { (tasks) in
            for task in tasks {
                #if DEBUG
                    let stateString:String
                    switch (task.state) {
                    case .canceling:
                        stateString = "canceling"
                        break
                    case .completed:
                        stateString = "completed"
                        break
                    case .running:
                        stateString = "running"
                        break
                    case .suspended:
                        stateString = "suspended"
                    }
                    DLog("session \(id) state: \(stateString).")
                #endif
                task.priority = URLSessionTask.highPriority
                if (task.state == .suspended || task.state == .running) {
                    task.resume()
                }
            }
        }
    }

    open func rejoinURLSession(_ wrapper: TFCTaskWrapper) {
        if let urlTask = wrapper.getTask() as? WKURLSessionRefreshBackgroundTask {
            let id = urlTask.sessionIdentifier
            self.rejoinURLSessionId(id)
            self.sessionRefreshTasks[id] = wrapper
            if !(self.validSessions[id] == true) {
                DLog("Session for \(id) was not in validSessions. add to valid sessions")
                self.validSessions[id] = true
            }
        }
    }

    public func updateComplicationIfNeeded(_ station: TFCStation) {
        // check if we fetched the one in the complication and then update it
        if let defaults = TFCDataStore.sharedInstance.getUserDefaults() {
            DLog("\(station.st_id) == \(String(describing: defaults.string(forKey: "lastFirstStationId") ?? nil))", toFile: true)
            if (station.st_id == defaults.string(forKey: "lastFirstStationId")) {
                if let c = CLKComplicationServer.sharedInstance().activeComplications?.count, c > 0 {
                    if self.watchdata.needsTimelineDataUpdate(station) {
                        DLog("updateComplicationData", toFile: true)
                        self.watchdata.updateComplicationData()
                    }
                }
            }
        }
    }

    fileprivate func handleURLSession(_ fileContent:Data?, st_id: String, sess_id: String? ) {
        //let fileContent = try? NSString(contentsOfURL: location, encoding: NSUTF8StringEncoding)
        DLog("__")
        if let fileContent = fileContent {
            DLog("__")
            if let station = TFCStation.initWithCacheId(st_id) {
                DLog("__")
                let  data = JSON(data: fileContent)
                station.didReceiveAPIResults(data, error: nil, context: nil)
                let isActive:Bool
                isActive = (WKExtension.shared().applicationState == .active)
                if (st_id == self.getLastViewedStation()?.st_id  && isActive) {
                    DLog("notification TFCWatchkitUpdateCurrentStation")
                    NotificationCenter.default.post(name: Notification.Name(rawValue: "TFCWatchkitUpdateCurrentStation"), object: nil, userInfo: nil)
                }
                self.updateComplicationIfNeeded(station)
            }
        } else {
            DLog("fileContent was nil", toFile: true)
        }

        if let sessID = sess_id {
            self.completeTask(sessID)
        }
      //  DLog("remaining tasks: \(self.sessionRefreshTasks.count)")
    }



    fileprivate func completeTask(_ sessID: String) {
        TFCWatchData.crunchQueue.async(flags: .barrier, execute: {
            if let wrapper = self.sessionRefreshTasks[sessID] {
                DLog("finished WKURLSessionRefreshBackgroundTask part 1 \(sessID)", toFile: true)
                wrapper.setTaskCompletedAndClear()
                self.sessionRefreshTasks.removeValue(forKey: sessID)
            } else {
                DLog("could not find wrapper for \(sessID) to complete task")
            }
        })
    }

    fileprivate func getValidSessionIdsDump() -> String {
        return self.getValidSessionIds().joined(separator: ", ");
    }

    fileprivate func getValidSessionIds() -> [String] {
        return self.validSessions.filter({ (key: String, value: Bool) -> Bool in
            return value
        }).map({ (key:String, value: Bool) -> String in
                return key
        })
    }

    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        DLog("Did download \(String(describing: downloadTask.taskDescription)) to \(location)", toFile: true)
        let fileContent = try? Data(contentsOf: location)
        if let st_id = downloadTask.taskDescription {
            if let start = self.downloading[st_id] {
                let time = Date().timeIntervalSince1970 - start.timeIntervalSince1970
                DLog("Download of \(st_id) took \(time) seconds. task: \(String(describing: session.configuration.identifier)) ", toFile: true)
            } else {
                DLog("Download of \(st_id) took unknown seconds. task: \(String(describing: session.configuration.identifier)) ", toFile: true)
            }
            if let lastDownload = lastDownload[st_id] {
                if (lastDownload.addingTimeInterval(3) > Date()) {
                    DLog("last download was just less than 3 seconds ago. Don't start the queue for processing")
                    return
                }

            }
            lastDownload[st_id] = Date()
          //  DLog("task: \(String(describing: session.configuration.identifier))", toFile: true)
            self.watchdata.startCrunchQueue {
                DLog("crunchQueue start didFinishDownloadingToURL \(st_id) \(String(describing: session.configuration.identifier)) ")
                self.handleURLSession(fileContent, st_id: st_id, sess_id: session.configuration.identifier)
                DLog("crunchQueue end   didFinishDownloadingToURL \(st_id) \(String(describing: session.configuration.identifier)) ")

            }
        }
    }

    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
       // DLog(" didCompleteWithError before crunchQueue \(String(describing: task.taskDescription))")

        self.watchdata.startCrunchQueue {
          //  DLog("crunchQueue start didCompleteWithError \(String(describing: task.taskDescription))")

            DLog("URLSession didComplete \(String(describing: task.taskDescription)) task: \(String(describing: session.configuration.identifier)) error: \(String(describing: error))", toFile: true)
            TFCDataStore.sharedInstance.watchdata.scheduleNextUpdate()
            if let st_id = task.taskDescription {
                self.downloading.removeValue(forKey: st_id)
            }
            if let sessID = session.configuration.identifier {
                self.completeTask(sessID)
            }

            session.finishTasksAndInvalidate()
            //DLog("crunchQueue end   didCompleteWithError \(String(describing: task.taskDescription))")

        }
    }

    open func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DLog("URLSessionDidFinishEventsForBackgroundURLSession \(String(describing: session.configuration.identifier))", toFile: true)
    }

    open func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let id = session.configuration.identifier {
            self.validSessions.removeValue(forKey: id)
        }
        DLog("URLSession didBecomeInvalidWithError \(String(describing: session.configuration.identifier)) error: \(String(describing: error))", toFile: true)

    }
}

