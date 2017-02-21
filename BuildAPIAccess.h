
//  Copyright (c) 2015-17 Tony Smith. All rights reserved.
//  Issued under the MIT licence

//  BuildAPIAccess 3.0.0


#import <Foundation/Foundation.h>
#import "BuildAPIAccessConstants.h"
#import "Connexion.h"


@interface BuildAPIAccess : NSObject <NSURLConnectionDataDelegate, NSURLSessionDataDelegate, NSURLSessionTaskDelegate>

{
    NSMutableArray *_connexions, *_loggingDevices;
	NSDictionary *_token;
    NSString *_baseURL, *_currentModelID, *_logURL, *_lastStamp, *_userAgent, *_username, *_password;
    BOOL _followOnFlag, _useSessionFlag;
}


// Initialization Methods

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (void)setCredentials:(NSString *)username :(NSString *)password;
- (void)getToken;
- (void)killAllConnections;

// v5 Data Request Methods

- (void)getProducts;
- (void)getProducts:(BOOL)withDeviceGroups;

// Data Request Methods

- (void)getModels;
- (void)getModels:(BOOL)withDevices;
- (void)getDevices;
- (void)getCode:(NSString *)modelID;
- (void)getCodeRev:(NSString *)modelID :(NSInteger)build;
- (void)getLogsForDevice:(NSString *)deviceID :(NSString *)since :(BOOL)isStream;

// Action Methods

- (void)createNewModel:(NSString *)modelName;
- (void)updateModel:(NSString *)modelID :(NSString *)key :(NSString *)value;
- (void)uploadCode:(NSString *)modelID :(NSString *)newDeviceCode :(NSString *)newAgentCode;
- (void)deleteModel:(NSString *)modelID;
- (void)assignDevice:(NSString *)deviceID toModel:(NSString *)modelID;
- (void)restartDevice:(NSString *)deviceID;
- (void)restartDevices:(NSString *)modelID;
- (void)deleteDevice:(NSString *)deviceID;
- (void)updateDevice:(NSString *)deviceID :(NSString *)key :(NSString *)value;
- (void)autoRenameDevice:(NSString *)deviceID;

// Logging Methods

- (void)startLogging:(NSString *)deviceID;
- (void)stopLogging:(NSString *)deviceID;
- (BOOL)isDeviceLogging:(NSString *)deviceID;
- (NSInteger)indexForID:(NSString *)deviceID;
- (NSUInteger)loggingCount;

// HTTP Request Construction Methods

- (NSMutableURLRequest *)makeGETrequest:(NSString *)path;
- (NSMutableURLRequest *)makePUTrequest:(NSString *)path :(NSDictionary *)bodyDictionary;
- (NSMutableURLRequest *)makePOSTrequest:(NSString *)path :(NSDictionary *)bodyDictionary;
- (NSMutableURLRequest *)makeDELETErequest:(NSString *)path;

// Connection Methods

- (Connexion *)launchConnection:(NSMutableURLRequest *)request :(NSInteger)actionCode;
- (void)relaunchConnection:(id)userInfo;

// NSURLSession/NSURLConnection Joint Methods

- (NSDictionary *)processConnection:(Connexion *)connexion;
- (void)processResult:(Connexion *)connexion :(NSDictionary *)data;

// Base64 Methods

- (NSString *)encodeBase64String:(NSString *)plainString;
- (NSString *)decodeBase64String:(NSString *)base64String;

// Utility Methods

- (NSDictionary *)makeDictionary:(NSString *)key :(NSString *)value;
- (NSMutableURLRequest *)makeRequest:(NSString *)verb :(NSString *)path;
- (void)setRequestAuthorization:(NSMutableURLRequest *)request;
- (void)reportError;


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

@end
