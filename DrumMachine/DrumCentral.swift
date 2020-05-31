/*
This file was modified from source in Apple's CoreBluetoothLESample project

 Copyright © 2020 Apple Inc.

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Abstract:
A class to discover, connect, receive notifications and write data to peripherals by using a transfer service and characteristic.
*/

//  DrumCentral.swift
//  DrumMachine

import Foundation

import CoreBluetooth
import AVFoundation


public protocol DrumCentralDelegate {
    func hitReceived(forUUID: CBUUID)
}

// CoreBluetooth class to listen for and announce drum hits
class DrumCentral : NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    public var delegate: DrumCentralDelegate?
    
    var centralManager: CBCentralManager!

    var transferCharacteristics: [CBCharacteristic]?
    
    var discoveredPeripherals: [CBPeripheral]! = [CBPeripheral]()
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }
    
    deinit {
        cleanup()
        centralManager.stopScan()
    }
    
    private func retrievePeripherals() {
        // scan for peripherals
        centralManager.scanForPeripherals(withServices: [PercussiveInstrument.serviceUUID],
                                               options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    
    /*
     *  Call this when things either go wrong, or you're done with the connection.
     *  This cancels any subscriptions if there are any, or straight disconnects if not.
     *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
     */
    private func cleanup() {
        // Don't do anything if we're not connected
        for peripheral in discoveredPeripherals {
            switch peripheral.state {
            case .connected:
                unsubscribeFrom(peripheral: peripheral)
            default:
                return
            }
            
            // If we've gotten this far, we're connected, but we're not subscribed, so we just disconnect
            centralManager.cancelPeripheralConnection(peripheral)
        }
        
    }
    
    private func unsubscribeFrom(peripheral: CBPeripheral) {
        for service in (peripheral.services ?? [] as [CBService]) {
            for characteristic in (service.characteristics ?? [] as [CBCharacteristic]) {
                // TODO: this was checking something else previously, it is probably a bug as it is currently written
                if characteristic.isNotifying {
                    // It is notifying, so unsubscribe
                    peripheral.setNotifyValue(false, for: characteristic)
                }
            }
        }
    }
    
    public func disconnect(peripheral: CBPeripheral) {
        if discoveredPeripherals.contains(peripheral) {
            for connectedperipheral in discoveredPeripherals {
                if peripheral == connectedperipheral && connectedperipheral.state == .connected {
                    unsubscribeFrom(peripheral: peripheral)
                }
                
                // If we've gotten this far, we're connected, but we're not subscribed, so we just disconnect
                centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    }

    // MARK: central code 
    /*
     *  centralManagerDidUpdateState is a required protocol method.
     *  Usually, you'd check for other states to make sure the current device supports LE, is powered on, etc.
     *  In this instance, we're just using it to wait for CBCentralManagerStatePoweredOn, which indicates
     *  the Central is ready to be used.
     */
    internal func centralManagerDidUpdateState(_ central: CBCentralManager) {

        switch central.state {
        case .poweredOn:
            // ... so start working with the peripheral
            print("CBManager is powered on")
            retrievePeripherals()
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
                switch central.authorization {
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
            print("A previously unknown central manager state occurred")
            // In a real app, you'd deal with yet unknown cases that might occur in the future
            return
        }
    }
    
    /*
     *  This callback comes whenever a peripheral that is advertising the transfer serviceUUID is discovered.
     *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
     *  we start the connection process
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        // Reject if the signal strength is too low to attempt data transfer.
        // Change the minimum RSSI value depending on your app’s use case.
        guard RSSI.intValue >= -100
            else {
                print("Discovered perhiperal not in expected range, at ", RSSI.intValue)
                return
        }
        
        print("Discovered ", String(describing: peripheral.name), " at ", RSSI.intValue)
        
        // Device is in range - have we already seen it?
        if !discoveredPeripherals.contains(peripheral) {
            
            // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it.
            discoveredPeripherals.append(peripheral)
            
            // And finally, connect to the peripheral.
            print("Connecting to perhiperal ", peripheral)
            centralManager.connect(peripheral, options: nil)
        }
    }

    /*
     *  If the connection fails for whatever reason, we need to deal with it.
     */
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to ", peripheral, " at ", String(describing: error))
        cleanup()
    }
    
    /*
     *  We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Peripheral Connected")
        
        /* I don't think we want to stop scanning here, we want to keep collecting peripherals
        // Stop scanning
        centralManager.stopScan()
        print("Scanning stopped")
         */
        
        // Make sure we get the discovery callbacks
        peripheral.delegate = self
        
        // Search only for services that match our UUID
        peripheral.discoverServices([PercussiveInstrument.serviceUUID])
    }
    
    /*
     *  Once the disconnection happens, we need to clean up our local copy of the peripheral
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Perhiperal Disconnected")
        if let index = discoveredPeripherals.firstIndex(of: peripheral) {
            discoveredPeripherals.remove(at: index)
        }
        
        // TODO: work out what this does
        /*
        // We're disconnected, so start scanning again
        if connectionIterationsComplete < defaultIterations {
            retrievePeripherals()
        } else {
            print("Connection iterations completed")
        }*/
    }
    
    // MARK: peripheral code
    /*
     *  The peripheral letting us know when services have been invalidated.
     */
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        
        for service in invalidatedServices where service.uuid == PercussiveInstrument.serviceUUID {
            print("Transfer service is invalidated - rediscover services")
            peripheral.discoverServices([PercussiveInstrument.serviceUUID])
        }
    }

    /*
     *  The Transfer Service was discovered
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: %s", error.localizedDescription)
            cleanup()
            return
        }
        
        // Discover the characteristic we want...
        
        // Loop through the newly filled peripheral.services array, just in case there's more than one.
        guard let peripheralServices = peripheral.services else { return }
        for service in peripheralServices {
            peripheral.discoverCharacteristics(PercussiveInstrument.characteristicUUIDs, for: service)
        }
    }
    
    /*
     *  The Transfer characteristic was discovered.
     *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Deal with errors (if any).
        if let error = error {
            print("Error discovering characteristics: %s", error.localizedDescription)
            cleanup()
            return
        }
        
        // Again, we loop through the array, just in case and check if it's the right one
        guard let serviceCharacteristics = service.characteristics else { return }
        for characteristic in serviceCharacteristics where PercussiveInstrument.characteristicUUIDs.contains(characteristic.uuid) {
            // If it is, subscribe to it
            transferCharacteristics?.append(characteristic)
            peripheral.setNotifyValue(true, for: characteristic)
        }
        
        // Once this is complete, we just need to wait for the data to come in.
    }
    
    
    /*
     *   This callback lets us know more data has arrived via notification on the characteristic
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Deal with errors (if any)
        if let error = error {
            print("Error discovering characteristics: %s", error.localizedDescription)
            cleanup()
            return
        }
        
        guard let characteristicData = characteristic.value,
            let stringFromData = String(data: characteristicData, encoding: .utf8) else { return }
        
        print("Received %d bytes: %s", characteristicData.count, stringFromData)
        
        // TODO: DON'T HARDCODE THIS!!!!!
        if stringFromData == "HIT" {
            // TODO:  notify the delegate to play the right audio track
            self.delegate?.hitReceived(forUUID: characteristic.uuid)
        }
    }

    /*
     *  The peripheral letting us know whether our subscribe/unsubscribe happened or not
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        // Deal with errors (if any)
        if let error = error {
            print("Error changing notification state: %s", error.localizedDescription)
            return
        }
        
        // Exit if it's not one of our transfer characteristics
        guard  PercussiveInstrument.characteristicUUIDs.contains(characteristic.uuid) else { return }
        
        if characteristic.isNotifying {
            // Notification has started
            print("Notification began on ", characteristic)
        } else {
            // Notification has stopped, so disconnect from the peripheral
            print("Notification stopped on ", characteristic, ". Disconnecting")
            cleanup()
        }
        
    }

}
