//
//  CalibrationGraphViewController.m
//  openLibreReader
//
//  Created by Gerriet Reents on 24.06.18.
//  Copyright © 2018 Sandra Keßler. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CalibrationGraphViewController.h"
#import "SimpleLinearRegressionCalibration.h"
#import "SimpleLinearRegressionViewController.h"
#import "Storage.h"
#import "calibrationValue.h"
#import "Configuration.h"
#import "bgValue.h"

@import Charts;

@interface CalibrationGraphViewController () <ChartViewDelegate, IChartAxisValueFormatter>
@property (nonatomic, strong) IBOutlet LineChartView *graph;
@property (strong, nonatomic) IBOutlet UIButton *reset;
@property (strong, nonatomic) IBOutlet UILabel *quality;
@property (strong, nonatomic) IBOutlet UITextField *slope;
//@property (nonatomic, strong) NSMutableArray* data;
//@property (nonatomic, strong) NSMutableArray* dataColors;
@property (strong, nonatomic) IBOutlet UIStepper *slopeStepper;
@property (strong, nonatomic) IBOutlet UITextField *intercept;
@property (strong, nonatomic) IBOutlet UIStepper *interceptStepper;
@property (nonatomic, strong) NSMutableArray* regressionLine;

@end

@interface CalibrationValueFormatter : NSObject <IChartValueFormatter>
@end

@implementation CalibrationValueFormatter

- (NSString * _Nonnull)stringForValue:(double)value entry:(ChartDataEntry * _Nonnull)entry dataSetIndex:(NSInteger)dataSetIndex viewPortHandler:(ChartViewPortHandler * _Nullable)viewPortHandler {
    calibrationValue* calibration = [entry data];
    NSTimeInterval now = [[NSDate date]timeIntervalSince1970];
    NSTimeInterval age = (double)(now - (double)[calibration timestamp]) / (double)(24*60*60);
    return [NSString stringWithFormat:@"%.1f",age];
}
@end

@implementation CalibrationGraphViewController


/// Called when a value (from labels inside the chart) is formatted before being drawn.
///
/// For performance reasons, avoid excessive calculations and memory allocations inside this method.
///
/// - returns: The formatted label ready for being drawn
///
/// - parameter value:           The value to be formatted
///
/// - parameter axis:            The entry the value belongs to - in e.g. BarChart, this is of class BarEntry
///
/// - parameter dataSetIndex:    The index of the DataSet the entry in focus belongs to
///
/// - parameter viewPortHandler: provides information about the current chart state (scale, translation, ...)
///
/*
-(NSString *)stringForValue:(double)value entry:(ChartDataEntry *)entry dataSetIndex:(NSInteger)dataSetIndex viewPortHandler:(ChartViewPortHandler *)viewPortHandler{
    return [NSString stringWithFormat:@"1"];
}
*/

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _graph.delegate = self;
    
//    [_graph setHighlightPerTapEnabled:NO];
//    [_graph setHighlightPerDragEnabled:NO];
    _graph.scaleEnabled = YES;
    _graph.pinchZoomEnabled = YES;
    _graph.dragEnabled = YES;
    _graph.drawGridBackgroundEnabled = NO;
    _graph.xAxis.valueFormatter = self;
    
    _graph.noDataText=NSLocalizedString(@"No Calibrations available",@"calchart: no Calibration");
    _graph.noDataTextColor=[UIColor whiteColor];
    
    // x-axis limit line
    ChartLimitLine *llXAxis = [[ChartLimitLine alloc] initWithLimit:10.0 label:@"Index 10"];
    llXAxis.lineWidth = 4.0;
    llXAxis.lineDashLengths = @[@(10.f), @(10.f), @(0.f)];
    llXAxis.labelPosition = ChartLimitLabelPositionRightBottom;
    llXAxis.valueFont = [UIFont systemFontOfSize:10.f];
    llXAxis.valueTextColor =[UIColor whiteColor];
    
    //[_chartView.xAxis addLimitLine:llXAxis];
    
    _graph.xAxis.gridLineDashLengths = @[@10.0, @10.0];
    _graph.xAxis.gridLineDashPhase = 0.f;
    _graph.xAxis.labelTextColor = [UIColor whiteColor];
    
    _graph.rightAxis.enabled = NO;
    _graph.legend.form = ChartLegendFormNone;
    _reset.layer.cornerRadius = 4;
}

