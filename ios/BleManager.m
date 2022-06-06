#import "BleManager.h"
#import "React/RCTBridge.h"
#import "React/RCTConvert.h"
#import "React/RCTEventDispatcher.h"
#import "NSData+Conversion.h"
#import "CBPeripheral+Extensions.h"
#import "BLECommandContext.h"
#import <math.h>

static CBCentralManager *_sharedManager = nil;
static BleManager * _instance = nil;

@implementation BleManager


RCT_EXPORT_MODULE();

@synthesize manager;
@synthesize peripherals;
@synthesize scanTimer;
bool hasListeners;
long tsStart;
long tsLong;
float ch1R, ch2R, ch3R, ch4R, ch5R, ch6R, ch7R, ch8R, ch9R, ch10R, ch11R, ch12R, ch13R, ch14R, ch15R, ch16R, ch17R;
float ch1Rs, ch2Rs, ch3Rs, ch4Rs, ch5Rs, ch6Rs, ch7Rs, ch8Rs, ch9Rs, ch10Rs, ch11Rs, ch12Rs, ch13Rs, ch14Rs, ch15Rs,ch16Rs,ch17Rs;
float ch1IR, ch2IR, ch3IR, ch4IR, ch5IR, ch6IR, ch7IR, ch8IR, ch9IR, ch10IR, ch11IR, ch12IR, ch13IR, ch14IR, ch15IR, ch16IR, ch17IR;
float ch1IRs, ch2IRs, ch3IRs, ch4IRs, ch5IRs, ch6IRs, ch7IRs, ch8IRs, ch9IRs, ch10IRs, ch11IRs, ch12IRs, ch13IRs, ch14IRs, ch15IRs, ch16IRs, ch17IRs;
float accDataX, accDataY, accDataZ, magDataX, magDataY, magDataZ, gyroDataX, gyroDataY, gyroDataZ;
float d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12;
double valuesR[100][16];
double valuesIR[100][16];
int snrDataBufferSize = 0;
NSMutableString *csvString;
NSString *filePath;
//csvString
NSString *fileNames = @"";
CBCharacteristic *NotifyCharacteristic;
CBCharacteristic *WriteCharacteristic;

- (instancetype)init
{
    
    if (self = [super init]) {
        peripherals = [NSMutableSet set];
        connectCallbacks = [NSMutableDictionary new];
        retrieveServicesLatches = [NSMutableDictionary new];
        readCallbacks = [NSMutableDictionary new];
        readRSSICallbacks = [NSMutableDictionary new];
        retrieveServicesCallbacks = [NSMutableDictionary new];
        writeCallbacks = [NSMutableDictionary new];
        writeQueue = [NSMutableArray array];
        notificationCallbacks = [NSMutableDictionary new];
        stopNotificationCallbacks = [NSMutableDictionary new];
        _instance = self;
        NSLog(@"BleManager created");
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bridgeReloading) name:RCTBridgeWillReloadNotification object:nil];
    }
    
    return self;
}

-(void)startObserving {
    hasListeners = YES;
}

-(void)stopObserving {
    hasListeners = NO;
}

-(void)bridgeReloading {
    if (manager) {
        if (self.scanTimer) {
            [self.scanTimer invalidate];
            self.scanTimer = nil;
            [manager stopScan];
        }
        
        manager.delegate = nil;
    }
    @synchronized(peripherals) {
        for (CBPeripheral* p in peripherals) {
            p.delegate = nil;
        }
    
        peripherals = [NSMutableSet set];
    }
}

+(BOOL)requiresMainQueueSetup
{
    return YES;
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[@"BleManagerDidUpdateValueForCharacteristic", @"BleManagerStopScan", @"BleManagerDiscoverPeripheral", @"BleManagerConnectPeripheral", @"BleManagerDisconnectPeripheral", @"BleManagerDidUpdateState"];
}

- (float)formattedchannelData:(int)data arg2:(const Byte *)sensorBytes{
    // Reconstruct the 16Bit data from the 8 Bits chunks
    uint16_t formattedData = (sensorBytes[1] << 8) + sensorBytes[data];
    // return channel data
    float channelData = (( formattedData / 4095.) * 3.3);
    return channelData;
}

-(void) getSNR {
    
    double meanR =0, meanIR = 0;
    double channelWiseSNR_R[16];
    double channelWiseSNR_IR[16];
    
    for (int channel = 0; channel<=15; channel++)
    {
        // Get DC component
        for (int i = 0; i<=99; i++){
            meanR = meanR + valuesR[i][channel];
            meanIR = meanIR + valuesIR[i][channel];
        }
        meanR = meanR / 100;
        meanIR = meanIR / 100;
        
        double varianceR = 0;
        double varianceIR = 0;
        
        for (int i = 0; i <= 99; i++) {
            varianceR += pow(valuesR[i][channel] - meanR, 2);
            varianceIR += pow(valuesIR[i][channel] - meanIR, 2);
        }
        varianceR = varianceR/100;
        varianceIR = varianceIR/100;
        
        channelWiseSNR_R[channel] = 20*log10(meanR/varianceR);
        channelWiseSNR_IR[channel] = 20*log10(meanIR/varianceIR);
    }
    
    NSArray *snrValuesRArray = [NSArray arrayWithObjects:[NSNumber numberWithFloat:channelWiseSNR_R[0]],[NSNumber numberWithFloat:channelWiseSNR_R[1]],[NSNumber numberWithFloat:channelWiseSNR_R[2]],[NSNumber numberWithFloat:channelWiseSNR_R[3]],[NSNumber numberWithFloat:channelWiseSNR_R[4]],[NSNumber numberWithFloat:channelWiseSNR_R[5]],[NSNumber numberWithFloat:channelWiseSNR_R[6]],[NSNumber numberWithFloat:channelWiseSNR_R[7]],[NSNumber numberWithFloat:channelWiseSNR_R[8]],[NSNumber numberWithFloat:channelWiseSNR_R[9]],[NSNumber numberWithFloat:channelWiseSNR_R[10]],[NSNumber numberWithFloat:channelWiseSNR_R[11]],[NSNumber numberWithFloat:channelWiseSNR_R[12]],[NSNumber numberWithFloat:channelWiseSNR_R[13]],[NSNumber numberWithFloat:channelWiseSNR_R[14]],[NSNumber numberWithFloat:channelWiseSNR_R[15]], nil];
    
    NSString *snrValuesR = [snrValuesRArray componentsJoinedByString:@","];
    
    NSArray *snrValuesIRArray = [NSArray arrayWithObjects:[NSNumber numberWithFloat:channelWiseSNR_IR[0]],[NSNumber numberWithFloat:channelWiseSNR_IR[1]],[NSNumber numberWithFloat:channelWiseSNR_IR[2]],[NSNumber numberWithFloat:channelWiseSNR_IR[3]],[NSNumber numberWithFloat:channelWiseSNR_IR[4]],[NSNumber numberWithFloat:channelWiseSNR_IR[5]],[NSNumber numberWithFloat:channelWiseSNR_IR[6]],[NSNumber numberWithFloat:channelWiseSNR_IR[7]],[NSNumber numberWithFloat:channelWiseSNR_IR[8]],[NSNumber numberWithFloat:channelWiseSNR_IR[9]],[NSNumber numberWithFloat:channelWiseSNR_IR[10]],[NSNumber numberWithFloat:channelWiseSNR_IR[11]],[NSNumber numberWithFloat:channelWiseSNR_IR[12]],[NSNumber numberWithFloat:channelWiseSNR_IR[13]],[NSNumber numberWithFloat:channelWiseSNR_IR[14]],[NSNumber numberWithFloat:channelWiseSNR_IR[15]], nil];
    
    NSString *snrValuesIR = [snrValuesIRArray componentsJoinedByString:@","];
    
        NSLog(@"SNR_Red : %@",snrValuesR);
        NSLog(@"SNR_Infrared :%@ ", snrValuesIR);
    
}


