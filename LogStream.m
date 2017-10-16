
//  Created by Tony Smith on 19/05/2017.
//  Copyright © 2017 Tony Smith. All rights reserved.


#import "LogStream.h"

@implementation LogStream



- (instancetype)initWithURL:(NSURL *)URL
{
	return [self initWithURL:URL :kLogStreamDefaultTimeout];
}



- (instancetype)initWithURL:(NSURL *)URL :(NSTimeInterval)timeoutInterval
{
	self = [super init];

	if (self)
	{
		streamURL = URL;
		timeout = timeoutInterval;
		retryInterval = kLogStreamDefaultRetryInterval;
		isClosed = YES;

		// Set up parallel operation queues and limit them to serial operation
		// TODO do we really need two?

		connectionQueue = [[NSOperationQueue alloc] init];
		connectionQueue.maxConcurrentOperationCount = 1;

		messageQueue = [[NSOperationQueue alloc] init];
		messageQueue.maxConcurrentOperationCount = 1;

		// Open the Connection
		/*
		[connectionQueue addOperationWithBlock:^{
			[self openStream];
		}];
		 */

		[self openStream];
	}

	return self;
}



- (void)openStream
{
	isClosed = NO;

	if (streamConnexion == nil) streamConnexion = [[Connexion alloc] init];

	NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
														  delegate:self
													 delegateQueue:[NSOperationQueue currentQueue]];

	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:streamURL
														   cachePolicy:NSURLRequestReloadIgnoringCacheData
													   timeoutInterval:timeout];

	if (lastEventID) [request setValue:lastEventID forHTTPHeaderField:@"Last-Event-ID"];

	streamConnexion.task = [session dataTaskWithRequest:request];

	[streamConnexion.task resume];

	// Create a new event to record the state change

	LogStreamEvent *event = [[LogStreamEvent alloc] init];
	event.readyState = kLogStreamEventStateConnecting;

	// Add the stage-change event to the connection queue

	/*
	[connectionQueue addOperationWithBlock:^{
		[self dispatchEvent:event :kLogStreamEventStateChange];
	}];
	*/

	[self dispatchEvent:event :kLogStreamEventStateChange];
}



- (void)close
{
	// Flag the closure (prevents an error report from the 'didComplete:' delegate method

	isClosed = YES;

	// Cancel the saved task to close it

	[streamConnexion.task cancel];

	// Notify the host that the log stream is closed

	[[NSNotificationCenter defaultCenter] postNotificationName:@"LogStreamConnectionClosed" object:nil];
}



- (void)dispatchEvent:(LogStreamEvent *)event
{
	// Processes the supplied event when it is called from the message queue:
	// ie. we add it to the connection queue

	/*
	[connectionQueue addOperationWithBlock:^{
		[self dispatchEvent:event :kLogStreamEventMessage];
	}];
	 */

	[self dispatchEvent:event :kLogStreamEventMessage];
}



- (void)dispatchEvent:(LogStreamEvent *)event :(NSInteger)eventType
{
	// Processes the supplied event when it is called from the connection queue

	NSDictionary *dict = nil;
	NSString *stateType;

	switch (eventType)
	{
		case kLogStreamEventStateChange:

			// The stream has signalled a state change

			switch (event.readyState)
			{
				case kLogStreamEventStateConnecting:
					stateType = @"State: Connecting";
					break;

				case kLogStreamEventStateOpen:
					stateType = @"State: Connection open";

					// Connection is open, notify the host

					//[[NSNotificationCenter defaultCenter] postNotificationName:@"LogStreamConnectionOpen" object:nil];
					[self performSelectorOnMainThread:@selector(relayLogOpen) withObject:nil waitUntilDone:NO];

					break;

				default:
					stateType = @"State: Connection closed";
			}

#ifdef DEBUG
	NSLog(@"%@", stateType);
#endif

			break;

		case kLogStreamEventConnectionOpen:
			break;

		case kLogStreamEventMessage:

#ifdef DEBUG
	NSLog(@"Message received: %@", event.data);
#endif

			// Relay the log message to the host app

			if (event.data != nil)
			{
				dict = @{ @"message" : event.data };

				[self performSelectorOnMainThread:@selector(relayLogEntry:) withObject:dict waitUntilDone:NO];
			}

			break;

		case kLogStreamEventError:

#ifdef DEBUG
	NSLog(@"Error: %@", event.error.description);
#endif

			NSNumber *ec = [NSNumber numberWithInteger:event.readyState];

			dict = @{ @"message" : event.error,
					  @"code" : ec };

			[self performSelectorOnMainThread:@selector(relayLogClosed:) withObject:dict waitUntilDone:NO];
			break;
	}
}



