
//  Copyright (c) 2015-16 Tony Smith. All rights reserved.
//  Issued under the MIT licence

//  BuildAPIAccess 2.0.0


#import <Foundation/Foundation.h>
#import "BuildAPIAccessConstants.h"
#import "Connexion.h"


@interface BuildAPIAccess : NSObject <NSURLConnectionDataDelegate, NSURLSessionDataDelegate, NSURLSessionTaskDelegate>

{
    NSMutableArray *_connexions, *_loggingDevices;
    NSString *_baseURL, *_currentModelID, *_logURL, *_lastStamp, *_harvey;
    BOOL _followOnFlag, _useSessionFlag;
}


// Initialization Methods

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initForNSURLSession;
- (instancetype)initForNSURLConnection;
- (void)clrk;
- (void)setk:(NSString *)harvey;
- (void)killAllConnections;

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
- (NSInteger)checkStatus:(NSDictionary *)data;

// Base64 Methods

- (NSString *)encodeBase64String:(NSString *)plainString;
- (NSString *)decodeBase64String:(NSString *)base64String;

// Utility Methods

- (NSDictionary *)makeDictionary:(NSString *)key :(NSString *)value;
- (NSMutableURLRequest *)makeRequest:(NSString *)verb :(NSString *)path;
- (void)setRequestAuthorization:(NSMutableURLRequest *)request;
- (void)reportError;


@property (nonatomic, strong) NSMutableArray *devices;
@property (nonatomic, strong) NSMutableArray *models;
@property (nonatomic, strong) NSMutableArray *codeErrors;
@property (nonatomic, strong) NSString *errorMessage;
@property (nonatomic, strong) NSString *statusMessage;
@property (nonatomic, strong) NSString *deviceCode;
@property (nonatomic, strong) NSString *agentCode;



@end
