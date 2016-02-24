//
//  LocationCompletionQueue.swift
//  Pods
//
//  Created by Aleš Kocur on 20/05/15.
//  Copyright © 2015 The Funtasty. All rights reserved.
//
//


import CoreLocation

typealias LocationCompletion = CLLocation? -> Void

class LocationCompletionQueueItem: Equatable {
    let completion: LocationCompletion
    var timeout: NSTimeInterval?
    
    init(timeout: NSTimeInterval?, completion: LocationCompletion) {
        self.completion = completion
        self.timeout = timeout
    }
}

func ==(lhs: LocationCompletionQueueItem, rhs: LocationCompletionQueueItem) -> Bool {
    return lhs === rhs
}

public class LocationCompletionQueue: NSObject {
    
    let locationManager: LocationManager
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }
    
    
    var queueItems: [LocationCompletionQueueItem] = []
    
    var isActive: Bool {
        return timer != nil
    }
    
    private var timer: NSTimer?
    
    func pushCompletionItem(timeout: NSTimeInterval? = nil, completionItem: LocationCompletion) {
        queueItems.append(LocationCompletionQueueItem(timeout: timeout, completion: completionItem))
        
        self.startTimerIfNeeded()
    }
    
    // MARK: - Timer
    
    func startTimerIfNeeded() {
        if timer != nil || queueItems.count == 0 {
            return
        }
        
        timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("tick"), userInfo: nil, repeats: true)
    }
    
    func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func tick() {
        
        var toDelete: [LocationCompletionQueueItem] = []
        
        for item in queueItems {
            if item.timeout == nil {
                continue
            } else if item.timeout == 0 {
                item.completion(self.locationManager.lastKnownLocation)
                toDelete.append(item)
            } else {
                item.timeout! -= 1
            }
        }
        
        for objectForDelete in toDelete {
            if let index = queueItems.indexOf(objectForDelete) {
                queueItems.removeAtIndex(index)
            }
        }
        
        if queueItems.count == 0 {
            self.invalidateTimer()
            self.locationManager.stopUpdatingLocationIfPossible()
        }
    }
    
    // MARK: - Run
    
    func completeWithLocation(location: CLLocation) {
        invalidateTimer()
        queueItems.forEach { $0.completion(location) }
        queueItems.removeAll()
    }
}
