//
//  FirstViewController.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "HomeViewController.h"
#import "blueReader.h"
#import "Configuration.h"
#import "Storage.h"
#import "bgValue.h"
#import "batteryValue.h"
#import "Alarms.h"
#import "AboutViewController.h"

@import Charts;

@interface HomeViewController () <ChartViewDelegate,IChartAxisValueFormatter>
    @property (nonatomic, strong) IBOutlet LineChartView *chartView;
    @property (nonatomic, strong) IBOutlet UILabel* statusLabel;
    @property (nonatomic, strong) IBOutlet UILabel* lastTime;
    @property (nonatomic, strong) IBOutlet UILabel* drift;
    @property (nonatomic, strong) IBOutlet UILabel* currentBG;
    @property (nonatomic, strong) IBOutlet UILabel* direction;
    @property (nonatomic, strong) IBOutlet UIButton* connectDevice;
    @property (nonatomic, strong) IBOutlet UIImageView* batteryStatus;
    @property (nonatomic, strong) IBOutlet UIButton* alarms;
    @property (nonatomic, strong) IBOutlet UIButton* value;

    @property (nonatomic, strong) NSMutableArray* data;
    @property (nonatomic, strong) NSMutableArray* dataColors;
    @property NSTimeInterval first;
    @property (strong) NSTimer* updater;
    @property (strong) NSTimer* reader;
