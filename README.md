# BuildAPIAccess 3.0.0 #

BuildAPIAccess is an Objective-C (macOS, iOS and tvOS) wrapper for [Electric Imp’s impCentral API](https://electricimp.com/docs/tools/impcentralapi/). It is called BuildAPIAccess for historical reasons: it was written to the support Electric Imp’s Build API, the predecessor to the impCentral API. BuildAPIAccess 3.0.0 does not support the Build API, which has been deprecated and will soon be removed from service.

BuildAPIAccess requires the (included) classes Connexion, LogStreamEvent and Token. All three are convenience classes for combining properties. Connexion combines an [NSURLSession](https://developer.apple.com/library/prerelease/mac/documentation/Foundation/Reference/NSURLSession_class/index.html) instance and associated impCentral API connection data. Token is used to store impCentral API authorization data. LogStreamEvent is a packaging object for Server-Sent Event (SSE) events issued by the impCentral API's logging system.

## impCentral API Authorization ##

Making use of the impCentral API requires an Electric Imp account. You will need your account username and password to authorize calls to the API. These are passed into the *login:* method. BuildAPIAccess instances does not maintain a permanent record of the selected account; this is the task of the host application.

## Licence and Copyright

BuildAPIAccess is &copy; Tony Smith, 2015-2017 and is offered under the terms of the MIT licence.

The impCentral API is &copy; Electric Imp, 2017.

## HTTP User Agent

From version 2.0.1, BuildAPIAccess issues HTTPS requests with a custom user agent string of the following form:

```
BuildAPIAccess/<VERSION> <HOST_APP_NAME>/<VERSION> (macOS <VERSION>)
```

## Class Usage ##

Initialize a BuildAPIAccess instance using *init:*

```
BuildAPIAccess *api = [[BuildAPIAccess alloc] init];
```

## Class Methods: Login and Authentication ##

### - (void)login:(NSString *)userName :(NSString *)passWord :(BOOL)is2FA ###

Log in using the supplied credentials. The method uses the credentials to retrieve a new API access token, which is used to authorize all further API accesses during the lifetime of the token.

### - (void)getNewAccessToken ###

Acquires a new access token using Electric Imp account credentials. Called automatically by *login:*.

### - (void)refreshAccessToken ###

Obtains a new access token when the current token has expired. Refreshing access tokens uses a different mechanism that obtaining the initial token, which is why this is a separate method from *getNewAccessToken*. It uses the refresh token supplied with the initial access token.

### - (BOOL)isAccessTokenValid ###

Returns `YES` if the current access token has not expired, or `NO` if it has.

### - (void)clearCredentials ###

Clears the instance's record of the user's Electric Imp account credentials. Called when the instance successfully obtains an initial access token.

### - (void)twoFactorLogin:(NSString *)loginToken :(NSString *)otp ###

Placeholder for support of two-factor authentication in due course.

### - (void)logout ###

Remove the instances impCentral API authorization tokens and close any current connections.

## Class Methods: Pagination ##

### - (void)setPageSize:(NSInteger)size ###

Set the maximum number of data items which will be returned by the impCentral API when the instance calls an endpoint that returns data sets. The value of *size* should be between 1 and 100, inclusive.

### - (BOOL)isFirstPage:(NSDictionary *)links ###

Used by the instance to determine whether a page of data is the first of many. This may also be the last page if the number of returned items is less than the page maximum.

*links* is an NSDictionary derived from the JSON data returned by the API.

### - (NSString *)nextPageLink:(NSDictionary *)links ###

Used by the instance to get the URL (as a string) of the next page of data in the sequence.

*links* is an NSDictionary derived from the JSON data returned by the API.

### - (NSString *)getNextURL:(NSString *)url ###

Used by the instance to obtain the query string from the URL pointing to the next page of data in the sequence.

## Class Methods: Getting Data ##

### - (void)getProducts ###

Obtains a list of all the impCentral products associated with the current account (see *login:*). This method may result in multiple calls to the API as it retrieves as many pages as a required.

The instance posts the notification `@"BuildAPIGotProductsList"` when the complete list of products has been received. The notification includes an NSDictionary: its *data* key points to an array of product NSDictionaries.

### - (void)getProductsWithFilter:(NSString *)filter :(NSString *)uuid ###

Obtains a list of all the impCentral products associated with the current account (see *login:*) that has been filtered with the named filter and associated resource UUID. Currently the only filter supported is `@"owner.id"` for which the supplied UUID must be an account ID.

This method may result in multiple calls to the API as it retrieves as many pages as a required. The instance posts the notification `@"BuildAPIGotProductsList"` when the complete list of products has been received. The notification includes an NSDictionary: its *data* key points to an array of product NSDictionaries.

### - (void)getProduct:(NSString *)productID ###

Obtains the record of the product with the specified ID.  The instance posts the notification `@"BuildAPIGotProduct"` when the product data has been received. The notification includes an NSDictionary: its *data* key points to the product NSDictionary.

### - (void)getDevicegroups ###

Obtains a list of all the impCentral device groups associated with the current account (see *login:*). This method may result in multiple calls to the API as it retrieves as many pages as a required.

The instance posts the notification `@"BuildAPIGotDeviceGroupsList"` when the complete list of device groups has been received. The notification includes an NSDictionary: its *data* key points to an array of device group NSDictionaries.

### - (void)getDevicegroupsWithFilter:(NSString *)filter :(NSString *)uuid ###

Obtains a list of all the impCentral device groups associated with the current account (see *login:*) that has been filtered with the named filter and associated resource UUID. Currently the only filters supported are `@"owner.id"`, `@"product.id"` or `@"type"`. Valid values for type are `"development_devicegroup"`, `"factoryfixture_devicegroup"`, `"pre_factoryfixture_devicegroup"`, `"pre_production_devicegroup"` and `"production_devicegroup"`, passed into the *uuid* parameter. This method may result in multiple calls to the API as it retrieves as many pages as a required.

The instance posts the notification `@"BuildAPIGotDeviceGroupsList"` when the complete list of device groups has been received. The notification includes an NSDictionary: its *data* key points to an array of device group NSDictionaries.

### - (void)getDevicegroup:(NSString *)devicegroupID ###

Obtains the record of the device group with the specified ID.  The instance posts the notification `@"BuildAPIGotDevicegroup"` when the device group data has been received. The notification includes an NSDictionary: its *data* key points to the device group NSDictionary.

### - (void)getDevices ###

Obtains a list of all the devices associated with the current account (see *login:*). This method may result in multiple calls to the API as it retrieves as many pages as a required.

The instance posts the notification `@"BuildAPIGotDevicesList"` when the complete list of devices has been received. The notification includes an NSDictionary: its *data* key points to an array of device NSDictionaries.

### - (void)getDevicesWithFilter:(NSString *)filter :(NSString *)uuid ###

Obtains a list of all the impCentral devices associated with the current account (see *login:*) that has been filtered with the named filter and associated resource UUID. Currently the only filters supported are `@"owner.id"`, `@"product.id"`, `@"devicegroup.id"`, `@"devicegroup.owner.id"` or `@"devicegroup.type"`. Valid values for type are `"development_devicegroup"`, `"factoryfixture_devicegroup"`, `"pre_factoryfixture_devicegroup"`, `"pre_production_devicegroup"` and `"production_devicegroup"`, passed into the *uuid* parameter. This method may result in multiple calls to the API as it retrieves as many pages as a required.

The instance posts the notification `@"BuildAPIGotDevicesList"` when the complete list of device groups has been received. The notification includes an NSDictionary: its *data* key points to an array of device group NSDictionaries.

### - (void)getDevice:(NSString *)deviceID ###

Obtains the record of the device with the specified ID. The instance posts the notification `@"BuildAPIGotDevice"` when the device data has been received. The notification includes an NSDictionary: its *data* key points to the device NSDictionary.

### - (void)getDeviceLogs:(NSString *)deviceID ###

### - (void)getDeviceHistory:(NSString *)deviceID ###

### - (void)getDeployments ###

Obtains a list of all the deployments made to device groups associated with the current account (see *login:*). This method may result in multiple calls to the API as it retrieves as many pages as a required.

The instance posts the notification `@"BuildAPIGotDeploymentsList"` when the complete list of deployments has been received. The notification includes an NSDictionary: its *data* key points to an array of deployment NSDictionaries.

### - (void)getDeploymentsWithFilter:(NSString *)filter :(NSString *)uuid ###

Obtains a list of all the deployments made to device groups associated with the current account (see *login:*) that has been filtered with the named filter and associated resource UUID. Currently the only filters supported are `@"owner.id"`, `@"creator.id"`, `@"product.id"`, `@"devicegroup.id"`, `@"sha"`, `@"flagged"`, `@"flagger.id"` or `@"tags"`. This method may result in multiple calls to the API as it retrieves as many pages as a required.

The instance posts the notification `@"BuildAPIGotDeploymentsList"` when the complete list of deployments has been received. The notification includes an NSDictionary: its *data* key points to an array of deployment NSDictionaries.

### - (void)getDeployment:(NSString *)deploymentID ###

Obtains the record of the deployment with the specified ID. The instance posts the notification `@"BuildAPIGotDeployment"` when the deployment data has been received. The notification includes an NSDictionary: its *data* key points to the deployment NSDictionary.

## Class Methods: Setting Data ###

### - (void)createProduct:(NSString *)name :(NSString *)description ###

Creates a product with the specified name and description. These values are limited by the API to 80 and 255 characters, respectively; the method will tail the supplied strings to ensure this limit is adhered to. The name may not be nil and must be at least one character in length. The description may be nil or an empty string.

The instance posts the notification `@"BuildAPIProductCreated"` when the product has been created. The notification includes an NSDictionary: its *data* key points to a record of the new product as an NSDictionary.

### - (void)updateProduct:(NSString *)productID :(NSArray *)keys :(NSArray *)values ###

Updates the specified product using the supplied keys and their associated values. The order of items in the keys and values arrays should match; no check is made to ensure that this is the case. The method checks that the two arrays are of equal length, however. The only supported key values are *name* and *description*.

The instance posts the notification `@"BuildAPIProductUpdated"` when the product has been updated. The notification includes an NSDictionary: its *data* key points to a record of the updated product as an NSDictionary.

### - (void)deleteProduct:(NSString *)productID ###

Deletes the product of the specified ID. Products cannot be deleted if they have associated device groups. If you attempt to delete a product that does, the API will issue an error, which the BuildAPIAccess instance will relay to the host app.

The instance posts the notification `@"BuildAPIProductDeleted"` when the product has been deleted.

### - (void)createDevicegroup:(NSDictionary *)details ###

Creates a device group with the settings specified as the *details* dictionary’s key-value pairs. Allowed keys are *name*, *description*, *type*, *"targetid* and *productid*. The keys’ values are also strings. The first and last of these are mandatory, and must not be nil or of zero length. See the [impCentral API documentation](https://preview-apidoc.electricimp.com/) for allowed types; BuildAPIAccess defaults to `@"development_devicegroup"` if no type is provided.

The values of *name* and *description* are limited by the API to 80 and 255 characters, respectively; the method will tail the supplied strings to ensure this limit is adhered to. The name may not be nil and must be at least one character in length. The description may be nil or an empty string.

The value of *targetid* is the ID of a production device group and can be omitted if the device group being created is of neither factoryfixture or pre_factoryfixture type.

The instance posts the notification `@"BuildAPIDeviceGroupCreated"` when the device group has been created. The notification includes an NSDictionary: its *data* key points to a record of the new device group as an NSDictionary.

### - (void)updateDevicegroup:(NSString *)devicegroupID :(NSString *)keys :(NSString *)values ###

Updates the specified device group using the supplied keys and their associated values. The order of items in the keys and values arrays should match; no check is made to ensure that this is the case. The method checks that the two arrays are of equal length, however. The only supported keys are *name*, *description*, *type*, *production_target* and *load_code_after_blessing*. The first three of these reference strings; *production_target* references a dictionary with the keys *id* (the ID of the target production device group) and *type* (the string `@"production_devicegroup"`); and *load_code_after_blessing* references an NSNumber created from a boolean value.

The instance posts the notification `@"BuildAPIDeviceGroupUpdated"` when the device group has been updated. The notification includes an NSDictionary: its *data* key points to a record of the updated device group as an NSDictionary.

### - (void)deleteDevicegroup:(NSString *)devicegroupID ###

Deletes the device group of the specified ID. Device groups cannot be deleted if they have assigned devices. If you attempt to delete a device group that does, the API will issue an error, which the BuildAPIAccess instance will relay to the host app.

The instance posts the notification `@"BuildAPIDeviceGroupDeleted"` when the device group has been deleted.

### - (void)updateDevice:(NSString *)deviceID :(NSString *)name ###

Updates the specified device group using the supplied name values. Name may be `nil` &mdash; this removes the device’s name, if it has one.

The instance posts the notification `@"BuildAPIDeviceUpdated"` when the product has been updated. The notification includes an NSDictionary: its *data* key points to a record of the updated device as an NSDictionary.

### - (void)deleteDevice:(NSDictionary *)device ###

Removes the specified development device from the account to which it is currently assigned. Production devices cannot be deleted.

The instance posts the notification `@"BuildAPIDeviceDeleted"` when the device has been deleted.

### - (void)createDeployment:(NSDictionary *)deployment ###

Creates a deployment with the settings specified as the *deployment* dictionary’s key-value pairs. The dictionary’s keys and values should match those expected by the impCentral API.

The instance posts the notification `@"BuildAPIDeploymentCreated"` when the deployment has been created. The notification includes an NSDictionary: its *data* key points to a record of the new deployment as an NSDictionary.

### - (void)updateDeployment:(NSString *)deploymentID :(NSArray *)keys :(NSArray *)values ###

Updates the specified deployment using the supplied keys and their associated values. The order of items in the keys and values arrays should match; no check is made to ensure that this is the case. The method checks that the two arrays are of equal length, however. The only supported keys are *description* and *flagged*.

The instance posts the notification `@"BuildAPIDeploymentUpdated"` when the deployment has been updated. The notification includes an NSDictionary: its *data* key points to a record of the updated deployment as an NSDictionary.

### - (void)deleteDeployment:(NSString *)deploymentID ###

Deletes the deployment of the specified ID. Deployments cannot be deleted if the deployment is flagged, or it is a device group's most recent deployment. If you attempt to delete a deployment that meets either of these criteria, the API will issue an error, which the BuildAPIAccess instance will relay to the host app.

The instance posts the notification `@"BuildAPIDeploymentDeleted"` when the device group has been deleted.

## Class Methods: Other Actions ##

### - (void)restartDevices:(NSString *)devicegroupID ###

Restarts all of the devices that are assigned to the specified device group. The instance posts the notification `@"BuildAPIDeviceGroupRestarted"` when all the devices has been instructed to restart. Note that not all devices will restart there and then as this depends upon their connection status.

### - (void)restartDevice:(NSString *)deviceID ###

Restarts the specified device. The instance posts the notification `@"BuildAPIDeviceRestarted"` when the device has been instructed to restart. Note that the device may not restart there and then as this depends upon its connection status.

### - (void)unassignDevice:(NSDictionary *)device ###

Removes a device from its assigned device group and leaves it in an unassigned state. The device is specified using a dictionary which matches the standard impCentral device record (see [the impCentral API reference](https://preview-apidoc.electricimp.com/#tag/Devices)).

The instance posts the notification `@"BuildAPIDeviceUnassigned"` when the device has been unassigned.

### - (void)unassignDevices:(NSArray *)devices ###

Removes a set of devices from their assigned device group (singular) and leaves them in an unassigned state. Each device is specified using a dictionary which matches the standard impCentral device record (see [the impCentral API reference](https://preview-apidoc.electricimp.com/#tag/Devices)), all provided to the method as an array.

Note that the method checks for already unassigned devices based on the information in the impCentral device records passed in. It also notes the first referenced device group &mdash; this is the device group from which all other devices will be unassigned. Any devices included which are not already assigned to this device group will be ignored.

The instance posts the notification `@"BuildAPIDevicesUnassigned"` when the device has been unassigned.

### - (void)assignDevice:(NSMutableDictionary *)device :(NSString *)devicegroupID ###

Assigns the specified device to the specified device group. The device is specified using a dictionary which matches the standard impCentral device record (see [the impCentral API reference](https://preview-apidoc.electricimp.com/#tag/Devices)).

The instance posts the notification `@"BuildAPIDeviceAssigned"` when the device has been assigned.

### - (void)assignDevices:(NSArray *)devices :(NSString *)devicegroupID ###

Assigns the specified devices to the specified device group. Each device is specified using a dictionary which matches the standard impCentral device record (see [the impCentral API reference](https://preview-apidoc.electricimp.com/#tag/Devices)); these records are added to an array, which is passed into the method.

The instance posts the notification `@"BuildAPIDevicesAssigned"` when the device has been assigned.

## Class Methods: Logging ##

### - (void)startLogging:(NSString *)deviceID ###

Adds the specified device (by its ID) to the list of devices for which streamed log entries are being received. If no stream is in place, BuildAPIAccess will set one up. The instance posts the notification `@"BuildAPIDeviceAddedToStream"` when the device has been added to the stream. The notification's object is a dictionary containing the key *device* &mdash; its value is the added device’s ID.

The instance also posts the notification `@"BuildAPILogEntryReceived"` when a log entry has been received. The log entry is passed as the notification’s object, which is a dictionary with the keys *message* and *code*. The former is the raw log entry data, which will be in the form:

```
"232390b030728cee 2017-05-19T17:28:19.095Z development server.log Connected by WiFi on SSID \"darkmatter\" with IP address 192.168.0.2"
```

The *code* key is only present in the case of an error; the value of *message* will then be an error message. Errors are relayed via the notification `@"BuildAPILogStreamClosed"`.

### - (void)stopLogging:(NSString *)deviceID ###

Removes the specified device (by its ID) from the list of devices for which streamed log entries are being received. The instance posts the notification `@"BuildAPIDeviceRemovedFromStream"` when the device has been added to the stream. The notification's object is a dictionary containing the key *device* &mdash; its value is the added device’s ID.

Relays the notification `@"BuildAPILogStreamClosed"` to the host app if logging is terminated because of a connection error.

### - (BOOL)isDeviceLogging:(NSString *)deviceID ###

Returns `YES` if the supplied device ID is that of a device which is currently live-streaming log data, otherwise `NO`.

### - (void)killAllConnections ###

Immediately halt all in-flight connections to the impCentral API, including log streams.

## Class Methods: Processing Connections ##

### - (NSDictionary *)processConnection:(Connexion *)connexion ###

When a connection to impCentral API returns, it is processed here. Its data payload is decoded. Any data-centric error conditions, eg. a request for a non-existent resource, a permissions error, or errors relayed by the impCloud's Squirrel syntax checker, are handled here. Valid data is passed to *processResult:* for further processing.

### - (void)processResult:(Connexion *)connexion :(NSDictionary *)data ###

Processes any valid data returned by the impCentral API and stores it in relevant internal arrays and other variables. It also issues asynchronous notifications to the host app to provide it with the information it has requested, in the form of dictionaries derived from the API-supplied data.

## Class Methods: Utilities ##

### - (void)reportError ###

Issue the contents of the *errorMessage* property to the host app as a simple error via the notification `@"BuildAPIError"`. The error is passed as a dictionary with the key *message*.

### - (void)reportError:(NSInteger)errCode ###

Issue the contents of the *errorMessage* property with an associated error code to the host app as a simple error via the notification `@"BuildAPIError"`. The error is passed as a dictionary with the keys *message* and *code*. The latter is an NSNumber with the value of *errCode*.

### - (NSString *)processAPIError:(NSDictionary *)error ###

Extracts key information from an impCentral API error record and formats it into a string for relay to the host app via *reportError:*.

### - (BOOL)checkFilter:(NSString *)filter :(NSArray *)validFilters ###

Returns `YES` if the supplied filter (a string) is included in the array of valid filters (also strings), otherwise `NO`.

### - (NSString *)encodeBase64String:(NSString *)plainString ###

Converts and returns the supplied plain-text string to Base64 encoding.

### - (NSString *)decodeBase64String:(NSString *)base64String ###

Converts and returns the supplied Base64-encoded string to plain text.
