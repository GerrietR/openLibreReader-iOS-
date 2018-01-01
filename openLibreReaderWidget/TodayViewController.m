//
//  TodayViewController.m
//  openLibreReaderWidget
//
//  Created by fishermen21 on 21.10.17.
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>
#import <MMWormhole/MMWormhole.h>
@import Charts;

@interface TodayViewController () <NCWidgetProviding,ChartViewDelegate,IChartAxisValueFormatter>
@property (nonatomic,strong) MMWormhole* wormhole;
@property (nonatomic, strong) IBOutlet LineChartView *chartView;
@property (nonatomic, strong) IBOutlet UILabel* statusLabel;
@property (nonatomic, strong) IBOutlet UILabel* lastTime;
@property (nonatomic, strong) IBOutlet UILabel* drift;
@property (nonatomic, strong) IBOutlet UILabel* currentBG;
@property (nonatomic, strong) IBOutlet UILabel* direction;
@property (nonatomic, strong) IBOutlet UIImageView* batteryStatus;
@property (nonatomic, strong) NSMutableArray* data;
@property (nonatomic, strong) NSMutableArray* dataColors;
@property (nonatomic, strong) LineChartDataSet *set1;
@property (nonatomic, strong) NSString* unit;
@end

@implementation TodayViewController

-(void)widgetActiveDisplayModeDidChange:(NCWidgetDisplayMode)activeDisplayMode withMaximumSize:(CGSize)maxSize
{
    if(activeDisplayMode == NCWidgetDisplayModeExpanded)
    {
        self.preferredContentSize = CGSizeMake( 0.0, 182.0);
    }
    else
    {
        self.preferredContentSize = maxSize;
    }
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:@"group.de.gerrietresents.openbluereader"
                                                         optionalDirectory:@"wormhole"];
    [self.wormhole listenForMessageWithIdentifier:@"currentData"
                                         listener:^(id messageObject) {
                                             [self updateUI];
                                         }];
    self.extensionContext.widgetLargestAvailableDisplayMode = NCWidgetDisplayModeExpanded;
    //self.preferredContentSize = CGSizeMake(self.view.frame.size.width, 182);

    _chartView.delegate = self;
    _chartView.dragEnabled = YES;
    [_chartView setHighlightPerTapEnabled:NO];
    [_chartView setHighlightPerDragEnabled:NO];
    _chartView.scaleEnabled = YES;
    _chartView.pinchZoomEnabled = YES;
    _chartView.drawGridBackgroundEnabled = NO;
    _chartView.xAxis.valueFormatter = self;

    _chartView.noDataText=NSLocalizedString(@"No Values available",@"chart: no Values");
    _chartView.noDataTextColor=[UIColor blackColor];

    // x-axis limit line
    ChartLimitLine *llXAxis = [[ChartLimitLine alloc] initWithLimit:10.0 label:@"Index 10"];
    llXAxis.lineWidth = 4.0;
    llXAxis.lineDashLengths = @[@(10.f), @(10.f), @(0.f)];
    llXAxis.labelPosition = ChartLimitLabelPositionRightBottom;
    llXAxis.valueFont = [UIFont systemFontOfSize:10.f];
    llXAxis.valueTextColor =[UIColor blackColor];

    //[_chartView.xAxis addLimitLine:llXAxis];

    _chartView.xAxis.gridLineDashLengths = @[@10.0, @10.0];
    _chartView.xAxis.gridLineDashPhase = 0.f;
    _chartView.xAxis.labelTextColor = [UIColor blackColor];

    _chartView.rightAxis.enabled = NO;
    [_chartView set_legend:nil];
    [_chartView setChartDescription:nil];

    _set1 = [[LineChartDataSet alloc] initWithValues:_data label:nil];
    _set1.drawIconsEnabled = NO;

    _set1.lineDashLengths = @[@5.f, @2.5f];
    _set1.highlightLineDashLengths = @[@5.f, @2.5f];
    [_set1 setColor:UIColor.blackColor];
    [_set1 setCircleColor:UIColor.greenColor];
    _set1.lineWidth = 0.0;//1.0;
    _set1.circleRadius = 2.0;
    _set1.drawCircleHoleEnabled = NO;
    _set1.drawValuesEnabled = NO;
    _set1.valueFont = [UIFont systemFontOfSize:9.f];
    _set1.valueTextColor = [UIColor blackColor];

    _set1.formLineDashLengths = @[@5.f, @2.5f];
    _set1.formLineWidth = 1.0;
    _set1.formSize = 15.0;
    _set1.drawFilledEnabled = NO;

    ChartYAxis *leftAxis = _chartView.leftAxis;
    leftAxis.gridLineDashLengths = @[@5.f, @5.f];
    leftAxis.drawZeroLineEnabled = NO;
    leftAxis.drawLimitLinesBehindDataEnabled = YES;
    leftAxis.labelTextColor = [UIColor blackColor];

    leftAxis.valueFormatter=self;

    NSMutableArray *dataSets = [[NSMutableArray alloc] init];
    [dataSets addObject:_set1];

    LineChartData *chartData = [[LineChartData alloc] initWithDataSets:dataSets];
    _chartView.data = chartData;

    [self updateUI];
}

