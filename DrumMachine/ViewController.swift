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
import MultipeerConnectivity


class ViewController: UIViewController, DrumTriggerDelegate, DrumCentralDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, MCSessionDelegate, StreamDelegate {

    // Main Audio Engine and it's corresponding mixer
    var audioEngine: DrummerAudioEngine = DrummerAudioEngine()
    
    var drumTrigger : DrumTrigger = DrumTrigger()
    
    var drumPeripheral : DrumPeripheral?
    var drumCentral : DrumCentral?
    
    var drumkit: [PercussiveInstrument] = []
    
    var emitterLayer : CAEmitterLayer = CAEmitterLayer()
    
    var drumEmitters : [PercussionType : CAEmitterLayer ] = [:]
    
    var drumSelection = 0
    
    let multipeertype = "kysor-drums"
    let hostPeerID = MCPeerID(displayName: "drum-brain")
    let drumPeerID = MCPeerID(displayName: "drum")
    var serviceAdvertiser : MCNearbyServiceAdvertiser?
    var serviceBrowser : MCNearbyServiceBrowser?
    var outputStream:OutputStream?
    var inputStream:InputStream?
    
    var session : MCSession!
    var isSender = false
    
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
        
        // get the audio engine
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
        
        // drumkit is ready to play locally!
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: hostPeerID, discoveryInfo: nil, serviceType: multipeertype)
        serviceAdvertiser!.delegate = self
        
        
        serviceBrowser = MCNearbyServiceBrowser(peer: hostPeerID, serviceType: multipeertype)
        serviceBrowser!.delegate = self
        
        session = MCSession(peer: hostPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
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
            // set up multipeer, you probably don't want to do this from scratch every time but let's just get it working
            //let title = drumSelector.titleForSegment(at: drumSelector.selectedSegmentIndex)!
            //serviceAdvertiser = MCNearbyServiceAdvertiser(peer: MCPeerID(displayName: title), discoveryInfo: nil, serviceType: multipeertype)
            //serviceAdvertiser!.delegate = self
            serviceAdvertiser!.startAdvertisingPeer()
            
            drumSelector.isEnabled = false
            isSender = true
        } else {
            serviceAdvertiser!.stopAdvertisingPeer()
            drumSelector.isEnabled = true
            isSender = false
        }
    }
    
    @IBAction func btCentralStatus(_ sender: UISwitch) {
        let btstatus = sender
        print("switch changed to: ", btstatus.isOn)
        if btstatus.isOn {
            // start the peripheral
            //serviceBrowser = MCNearbyServiceBrowser(peer: hostPeerID, serviceType: multipeertype)
            //serviceBrowser!.delegate = self
            serviceBrowser!.startBrowsingForPeers()
        } else {
            // stop the peripheral
            serviceBrowser!.stopBrowsingForPeers()
        }
    }
    
    func hitDetected() {
        audioEngine.drumTrigger(percussiveInstrument: drumkit[drumSelector.selectedSegmentIndex])
        displayHit(instrument: drumkit[drumSelector.selectedSegmentIndex].type)
        if drumkit[drumSelector.selectedSegmentIndex].type == .kick {
            view.backgroundColor = .random()
        }
        /*
        // bluetooth
        guard let advertising = drumPeripheral?.isAdvertising() else { return }
        if advertising { drumPeripheral?.sendTrigger() }
        */
        // multipeer
        if session.connectedPeers.count > 0 && isSender{
            /*
            do {
                // this is a potential issue as it assumes all connected peers have the same UISegmentedControl values
                let data = withUnsafeBytes(of: drumSelector.selectedSegmentIndex) { Data($0) }
                try session.send(data, toPeers: session.connectedPeers, with: .unreliable)
            }
            catch let error {
                NSLog("%@", "Error for sending: \(error)")
            }*/
            let string = "Testing stream"
            //let data = string.data(using: String.Encoding.utf8)!
            //let bytesWritten = data.withUnsafeBytes { outputStream?.write($0, maxLength: data.count) }
            if let output = outputStream {
                output.write(string, maxLength: string.utf8.count)
                
                print("outputStream written: \(string)")
            }
        }
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
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        NSLog("%@", "didNotStartAdvertisingPeer: \(error)")
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        NSLog("%@", "didReceiveInvitationFromPeer \(peerID)")
        invitationHandler(true, session)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        NSLog("%@", "didNotStartBrowsingForPeers: \(error)")
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        NSLog("%@", "foundPeer: \(peerID)")
        NSLog("%@", "invitePeer: \(peerID)")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("%@", "lostPeer: \(peerID)")
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        NSLog("%@", "peer \(peerID) didChangeState: \(state.rawValue)")
        //self.delegate?.connectedDevicesChanged(manager: self, connectedDevices: session.connectedPeers.map{$0.displayName})
        switch state {
            case .notConnected: break
            case .connecting: break
            case .connected: connectStream() // try and connect to an output stream
            default: break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        // when the data is "HIT" then play the corresponding drum based on the peerID
        // https://stackoverflow.com/questions/28680589/how-to-convert-an-int-into-nsdata-in-swift
        let drumReceived = data.withUnsafeBytes {
            $0.load(as: Int.self)
        }
        NSLog("%@", "didReceiveData: \(data) as int: \(drumReceived)")
        
        // this is happening on a weird thread or something else is getting in the way
        DispatchQueue.main.async {
            self.audioEngine.drumTrigger(percussiveInstrument: self.drumkit[drumReceived])
            self.displayHit(instrument: self.drumkit[drumReceived].type)
            if self.drumkit[drumReceived].type == .kick {
                self.view.backgroundColor = .random()
            }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        NSLog("%@", "didReceiveStream")
        inputStream = stream
        inputStream!.delegate = self
        inputStream!.schedule(in: RunLoop.main, forMode: RunLoop.Mode.default)
        inputStream!.open()
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        NSLog("%@", "didStartReceivingResourceWithName")
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        NSLog("%@", "didFinishReceivingResourceWithName")
    }
    
    func connectStream() {
        if isSender {
            do {
                try outputStream = session.startStream(withName: "drum-brain", toPeer: session.connectedPeers[0])
                if let outputStream = outputStream {
                    outputStream.delegate = self
                    outputStream.schedule(in: RunLoop.main, forMode: RunLoop.Mode.default)
                    outputStream.open()
                }
                
            } catch {
                print("error in connectStream()")
            }
        }
    }
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        print("stream delegate called")
        switch(eventCode){
        case Stream.Event.hasBytesAvailable:
            let input = aStream as! InputStream
            var buffer = [UInt8](repeating: 0, count: 1024) //allocate a buffer. The size of the buffer will depended on the size of the data you are sending.
            let numberBytes = input.read(&buffer, maxLength:1024)
            let data = Data(bytes: &buffer, count: numberBytes)
            let dataString = String(decoding: data, as: UTF8.self)
            //let message = NSKeyedUnarchiver.unarchiveObject(with: dataString as Data) as! String //deserializing the NSData
            
            print("received message as stream\(dataString)")
        //input
        case Stream.Event.hasSpaceAvailable:
            break
        //output
        default:
            break
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