@end

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _statusLabel.text=nil;

    [self setNeedsStatusBarAppearanceUpdate];

    _chartView.delegate = self;

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
    llXAxis.valueTextColor =[UIColor whiteColor];

    //[_chartView.xAxis addLimitLine:llXAxis];

    _chartView.xAxis.gridLineDashLengths = @[@10.0, @10.0];
    _chartView.xAxis.gridLineDashPhase = 0.f;
    _chartView.xAxis.labelTextColor = [UIColor whiteColor];

    _chartView.rightAxis.enabled = NO;
    _chartView.legend.form = ChartLegendFormNone;
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    Configuration* c = [Configuration instance];
    int lower = [c lowerBGLimit];
    int upper = [c upperBGLimit];
    int low = [c lowBGLimit];
    int high = [c highBGLimit];
    
    ChartLimitLine *ll1 = [[ChartLimitLine alloc] initWithLimit:high label:NSLocalizedString(@"High",@"chart: high value")];
    ll1.lineWidth = 2.0;
    ll1.lineDashLengths = @[@5.f, @5.f];
    ll1.labelPosition = ChartLimitLabelPositionRightTop;
    ll1.valueFont = [UIFont systemFontOfSize:10.0];
    ll1.valueTextColor = [UIColor whiteColor];

    ChartLimitLine *ll2 = [[ChartLimitLine alloc] initWithLimit:upper label:NSLocalizedString(@"Above Target",@"chart: above target")];
    ll2.lineWidth = 2.0;
    ll2.lineDashLengths = @[@5.f, @5.f];
    ll2.labelPosition = ChartLimitLabelPositionRightTop;
    ll2.valueFont = [UIFont systemFontOfSize:10.0];
    ll2.valueTextColor = [UIColor whiteColor];
    ll2.lineColor = UIColor.yellowColor;

    ChartLimitLine *ll3 = [[ChartLimitLine alloc] initWithLimit:lower label:NSLocalizedString(@"Below Target",@"chart: below target")];
    ll3.lineWidth = 2.0;
    ll3.lineDashLengths = @[@5.f, @5.f];
    ll3.labelPosition = ChartLimitLabelPositionRightTop;
    ll3.valueFont = [UIFont systemFontOfSize:10.0];
    ll3.valueTextColor = [UIColor whiteColor];
    ll3.lineColor = UIColor.yellowColor;

    ChartLimitLine *ll4 = [[ChartLimitLine alloc] initWithLimit:low label:NSLocalizedString(@"Low",@"chart: low")];
    ll4.lineWidth = 2.0;
    ll4.lineDashLengths = @[@5.f, @5.f];
    ll4.labelPosition = ChartLimitLabelPositionRightBottom;
    ll4.valueFont = [UIFont systemFontOfSize:10.0];
    ll4.valueTextColor = [UIColor whiteColor];

    ChartYAxis *leftAxis = _chartView.leftAxis;
    [leftAxis removeAllLimitLines];
    [leftAxis addLimitLine:ll1];
    [leftAxis addLimitLine:ll2];
    [leftAxis addLimitLine:ll3];
    [leftAxis addLimitLine:ll4];

    leftAxis.axisMaximum = 400.0;
    leftAxis.axisMinimum = 20.0;
    leftAxis.gridLineDashLengths = @[@5.f, @5.f];
    leftAxis.drawZeroLineEnabled = NO;
    leftAxis.drawLimitLinesBehindDataEnabled = YES;
    leftAxis.labelTextColor = [UIColor whiteColor];

    leftAxis.valueFormatter=self;
    
    LineChartDataSet *set1 = nil;
    _data = [NSMutableArray array];
    _dataColors = [NSMutableArray array];

    double min = low-30;
    double max = high+50;

    for(bgValue* value in [[Storage instance] bgValuesFrom:[[NSDate date]timeIntervalSince1970]-(8*60*60) to:[[NSDate date]timeIntervalSince1970]]) {
        ChartDataEntry* entry = [[ChartDataEntry alloc] initWithX:[value timestamp] y:[value value]];
        [_data addObject:entry];

        if([value value] < low) {
            [_dataColors addObject:[UIColor redColor]];
            if(min+30 > [value value])
                min = [value value]-30;
        } else if([value value] < lower) {
            [_dataColors addObject:[UIColor yellowColor]];
        } else if([value value] > high) {
            [_dataColors addObject:[UIColor redColor]];
            if(max-50 < [value value])
                max = [value value]+50;
        } else if([value value] > upper) {
            [_dataColors addObject:[UIColor yellowColor]];
        } else {
            [_dataColors addObject:[UIColor greenColor]];
        }
    }

    _chartView.leftAxis.axisMaximum = max;
    _chartView.leftAxis.axisMinimum = min;

    set1 = [[LineChartDataSet alloc] initWithValues:_data label:nil];
    [set1 setCircleColors:_dataColors];

    set1.drawIconsEnabled = NO;

    set1.lineDashLengths = @[@5.f, @2.5f];
    set1.highlightLineDashLengths = @[@5.f, @2.5f];
    [set1 setColor:UIColor.lightGrayColor];
    [set1 setColor:UIColor.whiteColor];
    [set1 setCircleColor:UIColor.greenColor];
    set1.lineWidth = 0.0;//1.0;
    set1.circleRadius = 2.0;
    set1.drawCircleHoleEnabled = NO;
    set1.drawValuesEnabled = NO;
    set1.valueFont = [UIFont systemFontOfSize:9.f];
    set1.valueTextColor = [UIColor whiteColor];

    set1.formLineDashLengths = @[@5.f, @2.5f];
    set1.formLineWidth = 1.0;
    set1.formSize = 15.0;
    set1.drawFilledEnabled = NO;

    _chartView.xAxis.axisMinimum = [[NSDate date]timeIntervalSince1970]-(8*60*60);
    _chartView.xAxis.axisMaximum = [[NSDate date]timeIntervalSince1970];

    NSMutableArray *dataSets = [[NSMutableArray alloc] init];
    [dataSets addObject:set1];

    LineChartData *data = [[LineChartData alloc] initWithDataSets:dataSets];

    _chartView.data = data;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(recieved:) name:kCalibrationBGValue object:nil];

    if(![[Storage instance] agreed]) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];

        UIViewController* vc = [storyboard instantiateViewControllerWithIdentifier:@"About"];
        ((AboutViewController*)vc).hideOnAgree = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentViewController:vc animated:YES completion:nil];
        });
        return;
    }

    if([[[Configuration instance] neededConfigurationSteps] count] > 0) {
        //complete configuration
       dispatch_async(dispatch_get_main_queue(), ^{
           [self performSegueWithIdentifier:@"showConfiguration" sender:self];
       });
    }

    _drift.text = [NSString stringWithFormat:@"-- %@",[[Configuration instance] displayUnit]];
    _currentBG.text = @"---";
    _direction.text = @"";

    _updater = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timer:) userInfo:nil repeats:YES];
    //FIXME if device support battery
    _batteryStatus.image = nil;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(recievedBattery:) name:kDeviceBatteryValueNotification object:nil];

    [self updateUI];


    if([c.device needsConnection]) {
        _connectDevice.hidden = NO;
    } else {
        if(c.device.lastDeviceStatus.status != DEVICE_CONNECTING && c.device.lastDeviceStatus.status != DEVICE_CONNECTED) {
            [c.device reload];
        }
        _connectDevice.hidden = YES;
    }

    if([[[Configuration instance] device] canForceValue]) {
        if([[NSDate date] timeIntervalSince1970]-[[Storage instance] lastBGValue] > 55.0)
        {
            [_value setHidden:NO];
        } else {
            [_value setHidden:YES];
        }
    } else {
        [_value setHidden:YES];
    }
}

