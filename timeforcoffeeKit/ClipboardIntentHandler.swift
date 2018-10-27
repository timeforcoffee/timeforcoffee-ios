//
//  NextDeparturesIntentHandler.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 21.09.18.
//  Copyright © 2018 opendata.ch. All rights reserved.
//

import Foundation


@available(iOSApplicationExtension 12.0, *)
@available(watchOSApplicationExtension 5.0, *)
public class ClipboardIntentHandler: NSObject, ClipboardIntentHandling {
    
    public override init() {
        super.init()
    }
    
    deinit {
        DLog("Deinit")
    }
    
    public func confirm(intent: ClipboardIntent, completion: @escaping (ClipboardIntentResponse) -> Void) {
        completion(ClipboardIntentResponse(code: .ready, userActivity: nil))
    }
    
  
    
    public func handle(intent: ClipboardIntent, completion: @escaping (ClipboardIntentResponse) -> Void) {
        
        #if !os(watchOS)
        let cb = TFCXCallback()
        if let url = UIPasteboard.general.string {
            cb.handleCall(input:url) { (url:URL?) in
                //replace ? in the beginning
                UIPasteboard.general.string = url?.absoluteString.replace("^\\?", template: "").removingPercentEncoding
                completion(ClipboardIntentResponse(code: .success, userActivity: nil))
                
            }
            return
        }
        #endif
        completion(ClipboardIntentResponse(code: .failure, userActivity: nil))

    
    }
    
    
}

