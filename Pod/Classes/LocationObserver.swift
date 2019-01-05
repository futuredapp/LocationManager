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
    @objc let locationManager: LocationManager
    let desiredAccuracy: CLLocationAccuracy?
    let distanceFilter: CLLocationDistance?
    let minimumTimeInterval: TimeInterval?
    let maximumTimeInterval: TimeInterval?
    @objc var previousLocation: CLLocation?
    @objc var newLocationForUpdate: CLLocation?
    @objc var minimumTimer: Timer?
    @objc var maximumTimer: Timer?

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

    @objc func invalidate() {
        deinitializeTimers()
    }

    @objc func validate(location: CLLocation) -> Bool {

        if let desiredAccuracy = desiredAccuracy, desiredAccuracy < location.horizontalAccuracy || desiredAccuracy < location.verticalAccuracy {
            return false
        }

        if let distanceFilter = distanceFilter, let previousLocation = previousLocation, previousLocation.distance(from: location) <= distanceFilter {
            return false
        }

        return true
    }

    @objc func update(location: CLLocation?) {

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

    // MARK: - Timer methods

    @objc func deinitializeTimers() {

        minimumTimer?.invalidate()
        minimumTimer = nil
        maximumTimer?.invalidate()
        maximumTimer = nil
    }

    @objc func initializeTimers() {

        if let interval = minimumTimeInterval {
            minimumTimer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(minimumTimerTick), userInfo: nil, repeats: true)
        }

        if let interval = maximumTimeInterval {
            maximumTimer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(maximumTimerTick), userInfo: nil, repeats: true)
        }
    }

    @objc func minimumTimerTick() {

        if let location = newLocationForUpdate {
            updateLocationFromTimer(location)
        }
    }

    @objc func maximumTimerTick() {

        if let location = newLocationForUpdate ?? previousLocation {
            updateLocationFromTimer(location)
        }
    }

    @objc func updateLocationFromTimer(_ location: CLLocation) {

        observer.didUpdate(manager: locationManager, newLocation: location)
        previousLocation = location
        newLocationForUpdate = nil
    }
}

func ==(llo: LocationObserverItem, rlo: LocationObserverItem) -> Bool {
    return llo === rlo
}
