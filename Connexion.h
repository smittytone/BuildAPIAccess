
//  Copyright (c) 2014-15 Tony Smith. All rights reserved.
//  Issued under the MIT licence

// BuildAPIAccess 1.1.1


#import <Foundation/Foundation.h>


@interface Connexion : NSObject


// Required by BuildAPI access class
// Connexion simply a packaging object for NSURLConnections / NSURLSessionTasks
// and associated data ie. it has no methods, just five properties:


@property (nonatomic, strong) NSURLConnection *connexion;
@property (nonatomic, strong) NSURLSessionTask *task;
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, readwrite) NSInteger actionCode;
@property (nonatomic, readwrite) NSInteger errorCode;


@end
