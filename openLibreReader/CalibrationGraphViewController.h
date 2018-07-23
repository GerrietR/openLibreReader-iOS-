//
//  CalibrationGraphViewController.h
//  openLibreReader
//
//  Created by Gerriet Reents on 24.06.18.
//  Copyright © 2018 Sandra Keßler. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol DataTransferDelegate
-(void) updateRegression: (double)slope intercept:(double)intercept;
-(NSString*) getSlope;
-(NSString*) getIntercept;
@end

@interface CalibrationGraphViewController : UIViewController
@property (nonatomic, weak) id<DataTransferDelegate> parentView;
@end

