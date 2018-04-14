//
//  SecondViewController.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "limitterDeviceViewController.h"
#import "Configuration.h"
#import "Storage.h"
#import "batteryValue.h"
@import Charts;

@interface limitterDeviceViewController () <ChartViewDelegate,IChartAxisValueFormatter>
    @property (nonatomic, strong) IBOutlet LineChartView *chartView;
    @property (nonatomic, strong) NSMutableArray* data;
    @property (nonatomic, strong) NSMutableArray* dataColors;
    @property (nonatomic, strong) IBOutlet UILabel* info;
@end

@implementation limitterDeviceViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    _chartView.delegate = self;

    _chartView.chartDescription.enabled = NO;

    _chartView.dragEnabled = YES;
    [_chartView setHighlightPerTapEnabled:NO];
    [_chartView setHighlightPerDragEnabled:NO];
    _chartView.scaleEnabled = YES;
    _chartView.pinchZoomEnabled = YES;
    _chartView.drawGridBackgroundEnabled = NO;
    _chartView.xAxis.valueFormatter = self;

    _chartView.noDataText=NSLocalizedString(@"No Values available",@"chart: no Values");
    _chartView.noDataTextColor=[UIColor whiteColor];

    // x-axis limit line
    ChartLimitLine *llXAxis = [[ChartLimitLine alloc] initWithLimit:10.0 label:@"Index 10"];
    llXAxis.lineWidth = 4.0;
    llXAxis.lineDashLengths = @[@(10.f), @(10.f), @(0.f)];
    llXAxis.labelPosition = ChartLimitLabelPositionRightBottom;
    llXAxis.valueFont = [UIFont systemFontOfSize:10.f];

    _chartView.xAxis.gridLineDashLengths = @[@10.0, @10.0];
    _chartView.xAxis.gridLineDashPhase = 0.f;

    ChartLimitLine *ll1 = [[ChartLimitLine alloc] initWithLimit:[[Configuration instance].device batteryFullValue] label:NSLocalizedString(@"FullBat",@"chart: FullBat")];
    ll1.lineWidth = 2.0;
    ll1.lineDashLengths = @[@5.f, @5.f];
    ll1.labelPosition = ChartLimitLabelPositionRightTop;
    ll1.valueFont = [UIFont systemFontOfSize:10.0];
    ll1.lineColor=UIColor.greenColor;

    ChartLimitLine *ll2 = [[ChartLimitLine alloc] initWithLimit:[[Configuration instance].device batteryLowValue] label:NSLocalizedString(@"LowBat",@"chart: LowBat")];
    ll2.lineWidth = 2.0;
    ll2.lineDashLengths = @[@5.f, @5.f];
    ll2.labelPosition = ChartLimitLabelPositionRightBottom;
    ll2.valueFont = [UIFont systemFontOfSize:10.0];
    ll2.lineColor = UIColor.redColor;

    ChartYAxis *leftAxis = _chartView.leftAxis;
    [leftAxis removeAllLimitLines];
    [leftAxis addLimitLine:ll1];
    [leftAxis addLimitLine:ll2];
    leftAxis.axisMaximum = [[Configuration instance].device batteryMaxValue];
    leftAxis.axisMinimum = [[Configuration instance].device batteryMinValue];
    leftAxis.gridLineDashLengths = @[@5.f, @5.f];
    leftAxis.drawZeroLineEnabled = NO;
    leftAxis.drawLimitLinesBehindDataEnabled = YES;

    _chartView.rightAxis.enabled = NO;

    _chartView.legend.form = ChartLegendFormNone;

    LineChartDataSet *set1 = nil;
    _data = [NSMutableArray array];
    _dataColors = [NSMutableArray array];
    
    for(batteryValue* value in [[Storage instance]batteryValuesFrom:[[NSDate date]timeIntervalSince1970]-(30*24*60*60) to:[[NSDate date]timeIntervalSince1970]]) {
        ChartDataEntry* entry = [[ChartDataEntry alloc] initWithX:[value timestamp] y:[value raw]];
        [_data addObject:entry];
        if([value raw] < [[Configuration instance].device batteryLowValue]) {
            [_dataColors addObject:[UIColor redColor]];
        } else if([value raw] < [[Configuration instance].device batteryFullValue]) {
            [_dataColors addObject:[UIColor orangeColor]];
        } else {
            [_dataColors addObject:[UIColor greenColor]];
        }
    }

    bgRawValue* bg = [[Storage instance] lastRawBgBefore:[NSDate date].timeIntervalSince1970];
    if([[bg.rawSource lowercaseString] isEqualToString:@"limitter"] || [[bg.rawSource lowercaseString] isEqualToString:@"transmitter"])
    {
        NSString* string = [[NSString alloc] initWithData:bg.rawData encoding:NSUTF8StringEncoding];
        NSArray* dat = [string componentsSeparatedByString:@" "];
        if([dat count] == 4) {
            int minutes = [[dat objectAtIndex:3] intValue];
            int hours = minutes / 60;
            int days = hours / 24;
            hours -= days*24;
            minutes -= (days*24*60) + (hours*60);
            _info.text = [NSString stringWithFormat:NSLocalizedString(@"Sensor running for %d days, %d hours and %d minutes", @"limitter.sensorage"),days,hours,minutes];
        } else {
            _info.text = NSLocalizedString(@"No Sensorage found", @"limitter.nosensorage");
        }
    }
    set1 = [[LineChartDataSet alloc] initWithValues:_data label:nil];
    set1.lineWidth = 0.0;
    set1.drawIconsEnabled = NO;
    set1.circleRadius = 3.0;
    set1.circleColors = _dataColors;
    set1.drawCircleHoleEnabled = NO;
    set1.drawFilledEnabled = NO;
    set1.valueFont = [UIFont systemFontOfSize:9.f];
    set1.drawValuesEnabled=NO;

    NSMutableArray *dataSets = [[NSMutableArray alloc] init];
    [dataSets addObject:set1];

    LineChartData *data = [[LineChartData alloc] initWithDataSets:dataSets];

    _chartView.data = data;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(recieved:) name:kDeviceBatteryValueNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewWillAppear:(BOOL)animated {
}

