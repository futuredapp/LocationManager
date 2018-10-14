//
//  LocationManager.swift
//  Pods
//
//  Created by Aleš Kocur on 20/05/15.
//  Copyright © 2015 The Funtasty. All rights reserved.
//
//

import CoreLocation
import PromiseKit

public enum LocationManagerError: Error {
    case locationServiceDisabled
    case cannotFetchLocation
}

public enum LocationManagerAuthorizationError: Error {
    case keyInPlistMissing
}

open class LocationManager: NSObject, CLLocationManagerDelegate {

    typealias AuthorizationFulfillment = (CLAuthorizationStatus) -> Void

    @objc public static let locationDidChangeAuthorizationStatusNotification = "locationDidChangeAuthorizationStatusNotification"
    @objc public static let sharedManager = LocationManager()

    @objc var currentLocation: CLLocation?
    @objc internal var lastKnownLocation: CLLocation?
    
    fileprivate var locationRequests = [LocationRequest]()
    fileprivate var locationObservers: Set<LocationObserverItem> = []
    fileprivate var askForLocationServicesFulfillments = [AuthorizationFulfillment]()
    fileprivate let locationManager = CLLocationManager()

    @objc public static var locationObserversCount: Int {
        return self.sharedManager.locationObserversCount
    }
    @objc open var locationObserversCount: Int {
        return self.locationObservers.count
    }

    public override init() {

        super.init()

        self.locationManager.delegate = self
        self.locationManager.distanceFilter = 0
        self.locationManager.desiredAccuracy = 0
    }
    
    @objc open class func isLocationStatusDetermined() -> Bool {
        return self.sharedManager.isLocationStatusDetermined()
    }
    
    @objc open func isLocationStatusDetermined() -> Bool {
        return CLLocationManager.authorizationStatus() != CLAuthorizationStatus.notDetermined
    }
    
    @objc open class func isLocationAvailable() -> Bool {
        return sharedManager.isLocationAvailable()
    }
    
    @objc open func isLocationAvailable() -> Bool {
        return CLLocationManager.locationServicesEnabled() && (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedAlways || CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedWhenInUse)
    }
    
    /**
     * Checks for authorization status of location services
     * returns promise for authorization status on success, LocationManagerAuthorizationError on fail
     */
    
    open class func askForLocationServicesIfNeeded() -> Promise<CLAuthorizationStatus> {
        return self.sharedManager.askForLocationServicesIfNeeded()
    }
    
    open func askForLocationServicesIfNeeded() -> Promise<CLAuthorizationStatus> {

        let promise = Promise<CLAuthorizationStatus> { seal in
            if isLocationStatusDetermined() {
                return seal.fulfill(CLLocationManager.authorizationStatus())
            }
            
            askWith(fulfillment: { (status: CLAuthorizationStatus) -> Void in
                seal.fulfill(status)
            }, rejection: seal.reject)
        }
        return promise
        
    }
    
    fileprivate func askWith(fulfillment: @escaping AuthorizationFulfillment, rejection: (Error) -> Void) -> Void {

        if !setupRequestPermissionsStrategy(rejection: rejection) {
            askForLocationServicesFulfillments.append(fulfillment)
        }
    }
    
