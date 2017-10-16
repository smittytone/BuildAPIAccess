
//  Created by Tony Smith on 19/05/2017.
//  Copyright © 2017 Tony Smith. All rights reserved.


#import <Foundation/Foundation.h>
#import "Connexion.h"
#import "LogStreamEvent.h"


// Define the object's constants

#ifndef LogStreamContants_h
#define LogStreamContants_h

// Data delimiters

#define kLogStreamKeyValueDelimiter				@":"
#define kLogStreamEventSeparatorLFLF			@"\n\n"
#define kLogStreamEventSeparatorCRCR			@"\r\r"
#define kLogStreamEventSeparatorCRLFCRLF		@"\r\n\r\n"
#define kLogStreamEventKeyValuePairSeparator	@"\n"

// Event keys

#define kLogStreamEventDataKey					@"data"
#define kLogStreamEventIDKey					@"id"
#define kLogStreamEventEventKey					@"event"
#define kLogStreamEventRetryKey					@"retry"

// Event types

#define kLogStreamEventStateChange				1
#define kLogStreamEventConnectionOpen			2
#define kLogStreamEventMessage					3
#define	kLogStreamEventError					4

// Event States

#define kLogStreamEventStateConnecting			0
#define kLogStreamEventStateOpen				1
#define kLogStreamEventStateClosed				2

#define kLogStreamDefaultTimeout				300.0
#define kLogStreamDefaultRetryInterval			1.0

#endif



@interface LogStream : NSObject <NSURLSessionDataDelegate, NSURLSessionTaskDelegate>
{
	Connexion *streamConnexion;

	NSURL *streamURL;
	NSString *lastEventID;
	NSTimeInterval timeout, retryInterval;
	NSOperationQueue *messageQueue, *connectionQueue;

	BOOL isClosed;
}


- (instancetype)initWithURL:(NSURL *)URL;
- (instancetype)initWithURL:(NSURL *)URL :(NSTimeInterval)timeoutInterval;

- (void)openStream;
- (void)dispatchEvent:(LogStreamEvent *)event :(NSInteger)eventType;
- (void)dispatchEvent:(LogStreamEvent *)event;

@end