- (NSString *)convertByteToChannelData:(NSData *)wrap arg2:(NSString *)timerString arg3:(int)stimulus  {
    NSLog(@"Value timerString %@", timerString);
    // getting pointer to the data
    const Byte *rawSensorBytes = [wrap bytes];
    
    // Set 1 Channels
    // Channels 1, 5, 6, 11, 16, 17
    
    ch1R = [self formattedchannelData: 0 arg2: rawSensorBytes];
    ch1Rs = [self formattedchannelData: 4 arg2: rawSensorBytes];
    ch5R =  [self formattedchannelData: 12 arg2: rawSensorBytes];
    ch5Rs = [self formattedchannelData: 4 arg2: rawSensorBytes];
    ch6R =  [self formattedchannelData: 6 arg2: rawSensorBytes];
    ch6Rs =  [self formattedchannelData: 4 arg2: rawSensorBytes];
    ch11R = [self formattedchannelData: 2 arg2: rawSensorBytes];
    ch11Rs = [self formattedchannelData: 8 arg2: rawSensorBytes];
    ch16R = [self formattedchannelData: 14 arg2: rawSensorBytes];
    ch16Rs = [self formattedchannelData: 8 arg2: rawSensorBytes];
    ch17R = [self formattedchannelData: 16 arg2: rawSensorBytes];
    ch17Rs = [self formattedchannelData: 10 arg2: rawSensorBytes];

    ch1IR  = [self formattedchannelData: 18 arg2: rawSensorBytes];
    ch1IRs = [self formattedchannelData: 22 arg2: rawSensorBytes];
    ch5IR =  [self formattedchannelData: 30 arg2: rawSensorBytes];
    ch5IRs = [self formattedchannelData: 22 arg2: rawSensorBytes];
    ch6IR =  [self formattedchannelData: 24 arg2: rawSensorBytes];
    ch6IRs =  [self formattedchannelData: 22 arg2: rawSensorBytes];
    ch11IR = [self formattedchannelData: 20 arg2: rawSensorBytes];
    ch11IRs = [self formattedchannelData: 26 arg2: rawSensorBytes];
    ch16IR = [self formattedchannelData: 32 arg2: rawSensorBytes];
    ch16IRs = [self formattedchannelData: 26 arg2: rawSensorBytes];
    ch17IR = [self formattedchannelData: 34 arg2: rawSensorBytes];
    ch17IRs = [self formattedchannelData: 28 arg2: rawSensorBytes];
    
    // Set 2 Long Channels
    // Channels 4, 7, 12, 13, 14, 15

    ch4R = [self formattedchannelData: 38 arg2: rawSensorBytes];
    ch4Rs = [self formattedchannelData: 40 arg2: rawSensorBytes];
    ch7R =  [self formattedchannelData: 36 arg2: rawSensorBytes];
    ch7Rs = [self formattedchannelData: 42 arg2: rawSensorBytes];
    ch12R =  [self formattedchannelData: 46 arg2: rawSensorBytes];
    ch12Rs =  [self formattedchannelData: 40 arg2: rawSensorBytes];
    ch13R = [self formattedchannelData: 52 arg2: rawSensorBytes];
    ch13Rs = [self formattedchannelData: 40 arg2: rawSensorBytes];
    ch14R = [self formattedchannelData: 48 arg2: rawSensorBytes];
    ch14Rs = [self formattedchannelData: 42 arg2: rawSensorBytes];
    ch15R = [self formattedchannelData: 50 arg2: rawSensorBytes];
    ch15Rs = [self formattedchannelData: 44 arg2: rawSensorBytes];
    
    ch4IR = [self formattedchannelData: 56 arg2: rawSensorBytes];
    ch4IRs = [self formattedchannelData: 58 arg2: rawSensorBytes];
    ch7IR =  [self formattedchannelData: 54 arg2: rawSensorBytes];
    ch7IRs = [self formattedchannelData: 60 arg2: rawSensorBytes];
    ch12IR =  [self formattedchannelData: 64 arg2: rawSensorBytes];
    ch12IRs =  [self formattedchannelData: 58 arg2: rawSensorBytes];
    ch13IR = [self formattedchannelData: 70 arg2: rawSensorBytes];
    ch13IRs = [self formattedchannelData: 58 arg2: rawSensorBytes];
    ch14IR = [self formattedchannelData: 66 arg2: rawSensorBytes];
    ch14IRs = [self formattedchannelData: 60 arg2: rawSensorBytes];
    ch15IR = [self formattedchannelData: 68 arg2: rawSensorBytes];
    ch15IRs = [self formattedchannelData: 62 arg2: rawSensorBytes];

    // Set 3 Long Channels
    // Channels 2, 3,8, 9, 10
    
    ch2R = [self formattedchannelData: 72 arg2: rawSensorBytes];
    ch2Rs = [self formattedchannelData: 76 arg2: rawSensorBytes];
    ch3R =  [self formattedchannelData: 74 arg2: rawSensorBytes];
    ch3Rs = [self formattedchannelData: 76 arg2: rawSensorBytes];
    ch8R =  [self formattedchannelData: 78 arg2: rawSensorBytes];
    ch8Rs =  [self formattedchannelData: 76 arg2: rawSensorBytes];
    ch9R = [self formattedchannelData: 82 arg2: rawSensorBytes];
    ch9Rs = [self formattedchannelData: 76 arg2: rawSensorBytes];
    ch10R = [self formattedchannelData: 80 arg2: rawSensorBytes];
    ch10Rs = [self formattedchannelData: 76 arg2: rawSensorBytes];
    
    ch2IR = [self formattedchannelData: 84 arg2: rawSensorBytes];
    ch2IRs = [self formattedchannelData: 88 arg2: rawSensorBytes];
    ch3IR =  [self formattedchannelData: 86 arg2: rawSensorBytes];
    ch3IRs = [self formattedchannelData: 88 arg2: rawSensorBytes];
    ch8IR =  [self formattedchannelData: 90 arg2: rawSensorBytes];
    ch8IRs =  [self formattedchannelData: 88 arg2: rawSensorBytes];
    ch9IR = [self formattedchannelData: 94 arg2: rawSensorBytes];
    ch9IRs = [self formattedchannelData: 88 arg2: rawSensorBytes];
    ch10IR = [self formattedchannelData: 92 arg2: rawSensorBytes];
    ch10IRs = [self formattedchannelData: 88 arg2: rawSensorBytes];

    d1 = [self formattedchannelData: 0 arg2: rawSensorBytes];
    d2 = [self formattedchannelData: 2 arg2: rawSensorBytes];
    d3 =  [self formattedchannelData: 4 arg2: rawSensorBytes];
    d4 = [self formattedchannelData: 76 arg2: rawSensorBytes];
    d5 =  [self formattedchannelData: 40 arg2: rawSensorBytes];
    d6 =  [self formattedchannelData: 6 arg2: rawSensorBytes];
    d7 = [self formattedchannelData: 90 arg2: rawSensorBytes];
    d8 = [self formattedchannelData: 26 arg2: rawSensorBytes];
    d9 = [self formattedchannelData: 28 arg2: rawSensorBytes];
    d10 = [self formattedchannelData: 4 arg2: rawSensorBytes];
    d11 = [self formattedchannelData: 32 arg2: rawSensorBytes];
    d12 = [self formattedchannelData: 34 arg2: rawSensorBytes];
    
    //creating a new array and setting the channel data
    double channelValuesR[] = {ch1R, ch2R, ch3R, ch4R, ch5R, ch6R, ch7R, ch8R, ch9R, ch10R, ch11R, ch12R, ch13R, ch14R, ch15R, ch16R};
    double channelValuesIR[] = {ch1IR, ch2IR, ch3IR, ch4IR, ch5IR, ch6IR, ch7IR, ch8IR, ch9IR, ch10IR, ch11IR, ch12IR, ch13IR, ch14IR, ch15IR, ch16IR};
    
    //Set the date
    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MM-dd-yyyy"];
    // or @"yyyy-MM-dd hh:mm:ss a" if you prefer the time with AM/PM
    NSString *formattedDate = [dateFormatter stringFromDate:[NSDate date]];
    
    NSArray *messageArray = [[NSArray alloc] initWithObjects:
                             [NSString stringWithString:formattedDate],
                             [NSString stringWithString:timerString],
                             [NSNumber numberWithFloat:ch1R],
                             [NSNumber numberWithFloat:ch1Rs],
                             [NSNumber numberWithFloat:ch1IR],
                             [NSNumber numberWithFloat:ch1IRs],
                             [NSNumber numberWithFloat:ch2R],
                             [NSNumber numberWithFloat:ch2Rs],
                             [NSNumber numberWithFloat:ch2IR],
                             [NSNumber numberWithFloat:ch2IRs],
                             [NSNumber numberWithFloat:ch3R],
                             [NSNumber numberWithFloat:ch3Rs],
                             [NSNumber numberWithFloat:ch3IR],
                             [NSNumber numberWithFloat:ch3IRs],
                             [NSNumber numberWithFloat:ch4R],
                             [NSNumber numberWithFloat:ch4Rs],
                             [NSNumber numberWithFloat:ch4IR],
                             [NSNumber numberWithFloat:ch4IRs],
                             [NSNumber numberWithFloat:ch5R],
                             [NSNumber numberWithFloat:ch5Rs],
                             [NSNumber numberWithFloat:ch5IR],
                             [NSNumber numberWithFloat:ch5IRs],
                             [NSNumber numberWithFloat:ch6R],
                             [NSNumber numberWithFloat:ch6Rs],
                             [NSNumber numberWithFloat:ch6IR],
                             [NSNumber numberWithFloat:ch6IRs],
                             [NSNumber numberWithFloat:ch7R],
                             [NSNumber numberWithFloat:ch7Rs],
                             [NSNumber numberWithFloat:ch7IR],
                             [NSNumber numberWithFloat:ch7IRs],
                             [NSNumber numberWithFloat:ch8R],
                             [NSNumber numberWithFloat:ch8Rs],
                             [NSNumber numberWithFloat:ch8IR],
                             [NSNumber numberWithFloat:ch8IRs],
                             [NSNumber numberWithFloat:ch9R],
                             [NSNumber numberWithFloat:ch9Rs],
                             [NSNumber numberWithFloat:ch9IR],
                             [NSNumber numberWithFloat:ch9IRs],
                             [NSNumber numberWithFloat:ch10R],
                             [NSNumber numberWithFloat:ch10Rs],
                             [NSNumber numberWithFloat:ch10IR],
                             [NSNumber numberWithFloat:ch10IRs],
                             [NSNumber numberWithFloat:ch11R],
                             [NSNumber numberWithFloat:ch11Rs],
                             [NSNumber numberWithFloat:ch11IR],
                             [NSNumber numberWithFloat:ch11IRs],
                             [NSNumber numberWithFloat:ch12R],
                             [NSNumber numberWithFloat:ch12Rs],
                             [NSNumber numberWithFloat:ch12IR],
                             [NSNumber numberWithFloat:ch12IRs],
                             [NSNumber numberWithFloat:ch13R],
                             [NSNumber numberWithFloat:ch13Rs],
                             [NSNumber numberWithFloat:ch13IR],
                             [NSNumber numberWithFloat:ch13IRs],
                             [NSNumber numberWithFloat:ch14R],
                             [NSNumber numberWithFloat:ch14Rs],
                             [NSNumber numberWithFloat:ch14IR],
                             [NSNumber numberWithFloat:ch14IRs],
                             [NSNumber numberWithFloat:ch15R],
                             [NSNumber numberWithFloat:ch15Rs],
                             [NSNumber numberWithFloat:ch15IR],
                             [NSNumber numberWithFloat:ch15IRs],
                             [NSNumber numberWithFloat:ch16R],
                             [NSNumber numberWithFloat:ch16Rs],
                             [NSNumber numberWithFloat:ch16IR],
                             [NSNumber numberWithFloat:ch16IRs],
                             [NSNumber numberWithFloat:ch17R],
                             [NSNumber numberWithFloat:ch17Rs],
                             [NSNumber numberWithFloat:ch17IR],
                             [NSNumber numberWithFloat:ch17IRs],
                             nil];
    
    NSString *message = [messageArray componentsJoinedByString:@","];
    message = [NSString stringWithFormat:@"%@%@", message, @"\r\n"];
    
    if (snrDataBufferSize > 99){
        //Reset buffer counter to 0
        snrDataBufferSize = 0;
        //Get signal SNR
        [self getSNR];

    }
    else{

        //Assign double array values with 16 channels of value
        int channelValuesRLength = (sizeof channelValuesR) / (sizeof channelValuesR[0]);
        
        int channelValuesIRLength = (sizeof channelValuesIR) / (sizeof channelValuesIR[0]);
        
        for(int i = 0;i<=channelValuesRLength;i++)
        {
            valuesR[snrDataBufferSize][i] = channelValuesR[i];
        }
        for(int i = 0;i<=channelValuesIRLength;i++)
        {
            valuesIR[snrDataBufferSize][i] = channelValuesIR[i];
        }
        //Iterate bufferSize counter
        snrDataBufferSize++;
    }
    return  message;
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
    RCTResponseSenderBlock readCallback = [readCallbacks objectForKey:key];
    
    //Create the data buffer from Value
    NSData* rawSensorData = characteristic.value;
    
    //catch the seconds data
    long currentTime = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    tsLong = currentTime  - tsStart;
    float timeSeconds = ((float) tsLong / 1000.0);
    NSString *timerstring = [NSString stringWithFormat:@"%.02f", timeSeconds];
    
    //call convertByteToChannelData
    [self convertByteToChannelData:rawSensorData arg2:timerstring arg3: 0];
    
    [csvString appendString:[self convertByteToChannelData:rawSensorData arg2:timerstring arg3: 0]];
    
    [csvString writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"Written DATA");
//
//    @"Time,Ch1R,Ch1Rs,Ch1IR,Ch1Rs,Ch2R,Ch2Rs,Ch2IR,Ch2IRs,Ch3R,Ch3Rs,Ch3IR,Ch3IRs,Ch4R,Ch4Rs,Ch4IR,Ch4IRs,Ch5R,Ch5Rs,Ch5IR,Ch5IRs,Ch6R,Ch6Rs,Ch6IR,Ch6IRs,Ch7R,Ch7Rs,Ch7IR,Ch7IRs,Ch8R,Ch8Rs,Ch8IR,Ch8IRs,Ch9R,Ch9Rs,Ch9IR,Ch9IRs,Ch10R,Ch10Rs,Ch10IR,Ch10IRs,Ch11R,Ch11Rs,Ch11IR,Ch11IRs,Ch12R,Ch12Rs,Ch12IR,Ch12IRs,Ch13R,Ch13Rs,Ch13IR,Ch13IRs,Ch14R,Ch14Rs,Ch14IR,Ch14IRs,Ch15R,Ch15Rs,Ch15IR,Ch15IRs,Ch16R,Ch16Rs,Ch16IR,Ch16IRs,Ch17R,Ch17Rs,Ch17IR,Ch17IRs,accX,accY,accZ,magX,magY,magZ,gyroX,gyroY,gyroZ,\r\n"
    
    
    
    if (error) {
        NSLog(@"Error %@ :%@", characteristic.UUID, error);
        if (readCallback != NULL) {
            readCallback(@[error, [NSNull null]]);
            [readCallbacks removeObjectForKey:key];
        }
        return;
    }
    NSLog(@"Read value [%@]: (%lu) %@", characteristic.UUID, [characteristic.value length], characteristic.value);
    
    if (readCallback != NULL) {
        readCallback(@[[NSNull null], ([characteristic.value length] > 0) ? [characteristic.value toArray] : [NSNull null]]);
        [readCallbacks removeObjectForKey:key];
    } else {
        if (hasListeners) {
            [self sendEventWithName:@"BleManagerDidUpdateValueForCharacteristic" body:@{@"peripheral": peripheral.uuidAsString, @"characteristic":characteristic.UUID.UUIDString, @"service":characteristic.service.UUID.UUIDString, @"value": ([characteristic.value length] > 0) ? [characteristic.value toArray] : [NSNull null]}];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error in didUpdateNotificationStateForCharacteristic: %@", error);
        return;
    }
    
    NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
    
    if (characteristic.isNotifying) {
        RCTResponseSenderBlock notificationCallback = [notificationCallbacks objectForKey:key];
        if (notificationCallback != nil) {
          NSLog(@"Notification began on %@", characteristic.UUID);
          notificationCallback(@[]);
          [notificationCallbacks removeObjectForKey:key];
        }
    } else {
        // Notification has stopped
        RCTResponseSenderBlock stopNotificationCallback = [stopNotificationCallbacks objectForKey:key];
        if (stopNotificationCallback != nil) {
            NSLog(@"Notification ended on %@", characteristic.UUID);
            stopNotificationCallback(@[]);
            [stopNotificationCallbacks removeObjectForKey:key];
        }
    }
}




- (NSString *) centralManagerStateToString: (int)state
{
    switch (state) {
        case CBCentralManagerStateUnknown:
            return @"unknown";
        case CBCentralManagerStateResetting:
            return @"resetting";
        case CBCentralManagerStateUnsupported:
            return @"unsupported";
        case CBCentralManagerStateUnauthorized:
            return @"unauthorized";
        case CBCentralManagerStatePoweredOff:
            return @"off";
        case CBCentralManagerStatePoweredOn:
            return @"on";
        default:
            return @"unknown";
    }
    
    return @"unknown";
}

- (NSString *) periphalStateToString: (int)state
{
    switch (state) {
        case CBPeripheralStateDisconnected:
            return @"disconnected";
        case CBPeripheralStateDisconnecting:
            return @"disconnecting";
        case CBPeripheralStateConnected:
            return @"connected";
        case CBPeripheralStateConnecting:
            return @"connecting";
        default:
            return @"unknown";
    }
    
    return @"unknown";
}

- (NSString *) periphalManagerStateToString: (int)state
{
    switch (state) {
        case CBPeripheralManagerStateUnknown:
            return @"Unknown";
        case CBPeripheralManagerStatePoweredOn:
            return @"PoweredOn";
        case CBPeripheralManagerStatePoweredOff:
            return @"PoweredOff";
        default:
            return @"unknown";
    }
    
    return @"unknown";
}

- (CBPeripheral*)findPeripheralByUUID:(NSString*)uuid {
    
    CBPeripheral *peripheral = nil;
    @synchronized(peripherals) {
        for (CBPeripheral *p in peripherals) {
        
            NSString* other = p.identifier.UUIDString;
        
            if ([uuid isEqualToString:other]) {
                peripheral = p;
                break;
            }
        }
    }
    return peripheral;
}

-(CBService *) findServiceFromUUID:(CBUUID *)UUID p:(CBPeripheral *)p
{
    for(int i = 0; i < p.services.count; i++)
    {
        CBService *s = [p.services objectAtIndex:i];
        if ([self compareCBUUID:s.UUID UUID2:UUID])
            return s;
    }
    
    return nil; //Service not found on this peripheral
}

-(int) compareCBUUID:(CBUUID *) UUID1 UUID2:(CBUUID *)UUID2
{
    char b1[16];
    char b2[16];
    [UUID1.data getBytes:b1 length:16];
    [UUID2.data getBytes:b2 length:16];
    
    if (memcmp(b1, b2, UUID1.data.length) == 0)
        return 1;
    else
        return 0;
}

RCT_EXPORT_METHOD(getDiscoveredPeripherals:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"Get discovered peripherals");
    NSMutableArray *discoveredPeripherals = [NSMutableArray array];
    @synchronized(peripherals) {
      for(CBPeripheral *peripheral in peripherals){
        NSDictionary * obj = [peripheral asDictionary];
        [discoveredPeripherals addObject:obj];
      }
    }
    callback(@[[NSNull null], [NSArray arrayWithArray:discoveredPeripherals]]);
}

