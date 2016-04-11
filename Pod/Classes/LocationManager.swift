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

enum LocationManagerError: ErrorType {
    case LocationServiceDisabled
    case CannotFetchLocation
}

enum LocationManagerAuthorizationError: ErrorType {
    case KeyInPlistMissing
}

public class LocationManager: NSObject, CLLocationManagerDelegate {
    
    static let locationDidChangeAuthorizationStatusNotification = "locationDidChangeAuthorizationStatusNotification"
    
    public static let sharedManager = LocationManager()

    var currentLocation: CLLocation?
    
    private var locationRequests: [LocationRequest] = []
    private var locationObservers: Set<LocationObserverItem> = []
    
    public static var locationObserversCount: Int {
        return self.sharedManager.locationObserversCount
    }
    public var locationObserversCount: Int {
        return self.locationObservers.count
    }
    
    private var askForLocationServicesFulfillments: [AuthorizationFulfillment] = []
    typealias AuthorizationFulfillment = CLAuthorizationStatus -> Void

    private let locationManager = CLLocationManager()

    public override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.distanceFilter = 0
        self.locationManager.desiredAccuracy = 0
    }
    
    public class func isLocationStatusDetermined() -> Bool {
        return self.sharedManager.isLocationStatusDetermined()
    }
    
    public func isLocationStatusDetermined() -> Bool {
        return CLLocationManager.authorizationStatus() != CLAuthorizationStatus.NotDetermined
    }
    
    public class func isLocationAvailable() -> Bool {
        return self.sharedManager.isLocationAvailable()
    }
    
    public func isLocationAvailable() -> Bool {
        return CLLocationManager.locationServicesEnabled() && (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.AuthorizedAlways || CLLocationManager.authorizationStatus() == CLAuthorizationStatus.AuthorizedWhenInUse)
    }
    
    /**
     * Checks for authorization status of location services
     * returns promise for authorization status on success, LocationManagerAuthorizationError on fail
     */
    
    public class func askForLocationServicesIfNeeded() -> Promise<CLAuthorizationStatus>{
        return self.sharedManager.askForLocationServicesIfNeeded()
    }
    
    public func askForLocationServicesIfNeeded() -> Promise<CLAuthorizationStatus>{
        return Promise { fulfill, reject in
            if self.isLocationStatusDetermined() {
                return fulfill(CLLocationManager.authorizationStatus())
            }
            self.askWithFulfillment({ (status: CLAuthorizationStatus) -> Void in
                fulfill(status)
            },rejection: reject)
        }
    }
    
    private func askWithFulfillment(fulfillment: AuthorizationFulfillment, rejection: (ErrorType) -> Void) -> Void {
        var rejected = false
        if self.askForLocationServicesFulfillments.count == 0 {
            if NSBundle.mainBundle().objectForInfoDictionaryKey("NSLocationAlwaysUsageDescription") != nil {
                if self.locationManager.respondsToSelector(#selector(CLLocationManager.requestAlwaysAuthorization)){
                    self.locationManager.requestAlwaysAuthorization()
                }
            } else if NSBundle.mainBundle().objectForInfoDictionaryKey("NSLocationWhenInUseUsageDescription") != nil {
                if self.locationManager.respondsToSelector(#selector(CLLocationManager.requestWhenInUseAuthorization)) {
                    self.locationManager.requestWhenInUseAuthorization();
                }
            }else{
                rejection(LocationManagerAuthorizationError.KeyInPlistMissing)
                rejected = true
            }
        }
        if !rejected {
            self.askForLocationServicesFulfillments.append(fulfillment)
        }
    }
    
    func startUpdatingLocationIfNeeded() {
        if self.locationRequests.count > 0 || self.locationObservers.count > 0 {
            self.askForLocationServicesIfNeeded()
            self.locationManager.startUpdatingLocation()
        }
        self.updateLocationManagerSettings()
    }
    
    func stopUpdatingLocationIfPossible() {
        if self.locationRequests.count == 0 && self.locationObservers.count == 0 {
            self.locationManager.stopUpdatingLocation()
        }
        self.updateLocationManagerSettings()
    }
    
    func updateLocationManagerSettings() {
        let requestsDesiredAccuracy = self.locationRequests.map { (request) -> CLLocationAccuracy in
            return request.desiredAccuracy ?? 0
            }.minElement() ?? 0
        
        let observersDesiredAccuracy = self.locationObservers.map { (observer) -> CLLocationAccuracy in
            return observer.desiredAccuracy ?? 0
            }.minElement() ?? 0
        
        let desiredAccuracy = min(requestsDesiredAccuracy,observersDesiredAccuracy)
        if self.locationManager.desiredAccuracy != desiredAccuracy {
           self.locationManager.desiredAccuracy = desiredAccuracy
        }
        
        if self.locationRequests.count == 0 {
            let observersDistanceFilter = self.locationObservers.map { (observer) -> CLLocationAccuracy in
                return observer.distanceFilter ?? 0
                }.minElement() ?? 0
            
            if self.locationManager.distanceFilter != observersDistanceFilter {
                self.locationManager.distanceFilter = observersDistanceFilter
            }
        }
    }
    
    // MARK: - location requests
    
    public class func getCurrentLocation(timeout timeout: NSTimeInterval? = 8.0, desiredAccuracy: CLLocationAccuracy? = nil, force: Bool = false) -> Promise<CLLocation> {
        return self.sharedManager.getCurrentLocation(timeout: timeout, desiredAccuracy: desiredAccuracy, force: force)
    }
    
    public func getCurrentLocation(timeout timeout: NSTimeInterval? = 8.0, desiredAccuracy: CLLocationAccuracy? = nil, force: Bool = false) -> Promise<CLLocation> {
        return self.askForLocationServicesIfNeeded().then { (status) -> Promise<CLLocation> in
            if !self.isLocationAvailable() {
                throw LocationManagerError.LocationServiceDisabled
            }
            return Promise { success, reject in
                if let currentLocation = self.currentLocation where !force {
                    success(currentLocation)
                } else {
                    self.updateLocation(timeout: timeout,desiredAccuracy: desiredAccuracy) { location in
                        if let location = location {
                            success(location)
                        } else {
                            reject(LocationManagerError.CannotFetchLocation)
                        }
                    }
                }
            }
        }
    }
    
    internal func locationRequestDidTimeout(request: LocationRequest) {
        self.removeLocationRequest(request)
    }
    
    internal func removeLocationRequest(request: LocationRequest) {
        if let index = self.locationRequests.indexOf(request) {
            self.locationRequests.removeAtIndex(index)
        }
    }
    
    // MARK: - location observers
    
    public class func addLocationObserver(observer: LocationObserver, desiredAccuracy: CLLocationAccuracy? = nil, distanceFilter: CLLocationDistance? = nil, minimumTimeInterval: NSTimeInterval? = nil, maximumTimeInterval: NSTimeInterval? = nil) {
        self.sharedManager.addLocationObserver(observer, desiredAccuracy: desiredAccuracy, distanceFilter: distanceFilter, minimumTimeInterval: minimumTimeInterval, maximumTimeInterval: maximumTimeInterval)
    }
    
    public func addLocationObserver(observer: LocationObserver, desiredAccuracy: CLLocationAccuracy? = nil, distanceFilter: CLLocationDistance? = nil, minimumTimeInterval: NSTimeInterval? = nil, maximumTimeInterval: NSTimeInterval? = nil) {
        let item = LocationObserverItem(locationObserver: observer, locationManager: self, desiredAccuracy: desiredAccuracy, distanceFilter: distanceFilter, minimumTimeInterval: minimumTimeInterval, maximumTimeInterval: maximumTimeInterval)
        self.locationObservers.insert(item)
        
        self.startUpdatingLocationIfNeeded()
    }
    
    public class func removeLocationObserver(observer: LocationObserver) {
        self.sharedManager.removeLocationObserver(observer)
    }
    
    public func removeLocationObserver(observer: LocationObserver) {
        if let index = self.locationObservers.indexOf({ (_observer) -> Bool in
            return observer === _observer.observer
        }) {
            self.locationObservers[index].invalidate()
            self.locationObservers.removeAtIndex(index)
        }
        
        self.stopUpdatingLocationIfPossible()
    }

    internal var lastKnownLocation: CLLocation?
    
    func updateLocation(timeout timeout: NSTimeInterval?, desiredAccuracy: CLLocationAccuracy?, completion: LocationCompletion) {
        
        let request = LocationRequest(timeout: timeout, desiredAccuracy: desiredAccuracy, completion: completion, locationManager: self)
        
        if !request.completeWithLocation(self.lastKnownLocation) {
            self.locationRequests.append(request)
            self.startUpdatingLocationIfNeeded()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    public func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        NSNotificationCenter.defaultCenter().postNotificationName(LocationManager.locationDidChangeAuthorizationStatusNotification, object: nil)
        if status != .NotDetermined {
            for fulfillment in self.askForLocationServicesFulfillments {
                fulfillment(status)
            }
        }
    }
    
    public func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let lastLocation = locations.last {
            self.lastKnownLocation = lastLocation
            
            for (_,request) in self.locationRequests.enumerate() {
                if request.completeWithLocation(lastLocation) {
                    self.removeLocationRequest(request)
                }
            }
            
            for observer in self.locationObservers {
                observer.updateLocation(lastLocation)
            }
            self.stopUpdatingLocationIfPossible()
        }
    }
}
