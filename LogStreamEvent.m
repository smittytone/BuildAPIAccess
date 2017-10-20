
//  Copyright © 2017 Tony Smith. All rights reserved.
//  Issued under the MIT licence

//  BuildAPIAccess 3.0.0

#import "LogStreamEvent.h"


@implementation LogStreamEvent


@synthesize eid, event, data, readyState, error;


- (instancetype)init
{
	if (self = [super init])
	{
		eid = nil;
		readyState = -1;
		event = nil;
		error = nil;
		data = nil;
	}

	return self;
}


@end