RCT_EXPORT_METHOD(getConnectedPeripherals:(NSArray *)serviceUUIDStrings callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"Get connected peripherals");
    NSMutableArray *serviceUUIDs = [NSMutableArray new];
    for(NSString *uuidString in serviceUUIDStrings){
        CBUUID *serviceUUID =[CBUUID UUIDWithString:uuidString];
        [serviceUUIDs addObject:serviceUUID];
    }

    NSMutableArray *foundedPeripherals = [NSMutableArray array];
    if ([serviceUUIDs count] == 0){
        @synchronized(peripherals) {
            for(CBPeripheral *peripheral in peripherals){
                if([peripheral state] == CBPeripheralStateConnected){
                    NSDictionary * obj = [peripheral asDictionary];
                    [foundedPeripherals addObject:obj];
                }
            }
        }
    } else {
        NSArray *connectedPeripherals = [manager retrieveConnectedPeripheralsWithServices:serviceUUIDs];
        for(CBPeripheral *peripheral in connectedPeripherals){
            NSDictionary * obj = [peripheral asDictionary];
            [foundedPeripherals addObject:obj];
            @synchronized(peripherals) {
                [peripherals addObject:peripheral];
            }
        }
    }
    
    callback(@[[NSNull null], [NSArray arrayWithArray:foundedPeripherals]]);
}

