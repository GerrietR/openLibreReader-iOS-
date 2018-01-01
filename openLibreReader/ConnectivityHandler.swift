//
//  ConnectivityHandler.swift
//  openLibreReader
//
//  Created by Gerriet Reents on 22.12.17.
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

import Foundation
import WatchConnectivity

@objc
class ConnectivityHandler : NSObject, WCSessionDelegate {
    
    var session = WCSession.default
    
    override init() {
        super.init()
        
        session.delegate = self
        session.activate()
        
        NSLog("%@", "Paired Watch: \(session.isPaired), Watch App Installed: \(session.isWatchAppInstalled)")
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        NSLog("%@", "activationDidCompleteWith activationState:\(activationState) error:\(error)")
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        NSLog("%@", "sessionDidBecomeInactive: \(session)")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        NSLog("%@", "sessionDidDeactivate: \(session)")
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        NSLog("%@", "sessionWatchStateDidChange: \(session)")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        NSLog("didReceiveMessage: %@", message)
    }

    @objc
    public func sendDictionary(dict: [String: Any]) -> Void {
        do {
            try self.session.updateApplicationContext(dict)
        } catch {
            print("Error sending dictionary \(dict) to Apple Watch!")
        }
    }
}
