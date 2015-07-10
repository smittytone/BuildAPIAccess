
//  Created by Tony Smith on 15/09/2014.
//  Copyright (c) 2014-15 Tony Smith. All rights reserved.
//  Issued under the MIT licence


#import <Foundation/Foundation.h>


@interface Connexion : NSObject


// Required by BuildAPIAccess
// Connexion simply a packaging object for NSURLConnections and associated data
// ie. it has no methods, just four properties:


@property (nonatomic, strong) NSURLConnection *connexion;
@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, readwrite) NSInteger actionCode;
@property (nonatomic, readwrite) NSInteger errorCode;


@end
