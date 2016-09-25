# BuildAPIAccess 2.0.1

An Objective-C (Mac OS X / iOS / tvOS) class wrapper for [Electric Imp’s Build API](https://electricimp.com/docs/buildapi/).

BuildAPIAccess requires the (included) class Connexion, a simple convenience class for bundling either an [NSURLConnection](https://developer.apple.com/library/prerelease/mac/documentation/Cocoa/Reference/Foundation/Classes/NSURLConnection_Class/index.html) or [NSURLSession](https://developer.apple.com/library/prerelease/mac/documentation/Foundation/Reference/NSURLSession_class/index.html) instance and associated Build API connection data.

BuildAPIAccess 2.0.0 supports both NSURLSession and NSURLConnection. The former is Apple’s preferred mechanism and the only one of the two supported by tvOS. For more information, see [Initialization Methods](#buildapiaccess-initialization-methods).

### Build API Authorization

Making use of the Build API requires an Electric Imp account and a Build API key associated with that account. Build API keys can be generated using the  Electric Imp IDE, as [detailed here](https://electricimp.com/docs/buildapi/keys/).

Each *BuildAPIAccess* instance does not maintain a permanent record of the selected account’s Build API Key; this is the task of the host application. *BuildAPIAccess* does require this information, so methods are provided to pass an account’s Build API Key into *BuildAPIAccess* instances.

## Licence and Copyright

BuildAPIAccess is &copy; Tony Smith, 2015-2016 and is offered under the terms of the MIT licence.

The BuildAPI is &copy; Electric Imp, 2014-2016.

## Build API Entities

### Devices

Devices are stored internally as [NSMutableDictionary](https://developer.apple.com/library/prerelease/mac/documentation/Cocoa/Reference/Foundation/Classes/NSMutableDictionary_Class/) objects with the following keys:

Key | Type | Description | Editable?
--- | --- | --- | ---
*id* | string | Unique identifier | No
*name* | string | Human-friendly name | Yes
*powerstate* | string | "offline" or "online" | No
*rssi* | integer | Local WiFi signal strength | No
*agent_id* | string | ID of the device’s paired agent | No
*agent_status* | string | "offline" or "online" | No
*model_id* | string | ID of the model the device is assigned to | Yes

### Models

Models are stored internally as [NSMutableDictionary](https://developer.apple.com/library/prerelease/mac/documentation/Cocoa/Reference/Foundation/Classes/NSMutableDictionary_Class/) objects with the following keys:

Key | Type | Description | Editable?
--- | --- | --- | ---
*id* | string | Unique identifier | No
*name* | string | Human-friendly name | Yes
*device* | array | An array of ID strings for the devices assigned to this model | No

### Log Entries

Log entries are returned as the *object* property of the [NSNotification](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSNotification_Class/index.html) object sent to the host application. This object will be of type *id* but is an instance of [NSArray](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSArray_Class/) containing zero or more [NSDictionary](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSDictionary_Class/) objects, each representing a single log entry using the following keys:

Key | Type | Description | Editable?
--- | --- | --- | ---
*timestamp* | string | The ISO 8601 timestamp at which the entry was posted | No
*type* | string | The entry’s flag, eg. ”Agent”, “Device”, “Status”, etc. | No
*message* | string | The logged information | No

### Code Revisions

A model’s code revisions are not retained by *BuildAPIAccess* but are retrieved when required on a per-build basis. When a given code revision is requested, the device and agent code files it comprises are stored, respectively, in the public properties *deviceCode* and *agentCode* as strings. Should a subsequent revision be retrieved from the same model or a different one, these properties’ values will be overwritten.

If the host application wishes to maintain a full local record of all of a model’s code revisions, it will need it iterate through each build. A call to the method [*getCode:*](#--voidgetcodensstring-modelid) will record the latest build number in the public property *latestBuild*.

## BuildAPIAccess Version History

### 2.0.1

- Add getConnectionCount: method
- Code

### 2.0.0

- Support for simultaneous log streaming from multiple devices.
- Breaking changes to methods:
	- launchConnection::
	- startLogging:
	- stopLogging:
- New methods:
	- isDeviceLogging:
	- indexForID:
	- loggingCount
	- killAllConnections

### 1.1.3

- Add *codeErrors* property to record [server-reported code syntax errors](#code-syntax-errors).
- Streamline HTTP request assembly.
- Code improvements and minor bug fixes.

## Installing BuildAPIAccess

Drag the files `BuildAPIAccess.h`, `BuildAPIAccess.m`, `BuildAPIAccessConstants.h`, `Connexion.h` and `Connexion.m` into Xcode’s Project Navigator (with your project loaded). Make sure you copy the files to your project &mdash; there is a checkbox in the ‘Add files...’ window for this. Add `#import "BuildAPI.h"` to the header of the code that will make use of BuildAPIAccess and in which you will instantiate one or more *BuildAPIAccess* objects.

## BuildAPIAccess Properties

| Property | Type | Default | Notes |
| --- | --- | --- | --- |
| *devices* | [NSMutableArray](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSMutableArray_Class/) | Empty array | Contains zero or more device records in NSDictionary form |
| *models* | [NSMutableArray](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSMutableArray_Class/) | Empty array | Contains zero or more model records in NSDictionary form |
| *codeErrors* | [NSMutableArray](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSMutableArray_Class/) | Empty array | Contains zero or more coder syntax error records in NSDictionary form **New in 1.1.3** |
| *deviceCode* | [NSString](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSString_Class/) | Empty string | The most recently retrieved code revision’s device code |
| *agentCode* | [NSString](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSString_Class/) | Empty string | The most recently retrieved code revision’s agent code |
| *latestBuild* | [NSInteger](https://developer.apple.com/library/ios/documentation/Cocoa/Reference/Foundation/Miscellaneous/Foundation_DataTypes/#//apple_ref/c/tdef/NSInteger) | -1 | The latest build number of the most recently request model. This is not set until [*getCode:*](#--voidgetcodensstring-modelid) is called |
| *errorMesage* | [NSString](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSString_Class/) | Empty string | The most recently reported BuildAPIAccess error message |

## BuildAPIAccess Initialization Methods

BuildAPIAccess provides two convenience initializers (constructors):

### - (id)initForNSURLSession
### - (id)initForNSURLConnection

Both methods initialize the BuildAPIAccess instance to make use of, respectively, Apple’s NSURLSession and NSURLConnection connectivity systems. iOS and Mac OS X support both modes, though NSURLSession is the mechanism Apple recommends. Indeed, tvOS *only* supports NSURLSession. As such, BuildAPIAccess now defaults to NSURLSession.

## BuildAPIAccess Authorization Methods

### - (void)setk:(NSString *)apiKey
### - (void)clrk

Use the first method to pass to the BuildAPIAcess instance the user’s Build API key, stored only for the lifetime of the instance. It is up to your host app to persist the API key across launches.

The second method can be used to clear the instance’s copy of the key.

## BuildAPIAccess Methods

BuildAPIAccess provides a number of methods, but these are the ones to call from your own application:

### - (void)getModels

This method results in a list of current models placed in the BuildAPIAccess NSMutableArray property *models*.

### - (void)getDevices

This method results in a list of current devices placed in the BuildAPIAccess NSMutableArray property *devices*.

### - (void)createNewModel:(NSString *)modelName

Creates a new model on the server with the name *modelName*.

### - (void)uploadCode:(NSString *)modelID :(NSString *)newDeviceCode :(NSString *)newAgentCode

Upload device and agent code, stored in strings, to the model with ID *modelID*.

### - (void)assignDevice:(NSString *)deviceID toModel:(NSString *)modelID

Associate the device with ID *deviceID* to the model with ID *modelID*.

### - (void)getCode:(NSString *)modelID

Get the most recent agent and device code from the model with ID *modelID*. This code is stored in the BuildAPIAccess NSString properties *deviceCode* and *agentCode*.

### - (void)getCodeRev:(NSString *)modelID :(NSInteger)build

Get a specific agent and device code revision &mdash; build number *build* &mdash; from the model with an ID *modelID*. This code is stored in the BuildAPIAccess NSString properties *deviceCode* and *agentCode*.

### - (void)restartDevice:(NSString *)deviceID

Force the device with ID *deviceID* to restart.

### - (void)restartDevices:(NSString *)modelID

Force all the devices assigned to the model of ID *modelID* to restart.

### - (void)deleteDevice:(NSString *)deviceID

Remove the device of ID *deviceID* from the server. Note that this doesn’t actually remove the device from the user’s Electric Imp account *(see the [Build API Delete Device documentation](https://electricimp.com/docs/buildapi/device/delete/))*

### - (void)deteleModel:(NSString *)modelID

Delete the model with ID *modelID*.

### - (void)updateDevice:(NSString *)deviceID :(NSString *)key :(NSString *)value

Update the information stored on the server for the device of ID *deviceID*. This is used to set or alter a single key within the key-value record.

### - (void)updateModel:(NSString *)modelID :(NSString *)key :(NSString *)value

Update the information stored on the server for the model of *modelID*. This is used to set or alter a single key within the key-value record.

### - (void)getLogsForDevice:(NSString *)deviceID :(NSString *)since :(BOOL)isStream

Get the current set of log entries stored on the server for the device of ID *deviceID*.

The parameter *since* is a Unix timestamp and with limit the log entries returned to those posted on or after the timestamp. Pass an empty string, `""`, to get all the most recent log entries (up to a server-imposed maximum of 200).

Pass `YES` into the *isStream* parameter if you want to initiate log streaming.

Currently, log entries can be streamed from only one device. To stream from another device, call [*stopLogging:*](#--voidstoplogging) then call [*getLogsForDevice:::*](#--voidgetlogsfordevicensstring-deviceid-nsstring-since-boolisstream) with the new device’s *deviceIndex* value.

### - (void)startLogging:(NSString *)deviceID

Having initiated log streaming using [*getLogsForDevice:::*](#--voidgetlogsfordevicensstring-deviceid-nsstring-since-boolisstream), this method is called automatically. But if your application uses [*stopLogging:*](#--voidstoplogging) to halt logging, this method can be called to recommence logging.

Its parameter is the device ID of the device for which logs can be streamed.

### - (void)stopLogging:(NSString *)deviceID

Call this method to stop the current logging stream. Its parameter is the device ID of the device for which logs are being streamed, or pass in `nil` to stop logging for **all** devices.

### - (BOOL)isDeviceLogging:(NSString *)deviceID

Call this method to check whether a device of ID *deviceID* is currently receiving streamed logs.

### - (NSInteger)indexForID:(NSString *)deviceID

Call this method to get the specified device’s location (0 - n) within BuildAPIAcess’ list of logging devices. It will return -1 if the device is not streaming logs.

### - (NSUInteger)loggingCount

This method returns the number of devices from which logs are currently being streamed.

## BuildAPIAccess Connection Methods

### - (void)killAllConnections

This method quickly cancels **all** current connections and clears the list of devices for which log entries are being streamed. Typically used to tidy up when the host app is closing down. However, it will issue notifications for devices whose log streams are being terminated.

### - (NSUInteger)getConnectionCount

This method returns the number of connections the class instance currently has in flight.

## BuildAPIAccess HTTPS Request Construction Methods

BuildAPIAccess provides the following convenience methods for construction HTTPS requests to the Electric Imp Cloud. Where a *bodyDictionary* parameter is required, pass an [NSDictionary](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSDictionary_Class/) object loaded with the key-value pairs you wish to change. Note that the Build API ignores keys that it does not allow users to change *([see above](#devices))*, and will ignore invalid keys.

These methods are called by the above Build API Access methods.

#### - (NSMutableURLRequest *)makeGETrequest:(NSString *)path

#### - (NSMutableURLRequest *)makePUTrequest:(NSString *)path :(NSDictionary *)bodyDictionary

#### - (NSMutableURLRequest *)makePOSTrequest:(NSString *)path :(NSDictionary *)bodyDictionary

#### - (NSMutableURLRequest *)makeDELETErequest:(NSString *)path

## Signalling Connections

BuildAPIAccess maintains a list of active connections. When a connection is completed for whatever reason, it is removed from the list. If there are no connections in flight, the list will be empty. When a connection is added to the empty list, BuildAPIAccess will signal this by sending the notification `BuildAPIProgressStart`. When the last listed connection completes, it will send the notification `BuildAPIProgressStop`. This is so that the host app can maintain a progress indicator which is visible so long as at least one connection is in flight (but gives to indication as to the progress of individual connections).

## Returning Data

Requests for data are made asynchronously. When the data returns &mdash; or, in the case of data being uploaded or changed, confirmation is made by the server &mdash; the result is signalled to the host application through notifications, listed below. When data is returned, it is stored in BuildAPIAccess member properties as outlined in the Build API access methods [listed above](#buildapiaccess-methods).

Notification | Description
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
BuildAPILogStreamEnd | Signals that a connection failure has stopped log streaming. The ID of the device that is no longer streaming logs is sent with the notification as an NSString

## Error Reporting

Errors arising from connectivity, or through the application’s interaction with the Build API, are announced by the notification `BuildAPIError`. When the application receives this notification, it should read the BuildAPIAccess instance’s *errorMessage* property for more information.

### Code Syntax Errors

Code uploaded to the Electric Imp Cloud via the Build API is automatically checked for syntax errors. These are reported using the standard error message reporting system: a list of all the errors is added to the BuildAPIAccess instance‘s *errorMessage* property.

From BuildAPIAccess 1.1.3 on, a new property *codeErrors* has been added. It is an [NSMutableArray](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSMutableArray_Class/) containing zero or more code error records. These records are [NSMutableDictionary](https://developer.apple.com/library/prerelease/mac/documentation/Cocoa/Reference/Foundation/Classes/NSMutableDictionary_Class/) objects containing the following keys:

Key | Type | Notes
--- | --- | ---
*message* | String | A human readable error message |
*type* | String | `"device"` or `"agent"` &mdash; which code unit contains the error |
*row* | NSNumber | The line number of the *compiled code* in which the error was detected |
*col* | NSNumber | The column at which the error was detected |

Note that *codeErrors* is cleared every time code is uploaded &mdash; it only contains the results of the most recent syntax check.