- (void)relayLogEntry:(NSDictionary *)entry
{
	// Called on the main thread to pass a received log entry to the host app

	[[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPILogEntryReceived" object:entry];
}



- (void)relayLogOpen
{
	// Called on the main thread to notify the host that the log stream is ooen

	[[NSNotificationCenter defaultCenter] postNotificationName:@"LogStreamConnectionOpen" object:nil];
}



- (void)relayLogClosed:(NSDictionary *)error
{
	// Called on the main thread to notify the host that the log stream is closed - possibly because of an error

	[[NSNotificationCenter defaultCenter] postNotificationName:@"LogStreamConnectionClosed" object:error];
}



#pragma mark - NSURLSession Connection Delegate Methods


- (void)URLSession:(NSURLSession *)session
		  dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
	NSHTTPURLResponse *rps = (NSHTTPURLResponse *)response;
	NSInteger code = rps.statusCode;

	if (code == 200)
	{
		// The stream is open, so signal this will a state-change event

		LogStreamEvent *event = [[LogStreamEvent alloc] init];
		event.readyState = kLogStreamEventStateOpen;

		// Issue a readyState-change event to connection queue
		/*
		[connectionQueue addOperationWithBlock:^{
			[self dispatchEvent:event :kLogStreamEventStateChange];
		}];
		 */

		[self dispatchEvent:event :kLogStreamEventStateChange];
	}

	// Allow the connection to complete so we can analyze any error later, in 'didCompleteWithError:'

	if (completionHandler) completionHandler(NSURLSessionResponseAllow);
}



- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
	// This delegate method is called when the server sends some data back
	// Run through the connections in our list and add the incoming data to the correct one

	NSString *eventString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	NSArray *lines = [eventString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

	LogStreamEvent *event = [[LogStreamEvent alloc] init];
	event.readyState = kLogStreamEventStateOpen;

	for (NSString *line in lines)
	{
		if ([line hasPrefix:kLogStreamKeyValueDelimiter])
		{
			// Ignore lines starting with ':'

			continue;
		}

		if (line == nil || line.length == 0)
		{
			if (event.data != nil)
			{
				// Dispatch message to the message queue to guarantee ordering of dispatch

				/*
				[messageQueue addOperationWithBlock:^{
					[self dispatchEvent:event];
				}];
				 */

				[connectionQueue addOperationWithBlock:^{
					[self dispatchEvent:event :kLogStreamEventMessage];
				}];
			}

			// Create a new event

			event = [[LogStreamEvent alloc] init];
			event.readyState = kLogStreamEventStateOpen;
			continue;
		}

		@autoreleasepool
		{
			NSScanner *scanner = [NSScanner scannerWithString:line];
			scanner.charactersToBeSkipped = [NSCharacterSet whitespaceCharacterSet];

			// Separate out keys and values

			NSString *key, *value;
			[scanner scanUpToString:kLogStreamKeyValueDelimiter intoString:&key];
			[scanner scanString:kLogStreamKeyValueDelimiter intoString:nil];
			[scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&value];

			if (key && value)
			{
				if ([key isEqualToString:kLogStreamEventEventKey])
				{
					event.event = value;
				}
				else if ([key isEqualToString:kLogStreamEventDataKey])
				{
					if (event.data != nil)
					{
						event.data = [event.data stringByAppendingFormat:@"\n%@", value];
					}
					else
					{
						event.data = value;
					}
				}
				else if ([key isEqualToString:kLogStreamEventIDKey])
				{
					lastEventID = value;
				}
				else if ([key isEqualToString:kLogStreamEventRetryKey])
				{
					retryInterval = [value doubleValue];
				}
			}
		}
	}
}



- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
	// Is the connection already closed? If so, bail

	if (isClosed) return;

	streamConnexion.task = nil;

	// Create an error event

	LogStreamEvent *event = [[LogStreamEvent alloc] init];
	event.readyState = kLogStreamEventStateClosed;
	event.error = (error != nil) ? error : [NSError errorWithDomain: @""
															   code: event.readyState
														   userInfo: @{ NSLocalizedDescriptionKey: @"Connection with the event source was closed." } ];

	// Dipatch a state-change event to the connection queue

	[connectionQueue addOperationWithBlock:^{
		[self dispatchEvent:event :kLogStreamEventStateChange];
	}];

	// [self dispatchEvent:event :kLogStreamEventStateChange];

	// Dispatch an error event to the connection queue

	/*
	[connectionQueue addOperationWithBlock:^{
		[self dispatchEvent:event :kLogStreamEventError];
	}];
	 */

	[self dispatchEvent:event :kLogStreamEventError];

	// Attempt to re-open the connection in 'retryInterval' seconds

	[NSTimer timerWithTimeInterval:retryInterval repeats:NO block:^(NSTimer * _Nonnull timer) {
		[self openStream];
	}];
}



@end
