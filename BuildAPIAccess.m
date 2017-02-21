
//  Copyright (c) 2015-17 Tony Smith. All rights reserved.
//  Issued under the MIT licence

//  BuildAPIAccess 3.0.0


#import "BuildAPIAccess.h"


@implementation BuildAPIAccess


@synthesize models, deviceCode, agentCode;
@synthesize codeErrors, numberOfConnections;

@synthesize products, deviceGroups, deployments, currentDeployment, devices, errorMessage, statusMessage;
@synthesize loggedInFlag;

#pragma mark - Initialization Methods


- (instancetype)init
{
    // Generic initializer - should not be called directly

    if (self = [super init])
    {
        // Public entities

        devices = [[NSMutableArray alloc] init];
        products = [[NSMutableArray alloc] init];
		deviceGroups = [[NSMutableArray alloc] init];
		deployments = [[NSMutableArray alloc] init];

        errorMessage = @"";
		loggedInFlag = NO;

		currentDeployment = nil;

        // Private entities

        _connexions = [[NSMutableArray alloc] init];
		_loggingDevices = [[NSMutableArray alloc] init];
        _lastStamp = nil;
        _logURL = nil;
        _username = nil;
		_password = nil;
        _useSessionFlag = YES;
		_pagesize = 50;
		_pagesizeChangeFlag = YES;

		_baseURL = [kBaseAPIURL stringByAppendingString:kAPIVersion];

		NSOperatingSystemVersion sysVer = [[NSProcessInfo processInfo] operatingSystemVersion];
		_userAgent = [NSString stringWithFormat:@"BuildAPIAccess/%@ %@/%@.%@ (macOS %li.%li.%li)", kBuildAPIAccessVersion, [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
					  [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"], (long)sysVer.majorVersion, (long)sysVer.minorVersion, (long)sysVer.patchVersion];
    }

    return self;
}


#pragma mark - Login Methods

- (void)login:(NSString *)username :(NSString *)password
{
	if (username.length == 0)
	{
		errorMessage = @"[ERROR] You must supply an Electric Imp account username or email address.";
		[self reportError];
		return;
	}

	if (password.length == 0)
	{
		errorMessage = @"[ERROR] You must supply an Electric Imp account password.";
		[self reportError];
		return;
	}

	_username = username;
	_password = password;

	[self getNewToken];
}


- (void)getNewToken
{
	if (!_username || !_password)
	{
		errorMessage = @"[ERROR] Missing Electric Imp credentials — cannot log in without username or email address, and password.";
		[self reportError];
		return;
	}

	// Set up a POST request to the /account/login URL to get session token
	// Need unique code here as we do not use the authentication method used by the API

	NSString *post = [NSString stringWithFormat:@"email=%@&password=%@", _username, _password];
	NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:NO];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[kBaseAPIURL stringByAppendingString:@"/account/login"]]];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	[request setHTTPMethod:@"POST"];
	[request setValue:_userAgent forHTTPHeaderField:@"User-Agent"];
	[request setHTTPBody:postData];

	if (request)
	{
		[self launchConnection:request :kConnectTypeGetToken];
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to retrieve a new session token.";
		[self reportError];
	}
}


- (BOOL)checkToken
{
	if (!_token)
	{
		// We do not have a token, return error

		return NO;
	}

	NSString *ds = [_token objectForKey:@"expires"];
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	NSDate *expiry = [dateFormatter dateFromString:ds];
	NSDate *now = [NSDate date];

	if ([now compare:expiry] == NSOrderedDescending)
	{
		// The token has expired, so return error
		return NO;
	}

	return YES;
}


#pragma mark - Pagination Methods

- (void)setPageSize:(NSInteger)size
{
	if (size == _pagesize) return;
	if (size < 1) size = 1;
	if (size > 100) size = 100;
	_pagesize = size;
	_pagesizeChangeFlag = YES;
}



- (void)getDevices
{
    // Set up a GET request to the /devices URL - gets all devices

    NSMutableURLRequest *request = [self makeGETrequest:[_baseURL stringByAppendingString:@"devices"]];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetDevices];
    }
    else
    {
        errorMessage = @"[ERROR] Could not create a request to list your devices.";
        [self reportError];
    }
}



- (void)getCode:(NSString *)modelID
{
    // Set up a GET request to the /models/[id]/revisions URL

    if (modelID == nil || modelID.length == 0)
    {
        errorMessage = @"[ERROR] Could not create a request to get the model's current code build: invalid model ID.";
        [self reportError];
        return;
    }

    NSString *urlString = [_baseURL stringByAppendingFormat:@"models/%@/revisions", modelID];
    NSMutableURLRequest *request = [self makeGETrequest:urlString];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetCodeLatestBuild];
        _currentModelID = modelID;
    }
    else
    {
        errorMessage = @"[ERROR] Could not create a request to get the model's current code build.";
        [self reportError];
    }
}



- (void)getCodeRev:(NSString *)modelID :(NSInteger)build
{
    // Set up a GET request to the /models/[id]/revisions/[build] URL

    if (modelID == nil || modelID.length == 0)
    {
        errorMessage = @"[ERROR] Could not create a request to get the required code build: invalid model ID.";
        [self reportError];
        return;
    }

    if (build < 1)
    {
        errorMessage = @"[ERROR] Could not create a request to get the required code build: invalid build number.";
        [self reportError];
        return;
    }

    NSString *urlString = [_baseURL stringByAppendingFormat:@"models/%@/revisions/%li", modelID, (long)build];
    NSMutableURLRequest *request = [self makeGETrequest:urlString];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetCodeRev];
    }
    else
    {
        errorMessage = @"[ERROR] Could not create a request to get the required code build.";
        [self reportError];
    }
}



- (void)getLogsForDevice:(NSString *)deviceID :(NSString *)since :(BOOL)isStream
{
    // Set up a GET request to the /device/[id]/logs URL

    if (deviceID == nil || deviceID.length == 0)
    {
        errorMessage = @"[ERROR] Could not create a request to get logs from the device: invalid device ID.";
        [self reportError];
        return;
    }

	NSMutableDictionary *logDevice;
    NSString *urlString = [_baseURL stringByAppendingFormat:@"devices/%@/logs", deviceID];
    NSInteger action = kConnectTypeNone;

    if (isStream)
    {
		BOOL match = NO;
		action = kConnectTypeGetLogEntriesRanged;

		if (_loggingDevices.count > 0)
		{
			for (NSMutableDictionary *aLogDevice in _loggingDevices)
			{
				NSString *devID = [aLogDevice objectForKey:@"id"];

				if ([devID compare:deviceID] == NSOrderedSame)
				{
					// Device ID is already on the list, so note that
					match = YES;
					break;
				}
			}
		}

		if (!match)
		{
			// DeviceID is not already on the list of logging devices, so add it

			NSArray *keys = [NSArray arrayWithObjects:@"id", @"url", nil];
			NSArray *values = [NSArray arrayWithObjects:deviceID, @"*", nil];
			logDevice = [NSMutableDictionary dictionaryWithObjects:values forKeys:keys];
		}
		else
		{
			// Requested streaming device is already present so bail

			for (NSMutableDictionary *device in devices)
			{
				NSString *devID = [device objectForKey:@"id"];

				if ([devID compare:deviceID] == NSOrderedSame)
				{
					errorMessage = [NSString stringWithFormat:@"[ERROR] You are already logging device \"%@\".", [device objectForKey:@"name"]];
					[self reportError];
					break;
				}
			}

			return;
		}
    }
    else
    {
        action = kConnectTypeGetLogEntries;
        if ([since compare:@""] != NSOrderedSame) urlString = [urlString stringByAppendingFormat:@"?since=%@", since];
    }

    NSMutableURLRequest *request = [self makeGETrequest:urlString];

	if (request)
	{
		Connexion *aConnexion = [self launchConnection:request :action];

		if (aConnexion)
		{
			// Initial request for logs (from which we get the poll URL) sent successfully
			// so update the logging device's connection record

			if (isStream)
			{
				[logDevice setObject:aConnexion forKey:@"connection"];
				[_loggingDevices addObject:logDevice];
			}
		}
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to get logs from the device.";
		[self reportError];
	}
}



