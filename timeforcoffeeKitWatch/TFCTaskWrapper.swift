//
//  TFCTaskWrapper.swift
//  timeforcoffeeKitWatch
//
//  Created by Christian Stocker on 27.09.18.
//  Copyright © 2018 opendata.ch. All rights reserved.
//

import Foundation
import WatchKit
open class TFCTaskWrapper {
    
    fileprivate let task:WKRefreshBackgroundTask
    var completed:Bool = false
    
    public init(_ task:WKRefreshBackgroundTask) {
        self.task = task
    }
    
    open func getTask() -> WKRefreshBackgroundTask {
        return self.task
    }
    
    open func getHash() -> Int {
        return self.task.hash
    }
    
    open func isCompleted() -> Bool {
        return self.completed
    }
    
    open func setAsCompleted() {
        self.completed = true
    }
    
    fileprivate func setTaskCompleted() {
        self.completed = true
        if #available(watchOSApplicationExtension 4.0, *) {
            task.setTaskCompletedWithSnapshot(false)
        } else {
            task.setTaskCompleted()
        }
    }
    open func setTaskCompletedAndClear(callback:(() -> Bool)? = nil) {
        DispatchQueue.main.async(execute: {
            if self.isCompleted() == false {
                DLog("runningTasks: Set Task completed for \(self.getHash()) \(self.getTask())")
                if let callback = callback {
                    if callback() {
                        self.setAsCompleted()
                    } else {
                        self.setTaskCompleted()
                    }
                    return
                }
                self.setTaskCompleted()
                return
            }
            DLog("runningTasks: Already called \(self.getHash()) before. Not call taskCompleted.")
        })
    }
}
