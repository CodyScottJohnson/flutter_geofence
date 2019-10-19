#import "FlutterGeofencePlugin.h"
#import <flutter_geofence/flutter_geofence-Swift.h>

@implementation FlutterGeofencePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    [SwiftFlutterGeofencePlugin registerWithRegistrar:registrar];
}
+ (void)setPluginRegistrantCallback:(FlutterPluginRegistrantCallback)callback {
    [SwiftFlutterGeofencePlugin setPluginRegistrantCallback:callback];
}
@end
