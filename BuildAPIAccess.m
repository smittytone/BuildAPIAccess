
//  Copyright (c) 2015-16 Tony Smith. All rights reserved.
//  Issued under the MIT licence

//  BuildAPIAccess 1.1.3


#import "BuildAPIAccess.h"


@implementation BuildAPIAccess


@synthesize devices, models, errorMessage, statusMessage, deviceCode, agentCode;



#pragma mark - Initialization Methods


- (instancetype)init
{
    // Generic initializer - should not be called directly

    if (self = [super init])
    {
        // Public entities

        devices = [[NSMutableArray alloc] init];
        models = [[NSMutableArray alloc] init];

        errorMessage = @"";

        // Private entities

        _connexions = [[NSMutableArray alloc] init];
        _lastStamp = nil;
        _logDevice = nil;
        _logURL = nil;
        _harvey = nil;
        _useSessionFlag = YES;

		_baseURL = [kBaseAPIURL stringByAppendingString:kAPIVersion];
    }

    return self;
}


- (id)initForNSURLSession
{
    return [self init];
}


- (id)initForNSURLConnection
{
    self = [self init];
    _useSessionFlag = NO;
    return self;
}


- (void)clrk
{
    // Clear the saved API k

    _harvey = nil;
}



- (void)setk:(NSString *)harvey
{
    // Set the API k used by the BuildAPIAccess instance

    if (harvey.length > 0) _harvey = harvey;
}



#pragma mark - Data Request Methods


- (void)getModels
{
    // Set up a GET request to the /models URL - gets all models

    NSMutableURLRequest *request = [self makeGETrequest:[_baseURL stringByAppendingString:@"models"]];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetModels];
    }
    else
    {
        errorMessage = @"[ERROR] Could not create a request to list your models.";
        [self reportError];
    }
}



- (void)getModels:(BOOL)withDevices {

	if (withDevices) _followOnFlag = YES;
	[self getModels];
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

    NSString *urlString = [_baseURL stringByAppendingFormat:@"devices/%@/logs", deviceID];
    NSInteger action = kConnectTypeNone;

    if (isStream)
    {
        action = kConnectTypeGetLogEntriesRanged;
        _logDevice = deviceID;
    }
    else
    {
        action = kConnectTypeGetLogEntries;
        if ([since compare:@""] != NSOrderedSame) urlString = [urlString stringByAppendingFormat:@"?since=%@", since];
    }

    NSMutableURLRequest *request = [self makeGETrequest:urlString];

    if (request)
    {
        [self launchConnection:request :action];
    }
    else
    {
        errorMessage = @"[ERROR] Could not create a request to get logs from the device.";
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



#pragma mark – Logging Methods


- (void)startLogging
{
    // _logURL is set by a prior request to the API for the streaming URL

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_logURL] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:3600.0];

    if (request)
    {
        [self setRequestAuthorization:request];
        [self launchConnection:request :kConnectTypeGetLogEntriesStreamed];
    }
    else
    {
        errorMessage = @"[ERROR] Could not create a request to start or continue logging.";
        [self reportError];
    }
}


