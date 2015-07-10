# BuildAPIAccess

Sample Objective-C (Mac OS X) class wrapper for [Electric Imp’s Build API](https://electricimp.com/docs/buildapi/).

BuildAPIAccess requires the (included) class Connexion, though this is a simple class for the bundles an [NSURLConnection](https://developer.apple.com/library/prerelease/mac/documentation/Cocoa/Reference/Foundation/Classes/NSURLConnection_Class/index.html) and associated data.

Devices are stored internally as [NSMutableDictionary](https://developer.apple.com/library/prerelease/mac/documentation/Cocoa/Reference/Foundation/Classes/NSMutableDictionary_Class/) objects with the following keys:

| Key | Type | Description | Editable? |
| --- | ---- | ---- |
| id | string | Unique identifier | No |
| name | string | Human-friendly name | Yes |
| powerstate | string | "offline" or "online" | No |
| rssi | integer | Local WiFi signal strength | No |
| agent_id | string | ID of the device’s paired agent | No |
| agent_status | string | "offline" or "online" | No |
| model_id | string | ID of the model the device is assigned to | Yes |

## Build API Access Methods

BuildAPIAccess provides a number of methods, but these are the ones to call from your own application:

### - (void)getInitialData:(NSString *)harvey;

Load up lists of models and devices from the Electric Imp Cloud. First time round, pass in your API key.

### - (void)getModels;

Also called by *getInitialData:*, this method results in a list of models placed in the BuildAPIAccess NSMutableArray property *models*.

### - (void)getDevices;

Also alled by *getInitialData:*, this method results in a list of devices placed in the BuildAPIAccess NSMutableArray property *devices*.

### - (void)createNewModel:(NSString *)modelName :(BOOL)isFactoryFirmware;

Creates a new model on the server with the name *modelName*. The second parameter is ignored &ndash; it is immediately set to `false` &ndash; and is reserved for future usage.

### - (void)uploadCode:(NSString *)newDeviceCode :(NSString *)newAgentCode :(NSInteger)modelIndex;

Upload device and agent code, stored in strings, to the model at index *modelIndex* within the property *models*.

### - (void)assignDevice:(NSInteger)deviceIndex toModel:(NSInteger)modelIndex;

Associate the device at index *deviceIndex* within the property *devices* with the model at index *modelIndex* within the property *models*.

### - (void)getCode:(NSString *)modelID;

Get the most recent agent and device code from the model with an ID *modelID*. Code is stored in the BuildAPIAccess NSString properties *deviceCode* and *agentCode*.

**TODO** Add an interface that supplies not the model ID but the model’s index within the property *models*.

- (void)getCodeRev:(NSString *)modelID :(NSInteger)build;

Get a specific agent and device code revision from the model with an ID *modelID*. Code is stored in the BuildAPIAccess NSString properties *deviceCode* and *agentCode*.

**TODO** Add an interface that supplies not the model ID but the model’s index within the property *models*.

### - (void)restartDevice:(NSInteger)deviceIndex;

Force the device at index *deviceIndex* within the property *devices* to restart.

### - (void)restartDevices:(NSInteger)modelIndex;

Force all the devices assigned to the model at index *modelIndex* within the property *models* to restart.

### - (void)deleteModel:(NSInteger)modelIndex;

Remove the model at index *modelIndex* within the property *models* from the server.

### - (void)deleteDevice:(NSInteger)deviceIndex;

Remove the device at index *deviceIndex* within the property *devices* from the server. Note that this doesn’t actually remove the device from the user’s Electric Imp account *(see the [Build API Delete Device documentation](https://electricimp.com/docs/buildapi/device/delete/)

### - (void)updateDevice:(NSInteger)deviceIndex :(NSString *)key :(NSString *)value;

Update the information stored on the server for the device at index *deviceIndex* within the property *devices*. This is used to set or alter a single key within the key-value record. 

### - (void)updateModel:(NSInteger)modelIndex :(NSString *)key :(NSString *)value;

Update the information stored on the server for the model at index *modelIndex* within the property *models*. This is used to set or alter a single key within the key-value record. 

### - (void)getLogsForDevice:(NSInteger)deviceIndex :(NSString *)since :(BOOL)isStream;

Get the current set of log entries stored on the server for the device at index *deviceIndex* within the property *devices*. 

The parameter *since* is a Unix timestamp and with limit the log entries returned to those posted on or after the timestamp. Pass an empty string, `""`, to get all the most recent log entries (up to a server-imposed maximum of 200).

Pass `YES` into the *isStream* parameter if you want to initiate log streaming.

Currently, log entries can be streamed from only one device. To stream from another device, call *stopLogging:* then call *getLogsForDevice:* with the new device’s *deviceIndex* value.

### - (void)startLogging;

Having initiated log streaming using *getLogsForDevice:*, this method is called automatically. But if your application uses *stopLogging:* to halt logging, this method can be called to recommence logging.

- (void)stopLogging;

Call this method to stop the current logging stream.

## HTTPS Request Construction

BuildAPIAccess provides the following convenience methods for construction HTTPS requests to the Electric Imp Cloud. Where a *bodyDictionary* parameter is required, pass an [NSDictionary]() object loaded with the key-value pairs you wish to change. Note that the Build API ignores keys that it does not allow users to change *(see above)*, and will ignore invalid keys.

These methods are called by the above Build API Access methods.

### - (NSURLRequest *)makeGETrequest:(NSString *)path;

### - (NSMutableURLRequest *)makePUTrequest:(NSString *)path :(NSDictionary *)bodyDictionary;

### - (NSMutableURLRequest *)makePOSTrequest:(NSString *)path :(NSDictionary *)bodyDictionary;

### - (NSURLRequest *)makeDELETErequest:(NSString *)path;
