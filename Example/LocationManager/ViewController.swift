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

    @IBOutlet var locationRequestLabel: UILabel!
    @IBOutlet var locationLabel: UILabel!
    @IBOutlet var location10Label: UILabel!
    @IBOutlet var location50Label: UILabel!
    
    lazy var observer: LocationObserverLabel = {
        return LocationObserverLabel(label: self.locationLabel)
    }()
    lazy var observer10: LocationObserverLabel = {
        return LocationObserverLabel(label: self.location10Label)
    }()
    lazy var observer50: LocationObserverLabel = {
        return LocationObserverLabel(label: self.location50Label)
    }()
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        LocationManager.sharedManager.addLocationObserver(self.observer)
        LocationManager.sharedManager.addLocationObserver(self.observer10, distanceFilter: 10)
        LocationManager.sharedManager.addLocationObserver(self.observer50, distanceFilter: 50)
    }
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        LocationManager.sharedManager.removeLocationObserver(self.observer)
        LocationManager.sharedManager.removeLocationObserver(self.observer10)
        LocationManager.sharedManager.removeLocationObserver(self.observer50)
    }
    
    @IBAction func refreshLocation(sender: AnyObject) {
        LocationManager.sharedManager.getCurrentLocation().then { location in
            self.locationRequestLabel.text = "\(location.coordinate.latitude) \(location.coordinate.longitude)"
        }.error { error in
            self.locationRequestLabel.text = "cannot fetch location"
        }
    }
    
}