    private func setupRequestPermissionsStrategy(rejection: (Error) -> Void) -> Bool {
        
        if askForLocationServicesFulfillments.isEmpty {
            
            if Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysUsageDescription") != nil {
                
                if locationManager.responds(to: #selector(CLLocationManager.requestAlwaysAuthorization)) {
                    locationManager.requestAlwaysAuthorization()
                }
                
            } else if Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil {
                
                if locationManager.responds(to: #selector(CLLocationManager.requestWhenInUseAuthorization)) {
                    locationManager.requestWhenInUseAuthorization();
                }
                
            } else {
                
                rejection(LocationManagerAuthorizationError.keyInPlistMissing)
                return true
            }
        }
        return false
    }
    
    @objc func startUpdatingLocationIfNeeded() {

        if !locationRequests.isEmpty || !locationObservers.isEmpty {

            _ = askForLocationServicesIfNeeded()
            locationManager.startUpdatingLocation()
        }

        updateLocationManagerSettings()
    }
    
    @objc func stopUpdatingLocationIfPossible() {

        if locationRequests.isEmpty && locationObservers.isEmpty {
            locationManager.stopUpdatingLocation()
        }

        updateLocationManagerSettings()
    }
    
    @objc func updateLocationManagerSettings() {

        let requestsDesiredAccuracy = locationRequests.map { (request) -> CLLocationAccuracy in
            return request.desiredAccuracy ?? 0
        }.min() ?? 0
        
        let observersDesiredAccuracy = locationObservers.map { (observer) -> CLLocationAccuracy in
            return observer.desiredAccuracy ?? 0
        }.min() ?? 0
        
        let desiredAccuracy = min(requestsDesiredAccuracy,observersDesiredAccuracy)

        if locationManager.desiredAccuracy != desiredAccuracy {
           locationManager.desiredAccuracy = desiredAccuracy
        }
        
        if locationRequests.isEmpty {

            let observersDistanceFilter = locationObservers.map { (observer) -> CLLocationAccuracy in
                return observer.distanceFilter ?? 0
            }.min() ?? 0
            
            if locationManager.distanceFilter != observersDistanceFilter {
                locationManager.distanceFilter = observersDistanceFilter
            }
        }
    }
    
    // MARK: - Location requests
    
    open class func getCurrentLocation(timeout: TimeInterval? = 8.0, desiredAccuracy: CLLocationAccuracy? = nil, force: Bool = false) -> Promise<CLLocation> {
        return sharedManager.getCurrentLocation(timeout: timeout, desiredAccuracy: desiredAccuracy, force: force)
    }
    
    open func getCurrentLocation(timeout: TimeInterval? = 8.0, desiredAccuracy: CLLocationAccuracy? = nil, force: Bool = false) -> Promise<CLLocation> {

        return askForLocationServicesIfNeeded().then { (status) -> Promise<CLLocation> in

            if !self.isLocationAvailable() {
                throw LocationManagerError.locationServiceDisabled
            }
            let promise = Promise<CLLocation> { seal in
                if let currentLocation = self.currentLocation, !force {
                    seal.resolve(currentLocation, nil)
                } else {

                    self.updateLocation(timeout: timeout,desiredAccuracy: desiredAccuracy) { location in

                        if let location = location {
                            seal.resolve(location, nil)
                        } else {
                            seal.resolve(nil, LocationManagerError.cannotFetchLocation)
                        }
                    }
                }
            }
            return promise
        }
    }
    
    @objc internal func locationRequestDidTimeout(_ request: LocationRequest) {
        remove(locationRequest: request)
    }
    
    @objc internal func remove(locationRequest: LocationRequest) {

        if let index = locationRequests.index(of: locationRequest) {
            locationRequests.remove(at: index)
        }
    }
    
    // MARK: - Location observers
    
    open class func add(locationObserver: LocationObserver, desiredAccuracy: CLLocationAccuracy? = nil, distanceFilter: CLLocationDistance? = nil, minimumTimeInterval: TimeInterval? = nil, maximumTimeInterval: TimeInterval? = nil) {
        sharedManager.add(locationObserver: locationObserver, desiredAccuracy: desiredAccuracy, distanceFilter: distanceFilter, minimumTimeInterval: minimumTimeInterval, maximumTimeInterval: maximumTimeInterval)
    }
    
    open func add(locationObserver: LocationObserver, desiredAccuracy: CLLocationAccuracy? = nil, distanceFilter: CLLocationDistance? = nil, minimumTimeInterval: TimeInterval? = nil, maximumTimeInterval: TimeInterval? = nil) {

        let item = LocationObserverItem(locationObserver: locationObserver, locationManager: self, desiredAccuracy: desiredAccuracy, distanceFilter: distanceFilter, minimumTimeInterval: minimumTimeInterval, maximumTimeInterval: maximumTimeInterval)
        locationObservers.insert(item)
        
        startUpdatingLocationIfNeeded()
    }
    
    open class func remove(locationObserver: LocationObserver) {
        sharedManager.remove(locationObserver: locationObserver)
    }
    
    open func remove(locationObserver: LocationObserver) {

        if let index = locationObservers.index(where: { (_observer) -> Bool in
            return locationObserver === _observer.observer
        }) {
            locationObservers[index].invalidate()
            locationObservers.remove(at: index)
        }
        
        stopUpdatingLocationIfPossible()
    }
    
    func updateLocation(timeout: TimeInterval?, desiredAccuracy: CLLocationAccuracy?, completion: @escaping LocationCompletion) {
        
        let request = LocationRequest(timeout: timeout, desiredAccuracy: desiredAccuracy, completion: completion, locationManager: self)
        
        if !request.completeWith(location: lastKnownLocation) {
            locationRequests.append(request)
            startUpdatingLocationIfNeeded()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    open func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {

        NotificationCenter.default.post(name: Notification.Name(rawValue: LocationManager.locationDidChangeAuthorizationStatusNotification), object: nil)

        if status != .notDetermined {
            askForLocationServicesFulfillments.forEach { $0(status) }
        }
    }
    
    open func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        if let lastLocation = locations.last {

            lastKnownLocation = lastLocation

            locationRequests.filter { $0.completeWith(location: lastLocation) }.forEach(remove)
            
            locationObservers.forEach { $0.update(location: lastLocation) }

            stopUpdatingLocationIfPossible()
        }
    }
}
