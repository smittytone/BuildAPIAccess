
//  Created by Tony Smith on 09/02/2015.
//  Copyright (c) 2015 Tony Smith. All rights reserved.
//  Issued under MIT licence


#import <Foundation/Foundation.h>
#import "BuildAPIAccessConstants.h"
#import "Connexion.h"


@interface BuildAPIAccess : NSObject <NSURLConnectionDataDelegate, NSURLSessionDataDelegate, NSURLSessionTaskDelegate>

{
	NSMutableArray *_connexions;
	NSString *_logStreamDevice, *_baseURL, *_currentModelID, *_logStreamURL, *_lastStamp, *_harvey;
	BOOL _followOnFlag, _useSessionFlag;
}


// Initialization Methods

- (id)initForNSURLSession;
- (id)initForNSURLConnection;
- (void)clrk;
- (void)setk:(NSString *)harvey;

// Data Request Methods

- (void)getModels;
- (void)getDevices;
- (void)createNewModel:(NSString *)modelNam;
- (void)getCode:(NSString *)modelID;
- (void)getCodeRev:(NSString *)modelID :(NSInteger)build;
- (void)getLogsForDevice:(NSString *)deviceID :(NSString *)since :(BOOL)isStream;

// Action Methods

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

- (void)startLogging;
- (void)stopLogging;

// HTTP Request Construction Methods

- (NSURLRequest *)makeGETrequest:(NSString *)path;
- (NSMutableURLRequest *)makePUTrequest:(NSString *)path :(NSDictionary *)bodyDictionary;
- (NSMutableURLRequest *)makePOSTrequest:(NSString *)path :(NSDictionary *)bodyDictionary;
- (NSURLRequest *)makeDELETErequest:(NSString *)path;
- (void)setRequestAuthorization:(NSMutableURLRequest *)request;

// Connection Methods

- (void)launchConnection:(id)request :(NSInteger)actionCode;
- (void)relaunchConnection:(id)userInfo;

// Misc Methods

- (void)reportError;
- (NSInteger)checkStatus:(NSDictionary *)data;

// Base64 Methods

- (NSString *)encodeBase64String:(NSString *)plainString;
- (NSString *)decodeBase64String:(NSString *)base64String;


@property (nonatomic, strong) NSMutableArray *devices;
@property (nonatomic, strong) NSMutableArray *models;
@property (nonatomic, strong) NSString *errorMessage;
@property (nonatomic, strong) NSString *statusMessage;
@property (nonatomic, strong) NSString *deviceCode;
@property (nonatomic, strong) NSString *agentCode;


@end