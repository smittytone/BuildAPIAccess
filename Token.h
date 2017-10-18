
//  Copyright © 2017 Tony Smith. All rights reserved.
//  Issued under the MIT licence

//  BuildAPIAccess 3.0.0

#import <Foundation/Foundation.h>

@interface Token : NSObject


@property (nonatomic, strong) NSString *accessToken;
@property (nonatomic, strong) NSString *expiryDate;
@property (nonatomic, strong) NSString *refreshToken;


@end