- (void)stopLogging
{
    if (_connexions.count == 0) return;

    _logDevice = nil;

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

        [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStop" object:nil];
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
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    if (bodyDictionary)
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



#pragma mark - Connection Method


- (void)launchConnection:(NSMutableURLRequest *)request :(NSInteger)actionCode
{
    // Create a default connexion object to store connection details

    Connexion *aConnexion = [[Connexion alloc] init];
    aConnexion.actionCode = actionCode;
    aConnexion.data = [NSMutableData dataWithCapacity:0];

    if (actionCode == kConnectTypeGetLogEntriesStreamed) [request setTimeoutInterval:3600.0];

    if (_useSessionFlag)
    {
        // Use NSURLSession for the connection. Compatible with iOS, tvOS and Mac OS X

        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
        aConnexion.task = [session dataTaskWithRequest:request];
        [aConnexion.task resume];
    }
    else
    {
        // Use NSURLConnection for the connection. Compatible with iOS and Mac OS X, but not tvOS
        // NOTE This approach has been deprecated by Apple

        aConnexion.connexion = [[NSURLConnection alloc] initWithRequest:request delegate:self];

        if (!aConnexion.connexion)
        {
            // Inform the user that the connection failed.

            errorMessage = @"[ERROR] Could not establish a connection to the Electric Imp Cloud.";
            [self reportError];
            return;
        }
    }

    if (_connexions.count == 0)
    {
        // Connection established successfully, so notify the main app to trigger the progress indicator
        // and then add the new connexion to the list of current connections

        [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStart" object:nil];
    }

    // Add the new connection to the list

    [_connexions addObject:aConnexion];
}



#pragma mark - NSURLConnection Delegate Methods


- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
    // Because the Build API uses Basic authentication, this is probably unnecessary,
    // but retain for future use as required

    if (protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic ||
        protectionSpace.authenticationMethod == NSURLAuthenticationMethodDefault)
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
    // Because the Build API uses Basic authentication, this is probably unnecessary,
    // but retain for future use as required

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
    // Inform the host app that there was a connection failure

    errorMessage = @"[ERROR] Could not connect to the Electric Imp server.";
    [self reportError];

    // Terminate the failed connection and remove it from the list of current connections

    [connection cancel];
    [_connexions removeObject:connection];

    if (_connexions.count < 1)
    {
        // If there are no current connections, tell the app to
        // turn off the connection activity indicator

        [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStop" object:nil];
    }
}



- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
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

            for (Connexion *aConnexion in _connexions)
            {
                // Run through the connections in our list and add the incoming error code to the correct one

                if (aConnexion.connexion == connection)
                {
                    // This request has been rate-limited, so we need to recall it in 1+ seconds

                    NSArray *values = [NSArray arrayWithObjects:[connection.originalRequest copy], [NSNumber numberWithInteger:aConnexion.actionCode], nil];
                    NSArray *keys = [NSArray arrayWithObjects:@"request", @"actioncode", nil];
                    NSDictionary *dict =[NSDictionary dictionaryWithObjects:values forKeys:keys];
                    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(relaunchConnection:) userInfo:dict repeats:NO];
                    [_connexions removeObject:aConnexion];
                    [connection cancel];

                    if (_connexions.count < 1)
                    {
                        // No active connections left, so notify the host app

                        [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStop" object:nil];
                    }
                }
            }
        }
        else if (code == 504)
        {
            // Bad Gateway error received - this usually occurs during log streaming

            if (_logDevice != nil)
            {
                // We are still streaming so just cancel the current connection...

                for (Connexion *aConnexion in _connexions)
                {
                    if (aConnexion.connexion == connection) [_connexions removeObject:aConnexion];
                }

                [connection cancel];

                // ...and recommence logging

                [self startLogging];
            }
        }
        else
        {
            // Any other error

            for (Connexion *aConnexion in _connexions)
            {
                // Run through the connections in our list and add the incoming error code to the correct one

                if (aConnexion.connexion == connection) aConnexion.errorCode = code;
            }
        }
    }
    else if (code > 299 && code < 400)
    {
        // This is a redirect code not an error. This *should* not occur,
        // but here is a point to trap it just in case

        NSLog(@"Redirect Status code received");
    }
}



- (void)relaunchConnection:(id)userInfo
{
    // This method is called in response to the receipt of a status code 429 from the server,
    // ie. we have been rate-limited. A timer will bring us here in 1.0 seconds

    NSDictionary *dict = (NSDictionary *)userInfo;
    NSMutableURLRequest *request = [dict objectForKey:@"request"];
    NSInteger actionCode = [[dict objectForKey:@"actioncode"] integerValue];
    [self launchConnection:request :actionCode];
}



- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // This delegate method is called when the server sends some data back
    // Add it to the correct connexion object

    for (Connexion *aConnexion in _connexions)
    {
        // Run through the connections in our list and add the incoming data to the correct one

        if (aConnexion.connexion == connection) [aConnexion.data appendData:data];
    }
}



- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // All the data has been supplied by the server in response to a connection
    // Parse the data and, according to the connection activity - update device, create model etc –
    // apply the results

    Connexion *theCurrentConnexion;
    id parsedData = nil;

    for (Connexion *aConnexion in _connexions)
    {
        // Run through the connections in the list and find the one that has just finished loading

        if (aConnexion.connexion == connection)
        {
            theCurrentConnexion = aConnexion;
            parsedData = [self processConnection:aConnexion];
        }
    }

    // End the finished connection and remove it from the list of current connections

    [connection cancel];

    if (theCurrentConnexion.actionCode != kConnectTypeNone) [self processResult:theCurrentConnexion :parsedData];

    theCurrentConnexion = nil;
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

				if (aConnexion.task == dataTask)
				{
					// This request has been rate-limited, so we need to recall it in 1+ seconds

					NSArray *values = [NSArray arrayWithObjects:[dataTask.originalRequest copy], [NSNumber numberWithInteger:aConnexion.actionCode], nil];
					NSArray *keys = [NSArray arrayWithObjects:@"request", @"actioncode", nil];
					NSDictionary *dict =[NSDictionary dictionaryWithObjects:values forKeys:keys];
					[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(relaunchConnection:) userInfo:dict repeats:NO];
					conn = aConnexion;
				}
			}

			if (conn != nil) [_connexions removeObject:conn];
			completionHandler(NSURLSessionResponseCancel);
			return;
		}

		if (code == 504)
		{
			// Bad Gateway error received - this usually occurs during log streaming
			// so if we are streaming, make sure we re-initiate the stream

			if (_logDevice != nil)
			{
				// We are still streaming to just recommence logging

				[self startLogging];
			}
		}

		// Allow the connection to pass because we'll handle the error later
		// This applies to all errors but 429s

		for (Connexion *aConnexion in _connexions) {

			// Run through the connections in our list and add the incoming error code to the correct one
			
			if (aConnexion.task == dataTask) aConnexion.errorCode = code;
		}
	}

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
	// Parse the data and, according to the connection activity - update device, create model etc –
	// apply the results

	if (error)
	{
		// React to a passed client-side error - most likely a timeout or inability to resolve the URL
		// First, notify the host app

		errorMessage = @"[ERROR] Could not connect to the Electric Imp server.";
		[self reportError];

		// Next, terminate the failed connection and remove it from the list of current connections

		Connexion *conn = nil;
		for (Connexion *aConnexion in _connexions)
		{
			// Run through the connections in the list and find the one that has just finished loading

			if (aConnexion.task == task)
			{
				[task cancel];
				conn = aConnexion;
			}
		}

		if (conn != nil) [_connexions removeObject:conn];

		// Check if there are any active connections

		if (_connexions.count < 1)
		{
			// There are no active connections, so inform the host app

			[[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStop" object:nil];
		}

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
	NSError *error;

	if (connexion.data != nil && connexion.data.length > 0)
	{
		// If we have data, attempt to decode it assuming that it is JSON (if it's not, 'error' will not equal nil

		parsedData = [NSJSONSerialization JSONObjectWithData:connexion.data options:kNilOptions error:&error];
	}

	if (error != nil)
	{
		// If the incoming data could not be decoded to JSON for some reason,
		// most likely a malformed request which returns a block of HTML

		// TODO?? Better interpret the HTML

		errorMessage = @"[ERROR] Received data could not be decoded. Is is JSON?";
		errorMessage = [errorMessage stringByAppendingFormat:@" %@", (NSString *)connexion.data];
		[self reportError];

		// Are we streaming? We want this to continue despite the error
		
		if (_logDevice != nil) [self startLogging];

		connexion.errorCode = -1;
		connexion.actionCode = kConnectTypeNone;
	}

	if (connexion.errorCode != -1)
	{
		// Check for an error being reported by the server. This will have been set for the current connection
		// by either of the didReceiveResponse: methods

		errorMessage = [NSString stringWithFormat:@"[ERROR] {Code: %lu} ", connexion.errorCode];

		if (parsedData != nil)
		{
			// 'parsedData' should contain a description of the error, eg. unknown device, or a code syntax error

			NSDictionary *errDict = [parsedData objectForKey:@"error"];
			NSString *errString = [errDict objectForKey:@"message_short"];
			errorMessage = [errorMessage stringByAppendingString:errString];
			errString = [errDict objectForKey:@"code"];

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

					errorMessage = [errorMessage stringByAppendingString:@"\n Agent Code errors:"];

					for (NSUInteger j = 0 ; j < aArray.count ; ++j)
					{
						errDict = [aArray objectAtIndex:j];
						NSNumber *row = [errDict valueForKey:@"row"];
						NSNumber *col = [errDict valueForKey:@"column"];
						errorMessage = [errorMessage stringByAppendingFormat:@"\n  %@ at row %li, col %li", [errDict objectForKey:@"error"], row.longValue, col.longValue];
					}
				}

				if (dArray != nil && (NSNull *)dArray != [NSNull null])
				{
					// We have error(s) in the device Squirrel - decode and report them

					errorMessage = [errorMessage stringByAppendingString:@"\n Device Code errors:"];

					for (NSUInteger j = 0 ; j < dArray.count ; ++j)
					{
						errDict = [dArray objectAtIndex:j];
						NSNumber *row = [errDict valueForKey:@"row"];
						NSNumber *col = [errDict valueForKey:@"column"];
						errorMessage = [errorMessage stringByAppendingFormat:@"\n  %@ at row %li, col %li", [errDict objectForKey:@"error"], row.longValue, col.longValue];
					}
				}
			}
		}

		// Report the error via notifications and clear the connection's action code

		if (!(connexion.errorCode == 504 && _logDevice != nil)) [self reportError];
		connexion.actionCode = kConnectTypeNone;
	}

	// Processing done, remove this connection from the current list of active connections and signal
	// the host app if there are no more active connections (eg. to disable an activity indicator)

	[_connexions removeObject:connexion];
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

        if ([self checkStatus:data] == kServerSendsSuccess)
        {
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
                    [self getModels];
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
                    [self getModels];
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
                    [self getModels];
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
                    [self getModels];
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
                    [self getModels];

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
                    [self getModels];
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

                    _logURL = [kBaseAPIURL stringByAppendingString:[data objectForKey:@"poll_url"]];
                    [self startLogging];

                    break;
                }

                case kConnectTypeGetLogEntriesStreamed:
                {
                    // We asked for a log stream and the first streamed entry has arrived. Send it to the main
                    // app to be displayed, and then re-commence logging

                    [nc postNotificationName:@"BuildAPILogStream" object:[data objectForKey:@"logs"]];
                    [self startLogging];

                    break;
                }

                default:
                    break;
            }
        }
    }
}



