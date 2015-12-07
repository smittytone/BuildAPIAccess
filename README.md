# BuildAPIAccess

Sample Objective-C (Mac OS X) class wrapper for [Electric Imp’s Build API](https://electricimp.com/docs/buildapi/).

BuildAPIAccess requires the (included) class Connexion, though this is a simple class for the bundles an [NSURLConnection](https://developer.apple.com/library/prerelease/mac/documentation/Cocoa/Reference/Foundation/Classes/NSURLConnection_Class/index.html) and associated data.

## Build API Authorization

Making use of the Build API requires an Electric Imp developer account and an API key associated with that account. API keys can be requested from Electric Imp, as [detailed here](https://electricimp.com/docs/buildapi/).

## Licence

BuildAPIAccess is offered under the terms of the MIT licence.

**A polite request** If you make use of BuildAPIAccess in any way, a credit and a link to this repository would be appreciated.

## Devices

Devices are stored internally as [NSMutableDictionary](https://developer.apple.com/library/prerelease/mac/documentation/Cocoa/Reference/Foundation/Classes/NSMutableDictionary_Class/) objects with the following keys:

Key | Type | Description | Editable?
--- | --- | --- | ---
id | string | Unique identifier | No
name | string | Human-friendly name | Yes
powerstate | string | "offline" or "online" | No
rssi | integer | Local WiFi signal strength | No
agent_id | string | ID of the device’s paired agent | No
agent_status | string | "offline" or "online" | No
model_id | string | ID of the model the device is assigned to | Yes

## Models

Models are stored internally as [NSDictionary](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSDictionary_Class/) objects with the following keys:

Key | Type | Description | Editable?
--- | --- | --- | ---
id | string | Unique identifier | No
name | string | Human-friendly name | Yes
device | array | An array of ID strings for the devices assigned to this model | No

## Log Entries

Log entries are returned as the *object* property of the [NSNotification](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSNotification_Class/index.html) object sent to the host application. This object will be of type *id* but is an instance of [NSArray](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSArray_Class/) containing zero or more [NSDictionary](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSDictionary_Class/) objects, each representing a single log entry using the following keys:

Key | Type | Description
--- | --- | ---
timestamp	| string | The ISO 8601 timestamp at which the entry was posted
type | string | The entry’s flag, eg. ”Agent”, “Device”, “Status”, etc.
message | string | The logged information

None of these keys’ values are editable.

## Initialization Methods

BuildAPIAccess provides two convenience initializers (constructors):

- initForNSURLSession
- initForNSURLConnection

Both initialize the BuildAPIAccess instance to make use of, respectively, Apple’s NSURLSession and NSURLConnection connectivity systems. iOS and Mac OS X support both modes, though NSURLSession is the mechanism Apple recommends. Indeed, tvOS *only* supports NSURLSession.

## Build API Access Methods

BuildAPIAccess provides a number of methods, but these are the ones to call from your own application:

### - (void)getInitialData:(NSString *)harvey;

Load up lists of models and devices from the Electric Imp Cloud. First time round, pass in your API key.

### - (void)getModels;

Also called by [*getInitialData:*](#--voidgetinitialdatansstring-harvey), this method results in a list of models placed in the BuildAPIAccess NSMutableArray property *models*.

### - (void)getDevices;

Also alled by [*getInitialData:*](#--voidgetinitialdatansstring-harvey), this method results in a list of devices placed in the BuildAPIAccess NSMutableArray property *devices*.

### - (void)createNewModel:(NSString *)modelName;

Creates a new model on the server with the name *modelName*.

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

Currently, log entries can be streamed from only one device. To stream from another device, call [*stopLogging:*](#--voidstoplogging) then call [*getLogsForDevice:*](#--voidgetlogsfordevicensintegerdeviceindex-nsstring-since-boolisstream) with the new device’s *deviceIndex* value.

### - (void)startLogging;

Having initiated log streaming using [*getLogsForDevice:*](#--voidgetlogsfordevicensintegerdeviceindex-nsstring-since-boolisstream), this method is called automatically. But if your application uses [*stopLogging:*](#--voidstoplogging) to halt logging, this method can be called to recommence logging.

### - (void)stopLogging;

Call this method to stop the current logging stream.

## HTTPS Request Construction

BuildAPIAccess provides the following convenience methods for construction HTTPS requests to the Electric Imp Cloud. Where a *bodyDictionary* parameter is required, pass an [NSDictionary](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSDictionary_Class/) object loaded with the key-value pairs you wish to change. Note that the Build API ignores keys that it does not allow users to change *([see above](#devices))*, and will ignore invalid keys.

These methods are called by the above Build API Access methods.

#### - (NSURLRequest *)makeGETrequest:(NSString *)path;

#### - (NSMutableURLRequest *)makePUTrequest:(NSString *)path :(NSDictionary *)bodyDictionary;

#### - (NSMutableURLRequest *)makePOSTrequest:(NSString *)path :(NSDictionary *)bodyDictionary;

#### - (NSURLRequest *)makeDELETErequest:(NSString *)path;

## Signalling Connections

BuildAPIAccess maintains a list of active connections. When a connection is completed for whatever reason, it is removed from the list. If there are no connections in flight, the list will be empty. When a connection is added to the empty list, BuildAPIAccess will signal this by sending the notification `BuildAPIProgressStart`. When the last listed connection completes, it will send the notification `BuildAPIProgressStop`. This is so that the host app can maintain a progress indicator which is visible so long as at least one connection is in flight (but gives to indication as to the progress of individual connections).

## Returning Data

Requests for data are made asynchronously. When the date returns &ndash; or, in the case of data being uploaded or changes &ndash; the result is signalled to the host application through notifications, listed below. When data is returned, it is stored in BuildAPIAccess member properties as outlined in the Build API access methods [listed above](#build-api-access-methods).

Notificiation | Description
--- | ---
BuildAPIGotModelsList | Model list acquired and now accessible through the *models* property
BuildAPIGotDevicesList | Device list acquired and now accessible through the *devices* property
BuildAPIPostedCode | Code revision uploaded successfully
BuildAPIDeviceRestarted | Device restarted as requested
BuildAPIDeviceAssigned | Device successfully assigned to the specified model
BuildAPIModelCreated | New model successfully created
BuildAPIModelUpdated | Model information successfully updated on the server
BuildAPIModelDeleted | Model successfully deleted
BuildAPIDeviceUpdated | Device information successfully updated on the server
BuildAPIDeviceDeleted | Device successfully ‘removed’ from your account
BuildAPIGotCodeRev | Successfully retrieved the requested code revision. Device code added to the *deviceCode* property. Model code added to the *modelCode* property
BuildAPIGotLogs | Successfully retrieved the requested log entries. The logs are sent with the notification as an [NSArray](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSArray_Class/) [log entry records](#log-entries)
BuildAPILogStream | Successfully retrieved a freshly posted log entry. The log entry is sent with the notification as an [NSArray](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSArray_Class/) [log entry records](#log-entries)

## Error Reporting

Errors arising from connectivity, or through the application’s interaction with the Build API, are announced by the notification `BuildAPIError`. When the application receives this notifcation, it should read the BuildAPIAccess instance’s *errorMessage* property for more information.