#pragma mark Data Request Methods (v5 API)

- (void)getProducts
{
	// Set up a GET request to /products

	NSMutableURLRequest *request = [self makeGETrequest:[_baseURL stringByAppendingString:@"products"]];

	if (request)
	{
		[self launchConnection:request :kConnectTypeGetProducts];
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to list your products.";
		[self reportError];
	}
}



- (void)getProducts:(BOOL)withDeviceGroups
{
	_followOnFlag = withDeviceGroups;
	[self getProducts];
}



- (void)getDeviceGroups
{
	// Set up a GET request to /device_groups

	NSMutableURLRequest *request = [self makeGETrequest:[_baseURL stringByAppendingString:@"devicegroups"]];

	if (request)
	{
		[self launchConnection:request :kConnectTypeGetDeviceGroups];
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to list your device groups.";
		[self reportError];
	}
}



- (void)getDeployments
{
	// Set up a GET request to /deployments

	NSMutableURLRequest *request = [self makeGETrequest:[_baseURL stringByAppendingString:@"deployments"]];

	if (request)
	{
		[self launchConnection:request :kConnectTypeGetDeployments];
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to get current deployments.";
		[self reportError];
	}
}



- (void)getDeployment:(NSString *)deploymentID
{
	// Set up a GET request to /deployments/[id]

	NSMutableURLRequest *request = [self makeGETrequest:[_baseURL stringByAppendingFormat:@"deployments/%@", deploymentID]];

	if (request)
	{
		[self launchConnection:request :kConnectTypeGetDeployment];
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to get the required deployment.";
		[self reportError];
	}
}



#pragma mark - Action Methods


- (void)createNewModel:(NSString *)modelName
{
    // Set up a POST request to the /models URL - we'll post the new model there

    if (modelName == nil || modelName.length == 0)
    {
        errorMessage = @"[ERROR] Could not create a request to create the new model: invalid model name.";
        [self reportError];
        return;
    }

    NSDictionary *dict = [self makeDictionary:@"name" :modelName];
    NSMutableURLRequest *request = [self makePOSTrequest:[_baseURL stringByAppendingString:@"models"] :dict];

    if (request)
    {
        [self launchConnection:request :kConnectTypeNewModel];
    }
    else
    {
        errorMessage = @"[ERROR] Could not create a request to create the new model.";
        [self reportError];
    }
}



- (void)updateModel:(NSString *)modelID :(NSString *)key :(NSString *)value
{
    // Make a PUT request to send the change

    if (modelID == nil || modelID.length == 0)
    {
        errorMessage = @"[ERROR] Could not create a request to update the model: invalid model ID.";
        [self reportError];
        return;
    }

    if (key == nil || key.length == 0)
    {
        // Malformed key? Report error and bail

        errorMessage = @"[ERROR] Could not create a request to update the model: invalid data field name.";
        [self reportError];
        return;
    }

    // Put the new name into the dictionary to pass to the API

    NSDictionary *newDict = [self makeDictionary:key :value];
    NSMutableURLRequest *request = [self makePUTrequest:[_baseURL stringByAppendingFormat:@"models/%@", modelID] :newDict];

    if (request)
    {
        [self launchConnection:request :kConnectTypeUpdateModel];
    }
    else
    {
        errorMessage = @"[ERROR] Could not create a request to update the model.";
        [self reportError];
    }
}



