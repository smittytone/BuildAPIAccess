
//  Created by Tony Smith on 09/02/2015.
//  Copyright (c) 2015 Tony Smith. All rights reserved.
//  Issued under the MIT licence


#import "BuildAPIAccess.h"

@implementation BuildAPIAccess

@synthesize devices, models, loggedInFlag;
@synthesize errorMessage, statusMessage, deviceCode, agentCode;



#pragma mark - Initialization Methods


- (id)init
{
	if (self = [super init])
	{
		// Set up arrays and initialize properties

		_connexions = [[NSMutableArray alloc] init];

		_initialLoadFlag = NO;
		_lastStamp = nil;
		_logStreamDevice = nil;
		_baseURL = [kBaseAPIURL stringByAppendingString:kAPIVersion];
		_harvey = nil;

		devices = [[NSMutableArray alloc] init];
		models = [[NSMutableArray alloc] init];

		loggedInFlag = NO;
		errorMessage = @"";

	}

	return self;
}



- (void)getInitialData:(NSString *)harvey
{
	if (loggedInFlag == NO)
	{
		if (harvey == nil || [harvey compare:@""] == NSOrderedSame)
		{
			errorMessage = @"[ERROR] In order to get app and device data, you must enter your API key in the Preferences.";
			[self reportError];
			return;
		}

		_harvey = harvey;
	}

	// Get the data

	_initialLoadFlag = YES;
	[self getModels];
	[self getDevices];
}



- (void)clear
{
	_harvey = nil;
}



#pragma mark - Data Request Methods


- (void)getModels
{
	// Set up a GET request to the /models URL - gets all models

	NSURLRequest *request = [self makeGETrequest:[_baseURL stringByAppendingString:@"models"]];
	[self launchConnection:request :kConnectTypeGetModels];
}



- (void)getDevices
{
	// Set up a GET request to the /devices URL - gets all devices

	NSURLRequest *request = [self makeGETrequest:[_baseURL stringByAppendingString:@"devices"]];
	[self launchConnection:request :kConnectTypeGetDevices];
}



- (void)getCode:(NSString *)modelID
{
	// Set up a GET request to the /models/[id]/revisions URL

	NSString *urlString = [_baseURL stringByAppendingFormat:@"models/%@/revisions", modelID];
	NSURLRequest *request = [self makeGETrequest:urlString];
	[self launchConnection:request :kConnectTypeGetCodeLatestBuild];
	_currentModelID = modelID;
}



- (void)getCodeRev:(NSString *)modelID :(NSInteger)build
{
	// Set up a GET request to the /models/[id]/revisions/[build] URL

	NSString *urlString = [_baseURL stringByAppendingFormat:@"models/%@/revisions/%li", modelID, (long)build];
	NSURLRequest *request = [self makeGETrequest:urlString];
	[self launchConnection:request :kConnectTypeGetCodeRev];
}



- (void)getLogsForDevice:(NSInteger)deviceIndex :(NSString *)since :(BOOL)isStream
{
	// Set up a GET request to the /device/[id]/logs URL

	if (deviceIndex < 0 || deviceIndex > devices.count)
	{
		// Out-of-range modelIndex? Report error and bail

		errorMessage = @"[ERROR] Could not create a request to get logs from the device.";
		[self reportError];
	}

	NSDictionary *device = [devices objectAtIndex:deviceIndex];
	NSString *urlString = [_baseURL stringByAppendingFormat:@"devices/%@/logs", [device objectForKey:@"id"]];
	NSURLRequest *request = nil;
	NSInteger action = kConnectTypeNone;

	if (isStream == YES)
	{
		action = kConnectTypeGetLogEntriesRanged;
		_logStreamDevice = device;
	}
	else
	{
		action = kConnectTypeGetLogEntries;
		if ([since compare:@""] != NSOrderedSame) urlString = [urlString stringByAppendingFormat:@"?since=%@", since];
	}

	request = [self makeGETrequest:urlString];
	[self launchConnection:request :action];
}




#pragma mark - Action Methods