RCT_EXPORT_METHOD(start:(NSDictionary *)options callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"BleManager initialized");
    NSMutableDictionary *initOptions = [[NSMutableDictionary alloc] init];
    
    if ([[options allKeys] containsObject:@"showAlert"]){
        [initOptions setObject:[NSNumber numberWithBool:[[options valueForKey:@"showAlert"] boolValue]]
                        forKey:CBCentralManagerOptionShowPowerAlertKey];
    }
    
    if ([[options allKeys] containsObject:@"restoreIdentifierKey"]) {
        
        [initOptions setObject:[options valueForKey:@"restoreIdentifierKey"]
                        forKey:CBCentralManagerOptionRestoreIdentifierKey];
        
        if (_sharedManager) {
            manager = _sharedManager;
            manager.delegate = self;
        } else {
            manager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:initOptions];
            _sharedManager = manager;
        }
    } else {
        manager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:initOptions];
        _sharedManager = manager;
    }
    
    callback(@[]);
}

RCT_EXPORT_METHOD(scan:(NSArray *)serviceUUIDStrings timeoutSeconds:(nonnull NSNumber *)timeoutSeconds allowDuplicates:(BOOL)allowDuplicates options:(nonnull NSDictionary*)scanningOptions callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"scan with timeout %@", timeoutSeconds);
    
    // Clear the peripherals before scanning again, otherwise cannot connect again after disconnection
    // Only clear peripherals that are not connected - otherwise connections fail silently (without any
    // onDisconnect* callback).
    @synchronized(peripherals) {
      NSMutableArray *connectedPeripherals = [NSMutableArray array];
      for (CBPeripheral *peripheral in peripherals) {
          if (([peripheral state] != CBPeripheralStateConnected) &&
              ([peripheral state] != CBPeripheralStateConnecting)) {
              [connectedPeripherals addObject:peripheral];
          }
      }
      for (CBPeripheral *p in connectedPeripherals) {
          [peripherals removeObject:p];
      }
    }

    NSArray * services = [RCTConvert NSArray:serviceUUIDStrings];
    NSMutableArray *serviceUUIDs = [NSMutableArray new];
    NSDictionary *options = nil;
    if (allowDuplicates){
        options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
    }
    
    for (int i = 0; i < [services count]; i++) {
        CBUUID *serviceUUID =[CBUUID UUIDWithString:[serviceUUIDStrings objectAtIndex: i]];
        [serviceUUIDs addObject:serviceUUID];
    }
    [manager scanForPeripheralsWithServices:serviceUUIDs options:options];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:[timeoutSeconds floatValue] target:self selector:@selector(stopScanTimer:) userInfo: nil repeats:NO];
    });
    callback(@[]);
}