-(void)viewDidDisappear:(BOOL)animated {
    double currentSlope =[[_slope.text stringByReplacingOccurrencesOfString:@"," withString:@"."] doubleValue];
    double currentIntercept = [[_intercept.text stringByReplacingOccurrencesOfString:@"," withString:@"."] doubleValue];
    [_parentView updateRegression:currentSlope intercept:currentIntercept];
}

-(void)updateUI {
    SimpleLinearRegressionCalibration* c = [SimpleLinearRegressionCalibration instance];
    
    double currentSlope =[[_slope.text stringByReplacingOccurrencesOfString:@"," withString:@"."] doubleValue];
    double currentIntercept = [[_intercept.text stringByReplacingOccurrencesOfString:@"," withString:@"."] doubleValue];
    double qual = [c qualityOfLinearRegression:currentSlope intercept:currentIntercept ];
    _quality.text = [NSString stringWithFormat:@"%.2f", qual];
    
    double lowValue = 30.0;
    ChartDataEntry* lowEntry = [[ChartDataEntry alloc] initWithX:lowValue y:currentIntercept + currentSlope * lowValue];
    [_regressionLine  replaceObjectAtIndex:0 withObject:lowEntry];
    
    double highValue = 350.0;
    ChartDataEntry* highEntry = [[ChartDataEntry alloc] initWithX:highValue y:currentIntercept + currentSlope * highValue];
    [_regressionLine replaceObjectAtIndex:1 withObject:highEntry];
    
    LineChartDataSet* line_set = (LineChartDataSet *)_graph.data.dataSets[1];
    line_set.values = _regressionLine;
    [_graph.data notifyDataChanged];
    [_graph notifyDataSetChanged];
}

