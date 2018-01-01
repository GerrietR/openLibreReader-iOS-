//
//  CalibrationViewController.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "ConfigurationListViewController.h"
#import "ConfigurationListTableViewCell.h"
#import "Configuration.h"
#import "Storage.h"

@interface ConfigurationListViewController ()
    @property (weak) IBOutlet UITableView* table;
    @property NSArray* configurables;
@end

@implementation ConfigurationListViewController

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _configurables = @[
                       @{@"title":NSLocalizedString(@"Display Unit", @"displayUnit.title"),
                         @"description":NSLocalizedString(@"Change the Unit for glucose Values",@"displayUnit.description"),
                         @"controller":@"units"
                         },
                       @{@"title":NSLocalizedString(@"Limit Values", @"limit.title"),
                         @"description":NSLocalizedString(@"Configure Values for high and Low Values",@"limit.description"),
                         @"controller":@"limits"
                         },
                       @{@"title":NSLocalizedString(@"Device", @"device.title"),
                         @"description":NSLocalizedString(@"Select and configure used Device",@"device.description"),
                         @"controller":@"device"
                         },
                       @{@"title":NSLocalizedString(@"Calibration", @"calibration.title"),
                         @"description":NSLocalizedString(@"Select and configure calibration method",@"calibration.description"),
                         @"controller":@"calibration"
                         },
                       @{@"title":NSLocalizedString(@"Alarms", @"alarms.title"),
                         @"description":NSLocalizedString(@"Configure Alarms",@"alarms.description"),
                         @"controller":@"alarms"
                         },
                       @{@"title":NSLocalizedString(@"Nightscout Uploader", @"nightscout.title"),
                         @"description":NSLocalizedString(@"Configure the NIghtscout Uploader to push bg data to a nightscout instance.\nNightscout following is configured in device.",@"nightscout.description"),
                         @"controller":@"nightscout"
                         },
                       @{@"title":NSLocalizedString(@"About", @"about.title"),
                         @"description":NSLocalizedString(@"About this app and Disclaimer.\n",@"about.description"),
                         @"controller":@"about"
                         }
                       ];

    _table.rowHeight = UITableViewAutomaticDimension;
    _table.estimatedRowHeight = 100.0;
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.title=NSLocalizedString(@"Settings",@"settings title");
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [_table reloadData];
}

#pragma mark - Navigation

-(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if([identifier isEqualToString:@"device"]) {
        if([[[Configuration instance] device] settingsSequeIdentifier]) {
            [self performSegueWithIdentifier:[[[Configuration instance] device] settingsSequeIdentifier] sender:self];
        }
        return NO;
    } else if([identifier isEqualToString:@"calibration"]) {
        if([[[Configuration instance] calibration] settingsSequeIdentifier]) {
            [self performSegueWithIdentifier:[[[Configuration instance] calibration] settingsSequeIdentifier] sender:self];
        }
        return NO;
    } else if([identifier isEqualToString:@"units"]) {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Change Unit",@"unitalert.title") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction* until = [UIAlertAction actionWithTitle:NSLocalizedString(@"Change the Unit",@"unitalert.change") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[Storage instance] setSelectedDisplayUnit:nil];
            [self.navigationController.tabBarController setSelectedIndex:0];
        }];

        UIAlertAction* cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",@"unitalert.cancel") style:UIAlertActionStyleDestructive handler:nil];
        [alert addAction:until];
        [alert addAction:cancel];
        [self presentViewController:alert animated:YES completion:nil];
    } else if(identifier != nil) {
        return YES;
    }
    return NO;
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_configurables count];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ConfigurationListTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"configurationListCell"];
    cell.headline.text = [[_configurables objectAtIndex:indexPath.row] objectForKey:@"title"];
    cell.text.text = [[_configurables objectAtIndex:indexPath.row] objectForKey:@"description"];
    return cell;
}
-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if([self shouldPerformSegueWithIdentifier:[[_configurables objectAtIndex:indexPath.row] objectForKey:@"controller"] sender:self]) {
        [self performSegueWithIdentifier:[[_configurables objectAtIndex:indexPath.row] objectForKey:@"controller"] sender:self];
    }
}
@end
