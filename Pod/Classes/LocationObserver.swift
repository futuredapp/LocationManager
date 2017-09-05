//
//  LocationObserver.swift
//  Pods
//
//  Created by Jakub Knejzlik on 25/02/16.
//
//

import CoreLocation

public protocol LocationObserver: AnyObject {
    func didUpdate(manager: LocationManager, newLocation: CLLocation)
}

class LocationObserverItem: NSObject {

    let observer: LocationObserver
    let locationManager: LocationManager
    let desiredAccuracy: CLLocationAccuracy?
    let distanceFilter: CLLocationDistance?
    let minimumTimeInterval: TimeInterval?
    let maximumTimeInterval: TimeInterval?
    var previousLocation: CLLocation?
    var newLocationForUpdate: CLLocation?
    var minimumTimer: Timer?
    var maximumTimer: Timer?
    
    init(locationObserver: LocationObserver, locationManager: LocationManager, desiredAccuracy: CLLocationAccuracy?, distanceFilter: CLLocationDistance?, minimumTimeInterval: TimeInterval?, maximumTimeInterval: TimeInterval?) {

        observer = locationObserver
        self.locationManager = locationManager
        self.desiredAccuracy = desiredAccuracy
        self.distanceFilter = distanceFilter
        self.minimumTimeInterval = minimumTimeInterval
        self.maximumTimeInterval = maximumTimeInterval
        
        super.init()
        
        initializeTimers()
    }
    
    func invalidate() {
        deinitializeTimers()
    }
    
    func validate(location: CLLocation) -> Bool {

        if let desiredAccuracy = desiredAccuracy , desiredAccuracy < location.horizontalAccuracy || desiredAccuracy < location.verticalAccuracy {
            return false
        }

        if let distanceFilter = distanceFilter , let previousLocation = previousLocation , previousLocation.distance(from: location) <= distanceFilter {
            return false
        }

        return true
    }
    
    func update(location: CLLocation?) {

        guard let location = location, validate(location: location) else {
            return
        }

        if validate(location: location) {

            if minimumTimer != nil && previousLocation != nil {
                newLocationForUpdate = location
            } else {
                observer.didUpdate(manager: locationManager, newLocation: location)
                previousLocation = location
            }
        }
    }
    
    // Mark: - Timer methods
    
    func deinitializeTimers() {

        minimumTimer?.invalidate()
        minimumTimer = nil
        maximumTimer?.invalidate()
        maximumTimer = nil
    }
    
    func initializeTimers() {

        if let interval = minimumTimeInterval {
            minimumTimer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(minimumTimerTick), userInfo: nil, repeats: true)
        }

        if let interval = maximumTimeInterval {
            maximumTimer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(maximumTimerTick), userInfo: nil, repeats: true)
        }
    }
    
    func minimumTimerTick() {

        if let location = newLocationForUpdate {
            updateLocationFromTimer(location)
        }
    }
    
    func maximumTimerTick() {

        if let location = newLocationForUpdate ?? previousLocation {
            updateLocationFromTimer(location)
        }
    }
    
    func updateLocationFromTimer(_ location: CLLocation) {

        observer.didUpdate(manager: locationManager, newLocation: location)
        previousLocation = location
        newLocationForUpdate = nil
    }
}

func ==(llo: LocationObserverItem, rlo: LocationObserverItem) -> Bool {
    return llo === rlo
}
