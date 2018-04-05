//
//  BluetoothService.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "BluetoothService.h"
#import "Storage.h"
#import "Configuration.h"

@interface BluetoothService () <CBCentralManagerDelegate,CBPeripheralDelegate>
    @property (retain) CBCentralManager* manager;
    @property (retain) NSMutableArray* foundDevices;
    @property (retain) BluetoothStatus* state;
    @property (retain) NSMutableArray<CBPeripheral*>* connectedPeripherals;
@end

@implementation BluetoothService

- (instancetype)init {
    self = [super init];
    if (self) {
        _connectedPeripherals = [NSMutableArray new];
        _manager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0) options:nil];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(restore:)
                                                 name:BLUETOOTH_RESTORE_DEVICE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(startScanning:)
                                                 name:BLUETOOTH_START_SCAN object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(stopScanning)
                                                 name:BLUETOOTH_STOP_SCAN object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(discover:)
                                                 name:BLUETOOTH_DISCOVER_DEVICE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(connect:)
                                                 name:BLUETOOTH_CONNECT_DEVICE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(disconnect:)
                                                 name:BLUETOOTH_DISCONNECT_DEVICE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(centralManagerDidUpdateState:)
                                                 name:BLUETOOTH_REQUEST_STATE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(send:)
                                                 name:BLUETOOTH_SEND_DATA object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(read:)
                                                 name:BLUETOOTH_READ_CHARACTERISTIC object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(disconnectAll:)
                                                 name:BLUETOOTH_DISCONNECT_ALL_DEVICES object:nil];

    return self;
}

-(void) restore:(NSNotification*)notofication {
    [[Storage instance] log:[NSString stringWithFormat:@"restore %@",[notofication object]] from:@"BluetoothService"];
    NSArray* list = [NSArray arrayWithObject:[notofication object]];
    NSArray* devices = [_manager retrievePeripheralsWithIdentifiers:list];
    if([devices count]>0) {
        [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_RESTORED_DEVICE object:[devices objectAtIndex:0]];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_RESTORED_DEVICE object:nil];
    }
}

-(void) discover:(NSNotification*)notofication {
    [[Storage instance] log:@"start discover" from:@"BluetoothService"];
    CBPeripheral* p = [notofication object];
    [p discoverServices:[[Configuration instance].device getRequestedDeviceUUIDs]];
}

-(void) connect:(NSNotification*)notofication {
    [[Storage instance] log:[NSString stringWithFormat:@"connect to %@",[[notofication object] identifier]] from:@"BluetoothService"];
    [_manager connectPeripheral:[notofication object] options:@{
                                                     CBConnectPeripheralOptionNotifyOnNotificationKey : @YES
                                                     }];
}

-(void) disconnect:(NSNotification*)notofication {
    [[Storage instance] log:[NSString stringWithFormat:@"disconnect from %@",[[notofication object] identifier]] from:@"BluetoothService"];
    [_manager cancelPeripheralConnection:[notofication object]];
}

-(void) disconnectAll:(NSNotification*)notofication {
    [[Storage instance] log:@"disconnected from all" from:@"BluetoothService"];
    NSArray* devices = [NSArray arrayWithArray:_connectedPeripherals];
    for(CBPeripheral* device in devices) {
        [_manager cancelPeripheralConnection:device];
    }
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if(central && [central isKindOfClass:[CBCentralManager class]]) {
        _state = [[BluetoothStatus alloc] init];
        _state.state = [central state];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_STATUS object:_state];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if(![_foundDevices containsObject:peripheral])
    {
        [[Storage instance] log:[NSString stringWithFormat:@"discovered %@",[peripheral identifier]] from:@"BluetoothService"];
        [_foundDevices addObject:peripheral];
        [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_DEVICE_DISCOVERED
                                                            object:peripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [[Storage instance] log:[NSString stringWithFormat:@"connected to %@",[peripheral identifier]] from:@"BluetoothService"];
    [peripheral setDelegate:self];
    [_connectedPeripherals addObject:peripheral];

    [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_DEVICE_CONNECTED
                                                        object:peripheral];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    [[Storage instance] log:[NSString stringWithFormat:@"failed connect to %@, error %@",[peripheral identifier],[error localizedDescription]] from:@"BluetoothService"];
    [_connectedPeripherals removeObject:peripheral];
    [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_DEVICE_FAILED
                                                        object:@{@"peripheral":peripheral,@"error":error}];
}
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    [[Storage instance] log:[NSString stringWithFormat:@"disconnected from %@",[peripheral identifier]] from:@"BluetoothService"];
    [_connectedPeripherals removeObject:peripheral];
    [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_DEVICE_DISCONNECTED
                                                        object:peripheral];
}

- (void) startScanning:(NSNotification*)notitifaction {
    Boolean all = [notitifaction.object boolValue];
    [[Storage instance] log:[NSString stringWithFormat:@"start scanning for %@",all?@"all":@"specific"] from:@"BluetoothService"];
    _foundDevices = [NSMutableArray array];
    if(all) {
        [_manager scanForPeripheralsWithServices:nil options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:CBCentralManagerScanOptionAllowDuplicatesKey]];
    } else {
        [_manager scanForPeripheralsWithServices:[[Configuration instance] getRequestedDeviceUUIDs] options:nil];
    }
}

-(void) stopScanning {
    [[Storage instance] log:@"stop scanning" from:@"BluetoothService"];
    [_manager stopScan];
}

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:service];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_DEVICE_DISCOVERED_SERVICE
                                                        object:peripheral];
}

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_DEVICE_DISCOVERED_SERVICE_CHARACTERISTICS
                                                            object:@{@"peripheral":peripheral,@"service":service}];
}

- (void) peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    [[Storage instance] log:[NSString stringWithFormat:@"updated %@",[peripheral identifier]] from:@"BluetoothService"];

    [[NSNotificationCenter defaultCenter] postNotificationName:BLUETOOTH_DEVICE_CHARACTERISTIC_CHANGED
                                                        object:@{@"peripheral":peripheral,@"characteristic":characteristic}];
}

-(void) send:(NSNotification*)notification {
    [[Storage instance] log:[NSString stringWithFormat:@"sending to %@",[notification object]] from:@"BluetoothService"];
    NSData* data = [notification.object objectForKey:@"data"];
    CBCharacteristic* characteristic = [notification.object objectForKey:@"characteristic"];

    if ((characteristic.properties & CBCharacteristicPropertyWriteWithoutResponse) != 0)
    {
        [characteristic.service.peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
    }
    else if ((characteristic.properties & CBCharacteristicPropertyWrite) != 0)
    {
        [characteristic.service.peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
    }
}

-(void) read:(NSNotification*)notification {
    [[Storage instance] log:[NSString stringWithFormat:@"reading from %@",[notification object]] from:@"BluetoothService"];
    CBCharacteristic* characteristic = notification.object;
    if(![characteristic isNotifying]) {
        [characteristic.service.peripheral setNotifyValue:YES forCharacteristic:characteristic];
    }
    if ((characteristic.properties & CBCharacteristicPropertyRead) != 0)
    {
        [characteristic.service.peripheral readValueForCharacteristic:characteristic];
    }
}
@end
