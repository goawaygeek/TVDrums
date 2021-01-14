//
//  ViewController.swift
//  TVDrumMachine
//
//  Created by Scott Brewer on 5/25/20.
//  Copyright © 2020 Scott Brewer. All rights reserved.
//

import UIKit
import CoreBluetooth
import AVFoundation

class ViewController: UIViewController, DrumCentralDelegate {

    var audioEngine: DrummerAudioEngine = DrummerAudioEngine()
    
    var drumCentral : DrumCentral?
    
    var drumkit: [PercussiveInstrument] = []
    
    var emitterLayer : CAEmitterLayer = CAEmitterLayer()
    
    var drumEmitters : [PercussionType : CAEmitterLayer ] = [:]
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        PercussionType.allCases.forEach {
            (drumkit.append(PercussiveInstrument(type: $0)))
        }
        
        // Get the singleton instance.
        audioEngine = DrummerAudioEngine()
        
        // load the kit
        audioEngine.loadKit(percussiveInstruments: drumkit)
        
        // start the engine
        audioEngine.startEngine()
        
        // setup the UI
        emitterSetup()
        
        drumCentral = DrumCentral()
        drumCentral?.delegate = self
        
    }
    
    // Bluetooth delegate
    func hitReceived(forUUID: CBUUID) {
        var selectedDrum = 0
        for percussiveInstrument in drumkit {
            if forUUID.uuidString == percussiveInstrument.characteristicUUID.uuidString {
                break
            } else {
                selectedDrum += 1
            }
        }
        audioEngine.drumTrigger(percussiveInstrument: drumkit[selectedDrum])
        displayHit(instrument: drumkit[selectedDrum].type)
        if drumkit[selectedDrum].type == .kick {
            view.backgroundColor = .random()
        }
        
    }
    
    func emitterSetup () {
        // get screen size
        let height = self.view.frame.size.height
        let widthMidPoint = self.view.frame.size.width / 2
        
        for instrument in drumkit {
            let emitterLayer = InstrumentEmitter()
            let x = CGFloat(instrument.location.x) * widthMidPoint
            let y = CGFloat(instrument.location.y) * height
            drumEmitters[instrument.type] = emitterLayer.createDrumEmitterLayerWith(color: UIColor.red.cgColor, location: CGPoint(x: widthMidPoint + x, y: height - y))
            view.layer.addSublayer(drumEmitters[instrument.type]!)
        }
    }
    
    func displayHit(instrument: PercussionType) {
        if drumEmitters[instrument]!.velocity == 1 {
            drumEmitters[instrument]!.velocity = 1000
            drumEmitters[instrument]!.birthRate = 1000
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // your code here
                self.displayHit(instrument: instrument)
            }
        } else {
            drumEmitters[instrument]!.velocity = 1
            drumEmitters[instrument]!.birthRate = 1
        }
    }


}

// https://stackoverflow.com/questions/29779128/how-to-make-a-random-color-with-swift

extension UIColor {
  static func random () -> UIColor {
    return UIColor(
      red: CGFloat.random(in: 0...1),
      green: CGFloat.random(in: 0...1),
      blue: CGFloat.random(in: 0...1),
      alpha: 1.0)
  }
}