-(void) timer:(NSTimer*)timer {
    NSTimeInterval l = [[Storage instance] lastBGValue];
    if(l==0) {
        _lastTime.text = NSLocalizedString(@"no Data recieved",@"chart: no Data");
    } else {
        NSTimeInterval d = [[NSDate new]timeIntervalSince1970]-l;
        int s = 0;
        if(d>60) {
            //Secoonds->minutes
            s++;
            d/=60;
            if(d>60) {
                //minutes->hours
                s++;
                d/=60;
                if(d>24) {
                    //hours->days
                    s++;
                    d/=24;
                }
            }
        }
        NSString* sufix = d>=2?NSLocalizedString(@"seconds",@"last reading seconds"):NSLocalizedString(@"second",@"last reading second");
        switch(s) {
            case 1:
                sufix = d>=2?NSLocalizedString(@"minutes",@"last reading minutes"):NSLocalizedString(@"minute",@"last reading minute");
                break;
            case 2:
                sufix = d>=2?NSLocalizedString(@"hours",@"last reading hours"):NSLocalizedString(@"hour",@"last reading hour");
                break;
            case 3:
                sufix = d>=2?NSLocalizedString(@"days",@"last reading days"):NSLocalizedString(@"day",@"last reading day");
                break;
        }
        _lastTime.text = [NSString stringWithFormat:NSLocalizedString(@"%d %@ ago",@"last reading"),((int)d),sufix];
    }
    switch([[Alarms instance] getState])
    {
        case kAlarmRunning:
            [_alarms setImage:[UIImage imageNamed:@"alarm-red"] forState:UIControlStateNormal];
            break;
        case kAlarmEnabled:
            [_alarms setImage:[UIImage imageNamed:@"alarm-white"] forState:UIControlStateNormal];
            break;
        case kAlarmDisabled:
            [_alarms setImage:[UIImage imageNamed:@"alarm-no"] forState:UIControlStateNormal];
            break;
    }
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceStatus:) name:kDeviceStatusNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceRequestStatusNotification object:nil];
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_updater invalidate];
}

-(IBAction)connectDevice:(id)sender {
    UIViewController* gvc = [[Configuration instance].device.class configurationViewController];
    if(gvc) {
        UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:gvc];
        [self presentViewController:nav animated:YES completion:nil];
    }
}

