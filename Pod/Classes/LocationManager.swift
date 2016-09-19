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

    open static let locationDidChangeAuthorizationStatusNotification = "locationDidChangeAuthorizationStatusNotification"
    open static let sharedManager = LocationManager()

    var currentLocation: CLLocation?
    internal var lastKnownLocation: CLLocation?
    
    fileprivate var locationRequests: [LocationRequest] = []
    fileprivate var locationObservers: Set<LocationObserverItem> = []
    fileprivate var askForLocationServicesFulfillments: [AuthorizationFulfillment] = []
    fileprivate let locationManager = CLLocationManager()

    open static var locationObserversCount: Int {
        return self.sharedManager.locationObserversCount
    }
    open var locationObserversCount: Int {
        return self.locationObservers.count
    }

    public override init() {

        super.init()

        self.locationManager.delegate = self
        self.locationManager.distanceFilter = 0
        self.locationManager.desiredAccuracy = 0
    }
    
    open class func isLocationStatusDetermined() -> Bool {
        return self.sharedManager.isLocationStatusDetermined()
    }
    
    open func isLocationStatusDetermined() -> Bool {
        return CLLocationManager.authorizationStatus() != CLAuthorizationStatus.notDetermined
    }
    
    open class func isLocationAvailable() -> Bool {
        return sharedManager.isLocationAvailable()
    }
    
    open func isLocationAvailable() -> Bool {
        return CLLocationManager.locationServicesEnabled() && (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedAlways || CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedWhenInUse)
    }
    
    /**
     * Checks for authorization status of location services
     * returns promise for authorization status on success, LocationManagerAuthorizationError on fail
     */
    
    open class func askForLocationServicesIfNeeded() -> Promise<CLAuthorizationStatus>{
        return self.sharedManager.askForLocationServicesIfNeeded()
    }
    
    open func askForLocationServicesIfNeeded() -> Promise<CLAuthorizationStatus>{

        return Promise { fulfill, reject in

            if isLocationStatusDetermined() {
                return fulfill(CLLocationManager.authorizationStatus())
            }

            askWithFulfillment({ (status: CLAuthorizationStatus) -> Void in
                fulfill(status)
            },rejection: reject)
        }
    }
    
    fileprivate func askWithFulfillment(_ fulfillment: @escaping AuthorizationFulfillment, rejection: (Error) -> Void) -> Void {

        var rejected = false

        if askForLocationServicesFulfillments.count == 0 {

            if Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysUsageDescription") != nil {

                if locationManager.responds(to: #selector(CLLocationManager.requestAlwaysAuthorization)){
                    locationManager.requestAlwaysAuthorization()
                }

            } else if Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil {

                if locationManager.responds(to: #selector(CLLocationManager.requestWhenInUseAuthorization)) {
                    locationManager.requestWhenInUseAuthorization();
                }

            } else {

                rejection(LocationManagerAuthorizationError.keyInPlistMissing)
                rejected = true
            }
        }

        if !rejected {
            askForLocationServicesFulfillments.append(fulfillment)
        }
    }
    
    func startUpdatingLocationIfNeeded() {

        if locationRequests.count > 0 || locationObservers.count > 0 {

            askForLocationServicesIfNeeded()
            locationManager.startUpdatingLocation()
        }

        updateLocationManagerSettings()
    }
    
    func stopUpdatingLocationIfPossible() {

        if locationRequests.count == 0 && locationObservers.count == 0 {
            locationManager.stopUpdatingLocation()
        }

        updateLocationManagerSettings()
    }
    
    func updateLocationManagerSettings() {

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
        
        if locationRequests.count == 0 {

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

            return Promise { success, reject in

                if let currentLocation = self.currentLocation, !force {
                    success(currentLocation)
                } else {

                    self.updateLocation(timeout: timeout,desiredAccuracy: desiredAccuracy) { location in

                        if let location = location {
                            success(location)
                        } else {
                            reject(LocationManagerError.cannotFetchLocation)
                        }
                    }
                }
            }
        }
    }
    
    internal func locationRequestDidTimeout(_ request: LocationRequest) {
        removeLocationRequest(request)
    }
    
    internal func removeLocationRequest(_ request: LocationRequest) {

        if let index = locationRequests.index(of: request) {
            locationRequests.remove(at: index)
        }
    }
    
    // MARK: - Location observers
    
    open class func addLocationObserver(_ observer: LocationObserver, desiredAccuracy: CLLocationAccuracy? = nil, distanceFilter: CLLocationDistance? = nil, minimumTimeInterval: TimeInterval? = nil, maximumTimeInterval: TimeInterval? = nil) {
        sharedManager.addLocationObserver(observer, desiredAccuracy: desiredAccuracy, distanceFilter: distanceFilter, minimumTimeInterval: minimumTimeInterval, maximumTimeInterval: maximumTimeInterval)
    }
    
    open func addLocationObserver(_ observer: LocationObserver, desiredAccuracy: CLLocationAccuracy? = nil, distanceFilter: CLLocationDistance? = nil, minimumTimeInterval: TimeInterval? = nil, maximumTimeInterval: TimeInterval? = nil) {

        let item = LocationObserverItem(locationObserver: observer, locationManager: self, desiredAccuracy: desiredAccuracy, distanceFilter: distanceFilter, minimumTimeInterval: minimumTimeInterval, maximumTimeInterval: maximumTimeInterval)
        locationObservers.insert(item)
        
        startUpdatingLocationIfNeeded()
    }
    
    open class func removeLocationObserver(_ observer: LocationObserver) {
        sharedManager.removeLocationObserver(observer)
    }
    
    open func removeLocationObserver(_ observer: LocationObserver) {

        if let index = locationObservers.index(where: { (_observer) -> Bool in
            return observer === _observer.observer
        }) {
            locationObservers[index].invalidate()
            locationObservers.remove(at: index)
        }
        
        stopUpdatingLocationIfPossible()
    }
    
    func updateLocation(timeout: TimeInterval?, desiredAccuracy: CLLocationAccuracy?, completion: @escaping LocationCompletion) {
        
        let request = LocationRequest(timeout: timeout, desiredAccuracy: desiredAccuracy, completion: completion, locationManager: self)
        
        if !request.completeWithLocation(lastKnownLocation) {
            locationRequests.append(request)
            startUpdatingLocationIfNeeded()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    open func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {

        NotificationCenter.default.post(name: Notification.Name(rawValue: LocationManager.locationDidChangeAuthorizationStatusNotification), object: nil)

        if status != .notDetermined {

            for fulfillment in askForLocationServicesFulfillments {
                fulfillment(status)
            }
        }
    }
    
    open func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        if let lastLocation = locations.last {

            lastKnownLocation = lastLocation
            
            for (_,request) in locationRequests.enumerated() {

                if request.completeWithLocation(lastLocation) {
                    removeLocationRequest(request)
                }
            }
            
            for observer in locationObservers {
                observer.updateLocation(lastLocation)
            }

            stopUpdatingLocationIfPossible()
        }
    }
}
