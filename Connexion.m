
//  Copyright (c) 2015-17 Tony Smith. All rights reserved.
//  Issued under the MIT licence

//  BuildAPIAccess 3.0.0


#import "Connexion.h"


@implementation Connexion


@synthesize actionCode, data, errorCode, task, representedObject;


- (instancetype)init
{
	if (self = [super init])
	{
		task = nil;
		data = nil;
		representedObject = nil;
		actionCode = -1;
		errorCode = -1;
	}

	return self;
}


@end
