
//  Copyright © 2017 Tony Smith. All rights reserved.
//  Issued under the MIT licence

//  BuildAPIAccess 3.0.0

#import "Token.h"

@implementation Token


@synthesize accessToken, refreshToken, expiryDate;


- (instancetype)init
{
	if (self = [super init])
	{
		accessToken = @"";
		refreshToken = @"";
		expiryDate = @"";
	}

	return self;
}


@end
