/*
This file was modified from source in Apple's CoreBluetoothLESample project

 Copyright © 2020 Apple Inc.

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Abstract:
A class to advertise, send notifications and receive data from central looking for transfer service and characteristic.
*/

import CoreBluetooth
import AVFoundation

// CoreBluetooth class to listen for and announce drum hits
class DrumPeripheral : NSObject, CBPeripheralManagerDelegate {
    
    var peripheralManager: CBPeripheralManager!
    
    var instrument: PercussiveInstrument!

    var transferCharacteristic: CBMutableCharacteristic?
    var connectedCentral: CBCentral?
    
    init(instrument: PercussiveInstrument) {
        super.init()
        self.instrument = instrument
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
    }
    
    deinit {
        peripheralManager.stopAdvertising()
    }
    
    public func toggleAdvertising (state: Bool) {
        if state {
            peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [PercussiveInstrument.serviceUUID]])
        } else {
            peripheralManager.stopAdvertising()
        }
    }
    
    private func setupPeripheral() {
        
        // Build our service.
        
        // Start with the CBMutableCharacteristic.
        let transferCharacteristic = CBMutableCharacteristic(type: instrument.characteristicUUID,
                                                         properties: [.notify, .writeWithoutResponse],
                                                         value: nil,
                                                         permissions: [.readable, .writeable])
        
        // Create a service from the characteristic.
        let transferService = CBMutableService(type: PercussiveInstrument.serviceUUID, primary: true)
        
        // Add the characteristic to the service.
        transferService.characteristics = [transferCharacteristic]
        
        // And add it to the peripheral manager.
        peripheralManager.add(transferService)
        
        // Save the characteristic for later.
        self.transferCharacteristic = transferCharacteristic
        
        toggleAdvertising(state: true)

    }
    
    public func isAdvertising() -> Bool {
        return peripheralManager.isAdvertising
    }
    
    // MARK: create send trigger function
    public func sendTrigger() {
        // if there isn't a connection don't send
        
        // sends BLE notification of drum tigger
        guard let transferCharacteristic = transferCharacteristic else {
            return
        }
        
        // change all of these to 'didTrigger'
        let didSend = peripheralManager.updateValue("HIT".data(using: .utf8)!, for: transferCharacteristic, onSubscribedCentrals: nil)
        // Did it send?
        if didSend {
            print("Sent: HIT")
        } else {
            print("send failed")
        }
        
    }
    
    internal func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
        //advertisingSwitch.isEnabled = peripheral.state == .poweredOn
        
        switch peripheral.state {
        case .poweredOn:
            // ... so start working with the peripheral
            print("CBManager is powered on")
            setupPeripheral()
        case .poweredOff:
            print("CBManager is not powered on")
            // In a real app, you'd deal with all the states accordingly
            return
        case .resetting:
            print("CBManager is resetting")
            // In a real app, you'd deal with all the states accordingly
            return
        case .unauthorized:
            // In a real app, you'd deal with all the states accordingly
            if #available(iOS 13.0, *) {
                switch peripheral.authorization {
                case .denied:
                    print("You are not authorized to use Bluetooth")
                case .restricted:
                    print("Bluetooth is restricted")
                default:
                    print("Unexpected authorization")
                }
            } else {
                // Fallback on earlier versions
            }
            return
        case .unknown:
            print("CBManager state is unknown")
            // In a real app, you'd deal with all the states accordingly
            return
        case .unsupported:
            print("Bluetooth is not supported on this device")
            // In a real app, you'd deal with all the states accordingly
            return
        @unknown default:
            print("A previously unknown peripheral manager state occurred")
            // In a real app, you'd deal with yet unknown cases that might occur in the future
            return
        }
    }
    
    internal func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Central subscribed to characteristic", characteristic)
        
        // save central
        connectedCentral = central
    }

}
