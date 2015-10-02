//
//  ViewController.m
//  BlunoController
//
//  Created by 朱正晶 on 15/10/2.
//  Copyright © 2015年 china. All rights reserved.
//

#import "ViewController.h"

@import CoreBluetooth;

@interface ViewController () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) NSMutableArray *peripherals;

@property (nonatomic, weak) IBOutlet UILabel *statusLabel;
@property (nonatomic, weak) IBOutlet UILabel *temperatureLabel;

@end

@implementation ViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.temperatureLabel.text = @"";
    self.peripherals = [NSMutableArray array];
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                               queue:nil
                                                             options:nil];
    
    // You should always scan for the exact peripheral that you are interested in.
    // Scanning by passing nil as the first parameter is going to be slow and return all peripherals around you.
    // However, the hardware must also send the peripheral identifer in the advertisement packet.
    // Since the TI sensor tag doesn't send it, we are forced to scan for all peripherals and use other hacks to find out which one is really the sensor tag.
    
    if(self.centralManager.state == CBCentralManagerStatePoweredOff) {
        
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Bluetooth Turned Off", @"")
                                    message:NSLocalizedString(@"Turn on bluetooth and try again", @"")
                                   delegate:self
                          cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
                          otherButtonTitles: nil] show];
        
    } else if(self.centralManager.state == CBCentralManagerStateUnsupported) {
        
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Bluetooth LE not available on this device", @"")
                                    message:NSLocalizedString(@"This is not a iPhone 4S+ device", @"")
                                   delegate:self
                          cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
                          otherButtonTitles: nil] show];
        
    } else if(self.centralManager.state == CBCentralManagerStatePoweredOn) {

        [self.centralManager scanForPeripheralsWithServices:nil
                                                    options:nil];
    }
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"centralManagerDidUpdateState = %d", (int)central.state);
    
    if(central.state == CBCentralManagerStatePoweredOn) {
        
        [self.centralManager scanForPeripheralsWithServices:nil
                                                    options:nil];
    } else if(self.centralManager.state == CBCentralManagerStatePoweredOff) {
        
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Bluetooth Turned Off", @"")
                                    message:NSLocalizedString(@"Turn on bluetooth and try again", @"")
                                   delegate:self
                          cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
                          otherButtonTitles: nil] show];
        
    } else if(self.centralManager.state == CBCentralManagerStateUnsupported) {
        
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Bluetooth LE not available on this device", @"")
                                    message:NSLocalizedString(@"This is not a iPhone 4S+ device", @"")
                                   delegate:self
                          cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
                          otherButtonTitles: nil] show];
        
    }
}


- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    NSLog(@"didDiscoverPeripheral name: %@, RSSI: %@", peripheral.name, RSSI);
    
    // optionally stop scanning for more peripherals
    // [self.centralManager stopScan];
    if(![self.peripherals containsObject:peripheral]) {
        
        self.statusLabel.text = NSLocalizedString(@"Connecting to Peripheral", @"");
        peripheral.delegate = self;
        [self.peripherals addObject:peripheral];
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"didConnectPeripheral, name = %@", peripheral.name);
    self.statusLabel.text = NSLocalizedString(@"Discovering services…", @"");
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    NSLog(@"didDisconnectPeripheral, name = %@", peripheral.name);
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    self.statusLabel.text = NSLocalizedString(@"Discovering characteristics…", @"");
    
    [peripheral.services enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        CBService *service = obj;
        
        NSLog(@"didDiscoverServices = %@", service.UUID.UUIDString);
        if([service.UUID isEqual:[CBUUID UUIDWithString:@"DFB0"]]) {
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    self.statusLabel.text = NSLocalizedString(@"Reading temperature…", @"");
    
    [service.characteristics enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        CBCharacteristic *ch = obj;
        NSLog(@"UUID = %@", ch.UUID.UUIDString);
        
        NSLog(@"send data...");
        uint8_t data[8] = {'1', '2', '3', '4', '5'};
        [peripheral writeValue:[NSData dataWithBytes:data length:5]
             forCharacteristic:ch
                          type:CBCharacteristicWriteWithResponse];
        [peripheral setNotifyValue:YES forCharacteristic:ch];
    }];
}

- (float)temperatureFromData:(NSData *)data
{
    NSLog(@"");
    char scratchVal[data.length];
    int16_t ambTemp;
    [data getBytes:&scratchVal length:data.length];
    ambTemp = ((scratchVal[2] & 0xff)| ((scratchVal[3] << 8) & 0xff00));
    
    return (float)((float)ambTemp / (float)128);
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    char scratchVal[characteristic.value.length + 1];
    [characteristic.value getBytes:&scratchVal length:characteristic.value.length];
    scratchVal[characteristic.value.length] = 0;
    NSLog(@"RECV[%d]: %s", (int)characteristic.value.length, scratchVal);
}

@end