- (void)createNewModel:(NSString *)modelName
{
	// Set up a POST request to the /models URL - we'll post the new model there

	NSArray *keys = [NSArray arrayWithObjects:@"name", nil];
	NSArray *values = [NSArray arrayWithObjects:modelName, nil];
	NSDictionary *dict = [NSDictionary dictionaryWithObjects:values forKeys:keys];
	NSURLRequest *request = [self makePOSTrequest:[_baseURL stringByAppendingString:@"models"] :dict];

	if (request != nil)
	{
		[self launchConnection:request :kConnectTypeNewModel];
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to create the new app.";
		[self reportError];
	}
}



- (void)updateModel:(NSInteger)modelIndex :(NSString *)key :(NSString *)value
{
	// Make a PUT request to send the change

	if (modelIndex < 0 || modelIndex > models.count)
	{
		// Out-of-range modelIndex? Report error and bail

		errorMessage = @"[ERROR] Could not create a request to update the app.";
		[self reportError];
	}

	if (key == nil || key.length == 0)
	{
		// Malformed key? Report error and bail

		errorMessage = @"[ERROR] Could not create a request to update the app.";
		[self reportError];
	}

	NSDictionary *mDict = [models objectAtIndex:modelIndex];

	// Put the new name into the dictionary to pass to the API

	NSArray *keys = [NSArray arrayWithObjects:key, nil];
	NSArray *values = [NSArray arrayWithObjects:value, nil];
	NSDictionary *newDict = [NSDictionary dictionaryWithObjects:values forKeys:keys];

	NSURLRequest *request = [self makePUTrequest:[_baseURL stringByAppendingFormat:@"models/%@", [mDict objectForKey:@"id"]] :newDict];

	if (request != nil)
	{
		[self launchConnection:request :kConnectTypeUpdateModel];
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to update the app.";
		[self reportError];
	}
}



- (void)deleteModel:(NSInteger)modelIndex
{
	// Set up a DELETE request to the /models/[id]

	if (modelIndex < 0 || modelIndex > models.count)
	{
		// Out-of-range modelIndex? Report error and bail

		errorMessage = @"[ERROR] Could not create a request to delete the app.";
		[self reportError];
	}

	NSDictionary *mDict = [models objectAtIndex:modelIndex];
	NSURLRequest *request = [self makeDELETErequest:[_baseURL stringByAppendingFormat:@"models/%@", [mDict objectForKey:@"id"]]];

	if (request != nil)
	{
		[self launchConnection:request :kConnectTypeDeleteModel];
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to delete the app.";
		[self reportError];
	}
}



- (void)uploadCode:(NSString *)newDeviceCode :(NSString *)newAgentCode :(NSInteger)modelIndex
{
	// Set up a POST request to the /models/[ID]/revisions URL - we'll post the new code there

	if (modelIndex < 0 || modelIndex > models.count)
	{
		// Out-of-range modelIndex? Report error and bail

		errorMessage = @"[ERROR] Could not create a request to upload the code to the app.";
		[self reportError];
	}

	// Replace nil code parameters with empty strings

	if (newDeviceCode == nil) newDeviceCode = @"";
	if (newAgentCode == nil) newAgentCode = @"";

	// Put the new code into a dictionary

	NSArray *keys = [NSArray arrayWithObjects:@"agent_code", @"device_code", nil];
	NSArray *values = [NSArray arrayWithObjects:newAgentCode, newDeviceCode, nil];
	NSDictionary *dict = [NSDictionary dictionaryWithObjects:values forKeys:keys];

	// Get the current model's ID using its index

	NSDictionary *mDict = [models objectAtIndex:modelIndex];
	NSString *urlString = [@"models/" stringByAppendingString:[mDict objectForKey:@"id"]];
	urlString = [urlString stringByAppendingString:@"/revisions"];

	// Make the POST request to send the code

	NSURLRequest *request = [self makePOSTrequest:[_baseURL stringByAppendingString:urlString] :dict];

	if (request != nil)
	{
		[self launchConnection:request :kConnectTypePostCode];
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to upload the code to the app.";
		[self reportError];
	}
}



