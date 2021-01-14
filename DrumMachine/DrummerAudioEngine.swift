//
//  DrummerAudioEngine.swift
//  DrumMachine
//
//  Created by Scott Brewer on 5/14/20.
//  Copyright © 2020 Scott Brewer. All rights reserved.
//

import AVFoundation

private struct drumDetails {
    var playerNode: AVAudioPlayerNode = AVAudioPlayerNode()
    var bufferNode: AVAudioPCMBuffer = AVAudioPCMBuffer()
}

public class DrummerAudioEngine {
    private var audioEngine: AVAudioEngine = AVAudioEngine()
    
    // used for headphones
    private var environmentalNode : AVAudioEnvironmentNode = AVAudioEnvironmentNode()
    
    private var drumkit : [PercussionType: drumDetails] = [PercussionType: drumDetails]()
    
    public init() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Set the audio session category, mode, and options.
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setPreferredIOBufferDuration(0.002)
        } catch {
            fatalError("Failed to set audio session category.")
        }
        
        // use one mixer and multiple positions attached to the players
        let mainMixer =  audioEngine.mainMixerNode
        
        audioEngine.attach(environmentalNode)
        environmentalNode.listenerPosition = AVAudioMake3DPoint(0.0, 0.0, 0.0)
        let format =  AVAudioFormat(standardFormatWithSampleRate: audioEngine.outputNode.outputFormat(forBus: 0).sampleRate, channels: 2)
        environmentalNode.renderingAlgorithm = .HRTF
        audioEngine.connect(environmentalNode, to: mainMixer, format: format)
    }
    
    public func loadKit(percussiveInstruments: [PercussiveInstrument]) {
        
        for i in 0..<percussiveInstruments.count {
            let percussiveInstrument = percussiveInstruments[i]
            let fileURL: URL = URL(fileURLWithPath: percussiveInstrument.samplePath)
            
            guard let audioFile = try? AVAudioFile(forReading: fileURL) else{ return }
            
            let audioFormat = audioFile.processingFormat
            let audioFrameCount = UInt32(audioFile.length)
            
            let audioBuffer = (AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount)!)
            
            do{
                try audioFile.read(into: audioBuffer)
            } catch{
                // TODO: update the error message
                print("failed")
            }
            
            // create a player
            let audioPlayerNode = (AVAudioPlayerNode())
            //audioPlayerNodes[i].position = drumPositions[i]
            audioEngine.attach(audioPlayerNode)
            audioEngine.connect(audioPlayerNode, to:environmentalNode, format: audioBuffer.format)
            
            // attach the playernode and buffer to the drumkit dictionary
            drumkit[percussiveInstrument.type] = drumDetails(playerNode: audioPlayerNode, bufferNode: audioBuffer)
            
        }
        //print(drumkit)
    }
        
        
    public func startEngine() {
        // start the engine
        try? audioEngine.start()
        // TODO: check for errors
        
    }
    
    public func drumTrigger(percussiveInstrument: PercussiveInstrument) {
        
        // stop the player
        drumkit[percussiveInstrument.type]!.playerNode.stop()
        
        // schedule the buffer
        drumkit[percussiveInstrument.type]?.playerNode.scheduleBuffer(drumkit[percussiveInstrument.type]!.bufferNode, at: nil, options: .interrupts, completionHandler: nil)
        
        // position the drum if headphones are on
        // drumkit[percussiveInstrument.type]?.playerNode.position = percussiveInstrument.location
        
        // play the buffer
        drumkit[percussiveInstrument.type]!.playerNode.play()

    }
    
}
