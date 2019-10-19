import Flutter
import UIKit
import CoreLocation

public class SwiftFlutterGeofencePlugin: NSObject, UIApplicationDelegate {
    private var _headlessRunner:FlutterEngine!
    private var _callbackChannel:FlutterMethodChannel!
    private var _mainChannel:FlutterMethodChannel!
    private var _registrar:FlutterPluginRegistrar!
    private var _persistentState:UserDefaults
    private var _eventQueue:Array<[String:Any]>!
    private var _onLocationUpdateHandle:Int64 = 0
    private var _locationManager: CLLocationManager
    
    
    let kRegionKey:String! = "region"
    let kEventType:String! = "event_type"
    let kEnterEvent:Int = 1
    let kExitEvent:Int = 2
    let kCallbackMapping:String = "geofence_region_callback_mapping"
    var instance:SwiftFlutterGeofencePlugin! = nil
    private static var registerPlugins:FlutterPluginRegistrantCallback? = nil
    var initialized:Bool = false
    
    init(registrar:FlutterPluginRegistrar) {
        //super.init(_persisten)
        //NSAssert(self, "super init cannot be nil")
        self._persistentState = UserDefaults.standard
        self._eventQueue = []
        self._locationManager = CLLocationManager()
        
        super.init()
        self._locationManager.delegate = self
        self._locationManager.requestAlwaysAuthorization()
        if #available(iOS 9.0, *) {
            self._locationManager.allowsBackgroundLocationUpdates = true
        }
        _headlessRunner = FlutterEngine(name:"GeofencingIsolate", project:nil, allowHeadlessExecution:true)
        self._registrar = registrar
        
        self._mainChannel = FlutterMethodChannel(name: "plugins.flutter.io/geofencing_plugin",binaryMessenger:registrar.messenger())
        registrar.addMethodCallDelegate(self, channel:_mainChannel)
        
