//
//  SecondViewController.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "blueReaderDeviceViewController.h"
#import "Configuration.h"
#import "Storage.h"
#import "batteryValue.h"
#import "BluetoothDevice.h"
@import Charts;

@interface blueReaderDeviceViewController () <ChartViewDelegate,IChartAxisValueFormatter>
    @property (nonatomic, strong) IBOutlet LineChartView *chartView;
    @property (nonatomic, strong) NSMutableArray* data;
    @property (nonatomic, strong) NSMutableArray* dataColors;
    @property (nonatomic, strong) IBOutlet UILabel* info;
    @property (nonatomic, strong) IBOutlet UITextField* minutes;
    @property (weak) CBCharacteristic* tx;
    @property (weak) CBCharacteristic* rx;
@end

@implementation blueReaderDeviceViewController

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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceDiscovered:) name:BLUETOOTH_DEVICE_DISCOVERED_SERVICE_CHARACTERISTICS object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataRecieved:) name:BLUETOOTH_DEVICE_CHARACTERISTIC_CHANGED object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) deviceDiscovered:(NSNotification*) notification {
    if([[[notification object] objectForKey:@"peripheral"] isEqual:[((BluetoothDevice*)[[Configuration instance] device]) device]]) {
        CBService* service = [[notification object] objectForKey:@"service"];
        if([service.UUID.UUIDString isEqualToString:BLUETOOTH_SERVICE_NORDIC_UART]) {
            for(CBCharacteristic* chara in service.characteristics) {
                if([chara.UUID.UUIDString isEqualToString:BLUETOOTH_SERVICE_NORDIC_UART_TX]) {
                    //[self.device setNotifyValue:YES forCharacteristic:chara];
                    _tx = chara;
                    [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_SEND_DATA
                                                                        object:@{
                                                                                 @"data":[@"IDN" dataUsingEncoding:NSUTF8StringEncoding],
                                                                                 @"characteristic":_tx}];
                } else if([chara.UUID.UUIDString isEqualToString:BLUETOOTH_SERVICE_NORDIC_UART_RX]) {
                    //[self.device setNotifyValue:YES forCharacteristic:chara];
                    _rx = chara;
                }
            }
        }
    }
}

-(void)viewWillAppear:(BOOL)animated {
    NSDictionary* deviceData = [[Storage instance] deviceData];
    int interval = [[deviceData objectForKey:@"interval"] intValue];
    if(interval==0) interval = 5;
    _minutes.text = [NSString stringWithFormat:@"%d",interval];
    [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_DISCOVER_DEVICE object:[((BluetoothDevice*)[[Configuration instance] device]) device]];
}

-(void)viewDidDisappear:(BOOL)animated {
    for(int i = 0; i < 100; i++) {
        [[self.view viewWithTag:i] resignFirstResponder];
    }

    [[Configuration instance] reloadNSUploadService];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [textField selectAll:nil];
}

-(BOOL)textFieldShouldReturn:(UITextField*)textField {
    [textField resignFirstResponder];
    return NO;
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    return YES;
}
-(IBAction)done:(id)sender {
    if(sender == _minutes) {
        NSMutableDictionary* deviceData = [[Storage instance] deviceData];
        int interval = [_minutes.text intValue];
        [deviceData setObject:[NSNumber numberWithInt:interval] forKey:@"interval"];
        [[Storage instance] saveDeviceData:deviceData];
    }
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
        dispatch_async(dispatch_get_main_queue(), ^{
            [_chartView.data notifyDataChanged];
            [_chartView notifyDataSetChanged];
        });
    }
}

-(NSString *)stringForValue:(double)value axis:(ChartAxisBase *)axis {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterNoStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    dateFormatter.timeZone = [NSTimeZone defaultTimeZone];

    return [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:value]];
}

/*-(IBAction)resetConfiguration:(id)sender {
    [[Configuration instance] resetConfiguration:nil];
    [[self tabBarController] setSelectedIndex:0];
}*/

-(IBAction)resetConfiguration:(id)sender {

    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Remove Device",@"blueReader.title") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel",@"blueReader.cancel") style:UIAlertActionStyleDefault handler:nil];

    UIAlertAction* remove = [UIAlertAction actionWithTitle:NSLocalizedString(@"Remove Device",@"blueReader.remove") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[Storage instance] setSelectedDeviceClass:nil];
        [self.navigationController popViewControllerAnimated:YES];
        [self.navigationController.tabBarController setSelectedIndex:0];
        [[NSNotificationCenter defaultCenter] postNotificationName:kConfigurationReloadNotification object:nil];
    }];
    [alert addAction:cancel];
    [alert addAction:remove];
    [self presentViewController:alert animated:YES completion:nil];
}

-(IBAction)shutdownDevice:(id)sender {

    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Shutdown Device",@"blueReader.titleShutdown") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel",@"blueReader.cancel") style:UIAlertActionStyleDefault handler:nil];

    UIAlertAction* remove = [UIAlertAction actionWithTitle:NSLocalizedString(@"Shutdown Device",@"blueReader.shutdown") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        if(_tx) {
            [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_SEND_DATA
                                                                object:@{
                                                                         @"data":[@"k" dataUsingEncoding:NSUTF8StringEncoding],
                                                                         @"characteristic":_tx}];
        }
    }];
    [alert addAction:cancel];
    [alert addAction:remove];
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)dataRecieved:(NSNotification*)notification {
    if([[((BluetoothDevice*)[[Configuration instance] device]) device] isEqual:[notification.object objectForKey:@"peripheral"]]) {
        if([[[notification object] objectForKey:@"characteristic"] isEqual:_rx]) {
            NSData* data = ((CBCharacteristic*)[[notification object] objectForKey:@"characteristic"]).value;
            NSString* s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if([s hasPrefix:@"IDR"]) {
                s = [s stringByReplacingOccurrencesOfString:@"IDR" withString:@""];
                NSArray* c = [s componentsSeparatedByString:@"|"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_info setText:[NSString stringWithFormat:NSLocalizedString(@"Firmware: %@\nProtocol: %@",@"firmware text"),[c objectAtIndex:1],[c objectAtIndex:0]]];
                });
                [[NSNotificationCenter defaultCenter] removeObserver:self name:BLUETOOTH_DEVICE_DISCOVERED_SERVICE_CHARACTERISTICS object:nil];
                [[NSNotificationCenter defaultCenter] removeObserver:self name:BLUETOOTH_DEVICE_CHARACTERISTIC_CHANGED object:nil];
            }
        }
    }
}
@end
