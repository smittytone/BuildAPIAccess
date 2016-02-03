

//  Copyright (c) 2014-15 Tony Smith. All rights reserved.
//  Issued under the MIT licence

// BuildAPIAccess 1.1.1


#import "Connexion.h"


@implementation Connexion


@synthesize actionCode, connexion, data, errorCode, task;



- (id)init
{
	if (self = [super init])
	{
		connexion = nil;
		task = nil;
		data = nil;
		actionCode = -1;
		errorCode = -1;
	}
	
	return self;
}


@end
