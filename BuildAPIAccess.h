
//  Created by Tony Smith on 09/02/2015.
//  Copyright (c) 2015 Tony Smith. All rights reserved.
//  Issued under MIT licence


#import <Foundation/Foundation.h>
#import "BuildAPIAccessConstants.h"
#import "Connexion.h"


@interface BuildAPIAccess : NSObject <NSURLConnectionDataDelegate>

{
	NSMutableArray *_connexions;
	NSDictionary *_logStreamDevice;
	NSString *_baseURL, *_currentModelID, *_logStreamURL, *_lastStamp, *_harvey;
	BOOL _initialLoadFlag;
}


// Initialization Methods

- (void)getInitialData:(NSString *)harvey;
- (void)clear;

// Data Request Methods

- (void)getModels;
- (void)getDevices;
- (void)createNewModel:(NSString *)modelNam;
- (void)uploadCode:(NSString *)newDeviceCode :(NSString *)newAgentCode :(NSInteger)modelIndex;
- (void)assignDevice:(NSInteger)deviceIndex toModel:(NSInteger)modelIndex;
- (void)getCode:(NSString *)modelID;
- (void)getCodeRev:(NSString *)modelID :(NSInteger)build;

// Action Methods

- (void)restartDevice:(NSInteger)deviceIndex;
- (void)restartDevices:(NSInteger)modelIndex;
- (void)deleteModel:(NSInteger)modelIndex;
- (void)deleteDevice:(NSInteger)deviceIndex;
- (void)updateDevice:(NSInteger)deviceIndex :(NSString *)key :(NSString *)value;
- (void)autoRenameDevice:(NSString *)devId;
- (void)updateModel:(NSInteger)modelIndex :(NSString *)key :(NSString *)value;
- (void)getLogsForDevice:(NSInteger)deviceIndex :(NSString *)since :(BOOL)isStream;
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
@property (nonatomic, assign) bool loggedInFlag;


@end
