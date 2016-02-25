//
//  LocationObserver.swift
//  Pods
//
//  Created by Jakub Knejzlik on 25/02/16.
//
//

import CoreLocation

//public func ==(llo: LocationObserver, rlo: LocationObserver) -> Bool {
//    return llo === rlo
//}

public protocol LocationObserver: AnyObject {
    
    func didUpdateLocation(manager: LocationManager, location: CLLocation)
    
}