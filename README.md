# BuildAPIAccess 3.1.0 #

*BuildAPIAccess* is an Objective-C (macOS, iOS and tvOS) wrapper for [Electric Imp’s impCentral™ API](https://developer.electricimp.com/tools/impcentralapi). It is called BuildAPIAccess for historical reasons: it was written to the support Electric Imp’s Build API, the predecessor to the impCentral API. **BuildAPIAccess 3.0.2 does not support the Build API**, which has been deprecated and will shortly be removed from service.

*BuildAPIAccess* requires the (included) classes *Connexion*, *LogStreamEvent* and *Toke*n. All three are convenience classes for combining properties.

- *Connexion* combines an [NSURLSession](https://developer.apple.com/library/prerelease/mac/documentation/Foundation/Reference/NSURLSession_class/index.html) instance and associated impCentral API connection data.
- *Token* is used to store impCentral API authorization data.
- *LogStreamEvent* is a packaging object for Server-Sent Events (SSE) issued by the impCentral API's logging system.

## impCentral API Authorization ##

Making use of the impCentral API requires an Electric Imp account. You will need your account username and password to authorize calls to the API. These are passed into the *login:* method. *BuildAPIAccess* instances do not maintain a permanent record of the selected account; this is the task of the host application.

## Licence and Copyright ##

BuildAPIAccess is &copy; Tony Smith, 2015-18 and is offered under the terms of the MIT licence.

The impCentral API is &copy; Electric Imp, 2017-18.

## HTTP User Agent ##

From version 2.0.1, BuildAPIAccess issues HTTPS requests with a custom user agent string of the following form:

```
BuildAPIAccess/<VERSION> <HOST_APP_NAME>/<VERSION> (macOS <VERSION>)
```

## Release Notes ##

- 3.1.0 *Released August 24, 2018*
    - Finalize multi-password authentication (MPA) support
        - Remove *is2FA* parameter from *login:::* (it's redundant)
    - Issue notification on login rejection rather than post an error
    - Unify all non-code error notifications (`@"BuildAPIError"`) to return `{ "message": <error_message>, "code": <error_code> }`
- 3.0.1 *Released July 10, 2018*
    - Add *getAccount()* and *gotMyAccount()* methods
- 3.0.0
    - Major revision to support the impCentral API
    - End support for the (deprecated) Build API

## Class Usage ##

Initialize a *BuildAPIAccess* instance using *init:*

```
BuildAPIAccess *api = [[BuildAPIAccess alloc] init];
```

## Class Methods: Login and Authentication ##

### - (void)login:(NSString &#42;)userName :(NSString &#42;)passWord ###

Log in using the supplied credentials. The method uses the credentials to retrieve a new API access token, which is used to authorize all further API accesses during the lifetime of the token.

### - (void)twoFactorLogin:(NSString &#42;)loginToken :(NSString &#42;)otp ###

If OTP is enabled for the target account, BuildAPIAccess will return the notification `@"BuildAPINeedOTP"` and return the server-supplied login token within the notification object via the key *token*. The host app should respond to this by requesting access using this method. Pass in the login token and the six-digit OTP code, typically retrieved from a phone app.

### - (void)logout ###

Delete the instance's impCentral API authorization tokens and close any current connections.

### - (void)setEndpoint:(NSString &#42;)pathWithVersion ###

Changes the URL to which BuildAPIAccess accesses the impCentral API. Use this if you are accessing the API within a Private Cloud. If this is not called, all API accesses are made to `https://api.electricimp.com/v5`.

### - (void)getMyAccount ###

Get information on the logged in account. The instance posts the notification `@"BuildAPIGotMyAccount"` when the account data has been received.

### - (void)getAccount:(NSString &#42;)accountID ###

Get information about the account with the specified ID. The instance posts the notification `@"BuildAPIGotAnAccount"` when the account data has been received.

This call will trigger an API error if you do not have permission to access the account because you are not a collaborator.

## Class Methods: Getting Data ##

### Products ###

### - (void)getProducts ###

Obtains a list of all the impCentral products associated with the account used to sign in to the impCentral API. This method may result in multiple calls to the API as it retrieves as many pages as a required *(see ‘Pagination’, below)*.

The instance posts the notification `@"BuildAPIGotProductsList"` when the complete list of products has been received. The notification includes an NSDictionary: its *data* key points to an array of product NSDictionaries.

### - (void)getProductsWithFilter:(NSString &#42;)filter :(NSString &#42;)uuid ###

Obtains a list of all the impCentral products associated with the current account that has been filtered with the named filter and associated resource UUID. Currently the only filter supported is `@"owner.id"` for which the supplied UUID must be an account ID.

This method may result in multiple calls to the API as it retrieves as many pages as a required. The instance posts the notification `@"BuildAPIGotProductsList"` when the complete list of products has been received. The notification includes an NSDictionary: its *data* key points to an array of product NSDictionaries.

### - (void)getProduct:(NSString &#42;)productID ###

Obtains the record of the product with the specified ID. The instance posts the notification `@"BuildAPIGotProduct"` when the product data has been received. The notification includes an NSDictionary: its *data* key points to the product NSDictionary.

### Device Groups ###

### - (void)getDevicegroups ###

Obtains a list of all the impCentral device groups associated with the current account (see *login:*). This method may result in multiple calls to the API as it retrieves as many pages as a required.

The instance posts the notification `@"BuildAPIGotDeviceGroupsList"` when the complete list of device groups has been received. The notification includes an NSDictionary: its *data* key points to an array of device group NSDictionaries.

### - (void)getDevicegroupsWithFilter:(NSString &#42;)filter :(NSString &#42;)uuid ###

Obtains a list of all the impCentral device groups associated with the current account (see *login:*) that has been filtered with the named filter and associated resource UUID. Currently the only filters supported are `@"owner.id"`, `@"product.id"` or `@"type"`. Valid values for type are `"development_devicegroup"`, `"factoryfixture_devicegroup"`, `"pre_factoryfixture_devicegroup"`, `"pre_production_devicegroup"` and `"production_devicegroup"`, passed into the *uuid* parameter. This method may result in multiple calls to the API as it retrieves as many pages as a required.

The instance posts the notification `@"BuildAPIGotDeviceGroupsList"` when the complete list of device groups has been received. The notification includes an NSDictionary: its *data* key points to an array of device group NSDictionaries.

### - (void)getDevicegroup:(NSString &#42;)devicegroupID ###

Obtains the record of the device group with the specified ID. The instance posts the notification `@"BuildAPIGotDevicegroup"` when the device group data has been received. The notification includes an NSDictionary: its *data* key points to the device group NSDictionary.

### Devices ###

### - (void)getDevices ###

Obtains a list of all the (development) devices associated with the current account (see *login:*). This method may result in multiple calls to the API as it retrieves as many pages as a required.

The instance posts the notification `@"BuildAPIGotDevicesList"` when the complete list of devices has been received. The notification includes an NSDictionary: its *data* key points to an array of device NSDictionaries.

### - (void)getDevicesWithFilter:(NSString &#42;)filter :(NSString &#42;)uuid ###

Obtains a list of all the impCentral devices associated with the current account (see *login:*) that has been filtered with the named filter and associated resource UUID. Currently the only filters supported are `@"owner.id"`, `@"product.id"`, `@"devicegroup.id"`, `@"devicegroup.owner.id"` or `@"devicegroup.type"`. Valid values for type are `"development_devicegroup"`, `"factoryfixture_devicegroup"`, `"pre_factoryfixture_devicegroup"`, `"pre_production_devicegroup"` and `"production_devicegroup"`, passed into the *uuid* parameter. This method may result in multiple calls to the API as it retrieves as many pages as a required.

The instance posts the notification `@"BuildAPIGotDevicesList"` when the complete list of device groups has been received. The notification includes an NSDictionary: its *data* key points to an array of device group NSDictionaries.

### - (void)getDevice:(NSString &#42;)deviceID ###

Obtains the record of the device with the specified ID. The instance posts the notification `@"BuildAPIGotDevice"` when the device data has been received. The notification includes an NSDictionary: its *data* key points to the device NSDictionary.

### - (void)getDeviceLogs:(NSString &#42;)deviceID ###

Obtains all of the historical logs posted by the specified device and its agent. This method may result in multiple calls to the API as it retrieves as many pages as a required.

The instance posts the notification `@"BuildAPIGotLogs"` when the complete list of device logs has been received. The notification includes an NSDictionary: its *data* key points to an array of log entry NSDictionaries; its *count* key indicates the number of log items supplied.

### - (void)getDeviceHistory:(NSString &#42;)deviceID ###

Obtains the enrollment history of the specified device. This method may result in multiple calls to the API as it retrieves as many pages as a required.

The instance posts the notification `@"BuildAPIGotHistory"` when the complete list of device history entries has been received. The notification includes an NSDictionary: its *data* key points to an array of history entry NSDictionaries.

### Deployments ###

### - (void)getDeployments ###

Obtains a list of all the deployments made to device groups associated with the current account (see *login:*). This method may result in multiple calls to the API as it retrieves as many pages as a required.

The instance posts the notification `@"BuildAPIGotDeploymentsList"` when the complete list of deployments has been received. The notification includes an NSDictionary: its *data* key points to an array of deployment NSDictionaries.

### - (void)getDeploymentsWithFilter:(NSString &#42;)filter :(NSString &#42;)uuid ###

Obtains a list of all the deployments made to device groups associated with the current account (see *login:*) that has been filtered with the named filter and associated resource UUID. Currently the only filters supported are `@"owner.id"`, `@"creator.id"`, `@"product.id"`, `@"devicegroup.id"`, `@"sha"`, `@"flagged"`, `@"flagger.id"` or `@"tags"`. This method may result in multiple calls to the API as it retrieves as many pages as a required.

The instance posts the notification `@"BuildAPIGotDeploymentsList"` when the complete list of deployments has been received. The notification includes an NSDictionary: its *data* key points to an array of deployment NSDictionaries.

### - (void)getDeployment:(NSString &#42;)deploymentID ###

Obtains the record of the deployment with the specified ID. The instance posts the notification `@"BuildAPIGotDeployment"` when the deployment data has been received. The notification includes an NSDictionary: its *data* key points to the deployment NSDictionary.

## Class Methods: Setting Data ##

### Products ###

### - (void)createProduct:(NSString &#42;)name :(NSString &#42;)description ###

Creates a product with the specified name and description. These values are limited by the API to 80 and 255 characters, respectively; the method will tail the supplied strings to ensure this limit is adhered to. The name may not be nil and must be at least one character in length. The description may be nil or an empty string.

The instance posts the notification `@"BuildAPIProductCreated"` when the product has been created. The notification includes an NSDictionary: its *data* key points to a record of the new product as an NSDictionary.

### - (void)updateProduct:(NSString &#42;)productID :(NSArray &#42;)keys :(NSArray &#42;)values ###

Updates the specified product using the supplied keys and their associated values. The order of items in the keys and values arrays should match; no check is made to ensure that this is the case. The method checks that the two arrays are of equal length, however. The only supported key values are *name* and *description*.

The instance posts the notification `@"BuildAPIProductUpdated"` when the product has been updated. The notification includes an NSDictionary: its *data* key points to a record of the updated product as an NSDictionary.

### - (void)deleteProduct:(NSString &#42;)productID ###

Deletes the product of the specified ID. Products cannot be deleted if they have associated device groups. If you attempt to delete a product that does, the API will issue an error, which the BuildAPIAccess instance will relay to the host app.

The instance posts the notification `@"BuildAPIProductDeleted"` when the product has been deleted.

### Device Groups ###

### - (void)createDevicegroup:(NSDictionary &#42;)details ###

Creates a device group with the settings specified as the *details* dictionary’s key-value pairs. Allowed keys are *name*, *description*, *type*, *"targetid* and *productid*. The keys’ values are also strings. The first and last of these are mandatory, and must not be nil or of zero length. See the [impCentral API documentation](https://apidoc.electricimp.com/) for allowed types; BuildAPIAccess defaults to `@"development_devicegroup"` if no type is provided.

The values of *name* and *description* are limited by the API to 80 and 255 characters, respectively; the method will tail the supplied strings to ensure this limit is adhered to. The name may not be nil and must be at least one character in length. The description may be nil or an empty string.

The value of *targetid* is the ID of a production device group and can be omitted if the device group being created is of neither factoryfixture or pre_factoryfixture type.

The instance posts the notification `@"BuildAPIDeviceGroupCreated"` when the device group has been created. The notification includes an NSDictionary: its *data* key points to a record of the new device group as an NSDictionary.

### - (void)updateDevicegroup:(NSString &#42;)devicegroupID :(NSString &#42;)keys :(NSString &#42;)values ###

Updates the specified device group using the supplied keys and their associated values. The order of items in the keys and values arrays should match; no check is made to ensure that this is the case. The method checks that the two arrays are of equal length, however. The only supported keys are *name*, *description*, *type*, *production_target* and *load_code_after_blessing*. The first three of these reference strings; *production_target* references a dictionary with the keys *id* (the ID of the target production device group) and *type* (the string `@"production_devicegroup"`); and *load_code_after_blessing* references an NSNumber created from a boolean value.

The instance posts the notification `@"BuildAPIDeviceGroupUpdated"` when the device group has been updated. The notification includes an NSDictionary: its *data* key points to a record of the updated device group as an NSDictionary.

### - (void)deleteDevicegroup:(NSString &#42;)devicegroupID ###

Deletes the device group of the specified ID. Device groups cannot be deleted if they have assigned devices. If you attempt to delete a device group that does, the API will issue an error, which the BuildAPIAccess instance will relay to the host app.

The instance posts the notification `@"BuildAPIDeviceGroupDeleted"` when the device group has been deleted.

### Devices ###

### - (void)updateDevice:(NSString &#42;)deviceID :(NSString &#42;)name ###

Updates the specified device group using the supplied name values. Name may be `nil` &mdash; this removes the device’s name, if it has one.

The instance posts the notification `@"BuildAPIDeviceUpdated"` when the product has been updated. The notification includes an NSDictionary: its *data* key points to a record of the updated device as an NSDictionary.

### - (void)deleteDevice:(NSDictionary *)device ###

Removes the specified development device from the account to which it is currently assigned. Production devices cannot be deleted.

The instance posts the notification `@"BuildAPIDeviceDeleted"` when the device has been deleted.

### Deployments ###

### - (void)createDeployment:(NSDictionary &#42;)deployment ###

Creates a deployment with the settings specified as the *deployment* dictionary’s key-value pairs. The dictionary’s keys and values should match those expected by the impCentral API.

The instance posts the notification `@"BuildAPIDeploymentCreated"` when the deployment has been created. The notification includes an NSDictionary: its *data* key points to a record of the new deployment as an NSDictionary.

### - (void)updateDeployment:(NSString &#42;)deploymentID :(NSArray &#42;)keys :(NSArray &#42;)values ###

Updates the specified deployment using the supplied keys and their associated values. The order of items in the keys and values arrays should match; no check is made to ensure that this is the case. The method checks that the two arrays are of equal length, however. The only supported keys are *description* and *flagged*.

The instance posts the notification `@"BuildAPIDeploymentUpdated"` when the deployment has been updated. The notification includes an NSDictionary: its *data* key points to a record of the updated deployment as an NSDictionary.

### - (void)deleteDeployment:(NSString &#42;)deploymentID ###

Deletes the deployment of the specified ID. Deployments cannot be deleted if the deployment is flagged, or it is a device group's most recent deployment. If you attempt to delete a deployment that meets either of these criteria, the API will issue an error, which the BuildAPIAccess instance will relay to the host app.

The instance posts the notification `@"BuildAPIDeploymentDeleted"` when the device group has been deleted.

## Class Methods: Other Actions ##

### - (void)restartDevices:(NSString &#42;)devicegroupID ###

Restarts all of the devices that are assigned to the specified device group. The instance posts the notification `@"BuildAPIDeviceGroupRestarted"` when all the devices has been instructed to restart. Note that not all devices will restart there and then as this depends upon their connection status.

### - (void)restartDevice:(NSString &#42;)deviceID ###

Restarts the specified device. The instance posts the notification `@"BuildAPIDeviceRestarted"` when the device has been instructed to restart. Note that the device may not restart there and then as this depends upon its connection status.

### - (void)assignDevice:(NSMutableDictionary &#42;)device :(NSString &#42;)devicegroupID ###

Assigns the specified device to the specified device group. The device is specified using a dictionary which matches the standard impCentral device record (see [the impCentral API reference](https://apidoc.electricimp.com/#tag/Devices)).

The instance posts the notification `@"BuildAPIDeviceAssigned"` when the device has been assigned.

### - (void)assignDevices:(NSArray &#42;)devices :(NSString &#42;)devicegroupID ###

Assigns the specified devices to the specified device group. Each device is specified using a dictionary which matches the standard impCentral device record (see [the impCentral API reference](https://apidoc.electricimp.com/#tag/Devices)); these records are added to an array, which is passed into the method.

The instance posts the notification `@"BuildAPIDevicesAssigned"` when the device has been assigned.

### - (void)unassignDevice:(NSDictionary &#42;)device ###

Removes a device from its assigned device group and leaves it in an unassigned state. The device is specified using a dictionary which matches the standard impCentral device record (see [the impCentral API reference](https://apidoc.electricimp.com/#tag/Devices)).

The instance posts the notification `@"BuildAPIDeviceUnassigned"` when the device has been unassigned.

### - (void)unassignDevices:(NSArray &#42;)devices ###

Removes a set of devices from their assigned device group (singular) and leaves them in an unassigned state. Each device is specified using a dictionary which matches the standard impCentral device record (see [the impCentral API reference](https://apidoc.electricimp.com/#tag/Devices)), all provided to the method as an array.

Note that the method checks for already unassigned devices based on the information in the impCentral device records passed in. It also notes the first referenced device group &mdash; this is the device group from which all other devices will be unassigned. Any devices included which are not already assigned to this device group will be ignored.

The instance posts the notification `@"BuildAPIDevicesUnassigned"` when the device has been unassigned.

## Class Methods: Logging ##

### - (void)startLogging:(NSString &#42;)deviceID ###

Adds the specified device (by its ID) to the list of devices for which streamed log entries are being received. If no stream is in place, BuildAPIAccess will set one up. The instance posts the notification `@"BuildAPIDeviceAddedToStream"` when the device has been added to the stream. The notification's object is a dictionary containing the key *device* &mdash; its value is the added device’s ID.

The instance also posts the notification `@"BuildAPILogEntryReceived"` when a log entry has been received. The log entry is passed as the notification’s object, which is a dictionary with the keys *message* and *code*. The former is the raw log entry data, which will be in the form:

```
"232390b030728cee 2017-05-19T17:28:19.095Z development server.log Connected by WiFi on SSID \"darkmatter\" with IP address 192.168.0.2"
```

The *code* key is only present in the case of an error; the value of *message* will then be an error message. Errors are relayed via the notification `@"BuildAPILogStreamClosed"`.

### - (void)stopLogging:(NSString &#42;)deviceID ###

Removes the specified device (by its ID) from the list of devices for which streamed log entries are being received. The instance posts the notification `@"BuildAPIDeviceRemovedFromStream"` when the device has been removed from the stream. The notification's object is a dictionary containing the key *device* &mdash; its value is the removed device’s ID.

Relays the notification `@"BuildAPILogStreamClosed"` to the host app if logging is terminated because of a connection error.

### - (BOOL)isDeviceLogging:(NSString &#42;)deviceID ###

Returns `YES` if the supplied device ID is that of a device which is currently live-streaming log data, otherwise `NO`.

### - (void)killAllConnections ###

Immediately halt all in-flight connections to the impCentral API, including log streams.

## Class Methods: Pagination ##

### - (void)setPageSize:(NSInteger)size ###

Set the maximum number of data items which will be returned by the impCentral API when the instance calls an endpoint that returns data sets. The value of *size* should be between 1 and 100, inclusive.

### - (BOOL)isFirstPage:(NSDictionary &#42;)links ###

Used by the instance to determine whether a page of data is the first of many. This may also be the last page if the number of returned items is less than the page maximum.

*links* is an NSDictionary derived from the JSON data returned by the API.

### - (NSString *)nextPageLink:(NSDictionary &#42;)links ###

Used by the instance to get the URL (as a string) of the next page of data in the sequence.

*links* is an NSDictionary derived from the JSON data returned by the API.

### - (NSString *)getNextURL:(NSString &#42;)url ###

Used by the instance to obtain the query string from the URL pointing to the next page of data in the sequence.

## Notifications ##

BuildAPIAccess can issue any of the following notifications to its host app.

| Notification Name | Meaning | Notes |
| --- | --- | --- |
| `@"BuildAPINeedOTP"` | impCentral requires a OTP to continue login | The host can can use this to ask the user for an OTP |
| `@"BuildAPILoginKey"` | A Login Token has been received | *object* is an NSDictionary: the data from the server |
| `@"BuildAPILoggedIn"` | The user is logged in | The host can can use this to notify the user. *object* is an NSDictionary: its *data* key value is `@"loggedin"` |
| `@"BuildAPILoginRejected"` | impCentral rejected the most recent login attempt | The host can can use this to warn the user |
| `@"BuildAPIGotMyAccount"` | The user’s account information has been received | *object* is an NSDictionary: its *data* key contains the account info |
| `@"BuildAPIGotAnAccount"` | A user’s account information has been received | *object* is an NSDictionary: its *data* key contains the account info |
| `@"BuildAPIError"` | A non-code error has occured | *object* is an NSDictionary: its *message* key contains a human-readable error string; its *code* key contains an error code |
| `@"BuildAPICodeErrors"` | There are syntax errors in uploaded code | *object* is an NSDictionary: its *data* key contains the returned error info |
| `@"BuildAPIProgressStart"` | A request has been sent to impCentral | The host app can use this to start a progress indicator |
| `@"BuildAPIProgressStop"` | A request sent to impCentral has completed | The host app can use this to start a progress indicator |
| `@"BuildAPIDeviceAssigned"` | Device successfully assigned to a Device Group | |
| `@"BuildAPIDeviceUnassigned"` | Device successfully unassigned from a Device Group | |
| `@"BuildAPIGotProductsList"` | List of Products received | *object* is an NSDictionary: its *data* key contains the returned Product list |
| `@"BuildAPIGotProduct"` | Product info received | *object* is an NSDictionary: its *data* key contains the requested Product's info |
| `@"BuildAPIGotProductCreated"` | A Product has been created | *object* is an NSDictionary: its *data* key contains the new Product’s info |
| `@"BuildAPIProductUpdated"` | A Product has been updated | *object* is an NSDictionary: its *data* key contains the updated Product’s info |
| `@"BuildAPIProductDeleted"` | A Product has been deleted | *object* is an NSDictionary: its *data* key value is `@"deleted"` |
| `@"BuildAPIGotDeviceGroupsList"` | List of Device Groups received | *object* is an NSDictionary: its *data* key contains the returned Device Group list |
| `@"BuildAPIGotDeviceGroup"` | Device Group info received | *object* is an NSDictionary: its *data* key contains the requested Device Group's info |
| `@"BuildAPIDeviceGroupCreated"` | A Device Group has been created | *object* is an NSDictionary: its *data* key contains the new Device Group’s info |
| `@"BuildAPIDeviceGroupUpdated"` | A Device Group has been updated | *object* is an NSDictionary: its *data* key contains the updated Device Group’s info |
| `@"BuildAPIDeviceGroupDeleted"` | A Device Group has been deleted | *object* is an NSDictionary: its *data* key value is `@"deleted"` |
| `@"BuildAPIDeviceGroupRestarted"` | A Device Group’s devices have been restarted | *object* is an NSDictionary: its *data* key value is `@"restarted"` |
| `@"BuildAPIGotDeploymentsList"` | List of Deployments received | *object* is an NSDictionary: its *data* key contains the returned Deployment list |
| `@"BuildAPIGotDeviceGroup"` | Deployment info received | *object* is an NSDictionary: its *data* key contains the requested Deployment's info |
| `@"BuildAPIDeploymentCreated"` | A Deploymentp has been created | *object* is an NSDictionary: its *data* key contains the new Deployment’s info |
| `@"BuildAPIDeploymentUpdated"` | A Deployment has been updated | *object* is an NSDictionary: its *data* key contains the updated Deployment’s info |
| `@"BuildAPIDeploymentDeleted"` | A Deployment has been deleted | *object* is an NSDictionary: its *data* key value is `@"deleted"` |
| `@"BuildAPISetMinDeployment"` | A Device Group’s Minimum Deployment has been set | *object* is an NSDictionary: its *data* key contains the Deployment’s info |
| `@"BuildAPIGotDevicesList"` | List of Devices received | *object* is an NSDictionary: its *data* key contains the returned Device list |
| `@"BuildAPIGotDevice"` | Device info received | *object* is an NSDictionary: its *data* key contains the requested Device Group's info |
| `@"BuildAPIDeviceUpdated"` | A Device has been updated | *object* is an NSDictionary: its *data* key contains the updated Device’s info |
| `@"BuildAPIDeviceDeleted"` | A Device has been deleted | *object* is an NSDictionary: its *data* key value is `@"deleted"` |
| `@"BuildAPIDeviceRestarted"` | A Device has been restarted | *object* is an NSDictionary: its *data* key value is `@"restarted"` |
| `@"BuildAPIDeviceAssigned"` | A Device has been assigned to a Device Group | *object* is an NSDictionary: its *data* key value is `@"assigned"` |
| `@"BuildAPIDevicesAssigned"` | Some Devices have been assigned to a Device Group | *object* is an NSDictionary: its *data* key value is `@"assigned"` |
| `@"BuildAPIDeviceUnassigned"` | A Device has been removed from a Device Group | *object* is an NSDictionary: its *data* key value is `@"unassigned"` |
| `@"BuildAPIDevicesUnassigned"` | Some Devices have been removed from a Device Group | *object* is an NSDictionary: its *data* key value is `@"unassigned"` |
| `@"BuildAPIGotLogs"` | A Device’s historical logs have been received | *object* is an NSDictionary: its *data* key contains the returned log entries |
| `@"BuildAPIGotHistory"` | A Device’s enrollment history has been received | *object* is an NSDictionary: its *data* key contains the returned history entries |
| `@"BuildAPIDeviceAddedToStream"` | A Device has been added to a log stream | *object* is an NSDictionary: its *device* key value is the Device’s ID |
| `@"BuildAPIDeviceRemovedFromStream"` | A Device has been removed from a log stream | *object* is an NSDictionary: its *device* key value is the Device’s ID |
| `@"BuildAPILogEntryReceived"` | A log item has been received | *object* points to the entry |
| `@"BuildAPILogStreamEnd"` | Log stream closed unexpectedly | |
