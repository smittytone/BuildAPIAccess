

//  Copyright (c) 2014-15 Tony Smith. All rights reserved.
//  Issued under the MIT licence


#import "Connexion.h"


@implementation Connexion


@synthesize actionCode, connexion, receivedData, errorCode, task;



- (id)init
{
	if (self = [super init])
	{
		connexion = nil;
		task = nil;
		receivedData = nil;
		actionCode = -1;
		errorCode = -1;
	}
	
	return self;
}


@end