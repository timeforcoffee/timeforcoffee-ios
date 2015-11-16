//
//  TFCNavigationController.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 01.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import UIKit

class TFCNavigationController: UINavigationController {

    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.All
    }

    override func viewDidLoad() {
        self.view.backgroundColor = UIColor.whiteColor()

    }
}