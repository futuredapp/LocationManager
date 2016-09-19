//
//  ViewController.swift
//  LocationManager
//
//  Created by Jakub Knejzlik on 02/24/2016.
//  Copyright (c) 2016 Jakub Knejzlik. All rights reserved.
//

import UIKit
import LocationManager
import CoreLocation

class ViewController: UIViewController {

    var observer: LocationObserverLabel? = nil

    @IBOutlet var locationRequestLabel: UILabel!
    @IBOutlet var locationLabel: UILabel!
    @IBOutlet weak var distanceFilterLabel: UILabel!
    @IBOutlet weak var distanceFilterSlider: UISlider!
    @IBOutlet weak var minimumIntervalLabel: UILabel!
    @IBOutlet weak var minimumIntervalSlider: UISlider!
    @IBOutlet weak var maximumIntervalLabel: UILabel!
    @IBOutlet weak var maximumIntervalSlider: UISlider!
    
    override func viewDidAppear(_ animated: Bool) {

        super.viewDidAppear(animated)

        self.refreshLocation(self.locationLabel)
        self.didUpdateInterface(self)
    }
    
    @IBAction func refreshLocation(_ sender: AnyObject) {

        self.locationRequestLabel.text = "...\n"

        LocationManager.getCurrentLocation().then { location in
            self.locationRequestLabel.text = "lat: \(location.coordinate.latitude)\nlng: \(location.coordinate.longitude)"
        }//.error { error in
           // self.locationRequestLabel.text = "cannot fetch location"
        //}
    }
    
    @IBAction func didUpdateInterface(_ sender: AnyObject) {

        self.distanceFilterLabel.text = "Distance (\(Int(self.distanceFilterSlider.value))m)"
        self.minimumIntervalLabel.text = "Minimum interval (\(Int(self.minimumIntervalSlider.value))s)"
        self.maximumIntervalLabel.text = "Minimum interval (\(Int(self.maximumIntervalSlider.value))s) – forces call even without new location"
        self.updateValuesAndInitializeObserver()
    }
    
    func updateValuesAndInitializeObserver() {

        if let currentObserver = self.observer {

            LocationManager.removeLocationObserver(currentObserver)
            self.observer = nil
        }

        let observer = LocationObserverLabel(label: self.locationLabel)
        self.observer = observer
        let minimumTimeInterval: Double? = self.minimumIntervalSlider.value == 0 ? nil : Double(self.minimumIntervalSlider.value)
        let maximumTimeInterval: Double? = self.maximumIntervalSlider.value == 0 ? nil : Double(self.maximumIntervalSlider.value)

        LocationManager.addLocationObserver(observer, distanceFilter: Double(self.distanceFilterSlider.value), minimumTimeInterval: minimumTimeInterval, maximumTimeInterval: maximumTimeInterval)
    }
}
