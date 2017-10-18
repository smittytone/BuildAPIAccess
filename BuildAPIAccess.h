
//  Copyright (c) 2015-17 Tony Smith. All rights reserved.
//  Issued under the MIT licence

//  BuildAPIAccess 3.0.0


#import <Foundation/Foundation.h>
#import "BuildAPIAccessConstants.h"
#import "Connexion.h"
#import "LogStreamEvent.h"
#import "Token.h"


@interface BuildAPIAccess : NSObject <NSURLSessionDataDelegate, NSURLSessionTaskDelegate>

{
	NSMutableArray *connexions, *pendingConnections, *loggingDevices, *products, *devices;
	NSMutableArray *devicegroups, *deployments, *history, *logs;

	NSDictionary *me;

	NSOperationQueue *connectionQueue, *messageQueue;

	NSString *baseURL, *userAgent, *username, *password, *logStreamID, *deviceToStream;

	NSDateFormatter *dateFormatter;

	NSURL *logStreamURL;

	NSTimeInterval logTimeout, logRetryInterval;

	NSInteger pageSize;

	BOOL pageSizeChangeFlag, logIsClosed, useTwoFactor;

	id logLastEventID;

	Connexion *logConnexion;

	Token *token;
}


// Initialization Methods

- (instancetype)init NS_DESIGNATED_INITIALIZER;

// Login Methods

- (void)login:(NSString *)userName :(NSString *)passWord :(BOOL)is2FA;
- (void)getNewSessionToken;
- (void)refreshSessionToken;
- (BOOL)isSessionTokenValid;
- (void)clearCredentials;
- (void)logout;

// Pagination Methods

- (void)setPageSize:(NSInteger)size;
- (BOOL)isFirstPage:(NSDictionary *)links;
- (NSString *)nextPageLink:(NSDictionary *)links;
- (NSString *)getNextURL:(NSString *)url;

// Data Request Methods

- (void)getProducts;
- (void)getProducts:(id)someObject;
- (void)getProductsWithFilter:(NSString *)filter :(NSString *)uuid;
- (void)getProductsWithFilter:(NSString *)filter :(NSString *)uuid :(id)someObject;

- (void)getProduct:(NSString *)productID;
- (void)getProduct:(NSString *)productID :(id)someObject;

- (void)getDevicegroups;
- (void)getDevicegroups:(id)someObject;
- (void)getDevicegroupsWithFilter:(NSString *)filter :(NSString *)uuid;
- (void)getDevicegroupsWithFilter:(NSString *)filter :(NSString *)uuid :(id)someObject;

- (void)getDevicegroup:(NSString *)devicegroupID;
- (void)getDevicegroup:(NSString *)devicegroupID :(id)someObject;

- (void)getDevices;
- (void)getDevices:(id)someObject;
- (void)getDevicesWithFilter:(NSString *)filter :(NSString *)uuid;
- (void)getDevicesWithFilter:(NSString *)filter :(NSString *)uuid :(id)someObject;

- (void)getDevice:(NSString *)deviceID;
- (void)getDevice:(NSString *)deviceID :(id)someObject;

- (void)startLogging:(NSString *)deviceID;
- (void)startLogging:(NSString *)deviceID :(id)someObject;

- (void)stopLogging:(NSString *)deviceID;
- (void)stopLogging:(NSString *)deviceID :(id)someObject;

- (void)getDeviceLogs:(NSString *)deviceID;
- (void)getDeviceLogs:(NSString *)deviceID :(id)someObject;

- (void)getDeviceHistory:(NSString *)deviceID;
- (void)getDeviceHistory:(NSString *)deviceID :(id)someObject;

- (void)getDeployments;
- (void)getDeployments:(id)someObject;
- (void)getDeploymentsWithFilter:(NSString *)filter :(NSString *)uuid;
- (void)getDeploymentsWithFilter:(NSString *)filter :(NSString *)uuid :(id)someObject;

- (void)getDeployment:(NSString *)deploymentID;
- (void)getDeployment:(NSString *)deploymentID :(id)someObject;

// Action Methods

- (void)createProduct:(NSString *)name :(NSString *)description;
- (void)createProduct:(NSString *)name :(NSString *)description :(id)someObject;

- (void)updateProduct:(NSString *)productID :(NSArray *)keys :(NSArray *)values;
- (void)updateProduct:(NSString *)productID :(NSArray *)keys :(NSArray *)values :(id)someObject;

- (void)deleteProduct:(NSString *)productID;
- (void)deleteProduct:(NSString *)productID :(id)someObject;

