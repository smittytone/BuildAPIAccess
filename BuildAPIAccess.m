
//  Copyright (c) 2015-17 Tony Smith. All rights reserved.
//  Issued under the MIT licence

//  BuildAPIAccess 3.0.0


#import "BuildAPIAccess.h"


@implementation BuildAPIAccess


@synthesize products, deviceGroups, deployments, currentDeployment, devices, errorMessage, statusMessage;
@synthesize loggedInFlag, pageSize;

@synthesize deviceCode, agentCode, codeErrors, numberOfConnections;


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

		// Private entities

        _connexions = [[NSMutableArray alloc] init];
		_loggingDevices = [[NSMutableArray alloc] init];
        _lastStamp = nil;
        _logURL = nil;
        _username = nil;
		_password = nil;
        _pageSize = kPaginationDefault;
		_pageSizeChangeFlag = YES;

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
	// Login is the process of sending the user's username/email address and password to the API
 	// in return for a new seven-day session token. We retain the credentials in case the token
	// expires during the host application's runtime, but we don't save them - this is the job
	// of the host application.

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

	// Get a new token using the credentials provided

	[self getNewSessionToken];
}



- (void)getNewSessionToken
{
	// Request a new session token using the stored credentials,
	// failing if neither has been provided (by login:)

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
		errorMessage = @"[ERROR] Could not create a request to retrieve a new impCloud session token.";
		[self reportError];
	}
}



- (BOOL)checkSessionToken
{
	if (!_token)
	{
		// We do not have a token, return error

		return NO;
	}

	NSString *dateString = [_token objectForKey:@"expires"];
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	NSDate *expiry = [dateFormatter dateFromString:dateString];
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
    // Sets a flag which will be tested when we next request data and, if set,
    // adds URL query code specifying the page size

    if (size == _pagesize) return;
	if (size < 1) size = 1;
	if (size > 100) size = 100;
	_pageSize = size;
    _pageSizeChangeFlag = YES;
    pageSize = size;
}




#pragma mark - Data Request Methods


- (void)getMyAccount
{
	// Set up a GET request to /accounts/me

	NSMutableURLRequest *request = [self makeGETrequest:[_baseURL stringByAppendingString:@"accounts/me"]];

	if (request)
	{
		[self launchConnection:request :kConnectTypeGetMyAccount];
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to list your account information.";
		[self reportError];
	}
}



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
    // '_followOnFlag' is used after we've processed the incoming list of products to
    // automatically trigger a request for device groups

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



#pragma mark - Action Methods (v5 API)