RCT_EXPORT_METHOD(stopScan:(nonnull RCTResponseSenderBlock)callback)
{
    if (self.scanTimer) {
        [self.scanTimer invalidate];
        self.scanTimer = nil;
    }
    [manager stopScan];
    if (hasListeners) {
        [self sendEventWithName:@"BleManagerStopScan" body:@{}];
    }
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(ReceivedData:(NSArray *)dataArray )
{
    for (NSString *string in dataArray) {
        NSLog(@"%@ ReceivedData", string);
    }
}


-(void)stopScanTimer:(NSTimer *)timer {
    NSLog(@"Stop scan");
    self.scanTimer = nil;
    [manager stopScan];
    if (hasListeners) {
        if (self.bridge) {
            [self sendEventWithName:@"BleManagerStopScan" body:@{}];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    @synchronized(peripherals) {
        [peripherals addObject:peripheral];
    }
    [peripheral setAdvertisementData:advertisementData RSSI:RSSI];
        
    NSLog(@"Discover peripheral: %@", [peripheral name]);
    if (hasListeners) {
        [self sendEventWithName:@"BleManagerDiscoverPeripheral" body:[peripheral asDictionary]];
    }
}

RCT_EXPORT_METHOD(connect:(NSString *)peripheralUUID callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"Connect");
    CBPeripheral *peripheral = [self findPeripheralByUUID:peripheralUUID];
    if (peripheral == nil){
        // Try to retrieve the peripheral
        NSLog(@"Retrieving peripheral with UUID : %@", peripheralUUID);
        NSUUID *uuid = [[NSUUID alloc]initWithUUIDString:peripheralUUID];
        if (uuid != nil) {
            NSArray<CBPeripheral *> *peripheralArray = [manager retrievePeripheralsWithIdentifiers:@[uuid]];
            if([peripheralArray count] > 0){
                peripheral = [peripheralArray objectAtIndex:0];
                @synchronized(peripherals) {
                    [peripherals addObject:peripheral];
                }
                NSLog(@"Successfull retrieved peripheral with UUID : %@", peripheralUUID);
            }
        } else {
            NSString *error = [NSString stringWithFormat:@"Wrong UUID format %@", peripheralUUID];
            callback(@[error, [NSNull null]]);
            return;
        }
    }
    if (peripheral) {
        NSLog(@"Connecting to peripheral with UUID : %@", peripheralUUID);
        
        [connectCallbacks setObject:callback forKey:[peripheral uuidAsString]];
        [manager connectPeripheral:peripheral options:nil];
        
    } else {
        NSString *error = [NSString stringWithFormat:@"Could not find peripheral %@.", peripheralUUID];
        NSLog(@"%@", error);
        callback(@[error, [NSNull null]]);
    }
}

RCT_EXPORT_METHOD(disconnect:(NSString *)peripheralUUID force:(BOOL)force callback:(nonnull RCTResponseSenderBlock)callback)
{
    CBPeripheral *peripheral = [self findPeripheralByUUID:peripheralUUID];
    if (peripheral) {
        NSLog(@"Disconnecting from peripheral with UUID : %@", peripheralUUID);
        
        if (peripheral.services != nil) {
            for (CBService *service in peripheral.services) {
                if (service.characteristics != nil) {
                    for (CBCharacteristic *characteristic in service.characteristics) {
                        if (characteristic.isNotifying) {
                            NSLog(@"Remove notification from: %@", characteristic.UUID);
                            [peripheral setNotifyValue:NO forCharacteristic:characteristic];
                        }
                    }
                }
            }
        }
        
        [manager cancelPeripheralConnection:peripheral];
        callback(@[]);
        
    } else {
        NSString *error = [NSString stringWithFormat:@"Could not find peripheral %@.", peripheralUUID];
        NSLog(@"%@", error);
        callback(@[error]);
    }
}

RCT_EXPORT_METHOD(checkState)
{
    if (manager != nil){
        [self centralManagerDidUpdateState:self.manager];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSString *errorStr = [NSString stringWithFormat:@"Peripheral connection failure: %@. (%@)", peripheral, [error localizedDescription]];
    NSLog(@"%@", errorStr);
    RCTResponseSenderBlock connectCallback = [connectCallbacks valueForKey:[peripheral uuidAsString]];

    if (connectCallback) {
        connectCallback(@[errorStr]);
        [connectCallbacks removeObjectForKey:[peripheral uuidAsString]];
    }
}

// RCT_EXPORT_METHOD(write:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID message:(NSArray*)message maxByteSize:(NSInteger)maxByteSize callback:(nonnull RCTResponseSenderBlock)callback)
// {
//     NSLog(@"Write");
    
//     BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyWrite callback:callback];
    
//     unsigned long c = [message count];
//     uint8_t *bytes = malloc(sizeof(*bytes) * c);
    
//     unsigned i;
//     for (i = 0; i < c; i++)
//     {
//         NSNumber *number = [message objectAtIndex:i];
//         int byte = [number intValue];
//         bytes[i] = byte;
//     }
//     NSData *dataMessage = [NSData dataWithBytesNoCopy:bytes length:c freeWhenDone:YES];
    
//     if (context) {
//         RCTLogInfo(@"Message to write(%lu): %@ ", (unsigned long)[message count], message);
//         CBPeripheral *peripheral = [context peripheral];
//         CBCharacteristic *characteristic = [context characteristic];
        
//         NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
//         [writeCallbacks setObject:callback forKey:key];
        
//         RCTLogInfo(@"Message to write(%lu): %@ ", (unsigned long)[dataMessage length], [dataMessage hexadecimalString]);
//         if ([dataMessage length] > maxByteSize){
//             int dataLength = (int)dataMessage.length;
//             int count = 0;
//             NSData* firstMessage;
//             while(count < dataLength && (dataLength - count > maxByteSize)){
//                 if (count == 0){
//                     firstMessage = [dataMessage subdataWithRange:NSMakeRange(count, maxByteSize)];
//                 }else{
//                     NSData* splitMessage = [dataMessage subdataWithRange:NSMakeRange(count, maxByteSize)];
//                     [writeQueue addObject:splitMessage];
//                 }
//                 count += maxByteSize;
//             }
//             if (count < dataLength) {
//                 NSData* splitMessage = [dataMessage subdataWithRange:NSMakeRange(count, dataLength - count)];
//                 [writeQueue addObject:splitMessage];
//             }
//             NSLog(@"Queued splitted message: %lu", (unsigned long)[writeQueue count]);
//             [peripheral writeValue:firstMessage forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
//         } else {
//             [peripheral writeValue:dataMessage forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
//         }
//     }
// }

//16进制字符串转换成16进制byte数组，每两位转换
- (NSData *)hexToBytes:(NSString *)str{
    NSMutableData* data = [NSMutableData data];
    int idx;
    for (idx = 0; idx+2 <= str.length; idx+=2) {
        NSRange range = NSMakeRange(idx, 2);
        NSString* hexStr = [str substringWithRange:range];
        NSScanner* scanner = [NSScanner scannerWithString:hexStr];
        unsigned int intValue;
        [scanner scanHexInt:&intValue];
        [data appendBytes:&intValue length:1];
    }
    return data;
}

RCT_EXPORT_METHOD(write:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID message:(NSString*)message maxByteSize:(NSInteger)maxByteSize callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"Write");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyWrite callback:callback];
    
    // unsigned long c = [message count];
    // uint8_t *bytes = malloc(sizeof(*bytes) * c);
    
    // unsigned i;
    // for (i = 0; i < c; i++)
    // {
    //     NSNumber *number = [message objectAtIndex:i];
    //     int byte = [number intValue];
    //     bytes[i] = byte;
    // }
    // NSData *dataMessage = [NSData dataWithBytesNoCopy:bytes length:c freeWhenDone:YES];
    NSData *dataMessage = [self hexToBytes:message];
    NSLog(@"byte[]:%@",dataMessage);
    
    if (context) {
        // RCTLogInfo(@"Message to write(%lu): %@ ", (unsigned long)[message count], message);
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];
        
        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
        [writeCallbacks setObject:callback forKey:key];
        
        RCTLogInfo(@"Message to write(%lu): %@ ", (unsigned long)[dataMessage length], [dataMessage hexadecimalString]);
        if ([dataMessage length] > maxByteSize){
            int dataLength = (int)dataMessage.length;
            int count = 0;
            NSData* firstMessage;
            while(count < dataLength && (dataLength - count > maxByteSize)){
                if (count == 0){
                    firstMessage = [dataMessage subdataWithRange:NSMakeRange(count, maxByteSize)];
                }else{
                    NSData* splitMessage = [dataMessage subdataWithRange:NSMakeRange(count, maxByteSize)];
                    [writeQueue addObject:splitMessage];
                }
                count += maxByteSize;
            }
            if (count < dataLength) {
                NSData* splitMessage = [dataMessage subdataWithRange:NSMakeRange(count, dataLength - count)];
                [writeQueue addObject:splitMessage];
            }
            NSLog(@"Queued splitted message: %lu", (unsigned long)[writeQueue count]);
            [peripheral writeValue:firstMessage forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
        } else {
            NSLog(@"writeValue");
            [peripheral writeValue:dataMessage forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
        }
    }
}


RCT_EXPORT_METHOD(writeWithoutResponse:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID message:(NSString*)message maxByteSize:(NSInteger)maxByteSize queueSleepTime:(NSInteger)queueSleepTime callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"writeWithoutResponse");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyWriteWithoutResponse callback:callback];
    // unsigned long c = [message count];
    // uint8_t *bytes = malloc(sizeof(*bytes) * c);
    
    // unsigned i;
    // for (i = 0; i < c; i++)
    // {
    //     NSNumber *number = [message objectAtIndex:i];
    //     int byte = [number intValue];
    //     bytes[i] = byte;
    // }
    // NSData *dataMessage = [NSData dataWithBytesNoCopy:bytes length:c freeWhenDone:YES];

    NSData *dataMessage = [self hexToBytes:message];
    
    if (context) {
        if ([dataMessage length] > maxByteSize) {
            NSUInteger length = [dataMessage length];
            NSUInteger offset = 0;
            CBPeripheral *peripheral = [context peripheral];
            CBCharacteristic *characteristic = [context characteristic];
            
            do {
                NSUInteger thisChunkSize = length - offset > maxByteSize ? maxByteSize : length - offset;
                NSData* chunk = [NSData dataWithBytesNoCopy:(char *)[dataMessage bytes] + offset length:thisChunkSize freeWhenDone:NO];
                
                offset += thisChunkSize;
                [peripheral writeValue:chunk forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
                [NSThread sleepForTimeInterval:(queueSleepTime / 1000)];
            } while (offset < length);
            
            NSLog(@"Message to write(%lu): %@ ", (unsigned long)[dataMessage length], [dataMessage hexadecimalString]);
            callback(@[]);
        } else {
            
            CBPeripheral *peripheral = [context peripheral];
            CBCharacteristic *characteristic = [context characteristic];
            
            NSLog(@"Message to write(%lu): %@ ", (unsigned long)[dataMessage length], [dataMessage hexadecimalString]);
            [peripheral writeValue:dataMessage forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
            callback(@[]);
        }
    }
}

// RCT_EXPORT_METHOD(writeWithoutResponse:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID message:(NSArray*)message maxByteSize:(NSInteger)maxByteSize queueSleepTime:(NSInteger)queueSleepTime callback:(nonnull RCTResponseSenderBlock)callback)
// {
//     NSLog(@"writeWithoutResponse");
    
//     BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyWriteWithoutResponse callback:callback];
//     unsigned long c = [message count];
//     uint8_t *bytes = malloc(sizeof(*bytes) * c);
    
//     unsigned i;
//     for (i = 0; i < c; i++)
//     {
//         NSNumber *number = [message objectAtIndex:i];
//         int byte = [number intValue];
//         bytes[i] = byte;
//     }
//     NSData *dataMessage = [NSData dataWithBytesNoCopy:bytes length:c freeWhenDone:YES];
//     if (context) {
//         if ([dataMessage length] > maxByteSize) {
//             NSUInteger length = [dataMessage length];
//             NSUInteger offset = 0;
//             CBPeripheral *peripheral = [context peripheral];
//             CBCharacteristic *characteristic = [context characteristic];
            
//             do {
//                 NSUInteger thisChunkSize = length - offset > maxByteSize ? maxByteSize : length - offset;
//                 NSData* chunk = [NSData dataWithBytesNoCopy:(char *)[dataMessage bytes] + offset length:thisChunkSize freeWhenDone:NO];
                
//                 offset += thisChunkSize;
//                 [peripheral writeValue:chunk forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
//                 [NSThread sleepForTimeInterval:(queueSleepTime / 1000)];
//             } while (offset < length);
            
//             NSLog(@"Message to write(%lu): %@ ", (unsigned long)[dataMessage length], [dataMessage hexadecimalString]);
//             callback(@[]);
//         } else {
            
//             CBPeripheral *peripheral = [context peripheral];
//             CBCharacteristic *characteristic = [context characteristic];
            
//             NSLog(@"Message to write(%lu): %@ ", (unsigned long)[dataMessage length], [dataMessage hexadecimalString]);
//             [peripheral writeValue:dataMessage forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
//             callback(@[]);
//         }
//     }
// }

RCT_EXPORT_METHOD(read:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"read");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyRead callback:callback];
    if (context) {
        
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];
        
        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
        [readCallbacks setObject:callback forKey:key];
        
        [peripheral readValueForCharacteristic:characteristic];  // callback sends value
    }
    
}