-(void)viewDidDisappear:(BOOL)animated {
    [[Configuration instance] reloadNSUploadService];
}

-(void)recieved:(NSNotification*)notification {
    batteryValue* data = [notification object];

    ChartDataEntry* entry = [[ChartDataEntry alloc] initWithX:[data timestamp] y:[data raw]];
    [_data addObject:entry];
    if([data raw] < [[Configuration instance].device batteryLowValue]) {
        [_dataColors addObject:[UIColor redColor]];
    } else if([data raw] < [[Configuration instance].device batteryFullValue]) {
        [_dataColors addObject:[UIColor orangeColor]];
    } else {
        [_dataColors addObject:[UIColor greenColor]];
    }

    LineChartDataSet *set1 = nil;
    if (_chartView.data.dataSetCount > 0) {
        int r = 0;
        for(ChartDataEntry* e in _data) {
            if(e.x < [[NSDate date]timeIntervalSince1970]-(30*24*60*60)) {
                r++;
            } else if(e.x >= [[NSDate date]timeIntervalSince1970]-(30*24*60*60)) {
                break;
            }
        }
        while(r>0) {
            [_data removeObjectAtIndex:0];
            [_dataColors removeObjectAtIndex:0];
            r--;
        }

        set1 = (LineChartDataSet *)_chartView.data.dataSets[0];
        set1.values = _data;
        set1.circleColors = _dataColors;
        [_chartView.data notifyDataChanged];
        [_chartView notifyDataSetChanged];
    }
    bgRawValue* bg = [[Storage instance] lastRawBgBefore:[NSDate date].timeIntervalSince1970];
    if([[bg.rawSource lowercaseString] isEqualToString:@"limitter"] || [[bg.rawSource lowercaseString] isEqualToString:@"transmitter"])
    {
        NSString* string = [[NSString alloc] initWithData:bg.rawData encoding:NSUTF8StringEncoding];
        NSArray* dat = [string componentsSeparatedByString:@" "];
        if([dat count] == 4) {
            int minutes = [[dat objectAtIndex:3] intValue];
            int hours = minutes / 60;
            int days = hours / 24;
            hours -= days*24;
            minutes -= (days*24) + (hours*60);
            _info.text = [NSString stringWithFormat:NSLocalizedString(@"Sensor running for %d days, %d hours and %d minutes", @"limitter.sensorage"),days,hours,minutes];
        } else {
            _info.text = NSLocalizedString(@"No Sensorage found", @"limitter.nosensorage");
        }
    }
}

-(NSString *)stringForValue:(double)value axis:(ChartAxisBase *)axis {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterNoStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    dateFormatter.timeZone = [NSTimeZone defaultTimeZone];

    return [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:value]];
}

-(IBAction)resetConfiguration:(id)sender {

    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Remove Device",@"limitter.title") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel",@"limitter.cancel") style:UIAlertActionStyleDefault handler:nil];

    UIAlertAction* remove = [UIAlertAction actionWithTitle:NSLocalizedString(@"Remove Device",@"limitter.remove") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[Storage instance] setSelectedDeviceClass:nil];
        [self.navigationController popViewControllerAnimated:YES];
        [self.navigationController.tabBarController setSelectedIndex:0];
        [[NSNotificationCenter defaultCenter] postNotificationName:kConfigurationReloadNotification object:nil];
    }];
    [alert addAction:cancel];
    [alert addAction:remove];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
