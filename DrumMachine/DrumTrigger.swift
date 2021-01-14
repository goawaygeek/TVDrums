//
//  DrumTrigger.swift
//  DrumMachine
//
//  Created by Scott Brewer on 5/14/20.
//  Copyright © 2020 Scott Brewer. All rights reserved.
//

import Foundation
import CoreMotion

public protocol DrumTriggerDelegate {
    func hitDetected()
}

public class DrumTrigger {
    
    public var delegate: DrumTriggerDelegate?
    
    var motionManager: CMMotionManager = CMMotionManager()
    
    // 0.5 seems to be good based on graphing hit tests
    let triggerCutoff = 0.5
    
    public init() {
        guard motionManager.isAccelerometerAvailable else {
            print("no motion")
            return
        }
        
        var previousZ = 0.0
        var previousDelta = 0.0
        let queue = OperationQueue()
        var pause = 0
        motionManager.startDeviceMotionUpdates(to: queue) {
            [weak self] (data, error) in

            // motion processing here
            guard let data = data, error == nil else {
                return
            }
            
            // pause the count to avoid double hits
            var posDelta = 0.0
            // use a simple high pass filter algorithm to detect hits
            let delta = data.userAcceleration.z - previousZ
            // square the delta to get positive values (so it doesn't matter which way the device is facing
            if (delta > 0 ) { posDelta = delta } else { posDelta = delta * -1 }
            
            if pause == 0 {
                // 0.2 seems to be a good cutoff for detecting a hit
                if posDelta > 0.4 && posDelta > previousDelta {
                    pause += 1
                    DispatchQueue.main.async {
                        // update UI here
                        self?.delegate?.hitDetected()
                    }
                }
                
            }
            if pause > 0 { pause += 1 }
            if pause == 10 {
                pause = 0
            }
            previousZ = data.userAcceleration.z
            previousDelta = posDelta
        }
    }
}
