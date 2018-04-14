//
//  CalibrationListViewController.m
//  openLibreReader
//
//  Created by Gerriet Reents on 21.01.18.
//  Copyright © 2018 Sandra Keßler. All rights reserved.
//

#import "Configuration.h"
#import "CalibrationListViewController.h"
#import "Storage.h"
#import "calibrationValue.h"
#import "SimpleLinearRegressionCalibration.h"

@interface CalibrationListViewController ()
    @property (weak) IBOutlet UITableView* table;
    @property NSMutableArray *calibrations;
@end

@implementation CalibrationListViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // todo: this should a model service
    _calibrations = [[NSMutableArray alloc] initWithArray:[[Storage instance]  calibrationFrom:[[NSDate distantPast] timeIntervalSince1970]  to:[[NSDate date] timeIntervalSince1970]]];
    
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table View Data source
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:
(NSInteger)section {
    return [_calibrations count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:
(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"calibrationCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:
                             cellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc]initWithStyle:
                UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    calibrationValue* value = [_calibrations objectAtIndex:indexPath.row];
    NSDate *today = [NSDate dateWithTimeIntervalSince1970:value.timestamp];
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateStyle:NSDateFormatterShortStyle];
    [dateFormat setTimeStyle:NSDateFormatterShortStyle];
    NSString *dateString = [dateFormat stringFromDate:today];
    
    Configuration *conf = [Configuration instance];
    NSString *stringForCell = [NSString stringWithFormat:@"%@: BG %@, Sensor %@", dateString,
                               [conf valueWithUnit:[value referenceValue]],
                               [conf valueWithUnit:[value value]]]; // TODO localization
    [cell.textLabel setText:stringForCell];
    cell.textLabel.adjustsFontSizeToFitWidth=YES;
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        //remove the deleted object from your data source.
        //If your data source is an NSMutableArray, do this
        calibrationValue* val = [_calibrations objectAtIndex:indexPath.row];
        SimpleLinearRegressionCalibration* c = [SimpleLinearRegressionCalibration instance];
        [c deleteCalibration:[val timestamp]];
        [_calibrations removeObjectAtIndex:indexPath.row];
        [tableView reloadData]; // tell table to refresh now
    }
}

@end
