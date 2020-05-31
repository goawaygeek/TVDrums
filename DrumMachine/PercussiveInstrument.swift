//
//  PercussiveInstrument.swift
//  DrumMachine
//
//  Created by Scott Brewer on 5/11/20.
//  Copyright © 2020 Scott Brewer. All rights reserved.
//

import Foundation
import CoreBluetooth
import AVFoundation

enum PercussionType : Hashable, CaseIterable { case hihat, crash, ride, snare, racktom, floortom, kick }

public struct PercussiveInstrument {
    static let serviceUUID = CBUUID(string: "3DD807AC-6B32-4848-8DFD-CF92B1926A85")
    
    // is this the best way this can be done?
    static let characteristicUUIDs = [
        CBUUID(string: "2288FC6A-9AB2-4853-AA93-138250725F43"),
        CBUUID(string: "75E78103-0866-43C0-9998-EF92490B13D8"),
        CBUUID(string: "6371647F-EC4C-4558-8B6C-87CB9B9A95A6"),
        CBUUID(string: "BDD93F3E-467B-4A9B-AB94-FE46C4409311"),
        CBUUID(string: "B56150C3-76BF-40E7-A3A5-90175C47AAD1"),
        CBUUID(string: "2F396A7C-2123-476C-8120-B6FDE67163DD"),
        CBUUID(string: "AAB15FE1-2968-40F6-BD38-6E7940796CB7")
    ]
    
    let type : PercussionType
    
    var characteristicUUID: CBUUID {
        switch self.type {
            // TODO: un-hack????
            case .hihat: return PercussiveInstrument.characteristicUUIDs[0]
            case .crash: return PercussiveInstrument.characteristicUUIDs[1]
            case .ride: return PercussiveInstrument.characteristicUUIDs[2]
            case .snare: return PercussiveInstrument.characteristicUUIDs[3]
            case .racktom: return PercussiveInstrument.characteristicUUIDs[4]
            case .floortom: return PercussiveInstrument.characteristicUUIDs[5]
            case .kick: return PercussiveInstrument.characteristicUUIDs[6]
        }
    }
    
    var samplePath: String {
        switch self.type {
            case .hihat: return Bundle.main.path(forResource: "ZDJN_HAT_C2FL_HT_015_01", ofType: "wav")!
            case .crash: return Bundle.main.path(forResource: "PSTE_CRSH_EGFL_HT_015_01", ofType: "wav")!
            case .ride: return Bundle.main.path(forResource: "PSTE_RIDE_EGFL_HT_01", ofType: "wav")!
            case .snare: return Bundle.main.path(forResource: "L400_SNR_DCFL_HT_01", ofType: "wav")!
            case .racktom: return Bundle.main.path(forResource: "RGRS_RTOM_CNFL_HT_01", ofType: "wav")!
            case .floortom: return Bundle.main.path(forResource: "RGRS_FTOM_CNFL_HT_01", ofType: "wav")!
            case .kick: return Bundle.main.path(forResource: "RGRS_KICK_HDFL_HT_01", ofType: "wav")!
        }
    }
    
    var location: AVAudio3DPoint {
        switch self.type {
            case .hihat: return AVAudioMake3DPoint(-0.5, 0.1, -0.25)
            case .crash: return AVAudioMake3DPoint(-0.3, 0.55, 0.1)
            case .ride: return AVAudioMake3DPoint(0.3, 0.55, 0.1)
            case .snare: return AVAudioMake3DPoint(-0.1, 0.15, -0.25)
            case .racktom: return AVAudioMake3DPoint(-0.2, 0.35, -0.75)
            case .floortom: return AVAudioMake3DPoint(0.25, 0.2, -0.25)
            case .kick: return AVAudioMake3DPoint(0.0, 0.2, -0.5)
        }
    }
    
    var description: String {
        switch self.type {
            case .hihat: return "Hi Hat"
            case .crash: return "Crash"
            case .ride: return "Ride"
            case .snare: return "Snare"
            case .racktom: return "Rack tom"
            case .floortom: return "Floor tom"
            case .kick: return "Kick"
        }
    }
}