- (void)deleteModel:(NSString *)modelID
{
    // Set up a DELETE request to the /models/[id]

    if (modelID == nil || modelID.length == 0)
    {
        errorMessage = @"[ERROR] Could not create a request to delete the model: invalid model ID.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makeDELETErequest:[_baseURL stringByAppendingFormat:@"models/%@", modelID]];

    if (request)
    {
        [self launchConnection:request :kConnectTypeDeleteModel];
    }
    else
    {
        errorMessage = @"[ERROR] Could not create a request to delete the model.";
        [self reportError];
    }
}



- (void)uploadCode:(NSString *)modelID :(NSString *)newDeviceCode :(NSString *)newAgentCode
{
    // Set up a POST request to the /models/[ID]/revisions URL - we'll post the new code there

    if (modelID == nil || modelID.length == 0)
    {
        errorMessage = @"[ERROR] Could not create a request to upload the code: invalid model ID.";
        [self reportError];
        return;
    }

    // Replace nil code parameters with empty strings

    if (newDeviceCode == nil) newDeviceCode = @"";
    if (newAgentCode == nil) newAgentCode = @"";

    // Put the new code into a dictionary

    NSArray *keys = [NSArray arrayWithObjects:@"agent_code", @"device_code", nil];
    NSArray *values = [NSArray arrayWithObjects:newAgentCode, newDeviceCode, nil];
    NSDictionary *dict = [NSDictionary dictionaryWithObjects:values forKeys:keys];

    // Make the POST request to send the code

    NSString *urlString = [@"models/" stringByAppendingString:modelID];
    urlString = [urlString stringByAppendingString:@"/revisions"];
    NSMutableURLRequest *request = [self makePOSTrequest:[_baseURL stringByAppendingString:urlString] :dict];

    if (request)
    {
        [self launchConnection:request :kConnectTypePostCode];
    }
    else
    {
        errorMessage = @"[ERROR] Could not create a request to upload the code to the model.";
        [self reportError];
    }
}



- (void)assignDevice:(NSString *)deviceID toModel:(NSString *)modelID
{
    // Set up a PUT request to assign a device to a model

    if (modelID == nil || modelID.length == 0)
    {
        errorMessage = @"[ERROR] Could not create a request to assign the device: invalid model ID.";
        [self reportError];
        return;
    }

    if (deviceID == nil || deviceID.length == 0)
    {
        errorMessage = @"[ERROR] Could not create a request to assign the device: invalid device ID.";
        [self reportError];
        return;
    }

    NSString *urlString = [@"devices/" stringByAppendingString:deviceID];

    // Put the new model ID into the dictionary to pass to the API

    NSDictionary *dict = [self makeDictionary:@"model_id" :modelID];

    // Make the PUT request to send the change

    NSMutableURLRequest *request = [self makePUTrequest:[_baseURL stringByAppendingString:urlString] :dict];

    if (request)
    {
        [self launchConnection:request :kConnectTypeAssignDeviceToModel];
    }
    else
    {
        errorMessage = @"[ERROR] Could not create a request to assign the device.";
        [self reportError];
    }
}



- (void)restartDevice:(NSString *)deviceID
{
    // Set up a POST request to the /devices/[ID]/restart URL - updates device with an unchanged model_id

    if (deviceID == nil || deviceID.length == 0)
    {
        errorMessage = @"[ERROR] Could not create a request to restart the device: invalid device ID.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makePOSTrequest:[_baseURL stringByAppendingFormat:@"devices/%@/restart", deviceID] :nil];

    if (request)
    {
        [self launchConnection:request :kConnectTypeRestartDevice];
    }
    else
    {
        errorMessage = @"[ERROR] Could not create a request to restart the device.";
        [self reportError];
    }
}



- (void)restartDevices:(NSString *)modelID
{
    // Set up a POST request to the /models/[ID] URL - gets all models

    if (modelID == nil || modelID.length == 0)
    {
        errorMessage = @"[ERROR] Could not create a request to restart all the model’s device: invalid model ID.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makePOSTrequest:[_baseURL stringByAppendingFormat:@"models/%@/restart", modelID] :nil];

    if (request)
    {
        [self launchConnection:request :kConnectTypeRestartDevice];
    }
    else
    {
        errorMessage = @"[ERROR] Could not create a request to restart all the model’s devices.";
        [self reportError];
    }
}



- (void)deleteDevice:(NSString *)deviceID
{
    // Set up a DELETE request to the /devices/[id]

    if (deviceID == nil || deviceID.length == 0)
    {
        errorMessage = @"[ERROR] Could not create a request to delete the device: invalid device ID.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makeDELETErequest:[_baseURL stringByAppendingFormat:@"devices/%@", deviceID]];

    if (request)
    {
        [self launchConnection:request :kConnectTypeDeleteDevice];
    }
    else
    {
        errorMessage = @"[ERROR] Could not create a request to delete the device.";
        [self reportError];
    }
}



- (void)updateDevice:(NSString *)deviceID :(NSString *)key :(NSString *)value
{
    // Make the PUT request to send the change

    if (deviceID == nil || deviceID.length == 0)
    {
        errorMessage = @"[ERROR] Could not create a request to update the device: invalid device ID.";
        [self reportError];
        return;
    }

    if (key == nil || key.length == 0)
    {
        // Malformed key? Report error and bail

        errorMessage = @"[ERROR] Could not create a request to update the device: invalid device property.";
        [self reportError];
        return;
    }

    // Put the new name into the dictionary to pass to the API

    NSDictionary *newDict = [self makeDictionary:key :value];
    NSMutableURLRequest *request = [self makePUTrequest:[_baseURL stringByAppendingFormat:@"devices/%@", deviceID] :newDict];

    if (request)
    {
        // TODO - add special case for unassigning a device kConnectTypeUnassignDevice

        [self launchConnection:request :kConnectTypeUpdateDevice];
    }
    else
    {
        errorMessage = @"[ERROR] Could not create a request to update the device.";
        [self reportError];
    }
}



- (void)autoRenameDevice:(NSString *)deviceID
{
    // This method should be used SOLELY to change the name of new, unassigned device
    // from <NULL> to their own id. It is called when the devices are listed

    // Put the new name (which matches id) into the dictionary to pass to the API

    NSDictionary *newDict = [self makeDictionary:@"name" :deviceID];

    // Make the PUT request to send the change

    NSMutableURLRequest *request = [self makePUTrequest:[_baseURL stringByAppendingFormat:@"devices/%@", deviceID] :newDict];

    if (request)
    {
        [self launchConnection:request :kConnectTypeUpdateDevice];
    }
    else
    {
        errorMessage = @"[ERROR] Could not create a request to auto-rename the device.";
        [self reportError];
    }
}



#pragma mark Action Methods 9(v5 API)

- (void)newProduct:(NSString *)name :(NSString *)description
{
	// Set up a POST request to /products

	if (name == nil || name.length == 0)
	{
		errorMessage = @"[ERROR] Could not create a request to create the new product: invalid product name.";
		[self reportError];
		return;
	}

	if (description == nil) description = @"";

	NSArray *keys = [NSArray arrayWithObjects:@"name", @"descripton", nil];
	NSArray *vals = [NSArray arrayWithObjects:name, description, nil];
	NSDictionary *pDictionary = [NSDictionary dictionaryWithObjects:vals forKeys:keys];
	NSMutableURLRequest *request = [self makePOSTrequest:[_baseURL stringByAppendingString:@"products"] :pDictionary];

	if (request)
	{
		[self launchConnection:request :kConnectTypeNewProduct];
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to create the new product.";
		[self reportError];
	}
}



- (void)updateProduct:(NSString *)productID :(NSString *)key :(NSString *)value
{
	// Set up a PATCH request to /products

	if (productID == nil || productID.length == 0)
	{
		errorMessage = @"[ERROR] Could not create a request to create the new product: invalid product ID.";
		[self reportError];
		return;
	}

	if (key == nil || value.length == 0)
	{
		errorMessage = @"[ERROR] Could not create a request to create the new product: data field name.";
		[self reportError];
		return;
	}

	NSDictionary *pDictionary = [self makeDictionary:key :value];
	NSMutableURLRequest *request = [self makePATCHrequest:[_baseURL stringByAppendingFormat:@"products/%@", productID] :pDictionary];

	if (request)
	{
		[self launchConnection:request :kConnectTypeUpdateProduct];
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to create the new product.";
		[self reportError];
	}
}



#pragma mark - Logging Methods


- (void)startLogging:(NSString *)deviceID
{
	if (deviceID.length == 0 || deviceID == nil) return;

	NSString *logURL;
	NSMutableDictionary *logDevice;
	BOOL match = NO;

	for (NSMutableDictionary *aLogDevice in _loggingDevices)
	{
		NSString *devID = [aLogDevice objectForKey:@"id"];

		if ([deviceID compare:devID] == NSOrderedSame)
		{
			// We've found the record for the logging device, so check we
			// have a valid poll URL

			logURL = [aLogDevice objectForKey:@"url"];

			if ([logURL compare:@"*"] == NSOrderedSame)
			{
				// We don't have a poll URL yet, so get one

				[self getLogsForDevice:deviceID :@"" :YES];
				return;
			}
			else
			{
				match = YES;
				logDevice = aLogDevice;
				break;
			}
		}
	}

	if (!match)
	{
		// The device ID is not on the list so assume the user wants it to be, so add it

		[self getLogsForDevice:deviceID :@"" :YES];
		return;
	}

	// Assemble and send a request for logs to the now-retrieved poll URL

	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:logURL] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:3600.0];

	if (request)
	{
		[self setRequestAuthorization:request];
		Connexion *aConnexion = [self launchConnection:request :kConnectTypeGetLogEntriesStreamed];

		if (aConnexion)
		{
			// The request for logs from the specified device has been successfully
			// sent, so add the connection to the the device’s record (which is
			// already in the '_loggingDevices' list)

			[logDevice setObject:aConnexion forKey:@"connection"];
		}
		else
		{
			// Could not launch the connection for some reason,
			// so remove the specified device from the list of devices
			// currently being streamed

			[_loggingDevices removeObject:logDevice];
		}
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to start or continue logging.";
		[self reportError];
		[_loggingDevices removeObject:logDevice];
	}
}


- (void)stopLogging:(NSString *)deviceID
{
	// There's no logging going on, or no connections, so bail

	if (_connexions.count == 0 || _loggingDevices.count == 0) return;

	Connexion *conn = nil;

	if (deviceID.length == 0 || deviceID == nil)
	{
		// No device ID passed in, so clear *all* logging devices and the connections

		for (NSMutableDictionary *aLogDevice in _loggingDevices)
		{
			for (Connexion *aConnexion in _connexions)
			{
				if (aConnexion.actionCode == kConnectTypeGetLogEntriesStreamed || aConnexion.actionCode == kConnectTypeGetLogEntriesRanged)
				{
					if (aConnexion == (Connexion *)[aLogDevice objectForKey:@"connection"])
					{
						[aConnexion.task cancel];

						// Recall the connexion so we don't mutate the array we're enumerating

						conn = aConnexion;
					}
				}
			}

			if (conn)
			{
				// We noted a connexion to clear, so remove it

				[_connexions removeObject:conn];
				numberOfConnections = _connexions.count;
				conn = nil;
			}
		}

		// Clear the list of logging devices

		[_loggingDevices removeAllObjects];
	}
	else
	{
		// A device ID was passed in so just clear this device from the logging list

		NSMutableDictionary *deviceToRemove = nil;
		BOOL match = NO;

		for (NSMutableDictionary *aLogDevice in _loggingDevices)
		{
			NSString *devID = [aLogDevice objectForKey:@"id"];

			if ([deviceID compare:devID] == NSOrderedSame)
			{
				match = YES;
				deviceToRemove = aLogDevice;
				break;
			}
		}

		if (match)
		{
			[_loggingDevices removeObject:deviceToRemove];

			// Check through the connection list for log streaming connections,
			// and of those that are, find the one that's linked to the logging
			// device we want to remove...

			Connexion *conn = nil;

			for (Connexion *aConnexion in _connexions)
			{
				if (aConnexion.actionCode == kConnectTypeGetLogEntriesStreamed || aConnexion.actionCode == kConnectTypeGetLogEntriesRanged)
				{
					if (aConnexion == [deviceToRemove objectForKey:@"connection"])
					{
						// ...and remove its connection

						[aConnexion.task cancel];
						conn = aConnexion;
					}
				}
			}

			[_connexions removeObject:conn];
			numberOfConnections = _connexions.count;
		}
	}

	if (_connexions.count < 1) [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStop" object:nil];
}



- (BOOL)isDeviceLogging:(NSString *)deviceID
{
	if ([self indexForID:deviceID] != -1) return YES;
	return NO;
}



- (NSInteger)indexForID:(NSString *)deviceID
{
	NSInteger index = -1;

	if (_loggingDevices.count > 0)
	{
		for (NSUInteger i = 0 ; i < _loggingDevices.count ; ++i)
		{
			NSMutableDictionary *aLogDevice = [_loggingDevices objectAtIndex:i];
			NSString *aDevID = [aLogDevice objectForKey:@"id"];

			if ([aDevID compare:deviceID] == NSOrderedSame)
			{
				index = i;
				break;
			}
		}
	}

	return index;
}



- (NSUInteger)loggingCount
{
	return _loggingDevices.count;
}



#pragma mark - HTTP Request Construction Methods


- (NSMutableURLRequest *)makeGETrequest:(NSString *)path
{
    return [self makeRequest:@"GET" :path];
}



- (NSMutableURLRequest *)makePOSTrequest:(NSString *)path :(NSDictionary *)bodyDictionary
{
    NSError *error = nil;

    NSMutableURLRequest *request = [self makeRequest:@"POST" :path];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    if (bodyDictionary) [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:bodyDictionary options:0 error:&error]];

    if (error)
    {
        return nil;
    }
    else
    {
        return request;
    }
}



- (NSMutableURLRequest *)makePUTrequest:(NSString *)path :(NSDictionary *)bodyDictionary
{
    NSError *error = nil;

    NSMutableURLRequest *request = [self makeRequest:@"PUT" :path];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:bodyDictionary options:0 error:&error]];

    if (error)
    {
        return nil;
    }
    else
    {
        return request;
    }
}