- (void)assignDevice:(NSInteger)deviceIndex toModel:(NSInteger)modelIndex
{
	// Set up a PUT request to assign a device to a model

	if (modelIndex < 0 || modelIndex > models.count)
	{
		// Out-of-range modelIndex? Report error and bail

		errorMessage = @"[ERROR] Could not create a request to assign the device to the app.";
		[self reportError];
	}

	if (deviceIndex < 0 || deviceIndex > devices.count)
	{
		// Out-of-range deviceIndex? Report error and bail

		errorMessage = @"[ERROR] Could not create a request to assign the device to the app.";
		[self reportError];
	}

	// Get the current device's ID using its index; get the model too

	NSDictionary *dDict = [devices objectAtIndex:deviceIndex];
	NSDictionary *mDict = [models objectAtIndex:modelIndex];
	NSString *urlString = [@"/devices/" stringByAppendingString:[dDict objectForKey:@"id"]];

	// Put the new model ID into the dictionary to pass to the API

	NSArray *keys = [NSArray arrayWithObjects:@"model_id", nil];
	NSArray *values = [NSArray arrayWithObjects:[mDict objectForKey:@"id"], nil];
	NSDictionary *dict = [NSDictionary dictionaryWithObjects:values forKeys:keys];

	// Make the PUT request to send the change

	NSURLRequest *request = [self makePUTrequest:[_baseURL stringByAppendingString:urlString] :dict];

	if (request != nil)
	{
		[self launchConnection:request :kConnectTypeAssignDeviceToModel];
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to assign the device.";
		[self reportError];
	}
}



- (void)restartDevice:(NSInteger)deviceIndex
{
	// Set up a POST request to the /devices/[ID]/restart URL - updates device with an unchanged model_id

	if (deviceIndex < 0 || deviceIndex > devices.count)
	{
		// Out-of-range deviceIndex? Report error and bail

		errorMessage = @"[ERROR] Could not create a request to restart the device.";
		[self reportError];
	}

	NSDictionary *dDict = [devices objectAtIndex:deviceIndex];
	NSURLRequest *request = [self makePOSTrequest:[_baseURL stringByAppendingFormat:@"devices/%@/restart", [dDict objectForKey:@"id"]] :nil];

	if (request != nil)
	{
		[self launchConnection:request :kConnectTypeRestartDevice];
	}
	else
	{
		errorMessage = @"[ERROR] Can’t create a request to restart the device.";
		[self reportError];
	}
}



- (void)restartDevices:(NSInteger)modelIndex
{
	// Set up a POST request to the /devices/[ID] URL - gets all models

	if (modelIndex < 0 || modelIndex > models.count)
	{
		// Out-of-range modelIndex? Report error and bail

		errorMessage = @"[ERROR] Could not create a request to restart the app's devices.";
		[self reportError];
	}

	NSDictionary *mDict = [models objectAtIndex:modelIndex];
	NSURLRequest *request = [self makePOSTrequest:[_baseURL stringByAppendingFormat:@"models/%@/restart", [mDict objectForKey:@"id"]] :nil];

	if (request != nil)
	{
		[self launchConnection:request :kConnectTypeRestartDevice];
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to restart the app's devices.";
		[self reportError];
	}
}



- (void)deleteDevice:(NSInteger)deviceIndex
{
	// Set up a DELETE request to the /devices/[id]

	if (deviceIndex < 0 || deviceIndex > devices.count)
	{
		// Out-of-range deviceIndex? Report error and bail

		errorMessage = @"[ERROR] Could not create a request to delete the device.";
		[self reportError];
	}

	NSDictionary *dDict = [devices objectAtIndex:deviceIndex];
	NSURLRequest *request = [self makeDELETErequest:[_baseURL stringByAppendingFormat:@"devices/%@", [dDict objectForKey:@"id"]]];

	if (request != nil)
	{
		[self launchConnection:request :kConnectTypeDeleteDevice];
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to delete the device.";
		[self reportError];
	}
}