NSInteger calibrationSort(calibrationValue* value1, calibrationValue* value2, void *reverse)
{
    if (reverse != NULL && *(BOOL *)reverse == YES) {
        return [[NSNumber numberWithInt:[value2 value]] compare:[NSNumber numberWithInt:[value1 value]]];
    }
    return [[NSNumber numberWithInt:[value1 value]] compare:[NSNumber numberWithInt:[value2 value]]];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    Configuration* c = [Configuration instance];
    ChartYAxis *leftAxis = _graph.leftAxis;
    leftAxis.axisMaximum = 400.0;
    leftAxis.axisMinimum = 0.0;
    leftAxis.gridLineDashLengths = @[@5.f, @5.f];
    leftAxis.drawZeroLineEnabled = NO;
    leftAxis.drawLimitLinesBehindDataEnabled = YES;
    leftAxis.labelTextColor = [UIColor whiteColor];
    leftAxis.valueFormatter=self;
    
    ChartXAxis *xAxis = _graph.xAxis;
    xAxis.axisMaximum = 400.0;
    xAxis.axisMinimum = 0.0;
    xAxis.gridLineDashLengths = @[@5.f, @5.f];
    xAxis.drawLimitLinesBehindDataEnabled = YES;
    xAxis.labelTextColor = [UIColor whiteColor];
    xAxis.valueFormatter=self;
    
    LineChartDataSet *set1 = nil;
    NSMutableArray* dataColors = [NSMutableArray array];
    
    SimpleLinearRegressionCalibration* calibration = [SimpleLinearRegressionCalibration instance];
    
    NSMutableArray* calibrationPoints = [NSMutableArray array];
    
    NSArray* calibrations = [calibration getCalibrations];
    NSArray* sortedCalibrations = [calibrations sortedArrayUsingFunction:calibrationSort context:NULL];
    NSTimeInterval now = [[NSDate date]timeIntervalSince1970];

    for(calibrationValue* value in sortedCalibrations) {
        ChartDataEntry* entry = [[ChartDataEntry alloc] initWithX:[value value] y:[value referenceValue] data:value];
        [calibrationPoints addObject:entry];

        if (now - [value timestamp] > 14*24*60*60 )
        {
            [dataColors addObject:[UIColor colorWithRed:0.5  green:0.5  blue:0.5 alpha:1.0]];
        } else {
            NSTimeInterval age = now - [value timestamp];
            double blue = ((double)(14*24*60*60) -(double)(age)) / (double)(14*24*60*60) * 0.5 + 0.5;
            [dataColors addObject:[UIColor colorWithRed:0.5  green:0.5  blue:blue alpha:1.0]];
        }
    }
    
    set1 = [[LineChartDataSet alloc] initWithValues:calibrationPoints label:NSLocalizedString(@"Calibrations",@"calchart: calibrations")];
    [set1 setCircleColors:dataColors];
    
    [set1 setColor:UIColor.lightGrayColor];
    set1.lineWidth = 0.0;
    set1.circleRadius = 4.0;
    set1.drawCircleHoleEnabled = NO;
    set1.drawValuesEnabled = YES;
    set1.valueFont = [UIFont systemFontOfSize:9.f];
    set1.valueTextColor = [UIColor whiteColor];
    set1.valueFormatter = [[CalibrationValueFormatter alloc] init];
  
    set1.formLineWidth = 4.0;
    set1.formSize = 15.0;
    set1.drawFilledEnabled = NO;
    
    LineChartDataSet *set2 = nil;
    _regressionLine = [NSMutableArray array];
    
    double lowValue = 30.0;
    ChartDataEntry* lowEntry = [[ChartDataEntry alloc] initWithX:lowValue y:[calibration getIntercept] + [calibration getSlope] * lowValue];
    [_regressionLine addObject:lowEntry];
    
    double highValue = 350.0;
    ChartDataEntry* highEntry = [[ChartDataEntry alloc] initWithX:highValue y:[calibration getIntercept] + [calibration getSlope] * highValue];
    [_regressionLine addObject:highEntry];
    
    set2 = [[LineChartDataSet alloc] initWithValues:_regressionLine label:NSLocalizedString(@"Regression Line",@"calchart: regression")];
    
    [set2 setColor:UIColor.darkGrayColor];
    [set2 setCircleColor:UIColor.darkGrayColor];
    set2.lineWidth = 4.0;
    set2.circleRadius = 2.0;
    set2.drawCircleHoleEnabled = NO;
    set2.drawValuesEnabled = NO;
    set2.formLineWidth = 4.0;
    set2.formSize = 15.0;
    set2.drawFilledEnabled = NO;
    
    NSMutableArray *dataSets = [[NSMutableArray alloc] init];
    [dataSets addObject:set1];
    [dataSets addObject:set2];
    
    LineChartData *data = [[LineChartData alloc] initWithDataSets:dataSets];
    
    _graph.data = data;
    _graph.backgroundColor = UIColor.blackColor;
    
    _slope.text = _parentView.getSlope;
    _intercept.text = _parentView.getIntercept;
    double currentSlope=[[_slope.text stringByReplacingOccurrencesOfString:@"," withString:@"."] doubleValue];
    double currentIntercept=[[_intercept.text stringByReplacingOccurrencesOfString:@"," withString:@"."] doubleValue];
    [self newRegression:currentIntercept currentSlope:currentSlope];

    [self updateUI];
}


- (IBAction)changeSlope:(id)sender {
    double currentSlope = _slopeStepper.value;
    _slope.text = [NSString stringWithFormat:@"%.2lf", currentSlope] ;
    [self updateUI];
}

- (IBAction)changeIntercept:(id)sender {
    double currentIntercept = _interceptStepper.value;
    _intercept.text = [NSString stringWithFormat:@"%.2lf", currentIntercept] ;
    [self updateUI];
}

- (void)newRegression:(double)currentIntercept currentSlope:(double)currentSlope {
    _slope.text = [NSString stringWithFormat:@"%.2lf", currentSlope] ;
    _intercept.text = [NSString stringWithFormat:@"%.2lf", currentIntercept] ;
    _slopeStepper.value = currentSlope;
    _interceptStepper.value = currentIntercept;
}

- (IBAction)calculateRegression:(id)sender {
    double currentSlope;
    double currentIntercept;
    SimpleLinearRegressionCalibration* cal = [SimpleLinearRegressionCalibration instance];
    [cal linearRegression:&currentSlope intercept:&currentIntercept];
    
    [self newRegression:currentIntercept currentSlope:currentSlope];
    [self updateUI];
}

-(NSString *)stringForValue:(double)value axis:(ChartAxisBase *)axis {
    if(axis == _graph.leftAxis) {
        return [[Configuration instance] valueWithoutUnit:value];
    } else {
        return [[Configuration instance] valueWithoutUnit:value];
    }
}
@end
