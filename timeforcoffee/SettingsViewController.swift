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
    @IBAction func closeButtionTapped(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    override func viewWillAppear(animated: Bool) {
        var numberOfCells = TFCDataStore.sharedInstance.getUserDefaults()?.integerForKey("numberOfCellsToday")
        if (numberOfCells == nil || numberOfCells == 0) {
            numberOfCells = 6
        }
        numberCellsTodaySlider.value = Float(numberOfCells!)
        numberCellsTodayValue.text = String(numberOfCells!)

        let favoritesSearchRadius = TFCFavorites.sharedInstance.getSearchRadius()
        setRadiusTextValue(favoritesSearchRadius)
        setRadiusSliderValue(favoritesSearchRadius)
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

    private func setRadiusSliderValue(radius:Int) {
        let newSliderValue = log(Float(radius)) / log(10)
        favoritesRadiusSlider.setValue(newSliderValue, animated: true)
    }

    private func setRadiusTextValue(radius:Int) {
        let formatted = String(format: "%.1f km", arguments: [Float(radius) / 1000.0])
        favoritesRadiusValue.text = formatted
    }

    private func getRadiusSliderValueInMeters() -> Float {
        var sliderValue = pow(10,favoritesRadiusSlider.value)
        return Float(roundf(sliderValue / 100)) * 100
    }

    @IBAction func favoritesRadiusSliderChanged(sender: AnyObject) {
        let rounded = Int(getRadiusSliderValueInMeters())
        setRadiusSliderValue(rounded)
        TFCDataStore.sharedInstance.getUserDefaults()?.setInteger(rounded, forKey: "favoritesSearchRadius")
    }

    @IBAction func favoritesRadiusSliderChangedValue(sender: AnyObject) {
        let rounded = getRadiusSliderValueInMeters()
        setRadiusTextValue(Int(rounded))
    }
}