- (void)createProduct:(NSString *)name :(NSString *)description
{
	// Set up a POST request to /products

	if (name == nil || name.length == 0)
	{
		errorMessage = @"[ERROR] Could not create a request to create the new product: invalid product name.";
		[self reportError];
		return;
	}

	if (description == nil) description = @"";
	if (description.length > 255) description = [description substringToIndex:254];

	NSArray *keys = [NSArray arrayWithObjects:@"name", @"description", nil];
	NSArray *values = [NSArray arrayWithObjects:name, description, nil];
	NSDictionary *attributes = [NSDictionary dictionaryWithObjects:values forKeys:keys];
	NSDictionary *relationships = [NSDictionary dictionaryWithObject:_me forKey:@"owner"];

	keys = [NSArray arrayWithObjects:@"type", @"attributes", @"relationships", nil];
	values = [NSArray arrayWithObjects:@"product", attributes, relationships, nil];
	NSDictionary *data = [NSDictionary dictionaryWithObjects:values forKeys:keys];
	NSDictionary *newProduct = [NSDictionary dictionaryWithObject:data forKey:@"data"];

	NSMutableURLRequest *request = [self makePOSTrequest:[_baseURL stringByAppendingString:@"products"] :newProduct];

	if (request)
	{
		[self launchConnection:request :kConnectTypeCreateProduct];
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
	// We can ONLY update a product's name or description

	if (productID == nil || productID.length == 0)
	{
		errorMessage = @"[ERROR] Could not create a request to create the new product: invalid product ID.";
		[self reportError];
		return;
	}

	if (key == nil)
	{
		errorMessage = @"[ERROR] Could not create a request to create the new product: data field name.";
		[self reportError];
		return;
	}

	NSDictionary *attributes = [self makeDictionary:key :value];
	NSArray *keys = [NSArray arrayWithObjects:@"type", @"id", @"attributes", nil];
	NSArray *values = [NSArray arrayWithObjects:@"product", productID, attributes, nil];

	NSDictionary *data = [NSDictionary dictionaryWithObjects:values forKeys:keys];
	NSDictionary *product = [NSDictionary dictionaryWithObject:data forKey:@"data"];

	NSMutableURLRequest *request = [self makePATCHrequest:[_baseURL stringByAppendingFormat:@"products/%@", productID] :product];

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



- (void)createDeviceGroup:(NSString *)name :(NSString *)description :(NSString *)productID :(NSInteger)type
{
	// Set up a POST request to /devicegroups

	if (name == nil || name.length == 0)
	{
		errorMessage = @"[ERROR] Could not create a request to create the new device group: invalid device group name.";
		[self reportError];
		return;
	}

	if (description == nil) description = @"";
	if (description.length > 255) description = [description substringToIndex:254];

	if (type < kDeviceGroupTypeDevelopment || type > kDeviceGroupTypeProduction)
	{
		errorMessage = @"[ERROR] Could not create a request to create the new device group: invalid device group type.";
		[self reportError];
		return;
	}

	NSArray *keys = [NSArray arrayWithObjects:@"name", @"description", nil];
	NSArray *values = [NSArray arrayWithObjects:name, description, nil];
	NSDictionary *attributes = [NSDictionary dictionaryWithObjects:values forKeys:keys];

	keys = [NSArray arrayWithObjects:@"type", @"id", nil];
	values = [NSArray arrayWithObjects:@"product", productID, nil];
	NSDictionary *product = [NSDictionary dictionaryWithObjects:values forKeys:keys];
	NSDictionary *relationships = [NSDictionary dictionaryWithObject:product forKey:@"product"];

	keys = [NSArray arrayWithObjects:@"type", @"attributes", @"relationships", nil];
	values = [NSArray arrayWithObjects:[self getDeviceGroupType:type], attributes, relationships, nil];
	NSDictionary *data = [NSDictionary dictionaryWithObjects:values forKeys:keys];
	NSDictionary *newDeviceGroup = [NSDictionary dictionaryWithObject:data forKey:@"data"];

	NSMutableURLRequest *request = [self makePOSTrequest:[_baseURL stringByAppendingString:@"devicegroups"] :newDeviceGroup];

	if (request)
	{
		[self launchConnection:request :kConnectTypeCreateDeviceGroup];
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to create the new product.";
		[self reportError];
	}
}



- (void)updateDeviceGroup:(NSDictionary *)devicegroup :(NSString *)key :(NSString *)value
{
	// Set up a PATCH request to /devicegroups
	// We can ONLY update a device group's name or description

	if (!devicegroup)
	{
		errorMessage = @"[ERROR] Could not create a request to update a device group: invalid device group.";
		[self reportError];
		return;
	}

	if (key == nil)
	{
		errorMessage = @"[ERROR] Could not create a request to create the new product: data field name.";
		[self reportError];
		return;
	}

	NSDictionary *attributes = [self makeDictionary:key :value];
	NSArray *keys = [NSArray arrayWithObjects:@"type", @"id", @"attributes", nil];
	NSString *type = [devicegroup objectForKey:@"type"];
	NSString *dgID = [devicegroup objectForKey:@"id"];
	NSArray *values = [NSArray arrayWithObjects:type, dgID, attributes, nil];
	NSDictionary *data = [NSDictionary dictionaryWithObjects:values forKeys:keys];
	NSDictionary *dg = [NSDictionary dictionaryWithObject:data forKey:@"data"];

	NSMutableURLRequest *request = [self makePATCHrequest:[_baseURL stringByAppendingFormat:@"devicegroups/%@", dgID] :dg];

	if (request)
	{
		[self launchConnection:request :kConnectTypeUpdateDeviceGroup];
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to create the new device group.";
		[self reportError];
	}
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
    [request setValue:@"application/vnd.api+json" forHTTPHeaderField:@"Content-Type"];

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



- (NSMutableURLRequest *)makeDELETErequest:(NSString *)path
{
	return [self makeRequest:@"DELETE" :path];
}



- (NSMutableURLRequest *)makePATCHrequest:(NSString *)path :(NSDictionary *)bodyDictionary
{
	NSError *error = nil;
	NSMutableURLRequest *request = [self makeRequest:@"PATCH" :path];
	[request setValue:@"application/vnd.api+json" forHTTPHeaderField:@"Content-Type"];

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



- (NSMutableURLRequest *)makePATCHrequest:(NSString *)path :(NSDictionary *)bodyDictionary
{
	NSError *error = nil;
	NSMutableURLRequest *request = [self makeRequest:@"PATCH" :path];
	[request setValue:@"application/vnd.api+json" forHTTPHeaderField:@"Content-Type"];
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
		// We do not have a valid token, so we must now acquire one. In the meantime, we
        // cache all new connexions in '_pendingConnexions' so they can be actioned when
        // we finally get the token

        // Q: do we want to put a limit on '_pendingConnexions' size?

		if (_pendingConnexions == nil) _pendingConnexions = [[NSMutableArray alloc] init];

		if (_pendingConnexions.count == 0)
		{
			// We have no queued connections, so get a new token

			[self getNewToken];
		}

		[_pendingConnexions addObject:aConnexion];
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

        Connexion *conn = nil;

        for (Connexion *aConnexion in _connexions)
        {
            // Run through the connections in our list and add the incoming error code to the correct one
            // TODO support for logging connections

            if (aConnexion.task == dataTask)
            {
                // This request has been rate-limited, so we need to recall it in 1+ seconds

                conn = aConnexion;
                break;
            }
        }

        if (code == 400)
        {
            if (conn.actionCode == kConnectTypeGetToken)
            {
                // This indicates a login credentials failure - we can proceed no further

                errorMessage = @"[ERROR] Your impCloud access credentials have been rejected - please check that your username and password were entered correctly.";
                [self reportError];
                completionHandler(NSURLSessionResponseCancel);
                return;
            }
        }



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

	// Complete the finished NSURLSessionTask

	[task cancel];

	// If we have a valid action code, process the received data

	if (currentConnexion.actionCode != kConnectTypeNone) [self processResult:currentConnexion :[self processConnection:currentConnexion]];
}



#pragma mark - Joint NSURLSession/NSURLConnection Methods


- (NSDictionary *)processConnection:(Connexion *)connexion {

	// Process the data returned by the current connection

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
			// 'parsedData' should contain an array of errors, eg. unknown device, or a code syntax error

			NSArray *errors = [parsedData objectForKey:@"errors"];
			NSInteger count = 0;

			for (NSDictionary *error in errors)
			{
				NSString *errString = [error objectForKey:@"title"];
				NSString *errDetail = [error objectForKey:@"detail"];

				if (errors.count > 1)
				{
					errorMessage = [errorMessage stringByAppendingFormat:@"%li. %@: %@\n", (count + 1), errString, errDetail];
				}
				else
				{
					errorMessage = [errorMessage stringByAppendingFormat:@"%@: %@", errString, errDetail];
				}
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

	// Tidy up the connection list by removing the current connexion from the list of connexions
    // Note: should not remove the connexion object

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
            case kConnectTypeGetProducts:
			{
				// We asked for a list of all the products, so replace the current list with
				// the newly returned data, one page at a time, making new connections to the
                // server as required

                // We have to handle pagination first

                NSDictionary *links = [data objectForKey:@"links"];
                NSString *nextURL = [self nextURL:links];
                BOOL isFirstPage = [self isFirstPage:links];

                // Only clear the products list if this is the first page

                if (isFirstPage) [products removeAllObjects];

				NSArray *prods = [data objectForKey:@"data"];

				for (NSDictionary *product in prods)
				{
					[products addObject:product];
				}

                // Are there more pages?

                if (nextURL.length != 0)
                {
                    // We found a 'next' field in the 'links' list, so we need to get the next page of data
                    // which we do by making a new request using the provided 'next' link

                    NSMutableURLRequest *request = [self makeGETrequest:nextURL];

                    if (request)
                    {
                        [self launchConnection:request :kConnectTypeGetProducts];
                        break;
                    }
                    else
                    {
                        errorMessage = @"[ERROR] Could not create a request to list all of your products — the list may be incomplete.";
                        [self reportError];
                    }

                }

                // Signal the host app that the list of products is ready to read

				[nc postNotificationName:@"BuildAPIGotProductsList" object:self];

				// Have we been asked to automatically get the list of device groups too?
                // TO DO? should we grab this asynchronously?

				if (_followOnFlag)
				{
					_followOnFlag = NO;
					[self getDeviceGroups];
				}

				break;
			}

            case kConnectTypeCreateProduct:
            {
                // We created a new product, so we need to update the products list so that the
                // change is reflected in our local data. First, notify the host app that
                // the model creation was a success

                [nc postNotificationName:@"BuildAPIProductCreated" object:nil];

                // Now get a new list of products

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
                
                [self getProducts];
                break;
            }
                
			case kConnectTypeGetDeviceGroups:
			{
				// We asked for a list of all the device groups, so replace the current list with
				// the newly returned data, adding content from fresh pages as necessary

                // We have to handle pagination first

                NSDictionary *links = [data objectForKey:@"links"];
                NSString *nextURL = [self nextURL:links];
                BOOL isFirstPage = [self isFirstPage:links];

                // Only clear the products list if this is the first page

                if (isFirstPage) [deviceGroups removeAllObjects];

				NSArray *dgs = [data objectForKey:@"data"];

				for (NSDictionary *deviceGroup in dgs)
				{
					[deviceGroups addObject:deviceGroup];
				}

                // Are there more pages?

                if (nextURL.length != 0)
                {
                    // We found a 'next' field in the 'links' list, so we need to get the next page of data
                    // which we do by making a new request using the provided 'next' link

                    NSMutableURLRequest *request = [self makeGETrequest:nextURL];

                    if (request)
                    {
                        [self launchConnection:request :kConnectTypeGetDeviceGroups];
                        break;
                    }
                    else
                    {
                        errorMessage = @"[ERROR] Could not create a request to list all of your device groups — the list may be incomplete.";
                        [self reportError];
                    }
                    
                }
                
                // Signal the host app that the list of device groups is ready to read

				[nc postNotificationName:@"BuildAPIGotDeviceGroupsList" object:self];
				break;
			}

            case kConnectTypeCreateDeviceGroup:
            {
                // We created a new device group, so we need to update the products list so that the
                // change is reflected in our local data. First, notify the host app that
                // the device group creation was a success

                [nc postNotificationName:@"BuildAPIDeviceGroupCreated" object:nil];

                // Now get a new list of products and their device groups

                _followOnFlag = YES;
                [self getProducts];
                break;
            }

            case kConnectTypeUpdateDeviceGroup:
            {
                // We updated a device group, so we need to update the device group list so that the
                // change is reflected in our local data. First, notify the host app that
                // the device group update was a success
                
                [nc postNotificationName:@"BuildAPIDeviceGroupUpdated" object:nil];
                
                // Now get a new list of products and their device groups
                
                [self getDeviceGroups];
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

            case kConnectTypeGetDevices:
            {
                // We asked for a list of all the devices, so replace the current list with
                // the newly returned data, adding content from further pages as necessary

                // We have to handle pagination first

                NSDictionary *links = [data objectForKey:@"links"];
                NSString *nextURL = [self nextURL:links];
                BOOL isFirstPage = [self isFirstPage:links];

                // Only clear the products list if this is the first page

                if (isFirstPage) [devices removeAllObjects];

                NSArray *ds = [data objectForKey:@"data"];

                for (NSDictionary *device in ds)
                {
                    [devices addObject:device;
                }

                // Are there more pages?

                if (nextURL.length != 0)
                {
                    // We found a 'next' field in the 'links' list, so we need to get the next page of data
                    // which we do by making a new request using the provided 'next' link

                    NSMutableURLRequest *request = [self makeGETrequest:nextURL];

                    if (request)
                    {
                        [self launchConnection:request :kConnectTypeGetDevices];
                        break;
                    }
                    else
                    {
                        errorMessage = @"[ERROR] Could not create a request to list all of your devices — the list may be incomplete.";
                        [self reportError];
                    }
                    
                }
                
                // Signal the host app that the list of devices is ready to read
                
                [nc postNotificationName:@"BuildAPIGotDeviceList" object:self];
                break;
            }

			case kConnectTypeGetToken:
			{
				_token = data;
				loggedInFlag = YES;

				NSLog([_token objectForKey:@"token"]);
				NSLog([_token objectForKey:@"expires"]);

				// Get user's account before we do anything else

				[self getMyAccount];

				// Do we have any pending connections we need to process?

				if (_pendingConnexions.count > 0)
				{
					for (Connexion *conn in _pendingConnexions)
					{
						[conn.task resume];

						if (_connexions.count == 0) [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStart" object:nil];

						[_connexions addObject:conn];
						[_pendingConnexions removeObject:conn];
					}

                    numberOfConnections = _connexions.count;
				}

				break;
			}

			case kConnectTypeGetMyAccount:
			{
				data = [data objectForKey:@"data"];
				NSMutableDictionary *account = [NSMutableDictionary dictionaryWithDictionary:[self makeDictionary:@"id" :[data objectForKey:@"id"]]];
				[account setObject:@"account" forKey:@"type"];
				_me = [NSDictionary dictionaryWithDictionary:account];
				NSLog(@"My account details obtained");
				break;
			}

			default:
				break;
		}
    }
}



#pragma mark - Utility Methods


- (void)reportError
{
    // Signal the host app that we have an error message for it to display (in 'errorMessage')

    [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIError" object:self];
}



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
		path = [path stringByAppendingFormat:@"?page/[size/]=%li", _pagesize];
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



- (NSString *)getDeviceGroupType:(NSInteger)type
{
	if (type == kDeviceGroupTypeFactory) return @"factoryfixture_devicegroup";
	if (type == kDeviceGroupTypeProduction) return @"production_devicegroup";
	return @"development_devicegroup";
}



- (BOOL)isFirstPage:(NSDictionary *)links
{
    BOOL isFirstPage = NO;

    for (NSString *key in links)
    {
        if ([key compare:@"first"] == NSOrderedSame)
        {
            NSString *selflink = (NSString *)[links objectForKey:@:"self"];
            NSString *firstlink = (NSString *)[links objectForKey:key];

            if ([selflink compare:firstlink] == NSOrderedSame)
            {
                // We are at the first page, so set the appropriate flag

                isFirstPage = YES;
            }
        }

        break;
    }

    return isFirstPage;
}


- (NSString *)nextPageLink:(NSDictionary *)links
{
    NSString *nextURLString = @"";

    for (NSString *key in links)
    {
        if ([key compare:@"next"] == NSOrderedSame)
        {
            // We have at least one more page to recover before we have the full list

            nextURLString = (NSString *)[links objectForKey:key];
            break;
        }
    }

    return nextURLString
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