        _callbackChannel = FlutterMethodChannel(name:"plugins.flutter.io/geofencing_plugin_background", binaryMessenger:_headlessRunner.binaryMessenger)
    }
    
    @nonobjc public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Check to see if we're being launched due to a location event.
        if launchOptions?[UIApplication.LaunchOptionsKey.location] != nil {
            // Restart the headless service.
            self.startGeofencingService(self.getCallbackDispatcherHandle());
        }
        
        // Note: if we return NO, this vetos the launch of the application.
        return true;
    }
    func sendLocationEvent(region:CLCircularRegion,event: Int) -> Void{
        //assert(region is CLCircularRegion, "region must be CLCircularRegion");
        let center:CLLocationCoordinate2D  = region.center;
        let handle:Int64 = self.getCallbackHandleForRegionId(identifier: region.identifier);
        self._callbackChannel.invokeMethod("",
                              arguments:[handle, [region.identifier], [center.latitude, center.longitude ], event]);
    }
    func startGeofencingService(_ handle: Int64) {
        self.setCallbackDispatcherHandle(handle)
        let info = FlutterCallbackCache.lookupCallbackInformation(handle)
        assert(info != nil, "failed to find callback")
        let entrypoint = info?.callbackName
        let uri = info?.callbackLibraryPath
        _headlessRunner.run(withEntrypoint: entrypoint, libraryURI: uri)
        assert(SwiftFlutterGeofencePlugin.registerPlugins != nil, "failed to set registerPlugins")
        
        // Once our headless runner has been started, we need to register the application's plugins
        // with the runner in order for them to work on the background isolate. `registerPlugins` is
        // a callback set from AppDelegate.m in the main application. This callback should register
        // all relevant plugins (excluding those which require UI).
        
        SwiftFlutterGeofencePlugin.registerPlugins!(_headlessRunner)
        _registrar.addMethodCallDelegate(self, channel: _callbackChannel)
    }
    func registerGeofence(callbackHandle:Int64,identifier:String, latitude:Double, longitude:Double,radius:Double,triggerMask:Int64) -> Void{
        
        let region:CLCircularRegion = CLCircularRegion(center: CLLocationCoordinate2DMake(latitude, longitude),
                                                       radius: radius,
                                                       identifier: identifier)
        region.notifyOnEntry = true;//((triggerMask & 0x1) != 0);
        region.notifyOnExit =  true;//((triggerMask & 0x2) != 0);
        self.setCallbackHandleForRegionId(handle:callbackHandle, identifier:identifier);
        self._locationManager.startMonitoring(for:region);
        
    }
    func getCallbackDispatcherHandle() -> Int64 {
        let handle = self._persistentState.integer(forKey:"callback_dispatcher_handle")
        return (handle as NSNumber).int64Value
    }
    
    func setCallbackDispatcherHandle(_ handle: Int64) {
        self._persistentState.set(NSNumber(value: handle), forKey: "callback_dispatcher_handle")
    }
    func setCallbackHandleForRegionId(handle:Int64, identifier:String) -> Void {
        var mapping = self.getRegionCallbackMapping();
        mapping[identifier] = handle
        self.setRegionCallbackMapping(mapping: mapping);
    }
    func getCallbackHandleForRegionId(identifier: String) -> Int64{
        let mapping = self.getRegionCallbackMapping();
        guard let handle = mapping[identifier] as? Int64 else{
            return 0
        }
        return handle;
    }
    func setRegionCallbackMapping(mapping:[String:Any]?) -> Void{
        let key = kCallbackMapping;
        assert(mapping != nil, "mapping cannot be nil");
        self._persistentState.set(mapping,forKey: key)
    }
    func getRegionCallbackMapping() -> [String:Any]{
        let key:String = kCallbackMapping;
        var callbackDict = self._persistentState.dictionary(forKey: key)
        if (callbackDict == nil) {
            callbackDict = [String:Any]();
            self._persistentState.set(callbackDict,forKey: key)
        }
        return callbackDict!;
    }
    
    
    
}
extension SwiftFlutterGeofencePlugin: FlutterPlugin{
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_geofence", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterGeofencePlugin(registrar: registrar)
        registrar.addApplicationDelegate(instance)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    @objc
    public static func setPluginRegistrantCallback(_ callback: @escaping FlutterPluginRegistrantCallback) {
        registerPlugins = callback
    }
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "GeofencingPlugin.initializeService":
            print("Trying to Initialize Server...");
            if let args = arguments as? [Int64] {
                print("Server Initialized");
                startGeofencingService(args[0])
                result(true)
            } else {
                result(false)
            }
        case "GeofencingService.initialized":
        {
            
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }
            initialized = true
            while (_eventQueue.count > 0) {
                let event = _eventQueue?[0]
                _eventQueue.remove(at: 0);
                //CLRegion*
                guard let region = event?[kRegionKey] as? CLCircularRegion,let type = event?[kEventType] as? Int
                    else{
                        return
                };
                self.sendLocationEvent(region:region, event: type);
            }
            
            
        }()
        case "GeofencingPlugin.registerGeofence":
            if let args = arguments as? [Any] {
                guard let callbackHandle = args[0] as? Int64,
                    let identifier = args[1] as? String,
                    let latitude = args[2] as? Double,
                    let longitude = args[3] as? Double,
                    let radius = args[4] as? Double,
                    let triggerMask = args[5] as? Int64 else {
                        result(false);
                        return;
                }
                self.registerGeofence(callbackHandle: callbackHandle, identifier: identifier, latitude: latitude, longitude: longitude, radius: radius, triggerMask: triggerMask);
                result(true);
            } else {
                result(false);
            }
        case "GeofencingPlugin.removeGeofence":
            result(true);
        default:
            result(FlutterMethodNotImplemented)
        }
        
        
    }
}
extension SwiftFlutterGeofencePlugin: CLLocationManagerDelegate {
    // called when user Exits a monitored region
    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("exited")
        if region is CLCircularRegion {
            {
                
                objc_sync_enter(self)
                defer { objc_sync_exit(self) }
                if (initialized) {
                    
                    self.sendLocationEvent(region:region as! CLCircularRegion, event:kEnterEvent);
                } else {
                    let dict:[String:Any] = [
                        kRegionKey: region,
                        kEventType: kEnterEvent
                    ];
                    _eventQueue.append(dict);
                }
            }()
        }
    }
    
    // called when user Enters a monitored region
    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("entered")
         if region is CLCircularRegion {
                   {
                       
                       objc_sync_enter(self)
                       defer { objc_sync_exit(self) }
                       print(initialized)
                       if (initialized) {
                           
                           print(region.identifier)
                           self.sendLocationEvent(region:region as! CLCircularRegion, event:kExitEvent);
                       } else {
                           let dict:[String:Any] = [
                               kRegionKey: region,
                               kEventType: kExitEvent
                           ];
                           _eventQueue.append(dict);
                       }
                   }()
               }
    }
    public func locationManager(manager: CLLocationManager, monitoringDidFailForRegion:CLRegion) {
        print("Failed: ",monitoringDidFailForRegion)
    }
                         
}
