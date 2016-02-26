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



public class LocationManager: NSObject, CLLocationManagerDelegate {
    
    public static let sharedManager = LocationManager()
    
    private let locationManager = CLLocationManager()
    
//    lazy private var locationCompletionQueue: LocationCompletionQueue = {
//        let queue = LocationCompletionQueue(locationManager: self)
//        return queue
//    }()
    
    private var locationRequests: [LocationRequest] = []
    private var locationObservers: [LocationObserverItem] = []
    
    static let locationDidUpdatePermissionsNotification = "locationDidUpdatePermissions"
    
    var currentLocation: CLLocation?
    
    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.distanceFilter = 0
        self.locationManager.desiredAccuracy = 0
        self.askForLocationServicesIfNeeded()
    }
    
    
    public func isLocationStatusDetermined() -> Bool {
        return CLLocationManager.authorizationStatus() != CLAuthorizationStatus.NotDetermined
    }
    
    public func isLocationAvailable() -> Bool {
        return CLLocationManager.locationServicesEnabled() && (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.AuthorizedAlways || CLLocationManager.authorizationStatus() == CLAuthorizationStatus.AuthorizedWhenInUse)
    }
    
    func askForLocationServicesIfNeeded() {
        if self.isLocationStatusDetermined() {
            return
        }
        
        if NSBundle.mainBundle().objectForInfoDictionaryKey("NSLocationAlwaysUsageDescription") != nil {
            if self.locationManager.respondsToSelector("requestAlwaysAuthorization"){
                self.locationManager.requestAlwaysAuthorization()
            }
        } else if NSBundle.mainBundle().objectForInfoDictionaryKey("NSLocationWhenInUseUsageDescription") != nil {
            if self.locationManager.respondsToSelector("requestWhenInUseAuthorization") {
                self.locationManager.requestWhenInUseAuthorization();
            }
        }else{
            print("[LocationManager ERROR] The keys NSLocationAlwaysUsageDescription or NSLocationWhenInUseUsageDescription are not defined in your tiapp.xml.  Starting with iOS8 this are required.")
        }
    }
    
    
    func startUpdatingLocationIfNeeded() {
        if self.locationRequests.count > 0 || self.locationObservers.count > 0 {
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
    
    // MARK: - location requests
    
    public func getCurrentLocation(timeout timeout: NSTimeInterval? = 8.0, desiredAccuracy: CLLocationAccuracy? = nil, force: Bool = false) -> Promise<CLLocation> {
        return Promise { success, reject in
            
            if !isLocationAvailable() && self.isLocationStatusDetermined() {
                reject(LocationManagerError.LocationServiceDisabled)
                return
            }
            
            if let currentLocation = currentLocation where !force {
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

    
    func updateLocationManagerSettings() {
        let requestsDesiredAccuracy = self.locationRequests.map { (request) -> CLLocationAccuracy in
            return request.desiredAccuracy ?? 0
        }.minElement() ?? 0
    
        let observersDesiredAccuracy = self.locationObservers.map { (observer) -> CLLocationAccuracy in
            return observer.desiredAccuracy ?? 0
        }.minElement() ?? 0
        
        self.locationManager.desiredAccuracy = min(requestsDesiredAccuracy,observersDesiredAccuracy)

        if self.locationRequests.count == 0 {
            let observersDistanceFilter = self.locationObservers.map { (observer) -> CLLocationAccuracy in
                return observer.distanceFilter ?? 0
            }.minElement() ?? 0
            
            self.locationManager.distanceFilter = observersDistanceFilter
        }
    }
    
    
    // MARK: - location observers
    
    public func addLocationObserver(observer: LocationObserver, desiredAccuracy: CLLocationAccuracy? = nil, distanceFilter: CLLocationDistance? = nil) {
        let item = LocationObserverItem(locationObserver: observer, locationManager: self, desiredAccuracy: desiredAccuracy, distanceFilter: distanceFilter)
        self.locationObservers.append(item)
        
        self.startUpdatingLocationIfNeeded()
    }
    
    public func removeLocationObserver(observer: LocationObserver) {
        if let index = self.locationObservers.indexOf({ (_observer) -> Bool in
            return observer === _observer
        }) {
            self.locationObservers.removeAtIndex(index)
        }
        
        self.stopUpdatingLocationIfPossible()
    }

    
    // MARK: - CLLocationManagerDelegate
    
    internal var lastKnownLocation: CLLocation?
    
    func updateLocation(timeout timeout: NSTimeInterval?, desiredAccuracy: CLLocationAccuracy?, completion: LocationCompletion) {
        
        self.locationRequests.append(LocationRequest(timeout: timeout, desiredAccuracy: desiredAccuracy, completion: completion, locationManager: self))
        
        self.startUpdatingLocationIfNeeded()
    }
    
    public func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        NSNotificationCenter.defaultCenter().postNotificationName(LocationManager.locationDidUpdatePermissionsNotification, object: nil)
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
    
    internal func locationRequestDidTimeout(request: LocationRequest) {
        self.removeLocationRequest(request)
    }
    
    internal func removeLocationRequest(request: LocationRequest) {
        if let index = self.locationRequests.indexOf(request) {
            self.locationRequests.removeAtIndex(index)
        }
    }
    
}
