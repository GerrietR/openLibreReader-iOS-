//
//  InterfaceController.swift
//  openLibreWatch Extension
//
//  Created by Gerriet Reents on 16.12.17.
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

import WatchKit
import UIKit
import Foundation
import WatchConnectivity

class InterfaceController: WKInterfaceController, WCSessionDelegate{

    @IBOutlet var currentBG: WKInterfaceLabel!
    @IBOutlet var direction: WKInterfaceLabel!
    @IBOutlet var lastTime: WKInterfaceLabel!
    @IBOutlet var drift: WKInterfaceLabel!
    @IBOutlet var imageView: WKInterfaceImage!
    
    var session : WCSession?
    
    var lowerBGLimit: Float = 70
    var upperBGLimit: Float = 170
    var lowBGLimit: Float = 60
    var highBGLimit: Float = 200
    
    var connected: Bool = false
    
    var unit: String = "mgdl"
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        updateUI(data: [String: Any]())
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
        
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    func updateUI(data: [String : Any]) {
//        _batteryStatus.image = nil;
        
        drift.setText("--")
        direction.setText("?")
        currentBG.setText("---")
        lastTime.setText("????")

        if let newcurrentBG = data["currentBG"] as? String {
            currentBG.setText(newcurrentBG)
        }
        if let newdirection = data["direction"] as? String {
            direction.setText(newdirection)
        }
        if let newdrift = data["drift"] as? String {
            drift.setText(newdrift)
        }
        if let newlastTime = data["lastTime"] as? String {
            lastTime.setText(newlastTime)
        }
        
        if let newLowerBGLimit = data["lowerBGLimit"] as? String {
            lowerBGLimit = Float(newLowerBGLimit)!
        }
        if let newUpperBGLimit = data["upperBGLimit"] as? String {
            upperBGLimit = Float(newUpperBGLimit)!
        }
        if let newHighBGLimit = data["highBGLimit"] as? String {
            highBGLimit = Float(newHighBGLimit)!
        }
        if let newLowBGLimit = data["lowBGLimit"] as? String {
            lowBGLimit = Float(newLowBGLimit)!
        }
        if let newConnected = data["connected"] as? String {
            connected = Bool(newConnected)!
        }
        if let newUnit = data["unit"] as? String {
            unit = newUnit
        }
        
        if let valueIndex = data.index(forKey: "values")
        {
            let newValuesData = data[valueIndex]
            let newValues = newValuesData.value as! NSArray
            if newValues.count > 0
            {
                let chart = WatchScatterPlotImage()
                chart.values.removeAll(keepingCapacity: true)
                for arrayEntry in newValues
                {
                    let entry = arrayEntry as! Dictionary<String,AnyObject>
                    let bg = entry["value"] as! Float
                    var color = UIColor.green
                    if bg <= lowBGLimit || bg >= highBGLimit {
                        color = UIColor.red
                    }
                    else if bg <= lowerBGLimit || bg >= upperBGLimit {
                        color = UIColor.yellow
                    }
                    let timestamp = Double(entry["timestamp"] as! Double)
                    chart.values[timestamp] = (entry["value"] as! Float, color)
                }
                
                chart.limits.removeAll(keepingCapacity: true)
                chart.limits.append((lowBGLimit, UIColor.red))
                chart.limits.append((highBGLimit, UIColor.red))
                chart.limits.append((lowerBGLimit, UIColor.yellow))
                chart.limits.append((upperBGLimit, UIColor.yellow))
                
                let date = Date()
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour, .day , .month, .year ], from: date)
                var guide = calendar.date(from: components)
                chart.guides.append((guide?.timeIntervalSince1970)!)
                guide?.addTimeInterval(-60.0*60.0)
                chart.guides.append((guide?.timeIntervalSince1970)!)
                guide?.addTimeInterval(-60.0*60.0)
                chart.guides.append((guide?.timeIntervalSince1970)!)
                guide?.addTimeInterval(-60.0*60.0)
                chart.guides.append((guide?.timeIntervalSince1970)!)
                guide?.addTimeInterval(-60.0*60.0)
                chart.guides.append((guide?.timeIntervalSince1970)!)
                guide?.addTimeInterval(-60.0*60.0)
                chart.guides.append((guide?.timeIntervalSince1970)!)
                guide?.addTimeInterval(-60.0*60.0)
                chart.guides.append((guide?.timeIntervalSince1970)!)
                guide?.addTimeInterval(-60.0*60.0)
                chart.guides.append((guide?.timeIntervalSince1970)!)

                chart.strokeWidth = 2.0              // width of line
                chart.strokeDefaultColor = UIColor.cyan     // color of line
                
                let frame = CGRect(x: 0, y: 0, width: contentFrame.width, height: contentFrame.height)
                let image = chart.draw( frame, scale: WKInterfaceDevice.current().screenScale)
                self.imageView.setImage(image)
            }
        }
    
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        NSLog("%@", "activationDidCompleteWith activationState:\(activationState) error:\(error)")
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("watch received app context: ", applicationContext)
        updateUI(data: applicationContext)
    }
}