RCT_EXPORT_METHOD(readRSSI:(NSString *)deviceUUID callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"readRSSI");
    
    CBPeripheral *peripheral = [self findPeripheralByUUID:deviceUUID];
    
    if (peripheral && peripheral.state == CBPeripheralStateConnected) {
        [readRSSICallbacks setObject:callback forKey:[peripheral uuidAsString]];
        [peripheral readRSSI];
    } else {
        callback(@[@"Peripheral not found or not connected"]);
    }
    
}

RCT_EXPORT_METHOD(createSensorDataCSV:(NSString *)fileName)
{
    NSLog(@"createSensorDataCSV");
    //createSensorDataCSV
    csvString = [[NSMutableString alloc]initWithCapacity:0];
    //Initial CSV
    [csvString appendString:@"Date,Time,Ch1R,Ch1Rs,Ch1IR,Ch1Rs,Ch2R,Ch2Rs,Ch2IR,Ch2IRs,Ch3R,Ch3Rs,Ch3IR,Ch3IRs,Ch4R,Ch4Rs,Ch4IR,Ch4IRs,Ch5R,Ch5Rs,Ch5IR,Ch5IRs,Ch6R,Ch6Rs,Ch6IR,Ch6IRs,Ch7R,Ch7Rs,Ch7IR,Ch7IRs,Ch8R,Ch8Rs,Ch8IR,Ch8IRs,Ch9R,Ch9Rs,Ch9IR,Ch9IRs,Ch10R,Ch10Rs,Ch10IR,Ch10IRs,Ch11R,Ch11Rs,Ch11IR,Ch11IRs,Ch12R,Ch12Rs,Ch12IR,Ch12IRs,Ch13R,Ch13Rs,Ch13IR,Ch13IRs,Ch14R,Ch14Rs,Ch14IR,Ch14IRs,Ch15R,Ch15Rs,Ch15IR,Ch15IRs,Ch16R,Ch16Rs,Ch16IR,Ch16IRs,Ch17R,Ch17Rs,Ch17IR,Ch17IRs,accX,accY,accZ,magX,magY,magZ,gyroX,gyroY,gyroZ,\r\n"];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    filePath = [NSString stringWithFormat:@"%@/%@.%@", documentsDirectory,fileName, @"csv"];
    NSLog(@"Doc directory:%@",documentsDirectory);
    NSLog(@"File directory:%@",filePath);
//    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
//    {
//        NSLog(@"Create if file dosent exist");
//        [[NSFileManager defaultManager] createFileAtPath: filePath contents:nil attributes:nil];
//    }
//    NSLog(@"Write with existing File");
    [csvString writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
}


- (NSString *)getPathForDirectory:(int)directory
{
  NSArray *paths = NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES);
  return [paths firstObject];
}


