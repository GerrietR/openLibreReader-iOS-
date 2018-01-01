//
//  WatchScatterPlotImage.swift
//  openLibreWatch Extension
//
//  Created by Gerriet Reents on 23.12.17.
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

import Foundation
import UIKit

/**
 *  A scatter plot image generator provides a chart image without `QuartzCore.framework` and `UIView`.
 Based on YOChartImageKit (https://github.com/yasuoza/YOChartImageKit)
 */
class WatchScatterPlotImage: NSObject {
    /** @name scatter plot rendering properties */
    /**
     *  The array of values for the line chart. `values` is a dictionary of x axis values and y axis values
     *  with individual colors for each point
     *  You must provide `values`, otherwise raises an exception.
     */
    
    var values = [Double:(y: Float, color: UIColor?)]()
    
    /**
     *
     */
    var limits = [(limit: Float, color: UIColor)]()
    var guides = [Double]()
    
    /**
     *  The maximum value to use for the chart. Setting this will override the
     *  default behavior of using the highest value as maxValue.
     */
    var maxValue: Float = 250.0
    var minValue: Float = 20.0

    /**
     *  The width of chart's stroke.
     *  The default width is `1.0`.
     */
    var strokeWidth: CGFloat = 1.0
    /**
     *  The color of chart's stroke.
     *  The default color is whiteColor.
     */
    var strokeDefaultColor: UIColor = UIColor.white

    /**
     *  The color of chart's area.
     *  The default color is `nil`.
     */
    var fillColor: UIColor = UIColor.black

    func draw(_ frame: CGRect, scale: CGFloat) -> UIImage {
        assert(values.count > 0, "no values assigned")
        
        let sortedValues = values.sorted(by: {$0.key < $1.key})
        
        let minX = sortedValues.first!.key
        let spanX = CGFloat(sortedValues.last!.key - minX)
        
        var points = [(point: CGPoint, color: CGColor)]()
        for point in sortedValues
        {
            let ratioY: CGFloat = CGFloat(max(min((Float(point.value.y) - minValue) / (maxValue - minValue), 1),0))
            let ratioX: CGFloat = CGFloat(point.key-minX) / CGFloat(spanX)
            let pointValue = CGPoint(x: (frame.size.width - strokeWidth) * ratioX, y: frame.size.height * (1 - ratioY) );
            points.append((pointValue, (point.value.color ?? strokeDefaultColor).cgColor))
        }
        UIGraphicsBeginImageContextWithOptions(frame.size, true , scale)
        var context = UIGraphicsGetCurrentContext()
    
        
        context?.setFillColor(fillColor.cgColor)
        context?.setStrokeColor(strokeDefaultColor.cgColor)
        context?.setLineDash(phase: 0, lengths: [2,3])
        for guide in guides
        {
            let xPosition = (frame.size.width - strokeWidth) * CGFloat( (guide - minX)) / spanX
            context?.setStrokeColor(UIColor.white.cgColor)
            context?.addLines(between: [CGPoint(x: xPosition + strokeWidth/2, y: 0),
                                        CGPoint(x: xPosition + strokeWidth/2, y: frame.width)])
            context?.drawPath(using: CGPathDrawingMode.fillStroke)
        }
        context?.setLineDash(phase: 0, lengths: [])
        
        for point in points
        {
            context?.setStrokeColor(point.color)
            context?.setFillColor(point.color)
            context?.addEllipse(in: CGRect(origin: point.point, size: CGSize(width: strokeWidth, height: strokeWidth) ))
            context?.drawPath(using: CGPathDrawingMode.fillStroke)
        }
        
        for limit in limits
        {
            let yPosition = frame.size.height - (frame.size.height * CGFloat( (limit.limit - minValue) / (maxValue - minValue)))
            context?.setStrokeColor(limit.color.cgColor)
            context?.addLines(between: [CGPoint(x: 0, y: yPosition), CGPoint(x: frame.width, y: yPosition)])
            context?.drawPath(using: CGPathDrawingMode.fillStroke)
        }

        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }
}
