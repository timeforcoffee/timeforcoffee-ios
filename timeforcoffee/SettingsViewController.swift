//
//  SettingsViewController.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 13.04.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import UIKit
import timeforcoffeeKit

class SettingsViewController: UIViewController {


    @IBOutlet weak var numberCellsTodayValue: UITextView!
    
    @IBOutlet weak var numberCellsTodaySlider: UISlider!

    @IBAction func closeButtionTapped(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    override func viewWillAppear(animated: Bool) {
        var numberOfCells = TFCDataStore.sharedInstance.getUserDefaults()?.integerForKey("numberOfCellsToday")
        if (numberOfCells == nil) {
            numberOfCells = 6
        }
        numberCellsTodaySlider.value = Float(numberOfCells!)
        numberCellsTodayValue.text = String(numberOfCells!)
    }

    @IBAction func sliderChanged(sender: AnyObject) {

        var sliderValue = lroundf(numberCellsTodaySlider.value)
        numberCellsTodayValue.text = String(sliderValue)
        numberCellsTodaySlider.setValue(Float(sliderValue), animated: true)
        TFCDataStore.sharedInstance.getUserDefaults()?.setInteger(sliderValue, forKey: "numberOfCellsToday")
    }

    @IBAction func sliderChangedValue(sender: AnyObject) {
        var sliderValue = lroundf(numberCellsTodaySlider.value)
        numberCellsTodayValue.text = String(sliderValue)
    }

}