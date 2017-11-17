
//  Copyright © 2017 Tony Smith. All rights reserved.
//  Issued under the MIT licence

//  BuildAPIAccess 3.0.0

#import "LogStreamEvent.h"


@implementation LogStreamEvent


@synthesize eid, event, data, type, state, error;


- (instancetype)init
{
	if (self = [super init])
	{
		eid = nil;
		type = kLogStreamEventTypeNone;
		state = kLogStreamEventStateUnknown;
		event = nil;
		error = nil;
		data = nil;
	}

	return self;
}


@end
