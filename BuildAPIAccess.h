
//  BuildAPIAccess
//  Copyright (c) 2015-18 Tony Smith. All rights reserved.
//  Issued under the MIT licence:
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//
//  BuildAPIAccess 3.0.0


#import <Foundation/Foundation.h>
#import "BuildAPIAccessConstants.h"
#import "Connexion.h"
#import "LogStreamEvent.h"
#import "Token.h"


@interface BuildAPIAccess : NSObject <NSURLSessionDataDelegate, NSURLSessionTaskDelegate>

{
    NSURLSession *apiSession;

    NSMutableArray *connexions, *pendingConnections, *loggingDevices, *products, *devices;
    NSMutableArray *devicegroups, *deployments, *history, *logs;

    NSDictionary *me;

    NSOperationQueue *eventQueue;

    NSString *baseURL, *userAgent, *username, *password, *logStreamID, *deviceToStream;

    NSDateFormatter *dateFormatter;

    NSURL *logStreamURL;

    NSTimeInterval logTimeout, logRetryInterval;

    NSInteger pageSize, tempImpCloudCode;

    BOOL pageSizeChangeFlag, logIsClosed, restartingLog, useTwoFactor;

    id logLastEventID;

    Connexion *logConnexion, *tokenConnexion;

    Token *token;
}


// Initialization Methods

- (instancetype)init NS_DESIGNATED_INITIALIZER;

// Login Methods

- (void)login:(NSString *)userName :(NSString *)passWord :(NSUInteger)impCloudCode :(BOOL)is2FA;
- (void)getNewAccessToken;
- (void)refreshAccessToken:(NSString *)loginKey;
- (BOOL)isAccessTokenValid;
- (void)clearCredentials;
- (void)logout;
- (void)twoFactorLogin:(NSString *)loginToken :(NSString *)otp;
- (void)setEndpoint:(NSString *)pathWithVersion;
- (void)getLoginKey:(NSString *)password;
- (void)loginWithKey:(NSString *)loginKey;

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

- (void)updateDevicegroup:(NSString *)devicegroupID :(NSArray *)keys :(NSArray *)values;
- (void)updateDevicegroup:(NSString *)devicegroupID :(NSArray *)keys :(NSArray *)values :(id)someObject;

- (void)deleteDevicegroup:(NSString *)devicegroupID;
- (void)deleteDevicegroup:(NSString *)devicegroupID :(id)someObject;

- (void)restartDevices:(NSString *)devicegroupID;
- (void)restartDevices:(NSString *)devicegroupID :(id)someObject;

- (void)conditionalRestartDevices:(NSString *)devicegroupID;
- (void)conditionalRestartDevices:(NSString *)devicegroupID :(id)someObject;

- (void)restartDevice:(NSString *)deviceID;
- (void)restartDevice:(NSString *)deviceID :(id)someObject;

- (void)updateDevice:(NSString *)deviceID :(NSString *)name;
- (void)updateDevice:(NSString *)deviceID :(NSString *)name :(id)someObject;

- (void)unassignDevice:(NSDictionary *)device;
- (void)unassignDevice:(NSDictionary *)device :(id)someObject;

- (void)unassignDevices:(NSArray *)devices;
- (void)unassignDevices:(NSArray *)devices :(id)someObject;

- (void)assignDevice:(NSDictionary *)device :(NSString *)devicegroupID;
- (void)assignDevice:(NSDictionary *)device :(NSString *)devicegroupID :(id)someObject;

- (void)assignDevices:(NSArray *)devices :(NSString *)devicegroupID;
- (void)assignDevices:(NSArray *)devices :(NSString *)devicegroupID :(id)someObject;

- (void)deleteDevice:(NSString *)deviceID;
- (void)deleteDevice:(NSString *)deviceID :(id)someObject;

- (void)createDeployment:(NSDictionary *)deployment;
- (void)createDeployment:(NSDictionary *)deployment :(id)someObject;

- (void)updateDeployment:(NSString *)deploymentID :(NSArray *)keys :(NSArray *)values;
- (void)updateDeployment:(NSString *)deploymentID :(NSArray *)keys :(NSArray *)values :(id)someObject;

- (void)deleteDeployment:(NSString *)deploymentID;
- (void)deleteDeployment:(NSString *)deploymentID :(id)someObject;

- (void)setMinimumDeployment:(NSString *)devicegroupID :(NSDictionary *)deployment;
- (void)setMinimumDeployment:(NSString *)devicegroupID :(NSDictionary *)deployment :(id)someObject;

// Logging Methods

- (void)startLogging:(NSString *)deviceID;
- (void)startLogging:(NSString *)deviceID :(id)someObject;
- (void)stopLogging:(NSString *)deviceID;
- (void)stopLogging:(NSString *)deviceID :(id)someObject;
- (void)restartLogging;

- (void)startStream:(NSURL *)url;
- (void)openStream;
- (void)closeStream;

- (void)dispatchEvent:(LogStreamEvent *)event;
- (void)processEvent:(LogStreamEvent *)event;

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

- (void)parseStreamData:(NSData *)data :(Connexion *)connexion;
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

@property (nonatomic, strong) NSString *currentAccount;
@property (nonatomic, strong) NSString *errorMessage;
@property (nonatomic, strong) NSString *statusMessage;
@property (nonatomic, readonly) NSUInteger numberOfConnections;
@property (nonatomic, readonly) NSUInteger numberOfLogStreams;
@property (nonatomic, readonly) NSInteger impCloudCode;
@property (nonatomic, readwrite) NSUInteger maxListCount;
@property (nonatomic, readonly) BOOL isLoggedIn;
@property (nonatomic, readwrite, setter=setPageSize:) NSInteger pageSize;


@end
