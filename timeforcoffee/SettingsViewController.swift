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

    @IBOutlet weak var favoritesRadiusSlider: UISlider!
    @IBOutlet weak var favoritesRadiusValue: UITextView!

    @IBOutlet weak var realTimeInfoSwitch: UISwitch!


    @IBAction func closeButtionTapped(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
    override func viewWillAppear(_ animated: Bool) {
        let favoritesSearchRadius = TFCFavorites.sharedInstance.getSearchRadius()
        setRadiusTextValue(favoritesSearchRadius)
        setRadiusSliderValue(favoritesSearchRadius)

        realTimeInfoSwitch.isOn = TFCSettings.sharedInstance.showRealTimeDebugInfo()
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