RCT_EXPORT_METHOD(StarStopDevice:(NSString *)peripheralUUID gameNumber:(int) gameNo gameState:(BOOL) eventState)
{
    // String peripheralUUID, int gameNo, boolean eventState
    NSLog(@"PID : '%@'  GameNo:'%d'  GameState : '%d' ", peripheralUUID , gameNo, eventState);
    CBPeripheral *peripheral = [self findPeripheralByUUID:peripheralUUID];
    NSLog(@"BLEEEEE : '%@' ", peripheral);
    
    if(eventState == YES)
    {
        NSLog(@"Event State true");
        tsStart = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
        NSString *startNum = @"01";
        @try {
            NSData *dataMessage = [self hexToBytes:startNum];
            NSLog(@"Write Char : '%@' ", WriteCharacteristic);
            [peripheral writeValue:dataMessage forCharacteristic:WriteCharacteristic type:CBCharacteristicWriteWithResponse];
            [peripheral setNotifyValue: YES forCharacteristic: NotifyCharacteristic];
         }
         @catch (NSException *exception) {
            NSLog(@"Error writing:%@", exception.reason);
         }
    }
    else
    {
        NSLog(@"Event State false");
        
        NSString *stopNum = @"00";
        NSData *stopMessage = [self hexToBytes:stopNum];
        [peripheral writeValue:stopMessage forCharacteristic:WriteCharacteristic type:CBCharacteristicWriteWithResponse];
        if (hasListeners) {
            [self sendEventWithName:@"Files Generated" body:@{}];
        }
    }
    
}

RCT_EXPORT_METHOD(retrieveServices:(NSString *)deviceUUID services:(NSArray<NSString *> *)services callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"retrieveServices %@", services);
    
    CBPeripheral *peripheral = [self findPeripheralByUUID:deviceUUID];
    
    if (peripheral && peripheral.state == CBPeripheralStateConnected) {
        [retrieveServicesCallbacks setObject:callback forKey:[peripheral uuidAsString]];
        
        NSMutableArray<CBUUID *> *uuids = [NSMutableArray new];
        for ( NSString *string in services ) {
            CBUUID *uuid = [CBUUID UUIDWithString:string];
            [uuids addObject:uuid];
        }
        
        if ( uuids.count > 0 ) {
            [peripheral discoverServices:uuids];
        } else {
            [peripheral discoverServices:nil];
        }
        
    } else {
        callback(@[@"Peripheral not found or not connected"]);
    }
}

RCT_EXPORT_METHOD(startNotification:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"startNotification");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyNotify callback:callback];
    
    if (context) {
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];
        
        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
        [notificationCallbacks setObject: callback forKey: key];
        
        [peripheral setNotifyValue:YES forCharacteristic:characteristic];
    }
    
}

RCT_EXPORT_METHOD(stopNotification:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID callback:(nonnull RCTResponseSenderBlock)callback)
{
    NSLog(@"stopNotification");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyNotify callback:callback];
    
    if (context) {
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];
        
        if ([characteristic isNotifying]){
            NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
            [stopNotificationCallbacks setObject: callback forKey: key];
            [peripheral setNotifyValue:NO forCharacteristic:characteristic];
            NSLog(@"Characteristic stopped notifying");
        } else {
            NSLog(@"Characteristic is not notifying");
            callback(@[]);
        }
        
    }
    
}

RCT_EXPORT_METHOD(enableBluetooth:(nonnull RCTResponseSenderBlock)callback)
{
    callback(@[@"Not supported"]);
}

RCT_EXPORT_METHOD(getBondedPeripherals:(nonnull RCTResponseSenderBlock)callback)
{
    callback(@[@"Not supported"]);
}

RCT_EXPORT_METHOD(createBond:(NSString *)deviceUUID callback:(nonnull RCTResponseSenderBlock)callback)
{
    callback(@[@"Not supported"]);
}

RCT_EXPORT_METHOD(removeBond:(NSString *)deviceUUID callback:(nonnull RCTResponseSenderBlock)callback)
{
    callback(@[@"Not supported"]);
}

RCT_EXPORT_METHOD(removePeripheral:(NSString *)deviceUUID callback:(nonnull RCTResponseSenderBlock)callback)
{
    callback(@[@"Not supported"]);
}

RCT_EXPORT_METHOD(requestMTU:(NSString *)deviceUUID mtu:(NSInteger)mtu callback:(nonnull RCTResponseSenderBlock)callback)
{
    callback(@[@"Not supported"]);
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSLog(@"didWrite");
    
    NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
    RCTResponseSenderBlock writeCallback = [writeCallbacks objectForKey:key];
    
    NSLog(@"%@ writeCallbacks",writeCallbacks);
    NSLog(@"%@ writeCallback",writeCallback);
    
    if (writeCallback) {
        if (error) {
            NSLog(@"%@", error);
            [writeCallbacks removeObjectForKey:key];
            writeCallback(@[error.localizedDescription]);
        } else {
            if ([writeQueue count] == 0) {
                NSLog(@"LOG 1");
                [writeCallbacks removeObjectForKey:key];
                writeCallback(@[]);
            }else{
                // Remove and write the queud message
                NSLog(@"LOG 2");
                NSData *message = [writeQueue objectAtIndex:0];
                [writeQueue removeObjectAtIndex:0];
                [peripheral writeValue:message forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
            }
            
        }
    }
    
}


- (void)peripheral:(CBPeripheral*)peripheral didReadRSSI:(NSNumber*)rssi error:(NSError*)error {
    NSLog(@"didReadRSSI %@", rssi);
    NSString *key = [peripheral uuidAsString];
    RCTResponseSenderBlock readRSSICallback = [readRSSICallbacks objectForKey: key];
    if (readRSSICallback) {
        readRSSICallback(@[[NSNull null], [NSNumber numberWithInteger:[rssi integerValue]]]);
        [readRSSICallbacks removeObjectForKey:key];
    }
}



- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Peripheral Connected: %@", [peripheral uuidAsString]);
    peripheral.delegate = self;

    // The state of the peripheral isn't necessarily updated until a small delay after didConnectPeripheral is called
    // and in the meantime didFailToConnectPeripheral may be called
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.002 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^(void){
        // didFailToConnectPeripheral should have been called already if not connected by now

        RCTResponseSenderBlock connectCallback = [connectCallbacks valueForKey:[peripheral uuidAsString]];

        if (connectCallback) {
            connectCallback(@[[NSNull null], [peripheral asDictionary]]);
            [connectCallbacks removeObjectForKey:[peripheral uuidAsString]];
        }

        if (hasListeners) {
            [self sendEventWithName:@"BleManagerConnectPeripheral" body:@{@"peripheral": [peripheral uuidAsString]}];
        }
    });

    [writeQueue removeAllObjects];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Peripheral Disconnected: %@", [peripheral uuidAsString]);

    if (error) {
        NSLog(@"Error: %@", error);
    }

    NSString *peripheralUUIDString = [peripheral uuidAsString];

    NSString *errorStr = [NSString stringWithFormat:@"Peripheral did disconnect: %@", peripheralUUIDString];

    RCTResponseSenderBlock connectCallback = [connectCallbacks valueForKey:peripheralUUIDString];
    if (connectCallback) {
        connectCallback(@[errorStr]);
        [connectCallbacks removeObjectForKey:peripheralUUIDString];
    }

    RCTResponseSenderBlock readRSSICallback = [readRSSICallbacks valueForKey:peripheralUUIDString];
    if (readRSSICallback) {
        readRSSICallback(@[errorStr]);
        [readRSSICallbacks removeObjectForKey:peripheralUUIDString];
    }

    RCTResponseSenderBlock retrieveServicesCallback = [retrieveServicesCallbacks valueForKey:peripheralUUIDString];
    if (retrieveServicesCallback) {
        retrieveServicesCallback(@[errorStr]);
        [retrieveServicesCallbacks removeObjectForKey:peripheralUUIDString];
    }

    NSArray* ourReadCallbacks = readCallbacks.allKeys;
    for (id key in ourReadCallbacks) {
        if ([key hasPrefix:peripheralUUIDString]) {
            RCTResponseSenderBlock callback = [readCallbacks objectForKey:key];
            if (callback) {
                callback(@[errorStr]);
                [readCallbacks removeObjectForKey:key];
            }
        }
    }

    NSArray* ourWriteCallbacks = writeCallbacks.allKeys;
    for (id key in ourWriteCallbacks) {
        if ([key hasPrefix:peripheralUUIDString]) {
            RCTResponseSenderBlock callback = [writeCallbacks objectForKey:key];
            if (callback) {
                callback(@[errorStr]);
                [writeCallbacks removeObjectForKey:key];
            }
        }
    }

    NSArray* ourNotificationCallbacks = notificationCallbacks.allKeys;
    for (id key in ourNotificationCallbacks) {
        if ([key hasPrefix:peripheralUUIDString]) {
            RCTResponseSenderBlock callback = [notificationCallbacks objectForKey:key];
            if (callback) {
                callback(@[errorStr]);
                [notificationCallbacks removeObjectForKey:key];
            }
        }
    }

    NSArray* ourStopNotificationsCallbacks = stopNotificationCallbacks.allKeys;
    for (id key in ourStopNotificationsCallbacks) {
        if ([key hasPrefix:peripheralUUIDString]) {
            RCTResponseSenderBlock callback = [stopNotificationCallbacks objectForKey:key];
            if (callback) {
                callback(@[errorStr]);
                [stopNotificationCallbacks removeObjectForKey:key];
            }
        }
    }

    if (hasListeners) {
        [self sendEventWithName:@"BleManagerDisconnectPeripheral" body:@{@"peripheral": [peripheral uuidAsString]}];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"Error: %@", error);
        return;
    }
    NSLog(@"Services Discover");
    
    NSMutableSet *servicesForPeriperal = [NSMutableSet new];
    [servicesForPeriperal addObjectsFromArray:peripheral.services];
    [retrieveServicesLatches setObject:servicesForPeriperal forKey:[peripheral uuidAsString]];
