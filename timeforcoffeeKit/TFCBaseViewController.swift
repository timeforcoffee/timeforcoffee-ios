//
//  TFCBaseViewController.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 24.02.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation

open class TFCBaseViewController: UIViewController, TFCLocationManagerDelegate {
    open lazy var locManager: TFCLocationManager? = self.lazyInitLocationManager()
    
    open func lazyInitLocationManager() -> TFCLocationManager? {
        return TFCLocationManager(delegate: self)
    }
    
    open func locationFixed(_ coord: CLLocation?) {
        //do nothing here, you have to overwrite that
    }

    open func locationDenied(_ manager: CLLocationManager, err:Error) {
    }

    open func locationStillTrying(_ manager: CLLocationManager, err:Error) {
    }


}
