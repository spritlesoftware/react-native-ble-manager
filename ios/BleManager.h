
#import "React/RCTBridgeModule.h"
#import "React/RCTEventEmitter.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <UIKit/UIKit.h>


@interface BleManager :  RCTEventEmitter <RCTBridgeModule,CBCentralManagerDelegate, CBPeripheralDelegate, UIAlertViewDelegate>{
    NSString* discoverPeripherialCallbackId;
    NSMutableDictionary* connectCallbacks;
    NSMutableDictionary *readCallbacks;
    NSMutableDictionary *writeCallbacks;
    NSMutableDictionary *readRSSICallbacks;
    NSMutableDictionary *retrieveServicesCallbacks;
    NSMutableArray *writeQueue;
    NSMutableDictionary *notificationCallbacks;
    NSMutableDictionary *stopNotificationCallbacks;
    NSMutableDictionary *retrieveServicesLatches;
}

@property (strong, nonatomic) NSMutableSet *peripherals;
@property (strong, nonatomic) CBCentralManager *manager;
@property (weak, nonatomic) NSTimer *scanTimer;
@property CBPeripheral*headBand;

// Returns the static CBCentralManager instance used by this library.
// May have unexpected behavior when using multiple instances of CBCentralManager.
// For integration with external libraries, advanced use only.
+(CBCentralManager *)getCentralManager;

// Returns the singleton instance of this class initiated by RN.
// For integration with external libraries, advanced use only.
+(BleManager *)getInstance;

@end
