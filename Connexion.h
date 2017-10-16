
//  Copyright (c) 2015-17 Tony Smith. All rights reserved.
//  Issued under the MIT licence

//  BuildAPIAccess 3.0.0


#import <Foundation/Foundation.h>


@interface Connexion : NSObject


// Required by BuildAPI access class
// Connexion simply a packaging object for NSURLSessionTasks
// and associated data ie. it has no methods, just four properties:


- (instancetype)init;


// Properties

@property (nonatomic, strong)       NSURLSessionTask    *task;
@property (nonatomic, strong)       NSMutableData       *data;
@property (nonatomic, readwrite)    NSInteger           actionCode;
@property (nonatomic, readwrite)    NSInteger           errorCode;
@property (nonatomic, strong)		id					representedObject;


@end
