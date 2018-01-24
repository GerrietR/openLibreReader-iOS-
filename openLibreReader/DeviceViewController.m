//
//  DeviceViewController.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "DeviceViewController.h"
#import "blueReader.h"
#import "DeviceCellTableViewCell.h"
#import "BluetoothStatus.h"

@interface DeviceViewController ()
    @property IBOutlet UITableView* table;
    @property IBOutlet UILabel* tableHolder;
    @property (strong) NSMutableArray* devices;
    @property (strong) CBPeripheral* choosenDevice;
@end

@implementation DeviceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _devices = [NSMutableArray array];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(btStatus:)
                                                 name:BLUETOOTH_STATUS
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceFound:)
                                                 name:BLUETOOTH_DEVICE_DISCOVERED
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceDiscovered:)
                                                 name:BLUETOOTH_DEVICE_DISCOVERED_SERVICE_CHARACTERISTICS
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceConnected:)
                                                 name:BLUETOOTH_DEVICE_CONNECTED
                                               object:nil];

    [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_REQUEST_STATE
                                                        object:nil];
}

-(void) btStatus:(NSNotification*)notification {
    if([((BluetoothStatus*)[notification object]) state]==CBManagerStatePoweredOn) {
        [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_DISCONNECT_ALL_DEVICES
                                                            object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_START_SCAN object:[NSNumber numberWithBool:true]];
    }
}

-(void) deviceFound:(NSNotification*)notification {
    if(_deviceFilter) {
        if([_deviceFilter compatibleName:[notification object]]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_CONNECT_DEVICE
                                                                object:[notification object]];
        }
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_CONNECT_DEVICE
                                                            object:[notification object]];
    }
}

-(void) deviceConnected:(NSNotification*)notification {
    [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_DISCOVER_DEVICE
                                                        object:[notification object]];
}

-(void) deviceDiscovered:(NSNotification*)notification {
    CBPeripheral* peripheral = [notification.object objectForKey:@"peripheral"];
    CBService* service = [notification.object objectForKey:@"service"];

    if(_deviceFilter) {
        if([_deviceFilter compatibleService:service]) {
            if(! [_devices containsObject:peripheral]) {
                [_devices addObject:peripheral];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_tableHolder setHidden:YES];
                    [self.table reloadData];
                });
            }
        }
    } else {
        if(! [_devices containsObject:peripheral]) {
            [_devices addObject:peripheral];
            dispatch_async(dispatch_get_main_queue(), ^{
                [_tableHolder setHidden:YES];
                [self.table reloadData];
            });
        }
    }
}

-(IBAction) back:(NSObject*)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_STOP_SCAN object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_DISCONNECT_ALL_DEVICES object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:DEVICEVIEW_CHOOSEN object:_choosenDevice];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_devices count];
}

// Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
// Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"deviceCellTableViewCell" forIndexPath:indexPath];

    if(cell) {
        CBPeripheral* device = [_devices objectAtIndex:indexPath.row];
        DeviceCellTableViewCell* deviceCell = (DeviceCellTableViewCell*)cell;
        deviceCell.mac.text = [[device identifier] UUIDString];
        deviceCell.name.text = [device name];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CBPeripheral* device = [_devices objectAtIndex:indexPath.row];
    _choosenDevice = device;
    [self back:self];
}

-(void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    //UIViewController* parent = [self presentingViewController];
    [super dismissViewControllerAnimated:flag completion:completion];
    /*if(self.targetSegue) {
        [[self presenter] performSegueWithIdentifier:[self targetSegue] sender:[self sender]];
    }*/
}

@end
