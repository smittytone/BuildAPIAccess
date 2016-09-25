
//  Copyright (c) 2014-16 Tony Smith. All rights reserved.
//  Issued under the MIT licence

//  BuildAPIAccess 2.0.1


#import "Connexion.h"


@implementation Connexion


@synthesize actionCode, connexion, data, errorCode, task;



- (instancetype)init
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
