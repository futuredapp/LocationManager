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

        refreshLocation(locationLabel)
        didUpdateInterface(self)
    }
    
    @IBAction func refreshLocation(_ sender: AnyObject) {

        locationRequestLabel.text = "...\n"
        
        LocationManager.getCurrentLocation().done { location in
            let user_lat = String(format: "%f", location.coordinate.latitude)
            let user_long = String(format: "%f", location.coordinate.longitude)
            self.locationRequestLabel.text = "lat: \(user_lat)\nlng: \(user_long)"
        }.catch {error in
            self.locationRequestLabel.text = "cannot fetch location"
        }
        
    }
    
    @IBAction func didUpdateInterface(_ sender: AnyObject) {

        distanceFilterLabel.text = "Distance (\(Int(distanceFilterSlider.value))m)"
        minimumIntervalLabel.text = "Minimum interval (\(Int(minimumIntervalSlider.value))s)"
        maximumIntervalLabel.text = "Minimum interval (\(Int(maximumIntervalSlider.value))s) – forces call even without new location"
        updateValuesAndInitializeObserver()
    }
    
    @objc func updateValuesAndInitializeObserver() {

        if let currentObserver = self.observer {

            LocationManager.remove(locationObserver: currentObserver)
            self.observer = nil
        }

        let observer = LocationObserverLabel(label: locationLabel)
        self.observer = observer
        let minimumTimeInterval: Double? = minimumIntervalSlider.value == 0 ? nil : Double(minimumIntervalSlider.value)
        let maximumTimeInterval: Double? = maximumIntervalSlider.value == 0 ? nil : Double(maximumIntervalSlider.value)

        LocationManager.add(locationObserver: observer, distanceFilter: Double(distanceFilterSlider.value), minimumTimeInterval: minimumTimeInterval, maximumTimeInterval: maximumTimeInterval)
    }
}
