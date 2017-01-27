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

    @IBOutlet weak var favoritesRadiusSlider: UISlider!
    @IBOutlet weak var favoritesRadiusValue: UITextView!

    @IBOutlet weak var realTimeInfoSwitch: UISwitch!


    @IBAction func closeButtionTapped(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
    override func viewWillAppear(_ animated: Bool) {
        var numberOfCells = TFCDataStore.sharedInstance.getUserDefaults()?.integer(forKey: "numberOfCellsToday")
        if (numberOfCells == nil || numberOfCells == 0) {
            numberOfCells = 6
        }
        numberCellsTodaySlider.value = Float(numberOfCells!)
        numberCellsTodayValue.text = String(numberOfCells!)

        let favoritesSearchRadius = TFCFavorites.sharedInstance.getSearchRadius()
        setRadiusTextValue(favoritesSearchRadius)
        setRadiusSliderValue(favoritesSearchRadius)

        realTimeInfoSwitch.isOn = TFCSettings.sharedInstance.showRealTimeDebugInfo()
    }

    @IBAction func sliderChanged(_ sender: AnyObject) {

        let sliderValue = lroundf(numberCellsTodaySlider.value)
        numberCellsTodayValue.text = String(sliderValue)
        numberCellsTodaySlider.setValue(Float(sliderValue), animated: true)
        TFCDataStore.sharedInstance.getUserDefaults()?.set(sliderValue, forKey: "numberOfCellsToday")
    }

    @IBAction func sliderChangedValue(_ sender: AnyObject) {
        let sliderValue = lroundf(numberCellsTodaySlider.value)
        numberCellsTodayValue.text = String(sliderValue)
    }

    fileprivate func setRadiusSliderValue(_ radius:Int) {
        let newSliderValue = log(Float(radius)) / log(10)
        favoritesRadiusSlider.setValue(newSliderValue, animated: true)
    }

    fileprivate func setRadiusTextValue(_ radius:Int) {
        let formatted = String(format: "%.1f km", arguments: [Float(radius) / 1000.0])
        favoritesRadiusValue.text = formatted
    }

    fileprivate func getRadiusSliderValueInMeters() -> Float {
        let sliderValue = pow(10,favoritesRadiusSlider.value)
        return Float(roundf(sliderValue / 100)) * 100
    }

    @IBAction func favoritesRadiusSliderChanged(_ sender: AnyObject) {
        let rounded = Int(getRadiusSliderValueInMeters())
        setRadiusSliderValue(rounded)
        TFCDataStore.sharedInstance.getUserDefaults()?.set(rounded, forKey: "favoritesSearchRadius")
    }

    @IBAction func favoritesRadiusSliderChangedValue(_ sender: AnyObject) {
        let rounded = getRadiusSliderValueInMeters()
        setRadiusTextValue(Int(rounded))
    }

    @IBAction func realTimeInfoSwitchChanged(_ sender: AnyObject) {
        TFCSettings.sharedInstance.setRealTimeDebugInfo(realTimeInfoSwitch.isOn)
    }


}