- (NSInteger)checkStatus:(NSDictionary *)data
{
    // Before using data returned from the server, check that the success field is not false
    // If it is, set up an error message. 1 = success; 0 = failure

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



#pragma mark - Utility Methods


- (NSDictionary *)makeDictionary:(NSString *)key :(NSString *)value
{
    NSArray *keys = [NSArray arrayWithObjects:key, nil];
    NSArray *values = [NSArray arrayWithObjects:value, nil];
    return [NSDictionary dictionaryWithObjects:values forKeys:keys];
}



- (NSMutableURLRequest *)makeRequest:(NSString *)verb :(NSString *)path
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path]];
    [self setRequestAuthorization:request];
    [request setHTTPMethod:verb];
    return request;
}



- (void)setRequestAuthorization:(NSMutableURLRequest *)request
{
    if (_harvey != nil)
    {
        [request setValue:[@"Basic " stringByAppendingString:[self encodeBase64String:_harvey]] forHTTPHeaderField:@"Authorization"];
        [request setTimeoutInterval:30.0];
    }
    else
    {
        errorMessage = @"Accessing the Build API requires an API key.";
        [self reportError];
    }
}


- (void)reportError
{
    // Signal the host app that we have an error message for it to display (in 'errorMessage')

    [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIError" object:self];
}


@end
