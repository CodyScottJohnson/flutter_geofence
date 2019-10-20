# Flutter Geofence

Package is currently a copy of [FlutterGeofencing](https://github.com/bkonyi/FlutterGeofencing) with the ios platform code rewritten in Swift. It will diverge from that overtime but for now that's what we've got.


## Getting Started

This project is a starting point for a Flutter
[plug-in package](https://flutter.dev/developing-packages/),
a specialized package that includes platform-specific implementation code for
Android and/or iOS.

For help getting started with Flutter, view our 
[online documentation](https://flutter.dev/docs), which offers tutorials, 
samples, guidance on mobile development, and a full API reference.

## Configuring on IOS
### info.plist
>add the following line to your info.plist file
```
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
	<string>Required for Flutter Geofencing example events.</string>
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Required for Flutter Geofencing example events.</string>
	<key>UIBackgroundModes</key>
	<array>
		<string>location</string>
	</array>

...

<key>UIRequiredDeviceCapabilities</key>
	<array>
		<string>location-services</string>
		<string>gps</string>
		<string>armv7</string>
	</array>
```
### AppDelegate.swift
> This part is necessary in order to register the headless background task.
```swift
import flutter_geofence

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
...

    FlutterGeofencePlugin.setPluginRegistrantCallback { registry in
      
        // Note : all of the app's plugins may not be required in this context ;
        // instead of using GeneratedPluginRegistrant.register(with: registry),
        // you may want to register only specific plugins.
        GeneratedPluginRegistrant.register(with: registry)
    }
   
...

  }
}
```