- (void)createDevicegroup:(NSDictionary *)details;
- (void)createDevicegroup:(NSDictionary *)details :(id)someObject;

- (void)updateDevicegroup:(NSString *)devicegroupID :(NSString *)devicegroupType :(NSString *)key :(NSString *)value;
- (void)updateDevicegroup:(NSString *)devicegroupID :(NSString *)devicegroupType :(NSString *)key :(NSString *)value :(id)someObject;

- (void)deleteDevicegroup:(NSString *)devicegroupID;
- (void)deleteDevicegroup:(NSString *)devicegroupID :(id)someObject;

- (void)restartDevices:(NSString *)devicegroupID;
- (void)restartDevices:(NSString *)devicegroupID :(id)someObject;

- (void)restartDevice:(NSString *)deviceID;
- (void)restartDevice:(NSString *)deviceID :(id)someObject;

- (void)updateDevice:(NSString *)deviceID :(NSString *)key :(NSString *)value;
- (void)updateDevice:(NSString *)deviceID :(NSString *)key :(NSString *)value :(id)someObject;

- (void)unassignDevice:(NSDictionary *)device;
- (void)unassignDevice:(NSDictionary *)device :(id)someObject;

- (void)assignDevice:(NSMutableDictionary *)device :(NSString *)devicegroupID;
- (void)assignDevice:(NSMutableDictionary *)device :(NSString *)devicegroupID :(id)someObject;

- (void)deleteDevice:(NSDictionary *)device;
- (void)deleteDevice:(NSDictionary *)device :(id)someObject;

- (void)createDeployment:(NSDictionary *)deployment;
- (void)createDeployment:(NSDictionary *)deployment :(id)someObject;

- (void)updateDeployment:(NSString *)deploymentID :(NSString *)key :(NSString *)value;
- (void)updateDeployment:(NSString *)deploymentID :(NSString *)key :(NSString *)value :(id)someObject;

- (void)deleteDeployment:(NSString *)deploymentID;
- (void)deleteDeployment:(NSString *)deploymentID :(id)someObject;

// Logging Methods

- (void)startStream:(NSURL *)url;
- (void)openStream;
- (void)closeStream;
- (void)dispatchEvent:(LogStreamEvent *)event;
- (void)dispatchEvent:(LogStreamEvent *)event :(NSInteger)eventType;
- (void)relayLogEntry:(NSDictionary *)entry;
- (void)logOpened;
- (void)logClosed:(NSDictionary *)error;
- (BOOL)isDeviceLogging:(NSString *)deviceID;
- (NSInteger)indexOfLoggedDevice:(NSString *)deviceID;

// HTTP Request Construction Methods

- (NSMutableURLRequest *)makeGETrequest:(NSString *)path :(BOOL)getMultipleItems;
- (NSMutableURLRequest *)makeDELETErequest:(NSString *)path;
- (NSMutableURLRequest *)makePATCHrequest:(NSString *)path :(NSDictionary *)body;
- (NSMutableURLRequest *)makePOSTrequest:(NSString *)path :(NSDictionary *)body;
- (NSMutableURLRequest *)makePUTrequest:(NSString *)path :(NSDictionary *)body;
- (NSMutableURLRequest *)makeRequest:(NSString *)verb :(NSString *)path :(BOOL)addContentType :(BOOL)getMultipleItems;
- (void)setRequestAuthorization:(NSMutableURLRequest *)request;

// Connection Methods

- (Connexion *)launchConnection:(NSMutableURLRequest *)request :(NSInteger)actionCode :(id)someObject;
- (void)relaunchConnection:(id)userInfo;
- (void)launchPendingConnections;
- (void)killAllConnections;

// Connection Result Processing Methods

- (NSDictionary *)processConnection:(Connexion *)connexion;
- (void)processResult:(Connexion *)connexion :(NSDictionary *)data;

// Utility Methods

- (void)reportError;
- (void)reportError:(NSInteger)errCode;
- (NSString *)processAPIError:(NSDictionary *)error;
- (BOOL)checkFilter:(NSString *)filter :(NSArray *)validFilters;

// Base64 Methods

- (NSString *)encodeBase64String:(NSString *)plainString;
- (NSString *)decodeBase64String:(NSString *)base64String;


// Properties

@property (nonatomic, strong)		NSString	*errorMessage;
@property (nonatomic, strong)		NSString	*statusMessage;
@property (nonatomic, readonly)		NSUInteger	numberOfConnections;
@property (nonatomic, readonly)		NSUInteger	numberOfLogStreams;
@property (nonatomic, readwrite)	NSInteger	pageSize;
@property (nonatomic, readonly)		BOOL		isLoggedIn;


@end
