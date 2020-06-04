//
//  DrumMultipeer.swift
//  DrumMachine
//
//  Created by Scott Brewer on 6/4/20.
//  Copyright © 2020 Scott Brewer. All rights reserved.
//

import MultipeerConnectivity

enum MultipeerType {case sender, receiver }

protocol DrumMultipeerDelegate {
    func hitReceived(forPercussiveType: PercussionType)
}

class DrumMultipeer: NSObject, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, MCSessionDelegate, StreamDelegate {
    
    public var delegate: DrumMultipeerDelegate?
    
    let multipeertype = "kysor-drums"
    let receiverPeerID = MCPeerID(displayName: "drum-brain")
    let senderPeerID = MCPeerID(displayName: "drum")
    var serviceAdvertiser : MCNearbyServiceAdvertiser?
    var serviceBrowser : MCNearbyServiceBrowser?
    var outputStream:OutputStream?
    var inputStream:InputStream?
    
    var session : MCSession!
    
    let type : MultipeerType
    
    public init(asType: MultipeerType) {
        // under normal use cases you would name the devices uniquely, but we're using them in a client / server manner
        switch asType {
            case .sender: type = .sender
            case .receiver: type = .receiver
        }
        super.init()
        var peerID : MCPeerID
        if type == .sender {
            peerID = senderPeerID
            serviceAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: multipeertype)
            serviceAdvertiser?.delegate = self
            serviceAdvertiser?.startAdvertisingPeer()
        } else {
            peerID = receiverPeerID
            serviceBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: multipeertype)
            serviceBrowser?.delegate = self
            serviceBrowser?.startBrowsingForPeers()
            
        }
        
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
    }
    
    public func startAdvertising() {
        switch type {
        case .sender: serviceAdvertiser?.startAdvertisingPeer()
        case .receiver: serviceBrowser?.startBrowsingForPeers()
        }
    }
    
    public func stopAdvertising() {
        switch type {
        case .sender: serviceAdvertiser?.stopAdvertisingPeer()
        case .receiver: serviceBrowser?.stopBrowsingForPeers()
        }
    }
    
    private func connectStream() {
        if type == .sender {
            // cycle through connectedPeers
            for peer in session.connectedPeers {
                // only connect to drum-brains
                if peer.displayName == receiverPeerID.displayName {
                    do {
                        // open a stream
                        try outputStream = session.startStream(withName: "drum-stream", toPeer: peer)
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
        }
    }
    
    // we send the percussiveHit with a PercussionType that we convert
    // to it's int value and send as data.  We will need to convert it
    // back when it is received
    public func sendPercussiveHit(percussionType: PercussionType) {
        // double check that this is only being used on senders
        // TODO: check for and send errors
        if type == .sender && session.connectedPeers.count > 0 {
            let string = percussionType.rawValue.description
            if let output = outputStream {
                output.write(string, maxLength: string.utf8.count)
            }
        }
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // we have received an invition, in our instance we attempt
        // to connect with every invitation we receive
        NSLog("%@", "didReceiveInvitationFromPeer \(peerID)")
        invitationHandler(true, session)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // we want to invite all perrs to make a connection
        NSLog("%@", "foundPeer: \(peerID)")
        NSLog("%@", "invitePeer: \(peerID)")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("%@", "lostPeer: \(peerID)")
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        // in our circumstances we know that all connections will
        // result in a stream so attempt to open that stream here
        // once the connction succeeds
        switch state {
            case .notConnected: break
            case .connecting: break
            case .connected: connectStream()
            default: break
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        NSLog("%@", "didReceiveData: \(data) ")
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        NSLog("%@", "didReceiveStream")
        // initialise the stream
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
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        print("stream delegate called")
        switch(eventCode){
        case Stream.Event.hasBytesAvailable:
            let input = aStream as! InputStream
            var buffer = [UInt8](repeating: 0, count: 1024) //allocate a buffer. The size of the buffer will depended on the size of the data you are sending.
            let numberBytes = input.read(&buffer, maxLength:1024)
            let data = Data(bytes: &buffer, count: numberBytes)
            let dataString = String(decoding: data, as: UTF8.self)
            
            // let the delegate know you've received a hit
            // convert the string to an int
            let dataInt : Int = Int(dataString) ?? -1
            var success = false
            for type in PercussionType.allCases {
                if type.rawValue == dataInt {
                    self.delegate?.hitReceived(forPercussiveType: type)
                    success = true
                }
            }
            //let message = NSKeyedUnarchiver.unarchiveObject(with: dataString as Data) as! String //deserializing the NSData
            
            print("received message as stream\(dataString), sent succesfully: \(success)")
            
        //input
        case Stream.Event.hasSpaceAvailable:
            break
        //output
        default:
            break
        }
    }
    
}
