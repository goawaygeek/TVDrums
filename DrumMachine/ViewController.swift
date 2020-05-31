//
//  ViewController.swift
//  DrumMachine
//
//  Created by Scott Brewer on 4/22/20.
//  Copyright © 2020 Scott Brewer. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMotion
import CoreBluetooth


class ViewController: UIViewController, DrumTriggerDelegate, DrumCentralDelegate {

    // Main Audio Engine and it's corresponding mixer
    var audioEngine: DrummerAudioEngine = DrummerAudioEngine()
    
    var drumTrigger : DrumTrigger = DrumTrigger()
    
    var drumPeripheral : DrumPeripheral?
    var drumCentral : DrumCentral?
    
    var drumkit: [PercussiveInstrument] = []
    
    var emitterLayer : CAEmitterLayer = CAEmitterLayer()
    
    var drumEmitters : [PercussionType : CAEmitterLayer ] = [:]
    
    var drumSelection = 0
    
    @IBOutlet weak var drumSelector: UISegmentedControl!
    @IBOutlet weak var kickButton: UIButton!
    @IBOutlet weak var snareButton: UIButton!
    @IBOutlet weak var floorTomButton: UIButton!
    @IBOutlet weak var rackTomButton: UIButton!
    @IBOutlet weak var hiHatButton: UIButton!
    @IBOutlet weak var crashButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // setup the drumkit
        // Do any additional setup after loading the view.
        PercussionType.allCases.forEach {
            (drumkit.append(PercussiveInstrument(type: $0)))
        }
        
        // setup the segmented control and buttons
        for i in 0..<drumkit.count {
            drumSelector.setTitle(drumkit[i].description, forSegmentAt: i)
            switch drumkit[i].type {
            case .kick: kickButton.tag = i
            case .snare: snareButton.tag = i
            case .hihat: hiHatButton.tag = i
            case .crash: crashButton.tag = i
            case .floortom: floorTomButton.tag = i
            case .racktom: rackTomButton.tag = i
            default:
                print("no button for ", drumkit[i].description)
            }
        }
        
        // setup the buttons
        
        // Get the singleton instance.
        audioEngine = DrummerAudioEngine()
        
        // load the kit
        audioEngine.loadKit(percussiveInstruments: drumkit)
        
        // start the engine
        audioEngine.startEngine()
        
        // start the drum trigger
        drumTrigger = DrumTrigger()
        drumTrigger.delegate = self
        
        // setup the UI
        emitterSetup()
        
        // drumkit is ready to play!
    }
    
    // create the AVAudioPlayerNodes here

    // Drum trigger hit
    @IBAction func drumHit(_ sender: UIButton) {
        let button = sender
        //print(button.tag)
        audioEngine.drumTrigger(percussiveInstrument: drumkit[button.tag])
        displayHit(instrument: drumkit[button.tag].type)
    }
    
    @IBAction func drumSelected(_ sender: UISegmentedControl) {
        let control = sender
        //print(control.selectedSegmentIndex)
        drumSelection = control.selectedSegmentIndex
    }
    @IBAction func bluetoothStatus(_ sender: UISwitch) {
        let btstatus = sender
        print("switch changed to: ", btstatus.isOn)
        if btstatus.isOn {
            // start the peripheral if it doesn't exist
            if drumPeripheral == nil {
                drumPeripheral = DrumPeripheral(instrument: drumkit[drumSelector.selectedSegmentIndex])
            } else {
                drumPeripheral = nil
                drumPeripheral = DrumPeripheral(instrument: drumkit[drumSelector.selectedSegmentIndex])
                //drumPeripheral?.toggleAdvertising(state: btstatus.isOn)
            }
            drumSelector.isEnabled = false
        } else {
            // stop the peripheral
            drumPeripheral?.toggleAdvertising(state: btstatus.isOn)
            //drumCentral?.disconnect(peripheral: drumPeripheral)
            drumSelector.isEnabled = true
        }
    }
    
    @IBAction func btCentralStatus(_ sender: UISwitch) {
        let btstatus = sender
        print("switch changed to: ", btstatus.isOn)
        if btstatus.isOn {
            // start the peripheral
            drumCentral = DrumCentral()
            drumCentral?.delegate = self
        } else {
            // stop the peripheral
            drumCentral = nil
        }
    }
    
    func hitDetected() {
        audioEngine.drumTrigger(percussiveInstrument: drumkit[drumSelector.selectedSegmentIndex])
        displayHit(instrument: drumkit[drumSelector.selectedSegmentIndex].type)
        if drumkit[drumSelector.selectedSegmentIndex].type == .kick {
            view.backgroundColor = .random()
        }
        guard let advertising = drumPeripheral?.isAdvertising() else { return }
        if advertising { drumPeripheral?.sendTrigger() }
    }
    
    // Bluetooth delegate
    func hitReceived(forUUID: CBUUID) {
        var localSelection = 0
        for percussiveInstrument in drumkit {
            if forUUID.uuidString == percussiveInstrument.characteristicUUID.uuidString {
                break
            } else {
                localSelection += 1
            }
        }
        audioEngine.drumTrigger(percussiveInstrument: drumkit[localSelection])
        displayHit(instrument: drumkit[localSelection].type)
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