-(IBAction)alarmButton:(id)sender {
    switch([[Alarms instance] getState])
    {
        case kAlarmRunning:
            //FIXME showing last one would be nice
            [[Alarms instance] cancelDelivered];
            break;
        case kAlarmEnabled: {
            UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Disable Alarms",@"alarmalert.title") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
            UIAlertAction* thirty = [UIAlertAction actionWithTitle:NSLocalizedString(@"30 minutes",@"alarmalert.title") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [[Alarms instance]  disable:(30*60)];
            }];
            UIAlertAction* one = [UIAlertAction actionWithTitle:NSLocalizedString(@"1 hour",@"alarmalert.title") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [[Alarms instance] disable:(60*60)];
            }];
            UIAlertAction* two = [UIAlertAction actionWithTitle:NSLocalizedString(@"2 hours",@"alarmalert.title") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [[Alarms instance] disable:(120*60)];
            }];
            UIAlertAction* until = [UIAlertAction actionWithTitle:NSLocalizedString(@"until re-enable",@"alarmalert.title") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [[Alarms instance] disable:(-1)];
            }];

            UIAlertAction* cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",@"alarmalert.title") style:UIAlertActionStyleDestructive handler:nil];
            [alert addAction:thirty];
            [alert addAction:one];
            [alert addAction:two];
            [alert addAction:until];
            [alert addAction:cancel];
            [self presentViewController:alert animated:YES completion:nil];
        } break;
        case kAlarmDisabled:
            [[Alarms instance] disable:(NO)];
            break;
    }
}

-(IBAction) readButton:(id)sender {
    [[[Configuration instance] device] forceValue];
    [_value setHidden:YES];
}
-(UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleLightContent;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)chartValueSelected:(ChartViewBase * __nonnull)chartView entry:(ChartDataEntry * __nonnull)entry highlight:(ChartHighlight * __nonnull)highlight {
}

- (void)chartValueNothingSelected:(ChartViewBase * __nonnull)chartView {
}

-(void)recievedBattery:(NSNotification*)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        batteryValue* data = [notification object];

        if(data.raw < [[Configuration instance].device batteryLowValue]) {
            _batteryStatus.image = [UIImage imageNamed:@"battery-red"];
        } else if(data.raw < [[Configuration instance].device batteryFullValue]) {
            _batteryStatus.image = [UIImage imageNamed:@"battery-yellow"];
        } else {
            _batteryStatus.image = [UIImage imageNamed:@"battery-green"];
        }
    });
}

-(void)deviceStatus:(NSNotification*)notification
{
    DeviceStatus* ds = [notification object];
    if(ds) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _statusLabel.text = ds.statusText;
            if(ds.status == NO_DEVICE)
            {
                [self connectDevice:nil];
            } else if(ds.status != DEVICE_CONNECTED && ds.status != DEVICE_OK && ds.status!=DEVICE_ERROR) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.connectDevice.hidden = NO;
                });
            } else if(ds.status==DEVICE_ERROR) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if([[[Configuration instance] device] canForceValue]) {
                        [_value setHidden:NO];
                    } else {
                        [_value setHidden:YES];
                    }
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.connectDevice.hidden = YES;
                });
            }
        });
    }
}

-(void)recieved:(NSNotification*)notification {
    bgValue* data = [notification object];

    Configuration* c = [Configuration instance];
    int lower = [c lowerBGLimit];
    int upper = [c upperBGLimit];
    int low = [c lowBGLimit];
    int high = [c highBGLimit];

    double min = low-30;
    double max = high+50;

    ChartDataEntry* entry = [[ChartDataEntry alloc] initWithX:[data timestamp] y:[data value]];
    //FIXME insert at correct point.x!
    [_data addObject:entry];

    if([data value] < low) {
        [_dataColors addObject:[UIColor redColor]];
        if(min+30 > [data value])
            min = [data value]-30;
    } else if([data value] < lower) {
        [_dataColors addObject:[UIColor yellowColor]];
    } else if([data value] > high) {
        [_dataColors addObject:[UIColor redColor]];
        if(max-50 < [data value])
            max = [data value]+50;
    } else if([data value] > upper) {
        [_dataColors addObject:[UIColor yellowColor]];
    } else {
        [_dataColors addObject:[UIColor greenColor]];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateUI];//:data];
        [_value setHidden:YES];
        if(_reader) {
            [_reader invalidate];
            _reader = nil;
        }
        _reader = [NSTimer scheduledTimerWithTimeInterval:55.0 target:self selector:@selector(readEnable:) userInfo:nil repeats:NO];
    });
}