- (NSMutableURLRequest *)makeDELETErequest:(NSString *)path
{
    return [self makeRequest:@"DELETE" :path];
}



- (NSMutableURLRequest *)makePATCHrequest:(NSString *)path :(NSDictionary *)bodyDictionary
{
	NSError *error = nil;

	NSMutableURLRequest *request = [self makeRequest:@"PATCH" :path];
	[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

	if (bodyDictionary) [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:bodyDictionary options:0 error:&error]];

	if (error)
	{
		return nil;
	}
	else
	{
		return request;
	}
}



#pragma mark - Connection Methods


- (Connexion *)launchConnection:(NSMutableURLRequest *)request :(NSInteger)actionCode
{
    // Create a default connexion object to store the details of the connection
	// we're about to initiate

    Connexion *aConnexion = [[Connexion alloc] init];
    aConnexion.actionCode = actionCode;
    aConnexion.data = [NSMutableData dataWithCapacity:0];

    // Use NSURLSession for the connection. Compatible with iOS, tvOS and Mac OS X

	NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
														  delegate:self
													 delegateQueue:[NSOperationQueue mainQueue]];
	aConnexion.task = [session dataTaskWithRequest:request];

	// Check that we have a valid session token - we can't proceed without one
	// If we are not logged in, we won't have a token so we need to let the check
	// pass so that a token is retrieved in the first place

	if ([self checkToken] || !loggedInFlag)
	{
		// We have a valid token so proceed with the connection

		[aConnexion.task resume];

		if (_connexions.count == 0)
		{
			// Notify the main app to trigger the progress indicator

			[[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStart" object:nil];
		}

		// Add the new connection to the list

		[_connexions addObject:aConnexion];
		numberOfConnections = _connexions.count;
	}
	else
	{
		// We do not have a valid token

		if (_pendingConnections == nil) _pendingConnections = [[NSMutableArray alloc] init];

		if (_pendingConnections.count == 0)
		{
			// We have no queued connections, so get a new token

			[self getNewToken];
		}

		[_pendingConnections addObject:aConnexion];
	}

	return aConnexion;
}



- (void)killAllConnections
{
	if (_connexions.count > 0)
	{
		// There are connections that we need to terminate

		if (_loggingDevices.count > 0)
		{
			// There are devices for which we are streaming logs, so clear the list...

			NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
			NSArray *loggingDevices = [_loggingDevices copy];
			[_loggingDevices removeAllObjects];

			// ...and notify the host for each device

			for (NSMutableDictionary *loggingDevice in loggingDevices)
			{
				[nc postNotificationName:@"BuildAPILogStreamEnd" object:[loggingDevice objectForKey:@"id"]];
			}
		}

		// Kill the remaining connections

		for (Connexion *aConnexion in _connexions)
		{
			[aConnexion.task cancel];
		}

		[_connexions removeAllObjects];
		numberOfConnections = _connexions.count;
	}
}



#pragma mark - NSURLSession Connection Delegate Methods


- (void)URLSession:(NSURLSession *)session
		  dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
	// This delegate method is called when the server responds to the connection request
	// Use it to trap certain status codes

	NSHTTPURLResponse *rps = (NSHTTPURLResponse *)response;
	NSInteger code = rps.statusCode;

	if (code > 399)
	{
		// The API has responded with a status code that indicates an error

		if (code == 429)
		{
			// Build API rate limit hit

			Connexion *conn = nil;

			for (Connexion *aConnexion in _connexions)
			{
				// Run through the connections in our list and add the incoming error code to the correct one
				// TODO support for logging connections

				if (aConnexion.task == dataTask)
				{
					// This request has been rate-limited, so we need to recall it in 1+ seconds

					NSArray *values = [NSArray arrayWithObjects:[dataTask.originalRequest copy], [NSNumber numberWithInteger:aConnexion.actionCode], nil];
					NSArray *keys = [NSArray arrayWithObjects:@"request", @"actioncode", nil];
					NSDictionary *dict =[NSDictionary dictionaryWithObjects:values forKeys:keys];
					[NSTimer scheduledTimerWithTimeInterval:1.1 target:self selector:@selector(relaunchConnection:) userInfo:dict repeats:NO];
					conn = aConnexion;
					break;
				}
			}

			if (conn != nil)
			{
				[_connexions removeObject:conn];
				numberOfConnections = _connexions.count;
			}

			completionHandler(NSURLSessionResponseCancel);
			return;
		}

		if (code == 504)
		{
			// Bad Gateway error received - this usually occurs during log streaming
			// so if we are streaming, make sure we re-initiate the stream

			Connexion *conn = nil;

			for (Connexion *aConnexion in _connexions)
			{
				if (aConnexion.task == dataTask) conn = aConnexion;
			}

			for (NSMutableDictionary *aLogDevice in _loggingDevices)
			{
				Connexion *aConnexion = (Connexion *)[aLogDevice objectForKey:@"connection"];

				if (conn == aConnexion)
				{
					[aLogDevice removeObjectForKey:@"connection"];
					[self startLogging:[aLogDevice objectForKey:@"id"]];
				}
			}
		}
		else
		{
			// All other 400-and-up error codes

			for (Connexion *aConnexion in _connexions) {

				// Run through the connections in our list and add the incoming error code to the correct one

				if (aConnexion.task == dataTask) aConnexion.errorCode = code;
			}
		}
	}

	// All the failed connection to complete so we can analyze it later

	completionHandler(NSURLSessionResponseAllow);
}



- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    // This delegate method is called when the server sends some data back
    // Add the data to the correct connexion object

    for (Connexion *aConnexion in _connexions)
    {
        // Run through the connections in our list and add the incoming data to the correct one

        if (aConnexion.task == dataTask) [aConnexion.data appendData:data];
    }
}



- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {

	// All the data has been supplied by the server in response to a connection - or an error has been encountered
	// Parse the data and, according to the connection activity - update device, create model etc – apply the results

	if (error)
	{
		// React to a passed client-side error - most likely a timeout or inability to resolve the URL
		// ie. the client is not connected to the Internet

		// 'error.code' will equal NSURLErrorCancelled when we kill all connections

		if (error.code == NSURLErrorCancelled) return;

		// Notify the host app

		errorMessage = @"[SERVER ERROR] Could not connect to the Electric Imp server.";
		[self reportError];

		// Is the connection related to a log stream?
		// If so record the device details as 'loggingDevice'

		NSMutableDictionary *loggingDevice = nil;
		for (NSMutableDictionary *aLogDevice in _loggingDevices)
		{
			Connexion *aConnexion = (Connexion *)[aLogDevice objectForKey:@"connection"];
			if (aConnexion.task == task) loggingDevice = aLogDevice;
		}

		if (loggingDevice)
		{
			// This call is prompted by a failed streaming log connection, so remove
			// the device from the list of streaming devices and notify the host app
			// NOTE don't call stopLogging: because we're about to cancel the connection like it does

			[_loggingDevices removeObject:loggingDevice];
			NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
			[nc postNotificationName:@"BuildAPILogStreamEnd" object:[loggingDevice objectForKey:@"id"]];
		}

		// Terminate the failed connection and remove it from the list of current connections

		Connexion *conn = nil;
		for (Connexion *aConnexion in _connexions)
		{
			// Run through the connections in the list and find the one that has just finished loading

			if (aConnexion.task == task)
			{
				[task cancel];
				conn = aConnexion;
				break;
			}
		}

		if (conn)
		{
			[_connexions removeObject:conn];
			numberOfConnections = _connexions.count;
		}

		// Check if there are any active connections

		if (_connexions.count < 1) [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStop" object:nil];

		return;
	}

	// The connection has come to a conclusion without error

	Connexion *currentConnexion;

	for (Connexion *aConnexion in _connexions)
	{
		// Run through the connections in the list and find the one that has just finished loading

		if (aConnexion.task == task) currentConnexion = aConnexion;
	}

	// End the finished connection and remove it from the list of current connections

	[task cancel];

	// If we have a valid action code, process the received data

	if (currentConnexion.actionCode != kConnectTypeNone) [self processResult:currentConnexion :[self processConnection:currentConnexion]];
}



#pragma mark - Joint NSURLSession/NSURLConnection Methods


- (NSDictionary *)processConnection:(Connexion *)connexion {

	// Process the data returned by the current connection. This comes independently
	// of whether the source was an NSURLSession or NSURLConncection.

	id parsedData = nil;
	NSError *dataDecodeError = nil;

	if (connexion.data != nil && connexion.data.length > 0)
	{
		// If we have data, attempt to decode it assuming that it is JSON (if it's not, 'error' will not equal nil

		parsedData = [NSJSONSerialization JSONObjectWithData:connexion.data options:kNilOptions error:&dataDecodeError];
	}

	if (dataDecodeError != nil)
	{
		// If the incoming data could not be decoded to JSON for some reason,
		// most likely a malformed request which returns a block of HTML

		// TODO?? Better interpret the HTML

		errorMessage = @"[SERVER ERROR] Received data could not be decoded. Is is JSON?";
		errorMessage = [errorMessage stringByAppendingFormat:@" %@", (NSString *)connexion.data];
		[self reportError];

		// Are we streaming?

		for (NSMutableDictionary *aLogDevice in _loggingDevices)
		{
			Connexion *devConnexion = [aLogDevice objectForKey:@"connection"];

			if (devConnexion == connexion)
			{
				[_loggingDevices removeObject:aLogDevice];
				NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
				[nc postNotificationName:@"BuildAPILogStreamEnd" object:[aLogDevice objectForKey:@"id"]];break;
			}
		}

		connexion.errorCode = -1;
		connexion.actionCode = kConnectTypeNone;
	}

	if (connexion.errorCode != -1)
	{
		// Check for an error being reported by the server. This will have been set for the current connection
		// by either of the didReceiveResponse: methods

		errorMessage = [NSString stringWithFormat:@"[SERVER ERROR] [Code: %lu] ", connexion.errorCode];

		if (parsedData != nil)
		{
			// 'parsedData' should contain a description of the error, eg. unknown device, or a code syntax error

			NSDictionary *errDict = [parsedData objectForKey:@"error"];
			NSString *errString = [errDict objectForKey:@"message_short"];
			errorMessage = [errorMessage stringByAppendingString:errString];

			if (connexion.errorCode == 400)
			{
				// Check for lapsed token errors

				NSRange eRange = [errString rangeOfString:@"Token may have expired" options:NSCaseInsensitiveSearch];

				if (eRange.location != NSNotFound)
				{
					// This IS a lapsed token. We need to restart logging for this device from scratch

					NSMutableDictionary *loggingDevice = nil;

					for (NSMutableDictionary *aLogDevice in _loggingDevices)
					{
						Connexion *aConnexion = (Connexion *)[aLogDevice objectForKey:@"connection"];

						if (aConnexion == connexion)
						{
							loggingDevice = aLogDevice;
							break;
						}
					}

					if (loggingDevice)
					{
						[_loggingDevices removeObject:loggingDevice];
						[self startLogging:[loggingDevice objectForKey:@"id"]];
						errorMessage = [errorMessage stringByAppendingFormat:@". Restarting log stream for device '%@'", [loggingDevice objectForKey:@"name"]];
					}
				}
			}

			errString = [errDict objectForKey:@"code"];

            if (codeErrors == nil)
            {
                codeErrors = [[NSMutableArray alloc] init];
            }
            else
            {
                [codeErrors removeAllObjects];
            }

			// Is the problem a code syntax error?

			if ([errString compare:@"CompileFailed"] == NSOrderedSame)
			{
				// The returned error description contains a 'message_short' field, if this key’s
				// value is 'CompileFailed', we have a syntax error in the (just) uploaded Squirrel

				errDict = [errDict objectForKey:@"details"];
				NSArray *aArray = nil;
				NSArray *dArray = nil;
				aArray = [errDict objectForKey:@"agent_errors"];
				dArray = [errDict objectForKey:@"device_errors"];

				// We have to check for [NSNull null] because this is how an empty
				// 'agent_errors' or 'device_errors' fields will be decoded

				if (aArray != nil && (NSNull *)aArray != [NSNull null])
				{
					// We have error(s) in the agent Squirrel - decode and report them

					errorMessage = [errorMessage stringByAppendingString:@"\n  Agent Code errors:"];

					for (NSUInteger j = 0 ; j < aArray.count ; ++j)
					{
						errDict = [aArray objectAtIndex:j];
						NSNumber *row = [errDict valueForKey:@"row"];
						NSNumber *col = [errDict valueForKey:@"column"];
						errorMessage = [errorMessage stringByAppendingFormat:@"\n  %@ at row %li, col %li", [errDict objectForKey:@"error"], row.longValue, col.longValue];

                        // Preserve the error details, and add extra keys - 'message' and 'type' -
                        // to the error record dictionary

                        NSMutableDictionary *aDict = [NSMutableDictionary dictionaryWithDictionary:errDict];
                        [aDict setObject:@"agent" forKey:@"type"];
                        [aDict setObject:[NSString stringWithFormat:@"\n  %@ at row %li, col %li", [errDict objectForKey:@"error"], row.longValue, col.longValue] forKey:@"message"];

                        [codeErrors addObject:aDict];
					}
				}

				if (dArray != nil && (NSNull *)dArray != [NSNull null])
				{
					// We have error(s) in the device Squirrel - decode and report them

					errorMessage = [errorMessage stringByAppendingString:@"\n  Device Code errors:"];

					for (NSUInteger j = 0 ; j < dArray.count ; ++j)
					{
						errDict = [dArray objectAtIndex:j];
						NSNumber *row = [errDict valueForKey:@"row"];
						NSNumber *col = [errDict valueForKey:@"column"];
						errorMessage = [errorMessage stringByAppendingFormat:@"\n  %@ at row %li, col %li", [errDict objectForKey:@"error"], row.longValue, col.longValue];

                        NSMutableDictionary *aDict = [NSMutableDictionary dictionaryWithDictionary:errDict];
                        [aDict setObject:[NSString stringWithFormat:@"\n  %@ at row %li, col %li", [errDict objectForKey:@"error"], row.longValue, col.longValue] forKey:@"message"];
                        [aDict setObject:@"device" forKey:@"type"];

                        [codeErrors addObject:aDict];
					}
				}
			}
			else
			{
				errorMessage = [errorMessage stringByAppendingString:@"Unknown error"];
			}
		}
		else
		{
			errorMessage = [errorMessage stringByAppendingString:@"Unknown error"];
		}

		if (_loggingDevices.count > 0)
		{
			// We have devices logging, so check if the failed connection is one of theirs

			NSMutableDictionary *removeLogDevice = nil;

			for (NSMutableDictionary *aLogDevice in _loggingDevices)
			{
				Connexion *aConn = (Connexion *)[aLogDevice objectForKey:@"connection"];

				if (aConn == connexion)
				{
					// The failed connection IS a logging connection

					if (connexion.errorCode != 504)
					{
						// Error is not a 'known' timeout (504), so record the device for later clearance

						removeLogDevice = aLogDevice;
						break;
					}
				}
			}

			if (removeLogDevice)
			{
				// Deal with the logging device's failed connection that was not a 'known' timeout (504)
				// Remove the device from the logging list and notify the host app

				[_loggingDevices removeObject:removeLogDevice];
				NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
				[nc postNotificationName:@"BuildAPILogStreamEnd" object:[removeLogDevice objectForKey:@"id"]];
			}
		}

		parsedData = nil;
		connexion.actionCode = kConnectTypeNone;
		[self reportError];
	}

	// Tidy up the connection list

	[_connexions removeObject:connexion];
	numberOfConnections = _connexions.count;
	if (_connexions.count < 1) [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStop" object:nil];

	// Return the decoded data (or nil)

	return parsedData;
}



- (void)processResult:(Connexion *)connexion :(NSDictionary *)data
{
    // If there has been no error recorded, we can now process the data returned by the server
    // (via NSURLSession or NSURLConnection), according to the type of connection that was initiated

    if (data)
    {
        // We have data returned by the server, but does it signal success or failure?
        // Call checkStatus: to find out and only proceed on success

        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

		switch (connexion.actionCode)
		{
			case kConnectTypeGetModels:
			{
				// We asked for a list of all the models, so replace the current list with
				// the newly returned data. This may have been called for an initial list at
				// start-up, or later if a model has changed name

				[models removeAllObjects];

				NSDictionary *mods = [data objectForKey:@"models"];

				for (NSDictionary *model in mods)
				{
					// Add each model to the list
					// Each model has the following keys:
					// id - string
					// name - string
					// device - array of devices

					[models addObject:model];
				}

				// Signal the host app that the list of models is ready to read

				[nc postNotificationName:@"BuildAPIGotModelsList" object:self];

				// Have we been asked to automatically get the list of devices too?

				if (_followOnFlag)
				{
					_followOnFlag = NO;
					[self getDevices];
				}

				break;
			}

			case kConnectTypeGetDevices:
			{
				// We asked for a list of all the devices, so replace the current list with
				// the newly returned data. This may have been called for an initial list at
				// start-up, or later if a device has changed name or model allocation

				[devices removeAllObjects];

				NSDictionary *devs = [data objectForKey:@"devices"];

				for (NSDictionary *device in devs)
				{
					// Add each model to the list
					// Each model has the following keys:
					// id - string
					// name - string
					// powerstate - string
					// rssi - integer
					// agent_id - string
					// agent_status - string
					// model_id - string

					// Convert the loaded device dictionary into a mutable dictionary as we may
					// have the change values, ie. the name if it is <null>

					NSMutableDictionary *newDevice = [NSMutableDictionary dictionaryWithDictionary:device];

					// Check for unexpected null values for certain keys

					NSString *deviceState = [newDevice valueForKey:@"powerstate"];
					if ((NSNull *)deviceState == [NSNull null])
					{
						// 'powerstate' is null for some unexpected reason - assume device is offline
						[newDevice setObject:@"offline" forKey:@"powerstate"];
					}

					deviceState = [newDevice valueForKey:@"agent_status"];
					if ((NSNull *)deviceState == [NSNull null])
					{
						// 'agent_status' is null for some unexpected reason - assume agent is offline
						[newDevice setObject:@"offline" forKey:@"agent_status"];
					}

					[devices addObject:newDevice];
				}

				// Signal the host app that the list of devices is ready to read

				[nc postNotificationName:@"BuildAPIGotDevicesList" object:self];
				break;
			}

			case kConnectTypePostCode:
			{
				// We posted a new code revision to a model, so just notify the host app that this succeeded

				[nc postNotificationName:@"BuildAPIPostedCode" object:nil];
				break;
			}

			case kConnectTypeRestartDevice:
			{
				// We asked that the current device or all the current model's device be restarted,
				// so just notify the host app that this succeeded

				[nc postNotificationName:@"BuildAPIDeviceRestarted" object:nil];
				break;
			}

			case kConnectTypeAssignDeviceToModel:
			{
				// We asked that the current device be assigned to another model,
				// so just notify the host app that this succeeded

				[nc postNotificationName:@"BuildAPIDeviceAssigned" object:nil];

				// Now refresh the list of models and then a new list of devices

				_followOnFlag = YES;
				//[self getModels];
				break;
			}

			case kConnectTypeNewModel:
			{
				// We created a new model, so we need to update the models list so that the
				// change is reflected in our local data. First, notify the host app that
				// the model creation was a success

				[nc postNotificationName:@"BuildAPIModelCreated" object:nil];

				// Now get a new list of models and then a new list of devices

				_followOnFlag = YES;
				//[self getModels];
				break;
			}

			case kConnectTypeDeleteModel:
			{
				// We deleted a new model, so we need to update the models list so that the
				// change is reflected locally

				// Tell the main app we have successfully deleted the model

				[nc postNotificationName:@"BuildAPIModelDeleted" object:nil];

				// Now get a new list of models and then a new list of devices

				_followOnFlag = YES;
				//[self getModels];
				break;
			}

			case kConnectTypeUpdateDevice:
			{
				// We asked that the device information be updated, which may include a name-change or
				// model assignment so we update the model and device lists so that the change
				// is reflected in our local data.

				// Tell the main app we have successfully updated the device

				[nc postNotificationName:@"BuildAPIDeviceUpdated" object:nil];

				// Now get a new list of models and then a new list of devices

				_followOnFlag = YES;
				//[self getModels];
				break;
			}

			case kConnectTypeDeleteDevice:
			{
				// We asked that the device be deleted, so we update the model and device lists
				// so that the change is reflected in our local data.

				// Tell the main app we have successfully deleted the device

				[nc postNotificationName:@"BuildAPIDeviceDeleted" object:nil];

				// Now get a new list of models and then a new list of devices

				_followOnFlag = YES;
				//[self getModels];

				break;
			}

			case kConnectTypeUpdateModel:
			{
				// We asked that the model be updated, which may include a name-change or
				// device assignment so we update the model and device lists so that the change
				// is reflected in our local data.

				// Tell the main app we have successfully updated the model

				[nc postNotificationName:@"BuildAPIModelUpdated" object:nil];

				// Now get a new list of models, and then a new list of devices

				_followOnFlag = YES;
				//[self getModels];
				break;
			}

			case kConnectTypeGetCodeLatestBuild:
			{
				// We asked for the most recent code revision. Here we have received all the builds –
				// we extract the version of the most recent entry, then request this particular build

				NSArray *revs = [data objectForKey:@"revisions"];
				NSDictionary *latestBuild = [revs objectAtIndex:0];
				NSNumber *num = [latestBuild valueForKey:@"version"];
				[self getCodeRev:_currentModelID :num.integerValue];
				break;
			}

			case kConnectTypeGetCodeRev:
			{
				// We asked for a code revision, which we make available to the main app

				NSDictionary *code = [data objectForKey:@"revision"];
				deviceCode = [code objectForKey:@"device_code"];
				agentCode = [code objectForKey:@"agent_code"];

				// Tell the main app we have the code in the deviceCode and agentCode properties

				[nc postNotificationName:@"BuildAPIGotCodeRev" object:nil];

				break;
			}

			case kConnectTypeGetLogEntries:
			{
				// We asked for all of a devices log entries, which we return to the main app

				NSArray *logs = [data objectForKey:@"logs"];

				// Pass the ball back to the AppDelegate

				// Tell the main app we have the code in the deviceCode and agentCode properties

				[nc postNotificationName:@"BuildAPIGotLogs" object:logs];

				break;
			}

			case kConnectTypeGetLogEntriesRanged:
			{
				// We asked for a log stream. The first time through the process, we only access the poll_url
				// property, which we use to generate a second request, for the 'streamed' data

				// Save the URL of the log stream and begin logging

				for (NSMutableDictionary *aLogDevice in _loggingDevices)
				{
					Connexion *aConnexion = [aLogDevice objectForKey:@"connection"];

					if (aConnexion == connexion)
					{
						// Got a match, so save the poll URL

						[aLogDevice setObject:[kBaseAPIURL stringByAppendingString:[data objectForKey:@"poll_url"]] forKey:@"url"];

						// Start logging with the device ID

						[self startLogging:[aLogDevice objectForKey:@"id"]];

						break;
					}
				}

				break;
			}

			case kConnectTypeGetLogEntriesStreamed:
			{
				// We asked for a log stream and the first streamed entry has arrived. Send it to the main
				// app to be displayed, and then re-commence logging

				for (NSMutableDictionary *aLogDevice in _loggingDevices)
				{
					// For each logging device, find the one whose connecion matches the one completed

					Connexion *aConnexion = [aLogDevice objectForKey:@"connection"];

					if (aConnexion == connexion)
					{
						// Bundle up the device ID and its logs and notify the main app

						NSArray *keys = [NSArray arrayWithObjects:@"id", @"logs", nil];
						NSArray *values = [NSArray arrayWithObjects:[aLogDevice objectForKey:@"id"], [data objectForKey:@"logs"], nil];
						NSDictionary *postData = [NSDictionary dictionaryWithObjects:values forKeys:keys];

						[nc postNotificationName:@"BuildAPILogStream" object:postData];

						// Resume logging with the device ID

						[self startLogging:[aLogDevice objectForKey:@"id"]];

						break;
					}
				}

				break;
			}

#pragma mark v5 API outcomes

			case kConnectTypeGetProducts:
			{
				// We asked for a list of all the products, so replace the current list with
				// the newly returned data. This may have been called for an initial list at
				// start-up, or later if a model has changed name

				[products removeAllObjects];

				NSArray *prods = [data objectForKey:@"data"];

				for (NSDictionary *product in prods)
				{
					// Add each product to the list
					// Each model has the following keys:
					// attributes - dictionary
					//   description - string
					//   name - string
					// id - string
					// type - string

					[products addObject:product];
				}

				// Signal the host app that the list of models is ready to read

				[nc postNotificationName:@"BuildAPIGotProductsList" object:self];

				// Have we been asked to automatically get the list of devices too?

				if (_followOnFlag)
				{
					_followOnFlag = NO;
					[self getDeviceGroups];
				}

				break;
			}

			case kConnectTypeGetDeviceGroups:
			{
				// We asked for a list of all the device groups, so replace the current list with
				// the newly returned data. This may have been called for an initial list at
				// start-up, or later if a device has changed name or model allocation

				[deviceGroups removeAllObjects];

				NSArray *dgs = [data objectForKey:@"data"];

				for (NSDictionary *deviceGroup in dgs)
				{
					// Add each device group to the list
					// Each device group has the following keys:
					// id - string
					// type - string
					// attributes - dictionary
					//   name - string
					//   kind - string
					// relationships - dictionary
					//   target_group - dictionary
					//     data - device group object

					[deviceGroups addObject:deviceGroup];
				}

				// Signal the host app that the list of devices is ready to read

				[nc postNotificationName:@"BuildAPIGotDeviceGroupsList" object:self];
				break;
			}

			case kConnectTypeGetDeployments:
			{
				// We asked for a list of all the deployments, so replace the current list with
				// the newly returned data. This may have been called for an initial list at
				// start-up, or later if a device has changed name or model allocation

				[deployments removeAllObjects];

				NSArray *deps = [data objectForKey:@"data"];

				for (NSDictionary *deployment in deps)
				{
					// Add each device group to the list
					// Each device group has the following keys:
					// id - string
					// type - string
					// attributes - dictionary
					//   agent_code - string
					//   device_code - string
					//   agent_sha256 - string
					//   device_sha256 - string
					//   combined_sha256 - string
					//   created_on - string
					//   flagged - Boolean

					[deployments addObject:deployment];
				}

				// Signal the host app that the list of devices is ready to read

				[nc postNotificationName:@"BuildAPIGotDeploymentsList" object:self];
				break;
			}

			case kConnectTypeGetDeployment:
			{
				// We asked for a code revision, which we make available to the main app

				NSArray *dep = [data objectForKey:@"data"];

				currentDeployment = [dep objectAtIndex:0]; // CHECK

				// Tell the main app we have the code in the deployment dictionary

				[nc postNotificationName:@"BuildAPIGotDeployment" object:currentDeployment];

				break;
			}

			case kConnectTypeNewProduct:
			{
				// We created a new product, so we need to update the products list so that the
				// change is reflected in our local data. First, notify the host app that
				// the model creation was a success

				[nc postNotificationName:@"BuildAPIProductCreated" object:nil];

				// Now get a new list of products and then a new list of deviceGroups

				_followOnFlag = YES; // Necessary now?
				[self getProducts];
				break;
			}

			case kConnectTypeUpdateProduct:
			{
				// We asked that the product be updated, which may include a name-change or
				// device assignment so we update the model and device lists so that the change
				// is reflected in our local data.

				// Tell the main app we have successfully updated the model

				[nc postNotificationName:@"BuildAPIProductUpdated" object:nil];

				// Now get a new list of models, and then a new list of devices

				_followOnFlag = YES;
				[self getProducts];
				break;
			}

			case kConnectTypeGetToken:
			{
				_token = data;
				loggedInFlag = YES;

				NSLog([_token objectForKey:@"token"]);
				NSLog([_token objectForKey:@"expires"]);

				// Do we have any pending connections we need to process?

				if (_pendingConnections.count > 0)
				{
					for (Connexion *conn in _pendingConnections)
					{
						[conn.task resume];

						if (_connexions.count == 0) [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStart" object:nil];

						[_connexions addObject:conn];
						[_pendingConnections removeObject:conn];
						numberOfConnections = _connexions.count;
					}
				}
			}

			default:
				break;
		}
    }
}



#pragma mark - Utility Methods


- (NSDictionary *)makeDictionary:(NSString *)key :(NSString *)value
{
    NSArray *keys = [NSArray arrayWithObjects:key, nil];
    NSArray *values = [NSArray arrayWithObjects:value, nil];
    return [NSDictionary dictionaryWithObjects:values forKeys:keys];
}



- (NSMutableURLRequest *)makeRequest:(NSString *)verb :(NSString *)path
{
	if (_token == nil)
	{
		// We have no session token, so we can't get any data

		errorMessage = @"[ERROR] You must be logged in to access the Electric Imp impCloud™";
		[self reportError];
		return nil;
	}

	if (_pagesizeChangeFlag)
	{
		// User has changed the page size, so we need to pass this in now to set it

		_pagesizeChangeFlag = NO;
		path = [path stringByAppendingFormat:@"?pagesize=%li", _pagesize];
	}

	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path]];
    [self setRequestAuthorization:request];
    [request setHTTPMethod:verb];
	[request setValue:_userAgent forHTTPHeaderField:@"User-Agent"];
	return request;
}



- (void)setRequestAuthorization:(NSMutableURLRequest *)request
{
	NSString *tk = [_token objectForKey:@"token"];
	tk = [tk stringByAppendingString:@":"];
	[request setValue:[@"Basic " stringByAppendingString:[self encodeBase64String:tk]] forHTTPHeaderField:@"Authorization"];
	[request setTimeoutInterval:30.0];
}



- (void)reportError
{
    // Signal the host app that we have an error message for it to display (in 'errorMessage')

    [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIError" object:self];
}



#pragma mark - Base64 Methods


- (NSString *)encodeBase64String:(NSString *)plainString
{
	NSData *data = [plainString dataUsingEncoding:NSUTF8StringEncoding];
	NSString *base64String = [data base64EncodedStringWithOptions:0];
	return base64String;
}



- (NSString *)decodeBase64String:(NSString *)base64String
{
	NSData *data = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
	NSString *decodedString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	return decodedString;
}



@end