- (void)updateDevice:(NSInteger)deviceIndex :(NSString *)key :(NSString *)value
{
	// Make the PUT request to send the change

	if (deviceIndex < 0 || deviceIndex > devices.count)
	{
		// Out-of-range deviceIndex? Report error and bail

		errorMessage = @"[ERROR] Could not create a request to update the device.";
		[self reportError];
	}

	if (key == nil || key.length == 0)
	{
		// Malformed key? Report error and bail

		errorMessage = @"[ERROR] Could not create a request to update the device.";
		[self reportError];
	}

	NSDictionary *dDict = [devices objectAtIndex:deviceIndex];

	// Put the new name into the dictionary to pass to the API

	NSArray *keys = [NSArray arrayWithObjects:key, nil];
	NSArray *values = [NSArray arrayWithObjects:value, nil];
	NSDictionary *newDict = [NSDictionary dictionaryWithObjects:values forKeys:keys];

	NSURLRequest *request = [self makePUTrequest:[_baseURL stringByAppendingFormat:@"devices/%@", [dDict objectForKey:@"id"]] :newDict];

	if (request != nil)
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



- (void)autoRenameDevice:(NSString *)deviceId
{
	// This method should be used SOLELY to change the name of new, unassigned deivce
	// from <NULL> to their own id. It is called when the devices are listed

	// Put the new name (which matches id) into the dictionary to pass to the API

	NSArray *keys = [NSArray arrayWithObjects:@"name", nil];
	NSArray *values = [NSArray arrayWithObjects:deviceId, nil];
	NSDictionary *newDict = [NSDictionary dictionaryWithObjects:values forKeys:keys];

	// Make the PUT request to send the change

	NSURLRequest *request = [self makePUTrequest:[_baseURL stringByAppendingFormat:@"devices/%@", deviceId] :newDict];

	if (request != nil)
	{
		[self launchConnection:request :kConnectTypeUpdateDevice];
	}
	else
	{
		errorMessage = @"[ERROR] Could not create a request to update the device.";
		[self reportError];
	}
}



#pragma mark – Logging Methods


- (void)startLogging
{
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_logStreamURL] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:3600.0];
	[self setRequestAuthorization:request];
	[self launchConnection:request :kConnectTypeGetLogEntriesStreamed];
}



- (void)stopLogging
{
	if (_connexions.count == 0) return;

	_logStreamDevice = nil;

	for (Connexion *aConnexion in _connexions)
	{
		if (aConnexion.actionCode == kConnectTypeGetLogEntriesStreamed)
		{
			[aConnexion.connexion cancel];
			[_connexions removeObject:aConnexion];
		}
	}

	if (_connexions.count < 1)
	{
		// No more connexions? Tell the app to hide the activity indicator

		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc postNotificationName:@"BuildAPIProgressStop" object:nil];
	}
}




#pragma mark - HTTP Request Construction Methods


- (NSURLRequest *)makeGETrequest:(NSString *)path
{
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path]];
	[self setRequestAuthorization:request];
	[request setHTTPMethod:@"GET"];
	return request;
}



- (NSMutableURLRequest *)makePOSTrequest:(NSString *)path :(NSDictionary *)bodyDictionary
{
	NSError *error = nil;

	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path]];
	[self setRequestAuthorization:request];
	[request setHTTPMethod:@"POST"];
	[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

	if (bodyDictionary != nil)
	{
		[request setHTTPBody:[NSJSONSerialization dataWithJSONObject:bodyDictionary options:0 error:&error]];
	}

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

	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path]];
	[self setRequestAuthorization:request];
	[request setHTTPMethod:@"PUT"];
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



- (NSURLRequest *)makeDELETErequest:(NSString *)path
{
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path]];
	[self setRequestAuthorization:request];
	[request setHTTPMethod:@"DELETE"];
	return request;
}



