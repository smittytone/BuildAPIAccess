
//  Copyright (c) 2015-17 Tony Smith. All rights reserved.
//  Issued under the MIT licence

//  BuildAPIAccess 3.0.0


#import <Foundation/Foundation.h>
#import "BuildAPIAccessConstants.h"
#import "Connexion.h"


@interface BuildAPIAccess : NSObject <NSURLConnectionDataDelegate, NSURLSessionDataDelegate, NSURLSessionTaskDelegate>

{
    NSMutableArray *_connexions, *_loggingDevices, *_pendingConnections;
	NSDictionary *_token, *_me;
    NSString *_baseURL, *_currentModelID, *_logURL, *_lastStamp, *_userAgent, *_username, *_password;
	NSInteger _pageSize;
    BOOL _followOnFlag, _pageSizeChangeFlag;
}


// Initialization Methods

- (instancetype)init NS_DESIGNATED_INITIALIZER;

// Login Methods

- (void)login:(NSString *)username :(NSString *)password;
- (void)getNewSessionToken;
- (BOOL)checkSessionToken;

// Pagination Methods

- (void)setPageSize:(NSInteger)size;

// v5 Data Request Methods

- (void)getProducts;
- (void)getProducts:(BOOL)withDeviceGroups;
- (void)getDeviceGroups;
- (void)getDevices;

// v5 Action Methods

- (void)createProduct:(NSString *)name :(NSString *)description;
- (void)updateProduct:(NSString *)productID :(NSString *)key :(NSString *)value;
- (void)createDeviceGroup:(NSString *)name :(NSString *)description :(NSString *)productID :(NSInteger)type;
- (void)updateDeviceGroup:(NSDictionary *)devicegroup :(NSString *)key :(NSString *)value;

// Logging Methods


// HTTP Request Construction Methods

- (NSMutableURLRequest *)makeGETrequest:(NSString *)path;
- (NSMutableURLRequest *)makePATCHrequest:(NSString *)path :(NSDictionary *)bodyDictionary;
- (NSMutableURLRequest *)makePOSTrequest:(NSString *)path :(NSDictionary *)bodyDictionary;
- (NSMutableURLRequest *)makeDELETErequest:(NSString *)path;

// Connection Methods

- (Connexion *)launchConnection:(NSMutableURLRequest *)request :(NSInteger)actionCode;
- (void)relaunchConnection:(id)userInfo;
- (void)killAllConnections;

// NSURLSession/NSURLConnection Joint Methods

- (NSDictionary *)processConnection:(Connexion *)connexion;
- (void)processResult:(Connexion *)connexion :(NSDictionary *)data;

// Base64 Methods

- (NSString *)encodeBase64String:(NSString *)plainString;
- (NSString *)decodeBase64String:(NSString *)base64String;

// Utility Methods

- (void)reportError;
- (NSDictionary *)makeDictionary:(NSString *)key :(NSString *)value;
- (NSMutableURLRequest *)makeRequest:(NSString *)verb :(NSString *)path;
- (void)setRequestAuthorization:(NSMutableURLRequest *)request;
- (NSString *)getDeviceGroupType:(NSInteger)type;
- (BOOL)isFirstPage:(NSDictionary *)links;
- (NSString *)nextPageLink:(NSDictionary *)links;


@property (nonatomic, strong) NSMutableArray *devices;
@property (nonatomic, strong) NSMutableArray *models;  // REMOVE
@property (nonatomic, strong) NSMutableArray *codeErrors;
@property (nonatomic, strong) NSString *errorMessage;
@property (nonatomic, strong) NSString *statusMessage;
@property (nonatomic, strong) NSString *deviceCode; // v4 MAY remove
@property (nonatomic, strong) NSString *agentCode; // v4 MAY remove
@property (nonatomic, readonly) NSUInteger numberOfConnections;

// v5 API entities

@property (nonatomic, strong) NSMutableArray *products;
@property (nonatomic, strong) NSMutableArray *deviceGroups;
@property (nonatomic, strong) NSMutableArray *deployments;
@property (nonatomic, strong) NSMutableDictionary *currentDeployment;
@property (nonatomic, readonly) BOOL loggedInFlag;
@property (nonatomic, readwrite) NSInteger pageSize;

@end