//    for (CBService *service in peripheral.services) {
//        NSLog(@"Service %@ %@", service.UUID, service.description);
//        [peripheral discoverCharacteristics:nil forService:service]; // discover all is slow
//    }
    for (CBService *service in peripheral.services) {
           NSLog(@"Service %@ %@", service.UUID, service.description);
           if ([service. UUID. UUIDString isEqualToString: @"938548E6-C655-11EA-87D0-0242AC130003"])
           {
               NSLog(@"GETTING REQUIRED SERVICE");
               NSLog(@"Service %@ %@", service.UUID, service.description);
               [peripheral discoverIncludedServices:nil forService:service]; // discover included services
               [peripheral discoverCharacteristics:nil forService:service]; // discover characteristics for service
           }
           
           if ([service. UUID. UUIDString isEqualToString: @"19B10000-E8F2-537E-4F6C-D104768A1214"])
           {
               NSLog(@"GETTING REQUIRED SERVICE");
               NSLog(@"Service %@ %@", service.UUID, service.description);
               [peripheral discoverIncludedServices:nil forService:service]; // discover included services
               [peripheral discoverCharacteristics:nil forService:service]; // discover characteristics for service
               }
           }

}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"Error: %@", error);
        return;
    }
    NSLog(@"Characteristics For Service Discover");
    
    NSString *peripheralUUIDString = [peripheral uuidAsString];
    NSMutableSet *latch = [retrieveServicesLatches valueForKey:peripheralUUIDString];
    [latch removeObject:service];
    
    for (CBCharacteristic *characteristic in service. characteristics) {
            NSLog(@"Charecteristics %@", characteristic.UUID);
           
            if ([characteristic.UUID.UUIDString containsString: @"77539407"]) {
                
                NSLog(@"Notify Characteristic %@", characteristic.UUID);
                
                NotifyCharacteristic = characteristic;
                
                //                [peripheral setNotifyValue: YES forCharacteristic: characteristic];
                
            }
                if ([characteristic.UUID.UUIDString containsString: @"19B10001"]) {
                    NSLog(@"Write Charecteristics %@", characteristic.UUID);
                    
                    WriteCharacteristic = characteristic;
                    
//                    NSData *data = [@"01" dataUsingEncoding:NSUTF8StringEncoding];
                    
                    
//                    NSLog(@"WRITING DATA");
//                    [peripheral writeValue: data forCharacteristic: characteristic
//                    type: CBCharacteristicWriteWithResponse];
                }
            }
    
    if ([latch count] == 0) {
        // Call success callback for connect
        RCTResponseSenderBlock retrieveServiceCallback = [retrieveServicesCallbacks valueForKey:peripheralUUIDString];
        if (retrieveServiceCallback) {
            retrieveServiceCallback(@[[NSNull null], [peripheral asDictionary]]);
            [retrieveServicesCallbacks removeObjectForKey:peripheralUUIDString];
        }
        [retrieveServicesLatches removeObjectForKey:peripheralUUIDString];
    }
}

// Find a characteristic in service with a specific property
-(CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service prop:(CBCharacteristicProperties)prop
{
    NSLog(@"Looking for %@ with properties %lu", UUID, (unsigned long)prop);
    for(int i=0; i < service.characteristics.count; i++)
    {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        if ((c.properties & prop) != 0x0 && [c.UUID.UUIDString isEqualToString: UUID.UUIDString]) {
            NSLog(@"Found %@", UUID);
            return c;
        }
    }
    return nil; //Characteristic with prop not found on this service
}

// Find a characteristic in service by UUID
-(CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service
{
    NSLog(@"Looking for %@", UUID);
    for(int i=0; i < service.characteristics.count; i++)
    {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        if ([c.UUID.UUIDString isEqualToString: UUID.UUIDString]) {
            NSLog(@"Found %@", UUID);
            return c;
        }
    }
    return nil; //Characteristic not found on this service
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSString *stateName = [self centralManagerStateToString:central.state];
    if (hasListeners) {
        [self sendEventWithName:@"BleManagerDidUpdateState" body:@{@"state":stateName}];
    }
}

// expecting deviceUUID, serviceUUID, characteristicUUID in command.arguments
-(BLECommandContext*) getData:(NSString*)deviceUUIDString  serviceUUIDString:(NSString*)serviceUUIDString characteristicUUIDString:(NSString*)characteristicUUIDString prop:(CBCharacteristicProperties)prop callback:(nonnull RCTResponseSenderBlock)callback
{
    CBUUID *serviceUUID = [CBUUID UUIDWithString:serviceUUIDString];
    CBUUID *characteristicUUID = [CBUUID UUIDWithString:characteristicUUIDString];
    
    CBPeripheral *peripheral = [self findPeripheralByUUID:deviceUUIDString];
    
    if (!peripheral) {
        NSString* err = [NSString stringWithFormat:@"Could not find peripherial with UUID %@", deviceUUIDString];
        NSLog(@"Could not find peripherial with UUID %@", deviceUUIDString);
        callback(@[err]);
        
        return nil;
    }
    
    CBService *service = [self findServiceFromUUID:serviceUUID p:peripheral];
    
    if (!service)
    {
        NSString* err = [NSString stringWithFormat:@"Could not find service with UUID %@ on peripheral with UUID %@",
                         serviceUUIDString,
                         peripheral.identifier.UUIDString];
        NSLog(@"Could not find service with UUID %@ on peripheral with UUID %@",
              serviceUUIDString,
              peripheral.identifier.UUIDString);
        callback(@[err]);
        return nil;
    }
    
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service prop:prop];
    
    // Special handling for INDICATE. If charateristic with notify is not found, check for indicate.
    if (prop == CBCharacteristicPropertyNotify && !characteristic) {
        characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service prop:CBCharacteristicPropertyIndicate];
    }
    
    // As a last resort, try and find ANY characteristic with this UUID, even if it doesn't have the correct properties
    if (!characteristic) {
        characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    }
    
    if (!characteristic)
    {
        NSString* err = [NSString stringWithFormat:@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@", characteristicUUIDString,serviceUUIDString, peripheral.identifier.UUIDString];
        NSLog(@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@",
              characteristicUUIDString,
              serviceUUIDString,
              peripheral.identifier.UUIDString);
        callback(@[err]);
        return nil;
    }
    
    BLECommandContext *context = [[BLECommandContext alloc] init];
    [context setPeripheral:peripheral];
    [context setService:service];
    [context setCharacteristic:characteristic];
    return context;
    
}

-(NSString *) keyForPeripheral: (CBPeripheral *)peripheral andCharacteristic:(CBCharacteristic *)characteristic {
    return [NSString stringWithFormat:@"%@|%@", [peripheral uuidAsString], [characteristic UUID]];
}

-(void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *,id> *)dict
{
    NSLog(@"centralManager willRestoreState");
}

+(CBCentralManager *)getCentralManager
{
    return _sharedManager;
}

+(BleManager *)getInstance
{
  return _instance;
}

@end
