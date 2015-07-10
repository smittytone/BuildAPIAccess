
//  Created by Tony Smith on 15/09/2014.
//  Copyright (c) 2014-15 Tony Smith. All rights reserved.
//  Issued under the MIT licence


#import "Connexion.h"

@implementation Connexion

@synthesize actionCode;
@synthesize connexion;
@synthesize receivedData;
@synthesize errorCode;



- (id)init
{
    if (self = [super init])
    {
        connexion = nil;
        receivedData = nil;
        actionCode = -1;
        errorCode = -1;
    }

    return self;
}



@end