-(void) updateUI {
    NSData* transferData = [self.wormhole messageWithIdentifier:@"currentData"];
    _batteryStatus.image = nil;
    _drift.text = [NSString stringWithFormat:@"--"];
    _direction.text = @"";
    _currentBG.text = @"---";
    _statusLabel.text = NSLocalizedString(@"noDataYet", @"noData recieved message");
    _lastTime.text = NSLocalizedString(@"noDataYet", @"noData recieved message");
    _data = [NSMutableArray array];
    _dataColors = [NSMutableArray array];

    if(!transferData) {
        NSMutableArray *dataSets = [[NSMutableArray alloc] init];
        [dataSets addObject:_set1];

        _chartView.data = nil;//chartData;

        [_chartView notifyDataSetChanged];
        return;
    }
    if(_chartView.data == nil) {
        NSMutableArray *dataSets = [[NSMutableArray alloc] init];
        [dataSets addObject:_set1];

        LineChartData *chartData = [[LineChartData alloc] initWithDataSets:dataSets];
        _chartView.data = chartData;
    }

    NSDictionary* data = [NSKeyedUnarchiver unarchiveObjectWithData:transferData];

    _unit =[data objectForKey:@"unit"];
    int lower = [[data objectForKey:@"lowerBGLimit"] intValue];
    int upper = [[data objectForKey:@"upperBGLimit"] intValue];
    int low = [[data objectForKey:@"lowBGLimit"] intValue];
    int high = [[data objectForKey:@"highBGLimit"] intValue];

    ChartLimitLine *ll1 = [[ChartLimitLine alloc] initWithLimit:high];
    ll1.lineWidth = 0.75;
    ll1.lineDashLengths = @[@5.f, @5.f];
    ll1.labelPosition = ChartLimitLabelPositionRightTop;
    ll1.valueFont = [UIFont systemFontOfSize:10.0];
    ll1.valueTextColor = [UIColor blackColor];

    ChartLimitLine *ll2 = [[ChartLimitLine alloc] initWithLimit:upper];
    ll2.lineWidth = 0.75;
    ll2.lineDashLengths = @[@5.f, @5.f];
    ll2.labelPosition = ChartLimitLabelPositionRightTop;
    ll2.valueFont = [UIFont systemFontOfSize:10.0];
    ll2.valueTextColor = [UIColor blackColor];
    ll2.lineColor = UIColor.yellowColor;

    ChartLimitLine *ll3 = [[ChartLimitLine alloc] initWithLimit:lower];
    ll3.lineWidth = 0.75;
    ll3.lineDashLengths = @[@5.f, @5.f];
    ll3.labelPosition = ChartLimitLabelPositionRightTop;
    ll3.valueFont = [UIFont systemFontOfSize:10.0];
    ll3.valueTextColor = [UIColor blackColor];
    ll3.lineColor = UIColor.yellowColor;

    ChartLimitLine *ll4 = [[ChartLimitLine alloc] initWithLimit:low];
    ll4.lineWidth = 0.75;
    ll4.lineDashLengths = @[@5.f, @5.f];
    ll4.labelPosition = ChartLimitLabelPositionRightBottom;
    ll4.valueFont = [UIFont systemFontOfSize:10.0];
    ll4.valueTextColor = [UIColor blackColor];

    ChartYAxis *leftAxis = _chartView.leftAxis;
    [leftAxis removeAllLimitLines];
    [leftAxis addLimitLine:ll1];
    [leftAxis addLimitLine:ll2];
    [leftAxis addLimitLine:ll3];
    [leftAxis addLimitLine:ll4];

    double min = low-30;
    double max = high+50;
    double minTime = 0;
    double maxTime = 0;

    [_data removeAllObjects];
    [_dataColors removeAllObjects];

    for(NSDictionary* value in [data objectForKey:@"values"]) {
        ChartDataEntry* entry = [[ChartDataEntry alloc] initWithX:[[value objectForKey:@"timestamp"] doubleValue] y:[[value objectForKey:@"value"] doubleValue]];
        [_data addObject:entry];

        if([[value objectForKey:@"value"] doubleValue] < low) {
            [_dataColors addObject:[UIColor redColor]];
            if(min+30 > [[value objectForKey:@"value"] doubleValue])
                min = [[value objectForKey:@"value"] doubleValue]-30;
        } else if([[value objectForKey:@"value"] doubleValue] < lower) {
            [_dataColors addObject:[UIColor yellowColor]];
        } else if([[value objectForKey:@"value"] doubleValue] > high) {
            [_dataColors addObject:[UIColor redColor]];
            if(max-50 < [[value objectForKey:@"value"] doubleValue])
                max = [[value objectForKey:@"value"] doubleValue]+50;
        } else if([[value objectForKey:@"value"] doubleValue] > upper) {
            [_dataColors addObject:[UIColor yellowColor]];
        } else {
            [_dataColors addObject:[UIColor greenColor]];
        }
        if(minTime == 0) minTime = [[value objectForKey:@"timestamp"] doubleValue];
        minTime = MIN(minTime, [[value objectForKey:@"timestamp"] doubleValue]);
        maxTime = MAX(maxTime, [[value objectForKey:@"timestamp"] doubleValue]);
    }

    _chartView.leftAxis.axisMaximum = max;
    _chartView.leftAxis.axisMinimum = min;

    _set1.values = _data;
    _set1.circleColors =_dataColors;

    _chartView.xAxis.axisMinimum = minTime;
    _chartView.xAxis.axisMaximum = maxTime;

    [_chartView.data notifyDataChanged];
    [_chartView notifyDataSetChanged];

    if([data objectForKey:@"battery"]) {
        _batteryStatus.image = [UIImage imageNamed:[data objectForKey:@"battery"]];
    }
    if([data objectForKey:@"drift"]) {
        _drift.text = [data objectForKey:@"drift"];
    }
    if([data objectForKey:@"direction"]) {
        _direction.text = [data objectForKey:@"direction"];
    }
    if([data objectForKey:@"currentBG"]) {
        _currentBG.text = [data objectForKey:@"currentBG"];
    }
    if([data objectForKey:@"lastTime"]) {
        _lastTime.text = [data objectForKey:@"lastTime"];
    }
    if([data objectForKey:@"status"]) {
        _statusLabel.text = [data objectForKey:@"status"];
    }


}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    // Perform any setup necessary in order to update the view.
    
    // If an error is encountered, use NCUpdateResultFailed
    // If there's no update required, use NCUpdateResultNoData
    // If there's an update, use NCUpdateResultNewData
    [self updateUI];
    completionHandler(NCUpdateResultNewData);
}

-(NSString *)stringForValue:(double)value axis:(ChartAxisBase *)axis {
    if(axis == _chartView.leftAxis) {
        if([[_unit lowercaseString] isEqualToString:@"mmol"]) {
            return [NSString stringWithFormat:@"%.1f",value];
        } else {
            return [NSString stringWithFormat:@"%.0f",value];
        }
    } else {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateStyle = NSDateFormatterNoStyle;
        dateFormatter.timeStyle = NSDateFormatterShortStyle;
        dateFormatter.timeZone = [NSTimeZone defaultTimeZone];

        return [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:value]];
    }
}

- (IBAction) goToApp: (id)sender {
    NSURL *url = [NSURL URLWithString:@"openlibrereader://home"];
    [self.extensionContext openURL:url completionHandler:nil];
}
@end