- (void)setRequestAuthorization:(NSMutableURLRequest *)request
{
	if (_harvey != nil)
	{
		[request setValue:[@"Basic " stringByAppendingString:[self encodeBase64String:_harvey]] forHTTPHeaderField:@"Authorization"];
		[request setTimeoutInterval:30.0];
	}
}



#pragma mark - Connection Methods


- (void)launchConnection:(id)request :(NSInteger)actionCode
{
	// Create a default connexion object to store connection details

	Connexion *aConnexion = [[Connexion alloc] init];
	aConnexion.actionCode = actionCode;
	aConnexion.errorCode = -1;
	aConnexion.receivedData = [NSMutableData dataWithCapacity:0];

	if (actionCode == kConnectTypeGetLogEntriesStreamed) [request setTimeoutInterval:3600.0];

	aConnexion.connexion = [[NSURLConnection alloc] initWithRequest:request delegate:self];

	if (!aConnexion.connexion)
	{
		// Inform the user that the connection failed.

		errorMessage = @"[ERROR] Could not establish a connection to the Electric Imp server.";
		[self reportError];
	}
	else
	{
		// Connection established successfully, so notify the main app to trigger the progress indicator
		// and then add the new connexion to the list of current connections

		if (_connexions.count < 1)
		{
			NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
			[nc postNotificationName:@"BuildAPIProgressStart" object:nil];
		}

		[_connexions addObject:aConnexion];
	}
}



- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
	if (protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic || protectionSpace.authenticationMethod == NSURLAuthenticationMethodDefault)
	{
		return YES;
	}
	else
	{
		return NO;
	}
}



- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	NSURLCredential *bonaFides;

	if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust)
	{
		bonaFides = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
	}
	else
	{
		bonaFides = [NSURLCredential credentialWithUser:[self encodeBase64String:_harvey]
				password:[self encodeBase64String:_harvey]
				persistence:NSURLCredentialPersistenceNone];
	}

	[[challenge sender] useCredential:bonaFides forAuthenticationChallenge:challenge];
}



- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	// Inform the user of the connection failure

	errorMessage = @"[ERROR] Could not connect to the Electric Imp server.";
	[self reportError];

	// Terminate the failed connection and remove it from the list of current connections

	[connection cancel];
	[_connexions removeObject:connection];

	if (_connexions.count < 1)
	{
		// If there are no current connections, tell the app to
		// turn off the connection activity indicator

		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc postNotificationName:@"BuildAPIProgressStop" object:nil];
	}
}



- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	// This delegate method is called when the server responds to the connection request
	// Use it to trap certain status codes

	NSHTTPURLResponse *rps = (NSHTTPURLResponse *)response;
	NSInteger code = rps.statusCode;

	if (code > 399 && code < 600)
	{
		// The API has responded with an error

		if (code == 504)
		{
			if (_logStreamDevice != nil)
			{
				// We are still streaming but have had a bad gateway (bug) - recommence logging

				[self startLogging];
			}
		}

		for (Connexion *aConnexion in _connexions)
		{
			// Run through the connections in our list and add the incoming error code to the correct one

			if (aConnexion.connexion == connection) aConnexion.errorCode = code;
		}
	}
}



- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	// This delegate method is called when the server sends some data back
	// Add the data to the correct connexion object

	for (Connexion *aConnexion in _connexions)
	{
		// Run through the connections in our list and add the incoming data to the correct one

		if (aConnexion.connexion == connection) [aConnexion.receivedData appendData:data];
	}
}



- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	// All the data has been supplied by the server in response to a connection
	// Parse the data and, according to the connection activity - update device, create model etc –
	// apply the results

	Connexion *theCurrentConnexion;
	NSError *error;
	id parsedData = nil;

	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

	for (Connexion *aConnexion in _connexions)
	{
		// Run through the connections in the list and find the one that has just finished loading

		if (aConnexion.connexion == connection)
		{
			theCurrentConnexion = aConnexion;

			if (aConnexion.receivedData && aConnexion.receivedData.length > 0)
			{
				// If we have data in, decode it assuming it is JSON
				parsedData = [NSJSONSerialization JSONObjectWithData:aConnexion.receivedData options:kNilOptions error:&error];
			}

			if (error != nil)
			{
				// If the incoming data could not be decoded for some reason –
				// most likely a malformed request which returns a block of HTML

				errorMessage = @"[ERROR] Received data could not be decoded. Is is JSON?";
						errorMessage = [errorMessage stringByAppendingFormat:@" %@", (NSString *)aConnexion.receivedData];
				[self reportError];
				aConnexion.actionCode = kConnectTypeNone;
			}

			if (aConnexion.errorCode != -1)
			{
				// Check for an error being reported by the server

				errorMessage = [NSString stringWithFormat:@"[ERROR] {Code: %lu} ", aConnexion.errorCode];

				if (parsedData)
				{
					// We managed to get sensible data back from the server
					// This should be a description of the error, eg. unknown device, or a code syntax error

					NSDictionary *eDict = [parsedData objectForKey:@"error"];
					NSString *eString = [eDict objectForKey:@"message_short"];
					errorMessage = [errorMessage stringByAppendingString:eString];
					eString = [eDict objectForKey:@"code"];

					// Is the problem a code syntax error?

					if ([eString compare:@"CompileFailed"] == NSOrderedSame)
					{
						eDict = [eDict objectForKey:@"details"];
						NSArray *aArray = nil;
						NSArray *dArray = nil;
						aArray = [eDict objectForKey:@"agent_errors"];
						dArray = [eDict objectForKey:@"device_errors"];

						// Decode the syntax error and report it

						if (aArray != nil && (NSNull *)aArray != [NSNull null])
						{
							errorMessage = [errorMessage stringByAppendingString:@"\n Agent Code errors:"];

							for (NSUInteger j = 0 ; j < aArray.count ; j++)
							{
								NSDictionary *aDict = [aArray objectAtIndex:j];
								NSNumber *row = [aDict valueForKey:@"row"];
								NSNumber *col = [aDict valueForKey:@"column"];
								errorMessage = [errorMessage stringByAppendingFormat:@"\n  %@ at row %li, col %li", [aDict objectForKey:@"error"], row.longValue, col.longValue];
							}
						}

						if (dArray != nil && (NSNull *)dArray != [NSNull null])
						{
							errorMessage = [errorMessage stringByAppendingString:@"\n Device Code errors:"];

							for (NSUInteger j = 0 ; j < dArray.count ; j++)
							{
								NSDictionary *dDict = [dArray objectAtIndex:j];
								NSNumber *row = [dDict valueForKey:@"row"];
								NSNumber *col = [dDict valueForKey:@"column"];
								errorMessage = [errorMessage stringByAppendingFormat:@"\n  %@ at row %li, col %li", [dDict objectForKey:@"error"], row.longValue, col.longValue];
							}
						}
					}
				}

				[self reportError];
				aConnexion.actionCode = kConnectTypeNone;
			}
		}
	}

	// End the finished connection and remove it from the list of current connections

	[connection cancel];
	[_connexions removeObject:theCurrentConnexion];

	if (_connexions.count < 1)
	{
		// There are no more current connections so tell the app to
		// turn off the connection activity indicator

		[nc postNotificationName:@"BuildAPIProgressStop" object:nil];
	}

	// Process the returned data according to the type of connection initiated

	switch (theCurrentConnexion.actionCode)
	{
		case kConnectTypeNone:
			break;

		case kConnectTypeGetModels:

			// We asked for a list of all the models, so replace the current list with
			// the newly returned data. This may have been called for an initial list at
			// start-up, or later if a model has changed name

			if (parsedData)
			{
				if ([self checkStatus:parsedData] == 1)
				{
					[models removeAllObjects];

					NSDictionary *mods = [parsedData objectForKey:@"models"];

					for (NSDictionary *model in mods)
					{
						// Add each model to the list
						// Each model has the following keys:
						// id - string
						// name - string
						// device - array of devices

						[models addObject:model];
					}

					// Tell the main app to redisplay the models list
					
					[nc postNotificationName:@"BuildAPIGotModelsList" object:nil];

					// Is this the first time we are requesting the list in this run time?
					// If so, record that we are logged in

					if (_initialLoadFlag) loggedInFlag = YES;
				}
			}

			break;

		case kConnectTypeGetDevices:

			// We asked for a list of all the devices, so replace the current list with
			// the newly returned data. This may have been called for an initial list at
			// start-up, or later if a device has changed name or model allocation

			if (parsedData)
			{
				if ([self checkStatus:parsedData] == 1)
				{
					[devices removeAllObjects];

					NSDictionary *devs = [parsedData objectForKey:@"devices"];

					for (NSDictionary *device in devs)
					{
						// Add each model to the list
						// Each model has the following keys:
						// id - string
						// name - string
						// powerstate - bool
						// rssi - integer
						// agent_id - string
						// agent_status - string
						// model_id - string

						// Convert the loaded device dictionary into a mutable dictionary as we may
						// have the change values, ie. the name if it is <null>

						NSMutableDictionary *newDevice = [NSMutableDictionary dictionaryWithDictionary:device];
						[devices addObject:newDevice];
					}

					// Tell the main app to redisplay the devices list
					
					[nc postNotificationName:@"BuildAPIGotDevicesList" object:nil];

					// Is this the first time we are requesting the list in this run time?
					// If so, future requests will not be, so clear the flag

					if (_initialLoadFlag) _initialLoadFlag = NO;
				}
			}

			break;

		case kConnectTypePostCode:

			// We posted a new code revision to the current model,
			// so just call the follow-up method in the main app

			if (parsedData)
			{
				if ([self checkStatus:parsedData] == 1)
				{
					[nc postNotificationName:@"BuildAPIPostedCode" object:nil];
				}
			}

			break;

		case kConnectTypeRestartDevice:

			// We asked that the current device or all the current model's device be restarted,
			// so just call the follow-up method in the main app

			if (parsedData)
			{
				if ([self checkStatus:parsedData] == 1)
				{
					[nc postNotificationName:@"BuildAPIDeviceRestarted" object:nil];
				}
			}

			break;

		case kConnectTypeAssignDeviceToModel:

			// We asked that the current device be assigned to another model,
			// so just call the follow-up method in the main app

			if (parsedData)
			{
				if ([self checkStatus:parsedData] == 1)
				{
					[nc postNotificationName:@"BuildAPIDeviceAssigned" object:nil];
					[self getModels];
					[self getDevices];
				}
			}

			break;

		case kConnectTypeNewModel:

			// We created a new model, so we need to update the models list so that the
			// change is reflected in our local data.

			if (parsedData)
			{
				if ([self checkStatus:parsedData] == 1)
				{
					// Tell the main app we have successfully created the model

					[nc postNotificationName:@"BuildAPIModelCreated" object:nil];

					// Now get a new list of models, and then a new list of devices

					[self getModels];
					[self getDevices];
				}
			}

			break;

		case kConnectTypeDeleteModel:

			// We deleted a new model, so we need to update the models list so that the
			// change is reflected in our local data.

			if (parsedData)
			{
				if ([self checkStatus:parsedData] == 1)
				{
					// Tell the main app we have successfully delete the model

					[nc postNotificationName:@"BuildAPIModelDeleted" object:nil];

					// Now get a new list of models, and then a new list of devices

					[self getModels];
					[self getDevices];
				}
			}

			break;

		case kConnectTypeUpdateDevice:

			// We asked that the device information be updated, which may include a name-change or
			// model assignment so we update the model and device lists so that the change
			// is reflected in our local data.

			if (parsedData)
			{
				if ([self checkStatus:parsedData] == 1)
				{
					// Tell the main app we have successfully updated the device

					[nc postNotificationName:@"BuildAPIDeviceUpdated" object:nil];

					// Now get a new list of models, and then a new list of devices

					[self getModels];
					[self getDevices];
				}
			}

			break;

		case kConnectTypeDeleteDevice:

			// We asked that the device be deleted, so we update the model and device lists
			//  so that the change is reflected in our local data.

			if (parsedData)
			{
				if ([self checkStatus:parsedData] == 1)
				{
					// Tell the main app we have successfully deleted the device

					[nc postNotificationName:@"BuildAPIDeviceDeleted" object:nil];

					// Now get a new list of models, and then a new list of devices

					[self getModels];
					[self getDevices];
				}
			}

			break;

		case kConnectTypeUpdateModel:

			// We asked that the model be updated, which may include a name-change or
			// device assignment so we update the model and device lists so that the change
			// is reflected in our local data.

			if (parsedData)
			{
				if ([self checkStatus:parsedData] == 1)
				{
					// Tell the main app we have successfully updated the model

					[nc postNotificationName:@"BuildAPIModelUpdated" object:nil];

					// Now get a new list of models, and then a new list of devices

					[self getModels];
					[self getDevices];
				}
			}

			break;

		case kConnectTypeGetCodeLatestBuild:

			// We asked for the most recent code revision. Here we have received all the builds –
			// we extract the version of the most recent entry, then request this particular build

			if (parsedData)
			{
				if ([self checkStatus:parsedData] == 1)
				{
					NSArray *code = [parsedData objectForKey:@"revisions"];
					NSDictionary *latestBuild = [code objectAtIndex:0];
					NSNumber *n = [latestBuild valueForKey:@"version"];
					[self getCodeRev:_currentModelID :n.integerValue];
				}
			}

			break;

		case kConnectTypeGetCodeRev:

			// We asked for a code revision, which we make available to the main app

			if (parsedData)
			{
				if ([self checkStatus:parsedData] == 1)
				{
					NSDictionary *code = [parsedData objectForKey:@"revision"];
					deviceCode = [code objectForKey:@"device_code"];
					agentCode = [code objectForKey:@"agent_code"];

					 // Tell the main app we have the code in the deviceCode and agentCode properties

					[nc postNotificationName:@"BuildAPIGotCodeRev" object:nil];
				}
			}

			break;

		case kConnectTypeGetLogEntries:

			// We asked for all of a devices log entries, which we return to the main app

			if (parsedData)
			{
				if ([self checkStatus:parsedData] == 1)
				{
					NSArray *logs = [parsedData objectForKey:@"logs"];

					// Pass the ball back to the AppDelegate

					// Tell the main app we have the code in the deviceCode and agentCode properties

					[nc postNotificationName:@"BuildAPIGotLogs" object:logs];
				}
			}

			break;

		case kConnectTypeGetLogEntriesRanged:

			// We asked for a log stream. The first time through the process, we only access the poll_url
			// property, which we use to generate a second request, for the 'streamed' data

			if (parsedData)
			{
				if ([self checkStatus:parsedData] == 1)
				{
					// Save the URL of the log stream and begin logging

					_logStreamURL = [kBaseAPIURL stringByAppendingString:[parsedData objectForKey:@"poll_url"]];
					[self startLogging];
				}
			}

			break;

		case kConnectTypeGetLogEntriesStreamed:

			// We asked for a log stream and the first streamed entry has arrived. Send it to the main
			// app to be displayed, and then re-commence logging

			if (parsedData)
			{
				if ([self checkStatus:parsedData] == 1)
				{
					[nc postNotificationName:@"BuildAPILogStream" object:[parsedData objectForKey:@"logs"]];
				}
			}

			[self startLogging];
			break;

		default:
			break;
	}

	theCurrentConnexion = nil;
}



#pragma mark - Misc Methods


- (void)reportError
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ToolsAPIError" object:nil];
}



- (NSInteger)checkStatus:(NSDictionary *)data
{
	// Before using data returned from the server, check that the success field is not false
	// If it is, set up an error message

	NSNumber *value = [data objectForKey:@"success"];

	if (value.integerValue == 0)
	{
		// There has been an error reported by the API

		NSDictionary *err = [data objectForKey:@"error"];
		errorMessage = [err objectForKey:@"message_short"];
		[self reportError];
	}

	return value.integerValue;
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