-(void) readEnable:(NSTimer*)timer {
    _reader = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        if([[[Configuration instance] device] canForceValue]) {
            [_value setHidden:NO];
        } else {
            [_value setHidden:YES];
        }
    });
}

-(void) updateUI {//}:(bgValue*)lastData {
    unsigned long count = [_data count];
    Configuration* c = [Configuration instance];

    if(count>0) {
        ChartDataEntry* last = [_data lastObject];
        _currentBG.text = [[Configuration instance] valueWithoutUnit:[last y]];

        if(count>1) {
            ChartDataEntry* prelast = [_data objectAtIndex:[_data indexOfObject:last]-1];
            double t = [last x]-[prelast x];
            double d = [last y]-[prelast y];
            t/=60;
            double deltamin = d/t;
            if(t>15) {
                _drift.text = @"---";
                _direction.text = @"";
            } else {
                _drift.text = [NSString stringWithFormat:@"%@ %@",(d>=0?@"+":@""),[c valueWithUnit:d]];
                _direction.text = [HomeViewController slopeToArrowSymbol:deltamin];
            }
        } else {
            _drift.text = [NSString stringWithFormat:@"-- %@",[c displayUnit]];
            _direction.text = @"";
        }

    } else {
        _drift.text = [NSString stringWithFormat:@"-- %@",[c displayUnit]];
        _direction.text = @"";
    }

    int low = [c lowBGLimit];
    int high = [c highBGLimit];

    double min = low-30;
    double max = high+50;

    LineChartDataSet *set1 = nil;
    if (_chartView.data.dataSetCount > 0) {
        int r = 0;
        for(ChartDataEntry* e in _data) {
            if(e.x < [[NSDate date]timeIntervalSince1970]-(8*60*60)) {
                r++;
            } else if(e.x >= [[NSDate date]timeIntervalSince1970]-(8*60*60)) {
                min = MIN(min,e.y-30);
                max = MAX(max,e.y+50);
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

        _chartView.leftAxis.axisMaximum = max;
        _chartView.leftAxis.axisMinimum = min;

        _chartView.xAxis.axisMinimum = [[NSDate date]timeIntervalSince1970]-(8*60*60);
        _chartView.xAxis.axisMaximum = [[NSDate date]timeIntervalSince1970];
    }
}
/**
 * adopted from https://github.com/dabear/FloatingGlucose/blob/b5c001504f84501a81c52c465dae8fa210bab655/FloatingGlucose/Classes/Utils/GlucoseMath.cs#L36
 */
+(NSString*) slopeToArrowSymbol:(double) slope {
    if (slope <= (-3.5)) {
        return @"\u21ca";// ⇊
    } else if (slope <= (-2)) {
        return @"\u2193"; // ↓
    } else if (slope <= (-1)) {
        return @"\u2198"; // ↘
    } else if (slope <= (1)) {
        return @"\u2192"; // →
    } else if (slope <= (2)) {
        return @"\u2197"; // ↗
    } else if (slope <= (3.5)) {
        return @"\u2191"; // ↑
    } else {
        return @"\u21c8"; // ⇈
    }
}

-(NSString *)stringForValue:(double)value axis:(ChartAxisBase *)axis {
    if(axis == _chartView.leftAxis) {
        return [[Configuration instance] valueWithoutUnit:value];
    } else {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateStyle = NSDateFormatterNoStyle;
        dateFormatter.timeStyle = NSDateFormatterShortStyle;
        dateFormatter.timeZone = [NSTimeZone defaultTimeZone];

        return [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:value]];
    }
}


@end
