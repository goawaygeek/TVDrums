//
//  InstrumentEmitter.swift
//  DrumMachine
//
//  Created by Scott Brewer on 5/14/20.
//  Copyright © 2020 Scott Brewer. All rights reserved.
//

import UIKit

// creates CAEmitterLayer for drum triggering onscreen animation
public class InstrumentEmitter {
    var emitterLayer : CAEmitterLayer = CAEmitterLayer()
    
    public func createDrumEmitterLayerWith (color: CGColor, location: CGPoint) -> CAEmitterLayer {
        
        emitterLayer.emitterPosition = location
        
        let cell = CAEmitterCell()
        cell.birthRate = 25
        cell.lifetime = 1
        cell.lifetimeRange = 0
        cell.velocity = 1
        cell.alphaRange = 0.2
        cell.alphaSpeed = -1
        cell.scale = 0.3
        cell.scaleRange = 0.2
        cell.scaleSpeed = -0.4
        cell.emissionRange = CGFloat.pi * 2.0
        cell.emissionLatitude = 0.0
        cell.emissionLongitude = 0.0
        
        cell.color = UIColor.white.cgColor
        cell.redRange = 1.0
        cell.greenRange = 1.0
        cell.blueRange = 1.0
        cell.alphaRange = 0.0
        cell.redSpeed = 0.0
        cell.greenSpeed = 0.0
        cell.blueSpeed = 0.0
        cell.alphaSpeed = -0.5
        
        //cell.color = color
        
        cell.contents = UIImage(named: "radial_gradient.png")!.cgImage
        
        emitterLayer.emitterCells = [cell]
        
        return emitterLayer
    }
    
    
}
