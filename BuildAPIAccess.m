
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


#import "BuildAPIAccess.h"


@implementation BuildAPIAccess



@synthesize errorMessage, statusMessage, isLoggedIn, pageSize;
@synthesize numberOfConnections, numberOfLogStreams, maxListCount;



#pragma mark - Initialization Methods


- (instancetype)init
{
    if (self = [super init])
    {
        // The list of connections should be instantiated immediately...

        connexions = [[NSMutableArray alloc] init];
        pendingConnections = nil;

        // impCentral API returned data lists

        products = nil;
        devices = nil;
        loggingDevices = nil;
        deployments = nil;
        devicegroups = nil;
        history = nil;
        logs = nil;

        // Message-handling Operation Queue

        eventQueue = nil;

        // Account

        username = nil;
        password = nil;

        // Logging

        logStreamID = nil;
        logStreamURL = nil;
        logTimeout = kLogTimeout;
        logRetryInterval = klogRetryInterval;
        logIsClosed = YES;
        maxListCount = kMaxHistoricalLogs;

        // Misc

        errorMessage = @"";
        isLoggedIn = NO;
        useTwoFactor = NO;

        // Pagination

        pageSize = kPaginationDefault;
        pageSizeChangeFlag = YES;
        baseURL = [kBaseAPIURL stringByAppendingString:kAPIVersion];

        // User Agent for impCentral API requests

        NSOperatingSystemVersion sysVer = [[NSProcessInfo processInfo] operatingSystemVersion];
        userAgent = [NSString stringWithFormat:@"BuildAPIAccess/%@ %@/%@.%@ (macOS %li.%li.%li)", kBuildAPIAccessVersion, [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                      [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"], (long)sysVer.majorVersion, (long)sysVer.minorVersion, (long)sysVer.patchVersion];

#ifdef DEBUG
    NSLog(@"User Agent: %@", userAgent);
#endif

    }

    return self;
}



#pragma mark - Login Methods


- (void)login:(NSString *)userName :(NSString *)passWord :(BOOL)is2FA
{
    // Login is the process of sending the user's username/email address and password to the API
    // in return for a new access token. We retain the credentials in case the token
    // expires during the host application's runtime, but we don't save them -
    // this is the job of the host application.

    if ((userName == nil || userName.length == 0) && (passWord == nil || passWord.length == 0))
    {
        errorMessage = @"Could not log in to the Electric Imp impCloud — no username/email address and password.";
        [self reportError:kErrorLoginNoCredentials];
        return;
    }

    if (userName == nil || userName.length == 0)
    {
        errorMessage = @"Could not log in to the Electric Imp impCloud — no username or email address.";
        [self reportError:kErrorLoginNoUsername];
        return;
    }

    if (passWord == nil || passWord.length == 0)
    {
        errorMessage = @"Could not log in to the Electric Imp impCloud — no password.";
        [self reportError:kErrorLoginNoPassword];
        return;
    }

    username = userName;
    password = passWord;

    // This is not currently used but will be in future

    useTwoFactor = is2FA;

    // Get a new token using the credentials provided

    [self getNewAccessToken];
}



- (void)getNewAccessToken
{
    // Request a new access token using the stored credentials,
    // failing if neither has been provided (by 'login:')

    if (!username || !password)
    {
        errorMessage = @"Missing Electric Imp credentials — cannot log in without username/email address and password.";
        [self reportError:kErrorLoginNoCredentials];
        return;
    }

    // Set up a POST request to the /auth URL to get a session token
    // Need unique code here as we do not use the Content-Type used by the API

    NSError *error = nil;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[baseURL stringByAppendingString:@"auth"]]];

    [request setHTTPMethod:@"POST"];
    [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSDictionary *dict = @{ @"id" : username,
                            @"password" : password };

    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:dict options:0 error:&error]];
    [self clearCredentials];

    if (request && !error)
    {
        [self launchConnection:request :kConnectTypeGetAccessToken :nil];
    }
    else
    {
        errorMessage = @"Could not create a request to get an impCloud access token.";
        [self reportError];
    }
}



- (void)refreshAccessToken
{
    // Getting a new session token using the refresh_token does not require the account username and pw

    if (token == nil)
    {
        // We don't have a token, so just get a new one

        [self getNewAccessToken];
        return;
    }

    NSDictionary *dict = @{ @"token" : token.refreshToken };
    NSError *error = nil;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[baseURL stringByAppendingString:@"auth/token"]]];

    [request setHTTPMethod:@"POST"];
    [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:dict options:0 error:&error]];

    if (error)
    {
        errorMessage = @"Could not create a request to refresh your impCloud session token.";
        [self reportError];
        return;
    }

    if (request)
    {
        [self launchConnection:request :kConnectTypeRefreshAccessToken :nil];
    }
    else
    {
        errorMessage = @"Could not create a request to retrieve a new impCloud session token.";
        [self reportError];
    }
}



- (BOOL)isAccessTokenValid
{
    // No token available; return BAD TOKEN

    if (token == nil) return NO;

    if (dateFormatter == nil)
    {
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZZ"; // @"yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSS'Z'";
        dateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    }

    NSDate *expiry = [dateFormatter dateFromString:token.expiryDate];
	NSDate *deltaExpiry = [NSDate dateWithTimeInterval:-240 sinceDate:expiry];
    NSDate *now = [NSDate date];

#ifdef DEBUG
    NSLog(@"      Expiry: %@", [dateFormatter stringFromDate:expiry]);
	NSLog(@"Expiry Delta: %@", [dateFormatter stringFromDate:deltaExpiry]);
	NSLog(@"         Now: %@", [dateFormatter stringFromDate:now]);
#endif

    NSDate *latest = [now laterDate:expiry];

    if (now == latest)
    {
#ifdef DEBUG
    NSLog(@"              EXPIRED");
#endif

        // Return BAD TOKEN

        return NO;
    }

	latest = [now laterDate:deltaExpiry];

	if (now == latest)
	{
#ifdef DEBUG
	NSLog(@"              ABOUT TO EXPIRE");
#endif

		// Return BAD TOKEN

		return NO;
	}


#ifdef DEBUG
    NSLog(@"              NOT EXPIRED");
#endif

	
	// Return GOOD TOKEN

    return YES;
}



- (void)clearCredentials
{
    // Just clear the stored credentials once they've been used
    // If the user needs to login again, they will be resubmitted (might have changed)

    username = @"";
    password = @"";
}



- (void)logout
{
    // To logout just clear the stored session data and cancel any remaining connections

    [self killAllConnections];

    token = nil;
    isLoggedIn = NO;
}



- (void)twoFactorLogin:(NSString *)loginToken :(NSString *)otp
{
    // This is essentially a placeholder for whe 2FA is introduced for impCentral API logins

    NSDictionary *dict = @{ @"otp" : otp,
                            @"login_token" : loginToken };

    NSError *error = nil;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[baseURL stringByAppendingString:@"auth"]]];

    [request setHTTPMethod:@"POST"];
    [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:dict options:0 error:&error]];

    if (error)
    {
        errorMessage = @"Could not create a request to submit your impCloud OTP token.";
        [self reportError];
        return;
    }

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetAccessToken :nil];
    }
    else
    {
        errorMessage = @"Could not create a request to submit your impCloud OTP token.";
        [self reportError];
    }
}



- (void)setEndpoint:(NSString *)pathWithVersion
{
	// Change the API's base URL: server address plus version
	// eg. api.electricimp.com/v5/
	
	baseURL = pathWithVersion;
	
	// Append a slash to the base URL if there isn't one
	
	if (![baseURL hasSuffix:@"/"]) baseURL = [baseURL stringByAppendingString:@"/"];
	
	// Log the user out if they are logged in
	
	if (isLoggedIn) [self logout];
}


#pragma mark - Pagination Methods


- (void)setPageSize:(NSInteger)size
{
    // Sets a flag which will be tested when we next request data and, if set,
    // will add a URL query code specifying the required page size

    if (size < 1) size = 1;
    if (size > 100) size = 100;
    pageSize = size;
    pageSizeChangeFlag = YES;
}



- (BOOL)isFirstPage:(NSDictionary *)links
{
    // Checks the 'links' dictionary returned by the server and responds YES or NO
    // if the received data is the first page of several

    BOOL isFirstPage = NO;

    for (NSString *key in links.allKeys)
    {
        if ([key compare:@"first"] == NSOrderedSame)
        {
            NSString *currentPageLink = [links objectForKey:@"self"];
            NSString *firstPageLink = [links objectForKey:@"first"];

            if ([currentPageLink compare:firstPageLink] == NSOrderedSame)
            {
                isFirstPage = YES;
                break;
            }
        }
    }

    return isFirstPage;
}



- (NSString *)nextPageLink:(NSDictionary *)links
{
    // Checks the 'links' dictionary returned by the server and responds with
    // the provided URL of the next page of data

    NSString *nextURLString = @"";

    for (NSString *key in links.allKeys)
    {
        if ([key compare:@"next"] == NSOrderedSame)
        {
            // We have at least one more page to recover before we have the full list

            nextURLString = [links objectForKey:@"next"];
            break;
        }
    }

    return nextURLString;
}



- (NSString *)getNextURL:(NSString *)url
{
    // Strips the non-query content out of the supplied URL, or
    // returns an empty string if 'url' is nil or empty - what's
    // returned is added to a full URL by the calling method

    if (url == nil || url.length == 0) return @"";
    return [url substringFromIndex:31];
}



#pragma mark - Data Request Methods


- (void)getMyAccount
{
    // Set up a GET request to /accounts/me

    NSMutableURLRequest *request = [self makeGETrequest:@"accounts/me" :NO];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetMyAccount :nil];
    }
    else
    {
        errorMessage = @"Could not create a request to list your account information.";
        [self reportError];
    }
}



#pragma mark Products


- (void)getProducts
{
    [self getProducts:nil];
}



- (void)getProducts:(id)someObject
{
    // Set up a GET request to /products

    NSMutableURLRequest *request = [self makeGETrequest:@"products" :YES];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetProducts :someObject];
    }
    else
    {
        errorMessage = @" Could not create a request to list your products.";
        [self reportError];
    }
}



- (void)getProductsWithFilter:(NSString *)filter :(NSString *)uuid
{
    [self getProductsWithFilter:filter :uuid :nil];
}



- (void)getProductsWithFilter:(NSString *)filter :(NSString *)uuid :(id)someObject
{
    // Set up a GET request to /products to get products by filter

    if (uuid == nil || uuid.length == 0)
    {
        // If no filterable UUID is passed, just get all the products

        [self getProducts :someObject];
        return;
    }

    if (filter == nil || filter.length == 0)
    {
        // No filter? Can't proceed - is the ID a product ID or what?

        errorMessage = @"Could not create a request to list your products: no filter specified.";
        [self reportError];
        return;
    }

    if (![self checkFilter:filter :@[@"owner.id"]])
    {
        // Wrong type of filter?

        errorMessage = @"Could not create a request to list your products: unrecognized filter specified.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makeGETrequest:[NSString stringWithFormat:@"products?filter[%@]=%@", filter, uuid] :NO];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetProducts :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to list your products.";
        [self reportError];
    }
}



- (void)getProduct:(NSString *)productID
{
    [self getProduct:productID :nil];
}



- (void)getProduct:(NSString *)productID :(id)someObject
{
    // Set up a GET request to /products/productID

    if (productID == nil || productID.length == 0)
    {
        // No ID? Can't proceed

        errorMessage = @"Could not create a request to get the product: no ID specified.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makeGETrequest:[NSString stringWithFormat:@"products/%@", productID] :YES];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetProduct :nil];
    }
    else
    {
        errorMessage = @"Could not create a request to get the specified product.";
        [self reportError];
    }
}



#pragma mark Device Groups


- (void)getDevicegroups
{
    [self getDevicegroups:nil];
}



- (void)getDevicegroups:(id)someObject
{
    // Set up a GET request to /devicegroups

    NSMutableURLRequest *request = [self makeGETrequest:@"devicegroups" :YES];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetDeviceGroups :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to list your device groups.";
        [self reportError];
    }
}



- (void)getDevicegroupsWithFilter:(NSString *)filter :(NSString *)uuid
{
    [self getDevicegroupsWithFilter:filter :uuid :nil];
}



- (void)getDevicegroupsWithFilter:(NSString *)filter :(NSString *)uuid :(id)someObject
{
    // Set up a GET request to /devicegroups to get device groups by filter

    if (uuid == nil || uuid.length == 0)
    {
        [self getDevicegroups :someObject];
        return;
    }

    if (filter == nil || filter.length == 0)
    {
        // No filter? Can't proceed - is the ID a product ID or what?

        errorMessage = @"Could not create a request to list your device groups: no filter specified.";
        [self reportError];
        return;
    }

    if (![self checkFilter:filter :@[@"product.id", @"type", @"owner.id"]])
    {
        // Wrong type of filter?

        errorMessage = @"Could not create a request to list your device groups: unrecognized filter specified.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makeGETrequest:[NSString stringWithFormat:@"devicegroups?filter[%@]=%@", filter, uuid] :YES];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetDeviceGroups :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to list your device groups.";
        [self reportError];
    }
}



- (void)getDevicegroup:(NSString *)devicegroupID
{
    [self getDevicegroup:devicegroupID :nil];
}



- (void)getDevicegroup:(NSString *)devicegroupID :(id)someObject
{
    // Set up a GET request to /devicegroups/devicegroupID

    if (devicegroupID == nil || devicegroupID.length == 0)
    {
        // No ID? Can't proceed

        errorMessage = @"Could not create a request to get the device group: no ID specified.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makeGETrequest:[NSString stringWithFormat:@"/devicegroups/%@", devicegroupID] :NO];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetDeviceGroup :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to get the specified device group.";
        [self reportError];
    }
}



#pragma mark Devices


- (void)getDevices
{
    [self getDevices:nil];
}



- (void)getDevices:(id)someObject
{
    // Set up a GET request to /devices

    NSMutableURLRequest *request = [self makeGETrequest:@"devices" :YES];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetDevices :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to list your devices.";
        [self reportError];
    }
}



- (void)getDevicesWithFilter:(NSString *)filter :(NSString *)uuid
{
    [self getDevicesWithFilter:filter :uuid :nil];
}



- (void)getDevicesWithFilter:(NSString *)filter :(NSString *)uuid :(id)someObject
{
    // Set up a GET request to /devices to get devices by filter

    if (uuid == nil || uuid.length == 0)
    {
        [self getDevices :nil];
        return;
    }

    if (filter == nil || filter.length == 0)
    {
        // No filter? Can't proceed - is the ID a product ID or what?

        errorMessage = @"Could not create a request to list your devices: no filter specified.";
        [self reportError];
        return;
    }

    if (![self checkFilter:filter :@[@"owner.id", @"product.id", @"devicegroup.id", @"devicegroup.owner.id", @"devicegroup.type"]])
    {
        // Wrong type of filter?

        errorMessage = @"Could not create a request to list your devicess: unrecognized filter specified.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makeGETrequest:[NSString stringWithFormat:@"devices?filter[%@]=%@", filter, uuid] :YES];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetDevices :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to list your devices.";
        [self reportError];
    }
}



- (void)getDevice:(NSString *)deviceID
{
    [self getDevice:deviceID :nil];
}



- (void)getDevice:(NSString *)deviceID :(id)someObject
{
    // Set up a GET request to /devices/deviceID

    if (deviceID == nil || deviceID.length == 0)
    {
        // No ID? Can't proceed

        errorMessage = @"Could not create a request to get the device: no ID specified.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makeGETrequest:[NSString stringWithFormat:@"devices/%@", deviceID] :NO];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetDevice :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to get the specified device.";
        [self reportError];
    }
}



- (void)getDeviceLogs:(NSString *)deviceID
{
    [self getDeviceLogs:deviceID :nil];
}



- (void)getDeviceLogs:(NSString *)deviceID :(id)someObject
{
    // Send a GET request to /devices/{id}/logs

    if (deviceID == nil || deviceID.length == 0)
    {
        errorMessage = @"Can't get logs for a device: no ID specified";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makeGETrequest:[NSString stringWithFormat:@"devices/%@/logs", deviceID] :YES];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetDeviceLogs :someObject];
    }
    else
    {
        errorMessage = @"Could not create request to get logs for the device.";
        [self reportError];
    }
}



- (void)getDeviceHistory:(NSString *)deviceID
{
    [self getDeviceHistory:deviceID :nil];
}



- (void)getDeviceHistory:(NSString *)deviceID :(id)someObject
{
    // Send a GET request to /devices/{id}/history

    if (deviceID == nil || deviceID.length == 0)
    {
        errorMessage = @"Can't get a history of a device: no ID specified";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makeGETrequest:[NSString stringWithFormat:@"devices/%@/history", deviceID] :YES];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetDeviceHistory :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to get a history of the device.";
        [self reportError];
    }
}



#pragma mark Deployments


- (void)getDeployments
{
    [self getDeployments:nil];
}



- (void)getDeployments:(id)someObject
{
    // Set up a GET request to /deployments

    NSMutableURLRequest *request = [self makeGETrequest:@"deployments" :YES];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetDeployments :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to get your deployments.";
        [self reportError];
    }
}



- (void)getDeploymentsWithFilter:(NSString *)filter :(NSString *)uuid
{
    [self getDeploymentsWithFilter:filter :uuid :nil];
}



- (void)getDeploymentsWithFilter:(NSString *)filter :(NSString *)uuid :(id)someObject
{
    // Set up a GET request to /deployments - gets deployments by filter

    if (uuid == nil || uuid.length == 0)
    {
        // No ID? Just get all deployments

        [self getDeployments:nil];
        return;
    }

    if (filter == nil || filter.length == 0)
    {
        // No filter? Can't proceed - is the ID a product ID or what?

        errorMessage = @"Could not create a request to get your deployments: no filter specified.";
        [self reportError];
        return;
    }

    if (![self checkFilter:filter :@[@"owner.id", @"creator.id", @"product.id", @"devicegroup.id", @"sha", @"flagged", @"flagger.id", @"tags"]])
    {
        // Wrong type of filter?

        errorMessage = @"Could not create a request to get your deployments: unrecognized filter specified.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makeGETrequest:[NSString stringWithFormat:@"deployments?filter[%@]=%@", filter, uuid] :YES];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetDeployments :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to get current deployments.";
        [self reportError];
    }
}



- (void)getDeployment:(NSString *)deploymentID
{
    [self getDeployment:deploymentID :nil];
}



- (void)getDeployment:(NSString *)deploymentID :(id)someObject
{
    // Set up a GET request to /deployments/deploymentID

    if (deploymentID == nil || deploymentID.length == 0)
    {
        // No ID? Can't proceed

        errorMessage = @"Could not create a request to get the deployment: no ID specified.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makeGETrequest:[NSString stringWithFormat:@"deployments/%@", deploymentID] :NO];

    if (request)
    {
        [self launchConnection:request :kConnectTypeGetDeployment :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to get the specified deployment.";
        [self reportError];
    }
}



#pragma mark - Action Methods

#pragma mark Products


- (void)createProduct:(NSString *)name :(NSString *)description
{
    [self createProduct:name :description :nil];
}



- (void)createProduct:(NSString *)name :(NSString *)description :(id)someObject
{
    // Set up a POST request to /products

    if (name == nil || name.length == 0)
    {
        errorMessage = @"Could not create a request to create the new product: no product name.";
        [self reportError];
        return;
    }

    if (description == nil) description = @"";
    if (description.length > 255) description = [description substringToIndex:255];
    if (name.length > 80) name = [name substringToIndex:80];

    NSDictionary *attributes = @{ @"name" : name,
                                  @"description" : description };

    NSDictionary *dict = @{ @"type" : @"product",
                            @"attributes" : attributes };

    NSDictionary *data = @{ @"data" : dict };

    // NOTE we don't add a relationships dictionary, so the product will be assigned
    // to the account the user is logged in as

    NSMutableURLRequest *request = [self makePOSTrequest:@"products" :data];

    if (request)
    {
        [self launchConnection:request :kConnectTypeCreateProduct :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to create the new product.";
        [self reportError];
    }
}



- (void)updateProduct:(NSString *)productID :(NSArray *)keys :(NSArray *)values
{
    [self updateProduct:productID :keys :values :nil];
}



- (void)updateProduct:(NSString *)productID :(NSArray *)keys :(NSArray *)values :(id)someObject
{
    // Set up a PATCH request to /products
    // We can ONLY update a product's name and/or description

    if (productID == nil || productID.length == 0)
    {
        errorMessage = @"Could not create a request to update the product: no product ID.";
        [self reportError];
        return;
    }

    if (keys == nil || keys.count == 0)
    {
        errorMessage = @"Could not create a request to update the product: no data fields specified.";
        [self reportError];
        return;
    }

    if (values.count == 0 || values.count != keys.count)
    {
        errorMessage = @"Could not create a request to update the product: insufficient or extraneous data supplied.";
        [self reportError];
        return;
    }

    // Check the keys for validity - only a product's attributes.name and attributes.description can be changed

    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    NSString *name = nil;

    for (NSUInteger i = 0 ; i < keys.count ; ++i)
    {
        NSString *key = [keys objectAtIndex:i];

        if ([key compare:@"name"] == NSOrderedSame)
        {
            name = [values objectAtIndex:i];

            if (name != nil)
            {
                if (name.length > 0)
                {
                    [attributes setValue:name forKey:@"name"];
                }
                else
                {
                    errorMessage = @"Could not create a request to update the product: invalid product name supplied.";
                    [self reportError];
                    return;
                }
            }

            break;
        }

        if ([key compare:@"description"] == NSOrderedSame)
        {
            name = [values objectAtIndex:i];
            if (name != nil) [attributes setValue:name forKey:@"description"];
        }
    }

    if (attributes.count > 0)
    {
        // Only proceed with if valid changes have been made

        NSDictionary *dict = @{ @"type" : @"product",
                                @"id" : productID,
                                @"attributes" : [NSDictionary dictionaryWithDictionary:attributes] };

        NSDictionary *data = @{ @"data" : dict };

        NSMutableURLRequest *request = [self makePATCHrequest:[NSString stringWithFormat:@"products/%@", productID] :data];

        if (request)
        {
            [self launchConnection:request :kConnectTypeUpdateProduct :someObject];
        }
        else
        {
            errorMessage = @"Could not create a request to update the product.";
            [self reportError];
        }
    }
    else
    {
        errorMessage = @"Could not create a request to update the product - no changes made.";
        [self reportError];
    }
}



- (void)deleteProduct:(NSString *)productID
{
    [self deleteProduct:productID :nil];
}



- (void)deleteProduct:(NSString *)productID :(id)someObject
{
    // Set up a DELETE to /products with the product ID URL-encoded

    if (productID == nil || productID.length == 0)
    {
        errorMessage = @"Could not create a request to delete the product: no product ID.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makeDELETErequest:[NSString stringWithFormat:@"products/%@", productID]];

    if (request)
    {
        [self launchConnection:request :kConnectTypeDeleteProduct :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to delete the product.";
        [self reportError];
    }
}



#pragma mark Device Groups


- (void)createDevicegroup:(NSDictionary *)details
{
    [self createDevicegroup:details :nil];
}



- (void)createDevicegroup:(NSDictionary *)details :(id)someObject
{
    // Set up a POST request to /devicegroups

    // The dictionary 'details' contains all the data we may need:
    // 'name', 'description', 'type', 'productid', 'targetid'
    // First get the mandatory items - method will fail without these

    NSString *name = [details valueForKey:@"name"];
    NSString *productID = [details valueForKey:@"productid"];

    if (name == nil || name.length == 0)
    {
        errorMessage = @"Could not create a request to create the new device group: no device group name.";
        [self reportError];
        return;
    }

    if (productID == nil || productID.length == 0)
    {
        errorMessage = @"Could not create a request to create the new device group: no product ID.";
        [self reportError];
        return;
    }

    // Optional items

    NSString *description = [details valueForKey:@"description"];
    NSString *type = [details valueForKey:@"type"];

    if (name.length > 80) name = [name substringToIndex:80];
    if (description == nil) description = @"";
    if (description.length > 255) description = [description substringToIndex:255];

    BOOL flag = NO;

    if (type.length == 0) type = @"development_devicegroup";

    NSArray *allowedTypes = @[ @"pre_production_devicegroup",
                               @"pre_factoryfixture_devicegroup",
                               @"development_devicegroup",
                               @"production_devicegroup",
                               @"factoryfixture_devicegroup",
                               @"development",
                               @"production",
                               @"factoryfixture",
                               @"pre_factoryfixture",
                               @"pre_production" ];

    for (NSUInteger i = 0 ; i < allowedTypes.count ; ++i)
    {
        NSString *pType = [allowedTypes objectAtIndex:i];

        if ([type compare:pType] == NSOrderedSame)
        {
            flag = YES;

            if (i > 4) type = [type stringByAppendingString:@"_devicegroup"];
        }
    }

    if (!flag)
    {
        errorMessage = @"Could not create a request to create the new device group: invalid device group type.";
        [self reportError];
        return;
    }

    // Factory Fixture Device Groups must have a target

    NSDictionary *target = nil;
    NSString *targetID = [details valueForKey:@"targetid"];

    if ([type compare:@"factoryfixture_devicegroup"] == NSOrderedSame)
    {
        if (targetID == nil || targetID.length == 0)
        {
            errorMessage = @"Could not create a request to create the new device group: invalid production target device group.";
            [self reportError];
            return;
        }

        target = @{ @"type" : @"production_devicegroup",
                    @"id" : targetID };
    }

	if ([type compare:@"pre_factoryfixture_devicegroup"] == NSOrderedSame)
	{
		if (targetID == nil || targetID.length == 0)
		{
			errorMessage = @"Could not create a request to create the new device group: invalid test production target device group.";
			[self reportError];
			return;
		}

		target = @{ @"type" : @"pre_production_devicegroup",
					@"id" : targetID };
	}

    NSDictionary *attributes = @{ @"name" : name,
                                  @"description" : description };

    NSDictionary *product = @{ @"type" : @"product",
                               @"id" : productID };

    NSDictionary *relationships = target != nil
    ? @{ @"product" : product, @"production_target" : target }
    : @{ @"product" : product };

    NSDictionary *dict = @{ @"type" : type,
                            @"attributes" : attributes,
                            @"relationships" : relationships};

    NSDictionary *data = @{ @"data" : dict };

    NSMutableURLRequest *request = [self makePOSTrequest:@"devicegroups" :data];

    if (request)
    {
        [self launchConnection:request :kConnectTypeCreateDeviceGroup :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to create the new device group.";
        [self reportError];
    }
}



- (void)updateDevicegroup:(NSString *)devicegroupID :(NSArray *)keys :(NSArray *)values
{
    [self updateDevicegroup:devicegroupID :keys :values :nil];
}



- (void)updateDevicegroup:(NSString *)devicegroupID :(NSArray *)keys :(NSArray *)values :(id)someObject
{
    // Set up a PATCH request to /devicegroups
    // We can ONLY update a device group's name or description FOR NOW
    // Coming: production_target, load_code_after_blessing

    if (devicegroupID == nil || devicegroupID.length == 0)
    {
        errorMessage = @"Could not create a request to update a device group: no device group specified.";
        [self reportError];
        return;
    }

    if (keys == nil || keys.count == 0)
    {
        errorMessage = @"Could not create a request to update the device group: no data fields specified.";
        [self reportError];
        return;
    }

    if (values.count == 0 || values.count != keys.count)
    {
        errorMessage = @"Could not create a request to update the device group: insufficient or extraneous data supplied.";
        [self reportError];
        return;
    }

    // Check the keys for validity - only a device group's attributes.name, attributes.description,
    // attributes.load_code_after_blessing, and relationships.production_target can be changed

    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *relationships = [[NSMutableDictionary alloc] init];

    NSString *devicegroupType = nil;
    NSString *name = nil;

    for (NSUInteger i = 0 ; i < keys.count ; ++i)
    {
        NSString *key = [keys objectAtIndex:i];

        if ([key compare:@"name"] == NSOrderedSame)
        {
            name = [values objectAtIndex:i];

            if (name != nil)
            {
                if (name.length > 0)
                {
                    [attributes setValue:name forKey:@"name"];
                }
                else
                {
                    errorMessage = @"Could not create a request to update the device group: invalid device group name supplied.";
                    [self reportError];
                    return;
                }
            }

            continue;
        }

        if ([key compare:@"description"] == NSOrderedSame)
        {
            name = [values objectAtIndex:i];
            if (name != nil) [attributes setValue:name forKey:@"description"];
            continue;
        }

        if ([key compare:@"production_target"] == NSOrderedSame)
        {
            NSDictionary *pt = [values objectAtIndex:i];
            if (pt != nil) [relationships setValue:pt forKey:@"production_target"];
            continue;
        }

        if ([key compare:@"type"] == NSOrderedSame)
        {
            devicegroupType = [values objectAtIndex:i];

            if (devicegroupType.length == 0) devicegroupType = @"development_devicegroup";

            BOOL flag = NO;
            NSArray *allowedTypes = @[ @"pre_production_devicegroup",
                                       @"pre_factoryfixture_devicegroup",
                                       @"development_devicegroup",
                                       @"production_devicegroup",
                                       @"factoryfixture_devicegroup",
                                       @"development",
                                       @"production",
                                       @"factoryfixture",
                                       @"pre_factoryfixture",
                                       @"pre_production" ];

            for (NSUInteger i = 0 ; i < allowedTypes.count ; ++i)
            {
                NSString *pType = [allowedTypes objectAtIndex:i];

                if ([devicegroupType compare:pType] == NSOrderedSame)
                {
                    flag = YES;

                    if (i > 4) devicegroupType = [devicegroupType stringByAppendingString:@"_devicegroup"];
                }
            }

            if (!flag)
            {
                errorMessage = @"Could not create a request to update the device group: invalid device group type supplied.";
                [self reportError];
                return;
            }

            continue;
        }

        if ([key compare:@"load_code_after_blessing"] == NSOrderedSame)
        {
            NSNumber *val = [values objectAtIndex:i];
            if (val != nil) [attributes setValue:val forKey:@"load_code_after_blessing"];
        }
    }

    NSDictionary *dict;

    if (devicegroupType == nil) devicegroupType = @"development_devicegroup";

    if (attributes.count > 0)
    {
        if (relationships.count > 0)
        {
            dict = @{ @"id" : devicegroupID,
                        @"type" : devicegroupType,
                        @"attributes" : [NSDictionary dictionaryWithDictionary:attributes],
                        @"relationships" : [NSDictionary dictionaryWithDictionary:relationships] };
        }
        else
        {
            dict = @{ @"id" : devicegroupID,
                      @"type" : devicegroupType,
                      @"attributes" : [NSDictionary dictionaryWithDictionary:attributes] };
        }
    }
    else
    {
        if (relationships.count > 0)
        {
            dict = @{ @"id" : devicegroupID,
                      @"type" : devicegroupType,
                      @"relationships" : [NSDictionary dictionaryWithDictionary:relationships] };
        }
        else
        {
            errorMessage = @"Could not create a request to update the device group: no changes made.";
            [self reportError];
            return;
        }
    }

    NSDictionary *data = @{ @"data" : dict };

    NSMutableURLRequest *request = [self makePATCHrequest:[NSString stringWithFormat:@"devicegroups/%@", devicegroupID] :data];

    if (request)
    {
        [self launchConnection:request :kConnectTypeUpdateDeviceGroup :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to update the device group.";
        [self reportError];
    }
}



- (void)deleteDevicegroup:(NSString *)devicegroupID
{
    [self deleteDevicegroup:devicegroupID :nil];
}



- (void)deleteDevicegroup:(NSString *)devicegroupID :(id)someObject
{
    // Set up a DELETE request to /devicegroups/id

    if (devicegroupID == nil || devicegroupID.length == 0)
    {
        errorMessage = @"Could not create a request to delete a device group: no device group specified.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makeDELETErequest:[NSString stringWithFormat:@"devicegroups/%@", devicegroupID]];

    if (request)
    {
        [self launchConnection:request :kConnectTypeDeleteDeviceGroup :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to delete the device group.";
        [self reportError];
    }
}



- (void)restartDevices:(NSString *)devicegroupID
{
    [self restartDevices:devicegroupID :nil];
}



- (void)restartDevices:(NSString *)devicegroupID :(id)someObject
{
    if (devicegroupID == nil || devicegroupID.length == 0)
    {
        errorMessage = @"Could not create a request to restart a device group: no device group ID specified.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makePOSTrequest:[NSString stringWithFormat:@"devicegroups/%@/restart", devicegroupID] :nil];

    if (request)
    {
        [self launchConnection:request :kConnectTypeRestartDevices :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to restart the device group.";
        [self reportError];
    }
}



- (void)conditionalRestartDevices:(NSString *)devicegroupID
{
    [self conditionalRestartDevices:devicegroupID :nil];
}



- (void)conditionalRestartDevices:(NSString *)devicegroupID :(id)someObject
{
    if (devicegroupID == nil || devicegroupID.length == 0)
    {
        errorMessage = @"Could not create a request to conditionally restart a device group: no device group ID specified.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makePOSTrequest:[NSString stringWithFormat:@"devicegroups/%@/conditional_restart", devicegroupID] :nil];

    if (request)
    {
        [self launchConnection:request :kConnectTypeRestartDevices :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to conditionally restart the device group.";
        [self reportError];
    }
}



#pragma mark Devices


- (void)restartDevice:(NSString *)deviceID
{
    [self restartDevice:deviceID :nil];
}



- (void)restartDevice:(NSString *)deviceID :(id)someObject
{
    if (deviceID == nil || deviceID.length == 0)
    {
        errorMessage = @"Could not create a request to restart a device: no device ID specified.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makePOSTrequest:[NSString stringWithFormat:@"devices/%@/restart", deviceID] :nil];

    if (request)
    {
        [self launchConnection:request :kConnectTypeRestartDevice :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to restart the device.";
        [self reportError];
    }
}



- (void)updateDevice:(NSString *)deviceID :(NSString *)name
{
    [self updateDevice:deviceID :name :nil];
}



- (void)updateDevice:(NSString *)deviceID :(NSString *)name :(id)someObject
{
    // Set up a PATCH request to /devices/
    // We can ONLY change the device's name

    if (deviceID == nil)
    {
        errorMessage = @"Could not create a request to update a device: no device specified.";
        [self reportError];
        return;
    }

    if (name == nil || name.length == 0) name = @"";

    // NOTE watch for a zero-length name - this is valid as it removes the device name,
    // ie. sets it to the device ID

    NSDictionary *attributes = @{ @"name" : name };

    NSDictionary *dict = @{ @"type" : @"device",
                            @"id" : deviceID,
                            @"attributes" : attributes };

    NSDictionary *data = @{ @"data" : dict };

    NSMutableURLRequest *request = [self makePATCHrequest:[NSString stringWithFormat:@"devices/%@", deviceID] :data];

    if (request)
    {
        [self launchConnection:request :kConnectTypeUpdateDevice :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to update the device.";
        [self reportError];
    }
}



- (void)unassignDevice:(NSDictionary *)device
{
    [self unassignDevice:device: nil];
}



- (void)unassignDevice:(NSDictionary *)device :(id)someObject
{
    // Set up a DELETE to /devicegroups/{id}/relationships/devices

    if (device == nil)
    {
        errorMessage = @"Could not create a request to unassign a device: no device specified.";
        [self reportError];
        return;
    }

    NSDictionary *relationships = [device objectForKey:@"relationships"];
    NSDictionary *dg = [relationships objectForKey:@"devicegroup"];

    if (dg == nil)
    {
        // If there is no devicegroup set for the device, it is unassigned
        // This is not an error, so we replicate the post-uhassignment process
        // to inform the host app

        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

        NSDictionary *dict = someObject != nil
        ? @{ @"object" : someObject, @"data" : @"already unassigned" }
        : @{ @"data" : @"already unassigned" };

        [nc postNotificationName:@"BuildAPIDeviceUnassigned" object:dict];
        return;
    }

    NSString *dgid = [dg objectForKey:@"id"];

    NSMutableURLRequest *request = [self makeRequest:@"DELETE" :[NSString stringWithFormat:@"/devicegroups/%@/relationships/devices", dgid] :YES :NO];

    NSDictionary *dict = @{ @"type" : @"device",
                            @"id" : [device objectForKey:@"id"] };

    NSArray *array = @[ dict ];

    NSDictionary *data = @{ @"data" : array };

    NSError *error;

    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:data options:0 error:&error]];

    if (error)
    {
        errorMessage = @"Could not create a request to unassign the device: bad JSON data.";
        [self reportError];
        return;
    }

    if (request)
    {
        [self launchConnection:request :kConnectTypeUnassignDevice :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to unassign the device: bad request.";
        [self reportError];
    }
}



- (void)unassignDevices:(NSArray *)devices
{
    [self unassignDevices:devices :nil];
}



- (void)unassignDevices:(NSArray *)devices :(id)someObject
{
    if (devices == nil || devices.count == 0)
    {
        errorMessage = @"Could not create a request to unassign devices: no devices specified.";
        [self reportError];
        return;
    }

    NSMutableArray *array = [[NSMutableArray alloc] init];
    NSString *groupid;

    for (NSDictionary *device in devices)
    {
        NSDictionary *relationships = [device objectForKey:@"relationships"];
        NSDictionary *dg = [relationships objectForKey:@"devicegroup"];

        if (dg == nil)
        {
            // If there is no devicegroup set for the device, it is unassigned
            // This is not an error, so we replicate the post-uhassignment process
            // to inform the host app

            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

            NSDictionary *dict = someObject != nil
            ? @{ @"object" : someObject, @"data" : @"already unassigned" }
            : @{ @"data" : @"already unassigned" };

            [nc postNotificationName:@"BuildAPIDeviceUnassigned" object:dict];
        }
        else
        {
            NSString *dgid = [dg objectForKey:@"id"];

            NSDictionary *dict = @{ @"type" : @"device",
                                @"id" : [device objectForKey:@"id"] };

            if (groupid == nil)
            {
                // Store the first device group ID on the list - this will be used for all
                // further devices on the list

                groupid = dgid;

            }

            if ([groupid compare:dgid] == NSOrderedSame)
            {
                // Add the device info to the data array

                [array addObject:dict];
            }
        }
    }

    NSDictionary *data = @{ @"data" : [NSArray arrayWithArray:array] };
    NSError *error;
    NSMutableURLRequest *request = [self makeRequest:@"DELETE" :[NSString stringWithFormat:@"/devicegroups/%@/relationships/devices", groupid] :YES :NO];

    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:data options:0 error:&error]];

    if (error)
    {
        errorMessage = @"Could not create a request to unassign the devices: bad JSON data.";
        [self reportError];
        return;
    }

    if (request)
    {
        [self launchConnection:request :kConnectTypeUnassignDevices :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to unassign the device: bad request.";
        [self reportError];
    }
}



- (void)assignDevice:(NSDictionary *)device :(NSString *)devicegroupID
{
    [self assignDevice:device :devicegroupID :nil];
}



- (void)assignDevice:(NSDictionary *)device :(NSString *)devicegroupID :(id)someObject
{
    // Set up a POST to /devicegroups/{id}/relationships/devices

    if (device == nil)
    {
        errorMessage = @"Could not create a request to assign a device: no device specified.";
        [self reportError];
        return;
    }

    if (devicegroupID == nil || devicegroupID.length == 0)
    {
        errorMessage = @"Could not create a request to assign a device: no device group specified.";
        [self reportError];
        return;
    }

    NSString *did = [device objectForKey:@"id"];

    if ([devicegroupID compare:did] == NSOrderedSame)
    {
        // Device is already assigned to this device group

        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

        NSDictionary *dict = someObject != nil
        ? @{ @"data" : @"already assigned", @"object" : someObject }
        : @{ @"data" : @"already assigned" };

        [nc postNotificationName:@"BuildAPIDeviceAssigned" object:dict];
        return;
    }

    NSDictionary *dict = @{ @"type" : @"device",
                            @"id" : did};

    NSArray *array = @[ dict ];

    NSDictionary *data = @{ @"data" : array };

    NSMutableURLRequest *request = [self makePOSTrequest:[NSString stringWithFormat:@"/devicegroups/%@/relationships/devices", devicegroupID] :data];

    if (request)
    {
        [self launchConnection:request :kConnectTypeAssignDevice :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to assign the device: bad request.";
        [self reportError];
    }
}



- (void)assignDevices:(NSArray *)devices :(NSString *)devicegroupID
{
    [self assignDevices:devices :devicegroupID :nil];
}



- (void)assignDevices:(NSArray *)devices :(NSString *)devicegroupID :(id)someObject
{
    if (devices == nil || devices.count == 0)
    {
        errorMessage = @"Could not create a request to assign devices: no devices specified.";
        [self reportError];
        return;
    }

    NSMutableArray *array = [[NSMutableArray alloc] init];

    for (NSDictionary *device in devices)
    {
        NSDictionary *relationships = [device objectForKey:@"relationships"];
        NSDictionary *dg = [relationships objectForKey:@"devicegroup"];

        if (dg != nil)
        {
            NSString *dgid = [dg objectForKey:@"id"];

            if ([dgid compare:devicegroupID] == NSOrderedSame)
            {
                // Device is already assigned to this device group

                NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

                NSDictionary *dict = someObject != nil
                ? @{ @"data" : @"already assigned", @"object" : someObject }
                : @{ @"data" : @"already assigned" };

                [nc postNotificationName:@"BuildAPIDeviceAssigned" object:dict];
            }
            else
            {
                NSDictionary *dict = @{ @"type" : @"device",
                                        @"id" : [device objectForKey:@"id"] };

                [array addObject:dict];
            }
        }
    }

    NSDictionary *data = @{ @"data" : [NSArray arrayWithArray:array] };
    NSError *error;
    NSMutableURLRequest *request = [self makePOSTrequest:[NSString stringWithFormat:@"/devicegroups/%@/relationships/devices", devicegroupID] :data];

    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:data options:0 error:&error]];

    if (error)
    {
        errorMessage = @"Could not create a request to unassign the devices: bad JSON data.";
        [self reportError];
        return;
    }

    if (request)
    {
        [self launchConnection:request :kConnectTypeUnassignDevices :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to unassign the device: bad request.";
        [self reportError];
    }
}



- (void)deleteDevice:(NSString *)deviceID
{
    [self deleteDevice:deviceID :nil];
}



- (void)deleteDevice:(NSString *)deviceID :(id)someObject
{
    // Set up a DELETE to /devices/{id}

    if (deviceID == nil || deviceID.length == 0)
    {
        errorMessage = @"Could not create a request to delete a device: no device specified.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makeDELETErequest:[NSString stringWithFormat:@"/devices/%@", deviceID]];

    if (request)
    {
        [self launchConnection:request :kConnectTypeDeleteDevice :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to assign the device: bad request.";
        [self reportError];
    }
}



#pragma mark Deployments


- (void)createDeployment:(NSDictionary *)deployment
{
    [self createDeployment:deployment :nil];
}



- (void)createDeployment:(NSDictionary *)deployment :(id)someObject
{
    // Set up a POST to /deployments

    if (deployment == nil)
    {
        errorMessage = @"Could not create a request to create a deployment: no deployment specified.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makePOSTrequest:@"deployments" :deployment];

    if (request)
    {
        [self launchConnection:request :kConnectTypeCreateDeployment :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to create a deployment: bad request.";
        [self reportError];
    }
}



- (void)updateDeployment:(NSString *)deploymentID :(NSArray *)keys :(NSArray *)values
{
    [self updateDeployment:deploymentID :keys :values :nil];
}



- (void)updateDeployment:(NSString *)deploymentID :(NSArray *)keys :(NSArray *)values :(id)someObject
{
    // Set up a PATCH request to /deployments/{id}
    // We can ONLY update a deployments flagged state and description FOR NOW
    // Coming: tags

    if (deploymentID == nil || deploymentID.length == 0)
    {
        errorMessage = @"Could not create a request to update a deployment: no deployment specified.";
        [self reportError];
        return;
    }

    if (keys == nil || keys.count == 0)
    {
        errorMessage = @"Could not create a request to update the deployment: no data fields specified.";
        [self reportError];
        return;
    }

    if (values.count == 0 || values.count != keys.count)
    {
        errorMessage = @"Could not create a request to update the deployment: insufficient or extraneous data supplied.";
        [self reportError];
        return;
    }

    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    NSString *desc = nil;

    for (NSUInteger i = 0 ; i < keys.count ; ++i)
    {
        NSString *key = [keys objectAtIndex:i];

        if ([key compare:@"description"] == NSOrderedSame)
        {
            desc = [values objectAtIndex:i];
            if (desc != nil) [attributes setValue:desc forKey:@"description"];
            break;
        }

        if ([key compare:@"flagged"] == NSOrderedSame)
        {
            NSNumber *value = [values objectAtIndex:i];
            if (value != nil) [attributes setValue:value forKey:@"flagged"];
        }
    }

    if (attributes.count > 0)
    {
        // Only proceed if valid changes have actually been made

        NSDictionary *dict= @{ @"id" : deploymentID,
                                @"type" : @"deployment",
                                @"attributes" : [NSDictionary dictionaryWithDictionary:attributes] };

        NSDictionary *data = @{ @"data" : dict };

        NSMutableURLRequest *request = [self makePATCHrequest:[NSString stringWithFormat:@"deployments/%@", deploymentID] :data];

        if (request)
        {
            [self launchConnection:request :kConnectTypeUpdateDeployment :someObject];
        }
        else
        {
            errorMessage = @"Could not create a request to update the deployment.";
            [self reportError];
        }
    }
    else
    {
        errorMessage = @"Could not create a request to update the deployment - no valid changes made.";
        [self reportError];
    }
}



- (void)deleteDeployment:(NSString *)deploymentID
{
    [self deleteDeployment:deploymentID :nil];
}



- (void)deleteDeployment:(NSString *)deploymentID :(id)someObject
{
    // Set up a DELETE to /devices/{id}

    if (deploymentID == nil || deploymentID.length == 0)
    {
        errorMessage = @"Could not create a request to delete a deployment: no deployment specified.";
        [self reportError];
        return;
    }

    NSMutableURLRequest *request = [self makeDELETErequest:[NSString stringWithFormat:@"/devices/%@", deploymentID]];

    if (request)
    {
        [self launchConnection:request :kConnectTypeDeleteDeployment :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to delete the deployment: bad request.";
        [self reportError];
    }
}



- (void)setMinimumDeployment:(NSString *)devicegroupID :(NSDictionary *)deployment
{
    [self setMinimumDeployment:devicegroupID :deployment :nil];
}



- (void)setMinimumDeployment:(NSString *)devicegroupID :(NSDictionary *)deployment :(id)someObject
{
    // Set up a PUT to /devicegroups/{ID}/relationships/min_supported_deployment

    if (devicegroupID == nil || devicegroupID.length == 0)
    {
        errorMessage = @"Could not create a request to set a minimum deployment: no device group specified.";
        [self reportError];
        return;
    }

    NSDictionary *data = @{ @"type" : @"deployment", @"id" : [deployment objectForKey:@"id"] };
    NSDictionary *body = @{ @"data" : data };

    NSMutableURLRequest *request = [self makePUTrequest:[NSString stringWithFormat:@"/devicegroups/%@/relationships/min_supported_deployment", devicegroupID] :body];

    if (request)
    {
        [self launchConnection:request :kConnectTypeSetMinDeployment :someObject];
    }
    else
    {
        errorMessage = @"Could not create a request to set a minimum deployment: bad request.";
        [self reportError];
    }
}



#pragma mark - HTTP Request Construction Methods


- (NSMutableURLRequest *)makeGETrequest:(NSString *)path :(BOOL)getMultipleItems
{
    return [self makeRequest:@"GET" :path :NO : getMultipleItems];
}



- (NSMutableURLRequest *)makeDELETErequest:(NSString *)path
{
    return [self makeRequest:@"DELETE" :path :NO :NO];
}



- (NSMutableURLRequest *)makePOSTrequest:(NSString *)path :(NSDictionary *)body
{
    NSError *error = nil;
    NSMutableURLRequest *request = [self makeRequest:@"POST" :path :YES :NO];

    if (body != nil) [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:body options:0 error:&error]];
    if (error != nil) return nil;
    return request;
}



- (NSMutableURLRequest *)makePATCHrequest:(NSString *)path :(NSDictionary *)body
{
    NSError *error = nil;
    NSMutableURLRequest *request = [self makeRequest:@"PATCH" :path :YES :NO];

    if (body != nil) [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:body options:0 error:&error]];
    if (error != nil) return nil;
    return request;
}



- (NSMutableURLRequest *)makePUTrequest:(NSString *)path :(NSDictionary *)body
{
    NSError *error = nil;
    NSMutableURLRequest *request = [self makeRequest:@"PUT" :path :YES :NO];

    if (body != nil) [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:body options:0 error:&error]];
    if (error != nil) return nil;
    return request;
}



- (NSMutableURLRequest *)makeRequest:(NSString *)verb :(NSString *)path :(BOOL)addContentType :(BOOL)getMultipleItems
{
    if (token == nil || !isLoggedIn)
    {
        // We have no access token, so we can't get any data

        errorMessage = @"You must be logged in to access the Electric Imp impCloud™";
        [self reportError];
        return nil;
    }

    if (pageSizeChangeFlag && ([path compare:@"accounts/me"] != NSOrderedSame) && [verb compare:@"GET"] == NSOrderedSame)
    {
        // User has changed the page size, so we need to pass this in now to set it
        // NOTE make sure this is not called when we do a request for the user's account
        // and that it's not duplicating the encoded string

        if (![path containsString:@"?"] && getMultipleItems) path = [path stringByAppendingFormat:@"?page[size]=%li", pageSize];
    }

    if (![path hasPrefix:@"https://"]) path = [baseURL stringByAppendingString:path];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path]];

    [self setRequestAuthorization:request];
    [request setHTTPMethod:verb];
    [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];

    if (addContentType) [request setValue:@"application/vnd.api+json" forHTTPHeaderField:@"Content-Type"];

    return request;
}



- (void)setRequestAuthorization:(NSMutableURLRequest *)request
{
    // Applies the stored access token data to the request
    // NOTE the validity of the accessToken should already have been checked

    [request setValue:[@"Bearer " stringByAppendingString:token.accessToken] forHTTPHeaderField:@"Authorization"];
    [request setTimeoutInterval:30.0];
}



#pragma mark - Connection Methods


- (Connexion *)launchConnection:(NSMutableURLRequest *)request :(NSInteger)actionCode :(id)someObject
{
    // Create a default connexion object to store the details of the connection
    // we're about to initiate

    Connexion *aConnexion = [[Connexion alloc] init];
    aConnexion.actionCode = actionCode;
    aConnexion.originalRequest = request;
    aConnexion.data = [NSMutableData dataWithCapacity:0];

    if (someObject) aConnexion.representedObject = someObject;

    // Use NSURLSession for the connection. Compatible with iOS, tvOS and Mac OS X

    if (apiSession == nil) apiSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                          delegate:self
                                                     delegateQueue:[NSOperationQueue mainQueue]];

    // Do we have a valid access token - or are we getting/refreshing the access token?

    if (aConnexion.actionCode == kConnectTypeGetAccessToken || aConnexion.actionCode == kConnectTypeRefreshAccessToken || [self isAccessTokenValid])
    {
        // Create and begin the task

        aConnexion.task = [apiSession dataTaskWithRequest:request];

        [aConnexion.task resume];

        // Notify the main app to show and start its progress indicator, if it has one

        if (connexions.count == 0) [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStart" object:nil];

        // Add the new connection to the list

        [connexions addObject:aConnexion];

        // Update the public property, numberOfConnections

        numberOfConnections = connexions.count;

        // Set 'tokenConnexion' if we need to

        if (aConnexion.actionCode == kConnectTypeGetAccessToken || aConnexion.actionCode == kConnectTypeRefreshAccessToken) tokenConnexion = aConnexion;
    }
    else
    {
        // We do not have a valid token, so we must now acquire one. In the meantime, we
        // cache all new connexions in 'pendingConnections' so they can be actioned when
        // we finally get the token

        // Q: do we want to put a limit on 'pendingConnections' size?

        if (pendingConnections == nil) pendingConnections = [[NSMutableArray alloc] init];

        if (tokenConnexion == nil)
        {
            // We have no queued connections yet, so get a new token
            // NOTE we need to ensure this is called only once per refresh

            [self refreshAccessToken];
        }

        // Add the current request to the pending queue while the new token is retrieved

        [pendingConnections addObject:aConnexion];
    }

    return aConnexion;
}



- (void)relaunchConnection:(id)userInfo
{
    // This method is called in response to the receipt of a status code 429 from the server,
    // ie. we have been rate-limited. A timer will bring us here 1.0 seconds after receipt of the error

    NSDictionary *dict = (NSDictionary *)userInfo;
    NSMutableURLRequest *request = [dict objectForKey:@"request"];
    NSInteger actionCode = [[dict objectForKey:@"actioncode"] integerValue];

    [self launchConnection:request :actionCode :[dict objectForKey:@"object"]];
}



- (void)launchPendingConnections
{
    // Pending connections are cached when we attempt to create a connection but no session
    // token has yet been received. Having elsewhere received the new token, we can now
    // launch the pending connections, if there are any

    if (pendingConnections != nil && pendingConnections.count > 0)
    {
        for (Connexion *conn in pendingConnections)
        {
            [self setRequestAuthorization:conn.originalRequest];

            if (apiSession == nil) apiSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                                  delegate:self
                                                             delegateQueue:[NSOperationQueue mainQueue]];

            conn.task = [apiSession dataTaskWithRequest:conn.originalRequest];

            [conn.task resume];
            [connexions addObject:conn];

            numberOfConnections = connexions.count;
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStart" object:nil];
        [pendingConnections removeAllObjects];
    }
}



- (void)killAllConnections
{
    // Cancel and clear all in-flight connections and any pending connections

    if (connexions.count > 0)
    {
        // There are connections that we need to terminate

        if (loggingDevices.count > 0)
        {
            // There are devices for which we are streaming logs, so clear the list...

            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            NSMutableArray *lgds = [loggingDevices copy];
            numberOfLogStreams = 0;

            [loggingDevices removeAllObjects];
            [self closeStream];

            // ...and notify the host for each device

            for (NSString *loggingDevice in lgds) [nc postNotificationName:@"BuildAPILogStreamEnd" object:loggingDevice];
        }

        // Kill the remaining connections.
        // The triggered delegate method didBecomeInvalid: wiil clear out 'connexions'

        if (apiSession != nil) [apiSession invalidateAndCancel];
    }

    // Remove any pending connections

    if (pendingConnections != nil && pendingConnections.count > 0) [pendingConnections removeAllObjects];
}



#pragma mark - Log Stream Methods


- (void)startLogging:(NSString *)deviceID
{
    [self startLogging:deviceID :nil];
}



- (void)startLogging:(NSString *)deviceID :(id)someObject
{
    if (deviceID == nil || deviceID.length == 0)
    {
        // No device ID? Can't proceed

        errorMessage = @"Could not create a request to stream the device logs: no device specified.";
        [self reportError];
        return;
    }

    if (loggingDevices == nil) loggingDevices = [[NSMutableArray alloc] init];

    // Check whether this is first device we're starting logging for, ie. whether we have a stream ID

    if (logStreamID == nil || logStreamID.length == 0)
    {
        // This is the first device, so we need to first get the stream ID and stream URL

        NSMutableURLRequest *request = [self makePOSTrequest:@"logstream?format=json" :nil];

        if (request)
        {
            // Pass in the first device's ID so we have it to use after the stream has been established

            NSDictionary *dict = someObject != nil
            ? @{ @"device" : deviceID, @"object" : someObject }
            : @{ @"device" : deviceID };

            [self launchConnection:request :kConnectTypeGetLogStreamID :dict];
        }
        else
        {
            errorMessage = @"Could not create a request to stream the specified device logs.";
            [self reportError];
        }
    }
    else
    {
        // We are already streaming from one or more devices, so just add the new one to the list

        [self addDeviceToLogStream:deviceID :someObject];
    }
}



- (void)addDeviceToLogStream:(NSString *)deviceID :(id)someObject
{
    // PUT { device identifier } to /logstream/<stream_id>
    // { device identifier } eg. { id: ‘d9f6f253-d203-487f-bdb0-70ea1529ee1b’, type: ‘device’ }

    if (loggingDevices.count > 0)
    {
        // First check that the device is not already logging; if it is, bail

        for (NSString *devid in loggingDevices)
        {
            if ([devid compare:deviceID] == NSOrderedSame) return;
        }
    }

    NSDictionary *dict = @{ @"id" : deviceID,
                            @"type" : @"device" };

    NSMutableURLRequest *request = [self makePUTrequest:[NSString stringWithFormat:@"%@/%@", logStreamURL.absoluteString, deviceID] :dict];

    if (request)
    {
        dict = (someObject != nil)
        ? @{ @"device" : deviceID, @"object" : someObject }
        : @{ @"device" : deviceID };

        [self launchConnection:request :kConnectTypeAddLogStream :dict];
    }
    else
    {
        errorMessage = @"Could not create a request to stream the specified device logs.";
        [self reportError];
    }
}



- (void)stopLogging:(NSString *)deviceID
{
    [self stopLogging:deviceID :nil];
}



- (void)stopLogging:(NSString *)deviceID :(id)someObject
{
    // DELETE /logstream/<stream_id>/<device_identifier>
    // { id: ‘d9f6f253-d203-487f-bdb0-70ea1529ee1b’, type: ‘device’ }

    NSDictionary *dict = @{ @"id" : deviceID,
                            @"type" : @"device" };

    NSMutableURLRequest *request = [self makeRequest:@"DELETE" :[NSString stringWithFormat:@"%@/%@", logStreamURL, deviceID] :NO :NO];
    NSError *error;

    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:dict options:0 error:&error]];

    if (error)
    {
        errorMessage = @"Could not create a request to stop streaming the specified device logs: bad JSON data.";
        [self reportError];
        return;
    }

    if (request)
    {
        dict = (someObject != nil)
        ? @{ @"device" : deviceID, @"object" : someObject }
        : @{ @"device" : deviceID };

        [self launchConnection:request :kConnectTypeEndLogStream :dict];
    }
    else
    {
        errorMessage = @"Could not create a request to stop streaming the specified device logs.";
        [self reportError];
    }
}



- (void)restartLogging
{
    // This is called if a log connection breaks for some reason, so enable logging to auto-restart
    // POST-ing to /logstream will return a stream ID by way of a 302, which we will trap later

    NSMutableURLRequest *request = [self makePOSTrequest:@"logstream?format=json" :nil];

    if (request)
    {
        // Pass in the first device's ID so we have it to use after the stream has been established

        restartingLog = YES;
        [self launchConnection:request :kConnectTypeGetLogStreamID :nil];
    }
    else
    {
        errorMessage = @"Could not create a request to stream the specified device logs.";
        [self reportError];
    }
}



- (void)startStream:(NSURL *)url
{
    // This method sets up the log stream which will recieve and handle server-sent events (SSE)
    // from the impCentral API. At this point we have no connection to pipe the SSEs

    logStreamURL = url;
    logIsClosed = YES;

    if (eventQueue == nil)
    {
        // Establish an single-tier operation to handle incoming log messages in order

        eventQueue = [[NSOperationQueue alloc] init];
        eventQueue.maxConcurrentOperationCount = 1;
    }

    // Create the only connexion for streaming

    logConnexion = [[Connexion alloc] init];
    logConnexion.actionCode = kConnectTypeLogStream;

    // Add the stream's connection to the list

    [connexions addObject:logConnexion];

    if (connexions.count == 1)
    {
        // Notify the main app to start the progress indicator

        [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStart" object:nil];
    }

    // Open the SSE connection
    // NOTE openStream: is a separate method so it can be called elsewhere too

    [self openStream];
}



- (void)openStream
{
    // Here we actually open the connection through which events from the server will pass

    logIsClosed = NO;

    if (apiSession == nil) apiSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                                      delegate:self
                                                                 delegateQueue:[NSOperationQueue mainQueue]];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:logStreamURL
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:logTimeout];

    [request setHTTPMethod:@"GET"];

    if (logLastEventID) [request setValue:logLastEventID forHTTPHeaderField:@"Last-Event-ID"];

    logConnexion.task = [apiSession dataTaskWithRequest:request];

    [logConnexion.task resume];

    // Create a new event to record the state change (connecting) and issue it
    // TODO Do we need to do this??

    LogStreamEvent *event = [[LogStreamEvent alloc] init];
    event.state = kLogStreamEventStateConnecting;
    event.type = kLogStreamEventTypeStateChange;

    // Place the event in the the event queue to guarantee displayed order = received order

    [eventQueue addOperationWithBlock:^{
        [self dispatchEvent:event];
    }];
}



- (void)closeStream
{
    // Flag the closure (prevents an error report from the 'didComplete:' delegate method

    logIsClosed = YES;

    // Cancel the saved task to close it

    if (logConnexion != nil)
    {
        // logConnexion.actionCode = kConnectTypeNone;

        [logConnexion.task cancel];
        [connexions removeObject:logConnexion];

        // Notify the main app to stop the progress indicator

        if (connexions.count == 0) [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStop" object:nil];

        logConnexion = nil;
        logStreamURL = nil;
        logStreamID = nil;
    }
}



- (void)dispatchEvent:(LogStreamEvent *)event
{
    // Processes an event from the event queue: pass it to the main thread for processing in processEvent:

    [self performSelectorOnMainThread:@selector(processEvent:) withObject:event waitUntilDone:NO];
}



- (void)processEvent:(LogStreamEvent *)event
{
    // Processes the supplied event when it is called from the connection queue

    NSDictionary *dict = nil;

    switch (event.type)
    {
        case kLogStreamEventTypeStateChange:

            // A stream state change has been signalled (by us or by the stream)

            switch (event.state)
            {
                case kLogStreamEventStateConnecting:
#ifdef DEBUG
    NSLog(@"%@", @"Log State: Connecting");
#endif
                    break;

                case kLogStreamEventStateOpen:
#ifdef DEBUG
    NSLog(@"%@", @"Log State: Connection open");
#endif
                    // The log stream signals that it is open, so we can now add the first device,
                    // whose ID has been retained through the stream set-up process. Calling logOpened: does this

                    [self performSelectorOnMainThread:@selector(logOpened) withObject:nil waitUntilDone:NO];
                    break;

                case kLogStreamEventStateSubscribed:
#ifdef DEBUG
    NSLog(@"%@", @"Log State: Device added");
#endif
                    break;

                case kLogStreamEventStateUnsubscribed:
#ifdef DEBUG
    NSLog(@"%@", @"Log State: Device removed");
#endif
                    break;

                case kLogStreamEventStateClosed:
#ifdef DEBUG
    NSLog(@"%@", @"Log State: Connection closed");
#endif
                    // Log stream has signalled closure for some reason, so we need to re-open it

                    [self closeStream];
                    [self restartLogging];
            }

            break;

        case kLogStreamEventTypeMessage:

            // A mesage has been received from the server. Relay it to the host app via relayLogEntry:

            if (event.data != nil)
            {
                dict = @{ @"message" : event.data };

                [self performSelectorOnMainThread:@selector(relayLogEntry:) withObject:dict waitUntilDone:NO];
            }

            break;

        case kLogStreamEventTypeError:
            // An error has broken the stream. Relay the error to the host app via logClosed:

            dict = @{ @"message" : event.error,
                      @"code" : [NSNumber numberWithInteger:event.state] };

            [self performSelectorOnMainThread:@selector(logClosed:) withObject:dict waitUntilDone:NO];
            break;
    }
}



- (void)relayLogEntry:(NSDictionary *)entry
{
    // Called on the main thread to pass a received log entry to the host app

    [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPILogEntryReceived" object:entry];
}



- (void)logOpened
{
    // Called on the main thread when the log stream has been successfully opened

    if (deviceToStream != nil) [self addDeviceToLogStream:deviceToStream :nil];
    deviceToStream = nil;

    if (restartingLog)
    {
        if (loggingDevices.count > 0)
        {
            for (NSString *deviceId in loggingDevices)
            {
                [self addDeviceToLogStream:deviceId :nil];
            }
        }

        restartingLog = NO;
    }
}



- (void)logClosed:(NSDictionary *)error
{
    // Called on the main thread to notify the host that the log stream is closed - possibly because of an error

    errorMessage = @"Log stream closed due to a connection error";
    [self reportError];

    NSMutableArray *lgds = [loggingDevices copy];
    [loggingDevices removeAllObjects];
    [self closeStream];

    numberOfLogStreams = 0;

    // ...and notify the host for each device

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    for (NSString *loggingDevice in lgds) [nc postNotificationName:@"BuildAPILogStreamEnd" object:loggingDevice];
}



- (BOOL)isDeviceLogging:(NSString *)deviceID
{
    // Check if a device, specified by ID, is one of those currently logging,
    // responding with YES or NO as appropriate

    if (deviceID == nil || deviceID.length == 0) return NO;

    for (NSString *dvid in loggingDevices)
    {
        if ([dvid compare:deviceID] == NSOrderedSame) return YES;
    }

    return NO;
}



- (NSInteger)indexOfLoggedDevice:(NSString *)deviceID
{
    // Returns the index within the list of logging devices of the specified device (by ID)
    // Returns -1 in the event of an error - the device is not on the list

    for (NSUInteger i = 0 ; i < loggingDevices.count ; ++i)
    {
        NSString *dvid = [loggingDevices objectAtIndex:i];

        if ([deviceID compare:dvid] == NSOrderedSame)
        {
            return i;
        }
    }

    return -1;
}



#pragma mark - NSURLSession Connection Delegate Methods


- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    // This delegate method is called when the server responds to the connection request
    // It is used to trap certain status codes / errors which affect connections rather than data
    // eg. rate-limiting responses

    // Get the connexion instance representing this connection task

    Connexion *connexion = nil;

    for (Connexion *aConnexion in connexions)
    {
        if (aConnexion.task == dataTask)
        {
            connexion = aConnexion;
            break;
        }
    }

    // Get the HTTP status code

    NSHTTPURLResponse *resp = (NSHTTPURLResponse *)response;
    NSInteger statusCode = resp.statusCode;

    if (statusCode > 399 || statusCode == 302)
    {
        // The API has responded with a status code that indicates an error.
        // Examine the status code to deal with specific errors

        if (statusCode == 302)
        {
            // TODO Is this ever called now?

            if (connexion.actionCode == kConnectTypeGetLogStreamID)
            {
                // We have asked for a log stream ID; this is returned as a 302, which we trap here

                logStreamID = [resp.allHeaderFields objectForKey:@"location"];

#ifdef DEBUG
    NSLog(@"Log Stream ID received: %@", logStreamID);
#endif
            }
        }

        if (statusCode == 401)
        {
            if (connexion.actionCode == kConnectTypeGetAccessToken)
            {
                // We have asked for an access token, so this indicates a login credentials failure -
                // we can proceed no further at this time. Report the error back to the host app
                // and end the connection

                isLoggedIn = NO;

                errorMessage = @"Your impCloud access credentials have been rejected.";
                [self reportError:kErrorLoginRejectCredentials];

                [connexions removeObject:connexion];
                numberOfConnections = connexions.count;

                if (connexions.count == 0) [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStop" object:nil];

                // Run the completion handler with a 'cancel' response becuase we are killing this connection

                if (completionHandler != nil) completionHandler(NSURLSessionResponseCancel);

                return;
            }

			if (connexion.actionCode == kConnectTypeRefreshAccessToken)
			{
				NSLog(@"401 encountered refreshing access token");
			}
        }

        if (statusCode == 429)
        {
            // impCentral API rate limit has been exceeded, which we neeed to deal with here
            // Bundle up connection data and pass it to 'relauchConnection:' in 'limit' * 1000 seconds' time
            // 'limit' is the milliseconds time to wait before reconnecting that has been submitted by
            // the server

            NSDictionary *dict = connexion.representedObject != nil
            ? @{ @"request" : [dataTask.originalRequest copy],
                 @"actioncode" : [NSNumber numberWithInteger:connexion.actionCode],
                 @"object" : connexion.representedObject }
            : @{ @"request" : [dataTask.originalRequest copy],
                 @"actioncode" : [NSNumber numberWithInteger:connexion.actionCode] };

            NSInteger limit = [[resp.allHeaderFields valueForKey:@"X-RateLimit-Reset"] integerValue];

            // Wait ('limit' * 1000) seconds and re-access the impCloud

            [NSTimer scheduledTimerWithTimeInterval:(limit * 1000)
                                             target:self
                                           selector:@selector(relaunchConnection:)
                                           userInfo:dict
                                            repeats:NO];

            if (connexion != nil)
            {
                [connexions removeObject:connexion];
                numberOfConnections = connexions.count;
            }

            if (connexions.count == 0) [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStop" object:nil];

            // Run the completion handler with a 'cancel' response becuase we are killing this connection

            if (completionHandler != nil) completionHandler(NSURLSessionResponseCancel);

            return;
        }
    }

    // For all other server-issued errors, record the error code to deal with later

    connexion.errorCode = statusCode;

    // Allow the connection to complete so we can analyze the error later

    if (completionHandler != nil) completionHandler(NSURLSessionResponseAllow);
}



- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    // This delegate method is called when the server sends some data back

    // Get the connexion instance representing this NSURLSessionDataTask

    Connexion *connexion = nil;

    for (Connexion *aConnexion in connexions)
    {
        if (aConnexion.task == dataTask)
        {
            connexion = aConnexion;
            break;
        }
    }

    if (connexion.actionCode == kConnectTypeLogStream)
    {
        // For logging connections, deal with the data immediately

        [self parseStreamData:data :connexion];
    }
    else
    {
        // For non-logging connections, append the incoming data chunk to the store
        // held by the appropriate connexion instance

        [connexion.data appendData:data];
    }
}



- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
{
    // All the data has been supplied by the server in response to a connection - or an error has been encountered.
    // Deal with the error, or pass the retrieved data on for processing

    // Get the connexion instance representing this connection task

    Connexion *connexion = nil;

    for (Connexion *aConnexion in connexions)
    {
        // Run through the connections in the list and find the one that has just finished loading

        if (aConnexion.task == task)
        {
            connexion = aConnexion;
            break;
        }
    }

    // Complete the finished NSURLSessionTask - this may be redundant, but just in case...

    [task cancel];
    connexion.task = nil;

    // React to a passed client-side error - most likely a timeout or inability to resolve the URL
    // eg. the client is not connected to the Internet

    if (error)
    {
        // NOTE 'error.code' will equal NSURLErrorCancelled when we cancel a live connection task,
        // eg. by killing all connections, so just return

        if (error.code == NSURLErrorCancelled) return;

        // Now process other errors

#ifdef DEBUG
	NSLog(@"%@", error.localizedDescription);
#endif

        if (connexion != nil)
        {
            if (connexion.actionCode == kConnectTypeLogStream)
            {
                // Are we logging? If so, handle this type of connection here
                // Is the connection already closed? If so, just bail

                if (logIsClosed) return;

                logIsClosed = YES;
				logStreamURL = nil;

                // Create an error event

                LogStreamEvent *event = [[LogStreamEvent alloc] init];
                event.type = kLogStreamEventTypeError;
                event.error = error != nil ? error : [NSError errorWithDomain:@"NSURLErrorDomain" code:event.state userInfo:@{ NSLocalizedDescriptionKey: @"Connection with the event source was closed." } ];

                // Add an error event to the event queue

                [eventQueue addOperationWithBlock:^{
                    [self dispatchEvent:event];
                }];

                /*
                 // Attempt to re-open the connection in 'retryInterval' seconds

                 [NSTimer timerWithTimeInterval:logRetryInterval
                 repeats:NO
                 block:^(NSTimer * _Nonnull timer) {
                 [self openStream];
                 }];
                 */

                // Bail because we will handle connection clear-up later

                return;
            }

            // Make sure we're not logged in if we haven't been able to get an access token

            if (connexion.actionCode == kConnectTypeGetAccessToken || connexion.actionCode == kConnectTypeRefreshAccessToken) isLoggedIn = NO;

            errorMessage = @"Unable to connect to the Electric Imp impCloud. Please check your network connection.";

            [self reportError:kErrorNetworkError];

            [connexions removeObject:connexion];

            numberOfConnections = connexions.count;
        }

        // If there are no more active connections, tell the host app

        if (connexions.count == 0) [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStop" object:nil];

        return;
    }

    // The connection has come to a conclusion without error, so if we have a valid action code,
    // we can proceed to process the received data

    if (connexion != nil)
    {
        if (connexion.actionCode != kConnectTypeNone)
        {
            // Handle the received data

            [self processResult:connexion :[self processConnection:connexion]];
        }
        else
        {
            // This might be redundant - can a connexion ever have 'actionCode == kConnectTypeNone' at this point?

            [connexions removeObject:connexion];

            numberOfConnections = connexions.count;

            // If there are no more active connections, tell the host app

            if (connexions.count == 0) [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStop" object:nil];
        }
    }
}



- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
    // This method is called after we have called invalidateAndCancel on an NSURLSession, eg. in 'killAllConnections:'

    // Clear all the connexions from the list

    [connexions removeAllObjects];

    // Tell the host app

    [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIProgressStop" object:nil];

    // Zero all the other connection-related properties

    apiSession = nil;
    numberOfConnections = 0;
}



#pragma mark - Connection Result Processing Methods


- (void)parseStreamData:(NSData *)data :(Connexion *)connexion
{
    // Wrangle an incoming batch of streamed data to pull out server-sent events and extract
    // the data from them (and defer incomplete events until the rest of them arrives)

#ifdef DEBUG
    //NSDate *date = [NSDate date];
#endif

    NSString *eventString;

    if (connexion.data != nil)
    {
        // Add in existing data from the last streamed chunk, if there is any

        [connexion.data appendData:data];
        eventString = [[NSString alloc] initWithData:connexion.data encoding:NSUTF8StringEncoding];
        connexion.data = [NSMutableData dataWithLength:0];
    }
    else
    {
        // Otherwise, just work with the freshly passed in data alone

        eventString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }

    // Check the last two characters of the string: are they newlines? If not, the data
    // is truncated and needs to be retained for the next pass

    NSString *lastTwoChars = @"";
    if (eventString.length > 2) lastTwoChars = [eventString substringFromIndex:eventString.length - 2];
    BOOL lastMessageTruncated = ([lastTwoChars compare:kLogStreamEventSeparatorLFLF] == NSOrderedSame) ? NO : YES;

    // Separate the string into individual events (separated by newline pairs)
    // If there are no newlines, events.count == 1, which we trap quickly

    NSArray *events = [eventString componentsSeparatedByString:kLogStreamEventSeparatorLFLF];

    if (events.count > 1)
    {
        for (NSUInteger i = 0 ; i < events.count ; ++i)
        {
            NSString *event = [events objectAtIndex:i];

            if (event.length == 0) continue;

            if (i == events.count - 1 && lastMessageTruncated)
            {
                // This is the detected event and it MIGHT be truncated, so just hold it for the next pass

                connexion.data = [NSMutableData dataWithData:[event dataUsingEncoding:NSUTF8StringEncoding]];

#ifdef DEBUG
     NSLog(@"Holding data for next stream chunk\nEvent -> %@", event);
#endif

            }
            else
            {
                // We have an event that we KNOW has been terminated with a \n\n,
                // ie. it is complete and can be processed

                LogStreamEvent *logStreamEvent = [[LogStreamEvent alloc] init];
                logStreamEvent.type = kLogStreamEventTypeMessage;

                // Separate the key-value pairs (separated by newlines)

                NSArray *lines = [event componentsSeparatedByString:kLogStreamEventKeyValuePairSeparator];
#ifdef DEBUG
    NSLog(@"Lines -> %lu", (long)lines.count);
#endif

                // Run through each of the event's lines and extract the information into the
                // relevant logStreamEvent object properties

                for (NSString *line in lines)
                {
#ifdef DEBUG
    NSLog(@"Line  -> %@ (%li)", line, (long)line.length);
#endif

                    if ([line hasPrefix:@":"]) continue;

                    NSString *key, *value;
                    NSRange fieldSeparatorRange = [line rangeOfString:kLogStreamKeyValueDelimiter];

                    if (fieldSeparatorRange.location != NSNotFound)
                    {
                        key = [line substringToIndex:fieldSeparatorRange.location];
                        value = [line substringFromIndex:fieldSeparatorRange.location + 2];

                        if (key != nil && value != nil)
                        {
                            if ([key isEqualToString:kLogStreamEventEventKey])
                            {
                                // 'event' - value will be 'message' or 'state_change'

                                logStreamEvent.event = value;
                            }
                            else if ([key isEqualToString:kLogStreamEventDataKey])
                            {
                                // 'data' - value will be, eg. 'opened', 'closed', '40000c2a69109f08 subscribed', or '<log entry>'

                                logStreamEvent.data = logStreamEvent.data != nil ? [logStreamEvent.data stringByAppendingFormat:@"\n%@", value] : value;
                            }
                            else if ([key isEqualToString:kLogStreamEventIDKey])
                            {
                                // 'id'

                                logLastEventID = value;
                            }
                            else if ([key isEqualToString:kLogStreamEventRetryKey])
                            {
                                // 'retry'

                                logRetryInterval = [value doubleValue];
                            }
                        }
                    }
                    else
                    {
#ifdef DEBUG
    // No field separator????
                        NSLog(@"Incoming event malformed - no field separator (: )");
#endif
                    }
                }

                if (logStreamEvent.data != nil)
                {
                    // Change the logStreamEvent's 'state' according to type
                    // NOTE 'type' is set to kLogStreamEventTypeMessage above; 'state' doesn't matter for messages

                    if ([logStreamEvent.event compare:@"state_change"] == NSOrderedSame)
                    {
                        logStreamEvent.type = kLogStreamEventTypeStateChange;
                        if ([logStreamEvent.data compare:@"opened"] == NSOrderedSame) logStreamEvent.state = kLogStreamEventStateOpen;
                        if ([logStreamEvent.data compare:@"closed"] == NSOrderedSame) logStreamEvent.state = kLogStreamEventStateClosed;
                        if ([logStreamEvent.data hasSuffix:@"subscribed"]) logStreamEvent.state = kLogStreamEventStateSubscribed;
                        if ([logStreamEvent.data hasSuffix:@"unsubscribed"]) logStreamEvent.state = kLogStreamEventStateUnsubscribed;
                    }

                    // Place the event in the the event queue to guarantee displayed order = received order

                    [eventQueue addOperationWithBlock:^{
                        [self dispatchEvent:logStreamEvent];
                    }];
                }
            }
        }
    }
    else
    {
        // Partial event (no \n\n in received data) so preserve it in the connexion
        // so it's ready to be added to the next chunk of data

        [connexion.data appendData:data];
    }

#ifdef DEBUG
    //double timePassed_ms = [date timeIntervalSinceNow] * -1000.0;
    //NSLog(@"parseStreamLog duration: %f milliseconds", timePassed_ms);
#endif
}



- (NSDictionary *)processConnection:(Connexion *)connexion
{
    // Process the data returned by the current connection
    // This may include an API error, so this is where we do the main impCentral API error
    // handling, eg. for code compilation errors

    id parsedData = nil;
    NSError *dataDecodeError = nil;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    if (connexion.data != nil && connexion.data.length > 0)
    {
        // If we have received data, so attempt to decode it assuming that it is JSON
        // If it's not JSON, 'dataDecodeError' will not be nil

        parsedData = [NSJSONSerialization JSONObjectWithData:connexion.data options:kNilOptions error:&dataDecodeError];
    }

    if (dataDecodeError != nil)
    {
        // If the incoming data could not be decoded to JSON for some reason,
        // most likely a malformed request which returns a block of HTML

        errorMessage = [NSString stringWithFormat:@"[SERVER ERROR] Received data could not be decoded: %@", (NSString *)connexion.data];
        [self reportError];

        connexion.errorCode = -1;
        connexion.actionCode = kConnectTypeNone;
    }

    if (connexion.errorCode > 399)
    {
        // Trap and handle impCentral API errors here
        // NOTE The value of 'errorCode' is the returned HTTP status code

        errorMessage = @"";

        if (parsedData != nil)
        {
            // 'parsedData' should contain an array of errors, eg. unknown device, or a code syntax error

            NSUInteger count = 0;
            NSMutableArray *codeErrors = [[NSMutableArray alloc] init];

            // Get the array of error messages from the returned data

            NSArray *errors = [parsedData objectForKey:@"errors"];

            // Trap 'old' errors and those not related to the API

            if (errors == nil)
            {
                NSString *message = [parsedData objectForKey:@"message"];
                errorMessage = [errorMessage stringByAppendingString:message];
            }
            else
            {
                // Run through the array elements and decode each in turn

                for (NSDictionary *error in errors)
                {
                    NSString *internalErrCode = [error objectForKey:@"code"];

                    if ([internalErrCode compare:@"CX005"] == NSOrderedSame)
                    {
                        // We have compilation errors.
                        // The 'meta' field contains all the details so add them to the 'codeErrors' array

                        [codeErrors addObject:[error objectForKey:@"meta"]];
                    }
                    else
                    {
						// Process other API errors
						
						NSDictionary *errorPlus;
						NSMutableDictionary *ed = [NSMutableDictionary dictionaryWithDictionary:error];
						NSString *action = @"N/A";
						
						if (connexion.representedObject != nil)
						{
							NSString *act = [connexion.representedObject objectForKey:@"action"];
							
							if (act != nil) action = act;
						}
						
						[ed setObject:action forKey:@"action"];
						errorPlus = [NSDictionary dictionaryWithObjects:[ed allValues] forKeys:[ed allKeys]];
						
						errorMessage = errors.count > 1
                        ? [errorMessage stringByAppendingFormat:@"%li. %@\n", (count + 1), [self processAPIError:errorPlus]]
                        : [self processAPIError:errorPlus];
                    }

                    ++count;
                }

                // Check if there were any code compilation errors and if so, relay them to the host

                if (codeErrors.count > 0)
                {
                    NSDictionary *returnData;

                    if (connexion.representedObject != nil)
                    {
                        returnData = @{ @"data" : codeErrors,
                                        @"object" : connexion.representedObject };
                    }
                    else
                    {
                        returnData = @{ @"data" : codeErrors };
                    }

                    [nc postNotificationName:@"BuildAPICodeErrors" object:returnData];

                    errorMessage = nil;
                }
            }
        }
        else
        {
            // We have no data payload so we can't say what the error was

            errorMessage = [errorMessage stringByAppendingString:@"Unknown error"];
        }

        // We've managed all the errors, so clear the returned data to avoid errors in subsequent
        // connection processing and clear the action code to avoid unnecessary checking later

        parsedData = nil;
        connexion.actionCode = kConnectTypeNone;

        // Report the error to the host if we have one (code compilation errors clear 'errorMessage')

        if (connexion.representedObject != nil)
		{
			NSDictionary *dict = connexion.representedObject;
			NSString *action = [dict objectForKey:@"action"];
			if (action != nil && action.length > 0) errorMessage = [errorMessage stringByAppendingFormat:@" (%@)", action];
		}

		if (errorMessage) [self reportError];
    }

    // Tidy up the connection list by removing the current connexion from the list of connexions

    [connexions removeObject:connexion];

    numberOfConnections = connexions.count;

    // Signal the host app if the number of connections is zero

    if (connexions.count == 0) [nc postNotificationName:@"BuildAPIProgressStop" object:nil];

    // Return the decoded data (or nil)

    return parsedData;
}



- (void)processResult:(Connexion *)connexion :(NSDictionary *)data
{
    // If there has been no error recorded, we can now process the real data returned by the server
    // according to the type of connection that was originally initiated

    // The object we return as the notification's object is structured as follows:
    //
    // "object" - The object passed into the BuildAPIAccess instance from the host,
    //            eg. the devicegroup that is being restarted.
    //   "data" - The data retrieved from the server, eg. the updated product, or
    //            a useful message string (in cases where these is no returned data)

    // Avoid processing the connection if it has no action code

    if (connexion.actionCode == kConnectTypeNone) return;

    NSDictionary *returnData;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    switch (connexion.actionCode)
    {
        case kConnectTypeGetProducts:
        {
            // The server returns an array of one or more products, which we add to an
            // emptied master array. The list is returned one page at a time, so we need
            // to check for the supplied URL of the next page in sequence

            NSDictionary *links = [data objectForKey:@"links"];
            NSString *nextURL = [self getNextURL:[self nextPageLink:links]];
            BOOL isFirstPage = [self isFirstPage:links];

            // Only clear the products list if this is the first page

            if (isFirstPage) [products removeAllObjects];

            // Add the received page of product records to the array

            NSArray *productList = [data objectForKey:@"data"];

            if (products == nil) products = [[NSMutableArray alloc] init];

            for (NSMutableDictionary *product in productList) [products addObject:product];

            // Are there more pages yet to be received?

            if (nextURL.length != 0)
            {
                // We found a 'next' field in the 'links' list. This will get us the next page of data
                // which we do by making a new request using the provided 'next' link

                NSMutableURLRequest *request = [self makeGETrequest:nextURL :NO];

                if (request)
                {
                    [self launchConnection:request :kConnectTypeGetProducts :connexion.representedObject];
                    break;
                }
                else
                {
                    errorMessage = @"Could not create a request to list all of your products — the list may be incomplete.";
                    [self reportError];
                }
            }

            // Send the array of products to the host

            returnData = connexion.representedObject != nil
            ? @{ @"data" : products, @"object" : connexion.representedObject }
            : @{ @"data" : products };

            [nc postNotificationName:@"BuildAPIGotProductsList" object:returnData];
            break;
        }

        case kConnectTypeCreateProduct:
        {
            // The server returns a record of the created product

            data = [data objectForKey:@"data"];

            returnData = connexion.representedObject != nil
            ? @{ @"data" : data, @"object" : connexion.representedObject }
            : @{ @"data" : data };

            [nc postNotificationName:@"BuildAPIProductCreated" object:returnData];
            break;
        }

        case kConnectTypeUpdateProduct:
        {
            // The server returns a record of the updated product

            data = [data objectForKey:@"data"];

            returnData = connexion.representedObject != nil
            ? @{ @"data" : data, @"object" : connexion.representedObject }
            : @{ @"data" : data };

            [nc postNotificationName:@"BuildAPIProductUpdated" object:returnData];
            break;
        }

        case kConnectTypeDeleteProduct:
        {
            // The server returns no data

            returnData = connexion.representedObject != nil
            ? @{ @"data" : @"deleted", @"object" : connexion.representedObject }
            : @{ @"data" : @"deleted" };

            [nc postNotificationName:@"BuildAPIProductDeleted" object:returnData];
            break;
        }

        case kConnectTypeGetProduct:
        {
            // The server returns a single product's record
            // NOTE Single items are sent by the API as objects, not as single-entry arrays

            NSDictionary *product = [data objectForKey:@"data"];

            returnData = connexion.representedObject != nil
            ? @{ @"data" : product, @"object" : connexion.representedObject }
            : @{ @"data" : product };

            [nc postNotificationName:@"BuildAPIGotProduct" object:returnData];
            break;
        }

        case kConnectTypeGetDeviceGroups:
        {
            // The server returns an array of one or more device groups, which we add to an
            // emptied master array. The list is returned one page at a time, so we need
            // to check for the supplied URL of the next page in sequence

            NSDictionary *links = [data objectForKey:@"links"];
            NSString *nextURL = [self getNextURL:[self nextPageLink:links]];
            BOOL isFirstPage = [self isFirstPage:links];

            if (isFirstPage) [devicegroups removeAllObjects];

            NSArray *devicegroupList = [data objectForKey:@"data"];

            if (devicegroups == nil) devicegroups = [[NSMutableArray alloc] init];

            for (NSDictionary *devicegroup in devicegroupList) [devicegroups addObject:devicegroup];

            if (nextURL.length != 0)
            {
                NSMutableURLRequest *request = [self makeGETrequest:nextURL :YES];

                if (request)
                {
                    [self launchConnection:request :kConnectTypeGetDeviceGroups :connexion.representedObject];
                    break;
                }
                else
                {
                    errorMessage = @"Could not create a request to list all of your device groups — the list may be incomplete.";
                    [self reportError];
                }
            }

            returnData = connexion.representedObject != nil
            ? @{ @"data" : devicegroups, @"object" : connexion.representedObject }
            : @{ @"data" : devicegroups };

            [nc postNotificationName:@"BuildAPIGotDeviceGroupsList" object:returnData];
            break;
        }

        case kConnectTypeCreateDeviceGroup:
        {
            // The server returns a record of the created device group

            data = [data objectForKey:@"data"];

            returnData = connexion.representedObject != nil
            ? @{ @"data" : data, @"object" : connexion.representedObject }
            : @{ @"data" : data };

            [nc postNotificationName:@"BuildAPIDeviceGroupCreated" object:returnData];
            break;
        }

        case kConnectTypeUpdateDeviceGroup:
        {
            // The server returns a record of the updated device group

            data = [data objectForKey:@"data"];

            returnData = connexion.representedObject != nil
            ? @{ @"data" : data, @"object" : connexion.representedObject }
            : @{ @"data" : data };

            [nc postNotificationName:@"BuildAPIDeviceGroupUpdated" object:returnData];
            break;
        }

        case kConnectTypeDeleteDeviceGroup:
        {
            // The server returns no data

            returnData = connexion.representedObject != nil
            ? @{ @"object" : connexion.representedObject }
            : nil;

            [nc postNotificationName:@"BuildAPIDeviceGroupDeleted" object:returnData];
            break;
        }

        case kConnectTypeGetDeviceGroup:
        {
            // The server returns a record of the single device group

            NSDictionary *dg = [data objectForKey:@"data"];

            returnData = connexion.representedObject != nil
            ? @{ @"data" : dg, @"object" : connexion.representedObject }
            : @{ @"data" : dg };

            [nc postNotificationName:@"BuildAPIGotDevicegroup" object:returnData];
            break;
        }

        case kConnectTypeRestartDevices:
        {
            // The server returns no data

            returnData = connexion.representedObject != nil
            ? @{ @"data" : @"restarted", @"object" : connexion.representedObject }
            : @{ @"data" : @"restarted" };

            [nc postNotificationName:@"BuildAPIDeviceGroupRestarted" object:returnData];
            break;
        }

        case kConnectTypeGetDeployments:
        {
            // The server returns an array of one or more deployments, which we add to an
            // emptied master array. The list is returned one page at a time, so we need
            // to check for the supplied URL of the next page in sequence

            NSDictionary *links = [data objectForKey:@"links"];
            NSString *nextURL = [self getNextURL:[self nextPageLink:links]];
            BOOL isFirstPage = [self isFirstPage:links];

            if (isFirstPage) [deployments removeAllObjects];

            NSArray *deploymentList = [data objectForKey:@"data"];

            if (deployments == nil) deployments = [[NSMutableArray alloc] init];

            for (NSMutableDictionary *deployment in deploymentList) [deployments addObject:deployment];

            if (nextURL.length != 0 && deployments.count < maxListCount)
            {
                NSMutableURLRequest *request = [self makeGETrequest:nextURL :YES];

                if (request)
                {
                    [self launchConnection:request :kConnectTypeGetDeployments :connexion.representedObject];
                    break;
                }
                else
                {
                    errorMessage = @"Could not create a request to list all of your deployments — the list may be incomplete.";
                    [self reportError];
                }
            }

            returnData = connexion.representedObject != nil
            ? @{ @"data" : deployments, @"object" : connexion.representedObject }
            : @{ @"data" : deployments };

            [nc postNotificationName:@"BuildAPIGotDeploymentsList" object:returnData];
            break;
        }

        case kConnectTypeCreateDeployment:
        {
            // The server returns a record of the created deployment

            data = [data objectForKey:@"data"];

            returnData = connexion.representedObject != nil
            ? @{ @"data" : data, @"object" : connexion.representedObject }
            : @{ @"data" : data };

            [nc postNotificationName:@"BuildAPIDeploymentCreated" object:returnData];
            break;
        }

        case kConnectTypeUpdateDeployment:
        {
            // The server returns a record of the updated deployment

            data = [data objectForKey:@"data"];

            returnData = connexion.representedObject != nil
            ? @{ @"data" : data, @"object" : connexion.representedObject }
            : @{ @"data" : data };

            [nc postNotificationName:@"BuildAPIDeploymentUpdated" object:returnData];
            break;
        }

        case kConnectTypeDeleteDeployment:
        {
            // The server returns no data

            returnData = connexion.representedObject != nil
            ? @{ @"data" : @"deleted", @"object" : connexion.representedObject }
            : @{ @"data" : @"deleted" };

            [nc postNotificationName:@"BuildAPIDeploymentDeleted" object:returnData];
            break;
        }

        case kConnectTypeGetDeployment:
        {
            // The server returns a record of the single deployment

            NSDictionary *dp = [data objectForKey:@"data"];

            returnData = connexion.representedObject != nil
            ?  @{ @"data" : dp, @"object" : connexion.representedObject }
            : @{ @"data" : dp };

            [nc postNotificationName:@"BuildAPIGotDeployment" object:returnData];
            break;
        }

        case kConnectTypeSetMinDeployment:
        {
            // The server returns a record of the single deployment

            NSDictionary *dp = [data objectForKey:@"data"];

            returnData = connexion.representedObject != nil
            ?  @{ @"data" : dp, @"object" : connexion.representedObject }
            : @{ @"data" : dp };

            [nc postNotificationName:@"BuildAPISetMinDeployment" object:returnData];
            break;
        }

        case kConnectTypeGetDevices:
        {
            // The server returns an array of one or more devices, which we add to an
            // emptied master array. The list is returned one page at a time, so we need
            // to check for the supplied URL of the next page in sequence

            NSDictionary *links = [data objectForKey:@"links"];
            NSString *nextURL = [self getNextURL:[self nextPageLink:links]];
            BOOL isFirstPage = [self isFirstPage:links];

            if (isFirstPage) [devices removeAllObjects];

            NSArray *deviceList = [data objectForKey:@"data"];

            if (devices == nil) devices = [[NSMutableArray alloc] init];

            for (NSDictionary *device in deviceList) [devices addObject:device];

            if (nextURL.length != 0)
            {
                NSMutableURLRequest *request = [self makeGETrequest:nextURL :YES];

                if (request)
                {
                    [self launchConnection:request :kConnectTypeGetDevices :connexion.representedObject];
                    break;
                }
                else
                {
                    errorMessage = @"Could not create a request to list all of your devices — the list may be incomplete.";
                    [self reportError];
                }
            }

            returnData = connexion.representedObject != nil
            ? @{ @"data" : devices, @"object" : connexion.representedObject }
            : @{ @"data" : devices };

            [nc postNotificationName:@"BuildAPIGotDevicesList" object:returnData];
            break;
        }

        case kConnectTypeUpdateDevice:
        {
            // The server returns a record of the updated device

            data = [data objectForKey:@"data"];

            returnData = connexion.representedObject != nil
            ? @{ @"data" : data, @"object" : connexion.representedObject }
            : @{ @"data" : data };

            [nc postNotificationName:@"BuildAPIDeviceUpdated" object:returnData];
            break;
        }

        case kConnectTypeDeleteDevice:
        {
            // The server returns no data

            returnData = connexion.representedObject != nil
            ? @{ @"data" : @"deleted", @"object" : connexion.representedObject }
            : @{ @"data" : @"deleted" };

            [nc postNotificationName:@"BuildAPIDeviceDeleted" object:returnData];
            break;
        }

        case kConnectTypeAssignDevice:
        {
            // The server returns no data

            returnData = connexion.representedObject != nil
            ? @{ @"data" : @"assigned", @"object" : connexion.representedObject }
            : @{ @"data" : @"assigned" };

            [nc postNotificationName:@"BuildAPIDeviceAssigned" object:returnData];
            break;
        }

        case kConnectTypeAssignDevices:
        {
            // The server returns no data

            returnData = connexion.representedObject != nil
            ? @{ @"data" : @"assigned", @"object" : connexion.representedObject }
            : @{ @"data" : @"assigned" };

            [nc postNotificationName:@"BuildAPIDevicesAssigned" object:returnData];
            break;
        }

        case kConnectTypeUnassignDevice:
        {
            // The server returns no data

            returnData = connexion.representedObject != nil
            ? @{ @"data" : @"unassigned", @"object" : connexion.representedObject }
            : @{ @"data" : @"unassigned" };

            [nc postNotificationName:@"BuildAPIDeviceUnassigned" object:returnData];
            break;
        }

        case kConnectTypeUnassignDevices:
        {
            // The server returns no data

            returnData = connexion.representedObject != nil
            ? @{ @"data" : @"unassigned", @"object" : connexion.representedObject }
            : @{ @"data" : @"unassigned" };

            [nc postNotificationName:@"BuildAPIDevicesUnassigned" object:returnData];
            break;
        }

        case kConnectTypeRestartDevice:
        {
            // The server returns no data

            returnData = connexion.representedObject != nil
            ? @{ @"data" : @"restarted", @"object" : connexion.representedObject }
            : @{ @"data" : @"restarted" };

            [nc postNotificationName:@"BuildAPIDeviceRestarted" object:returnData];
            break;
        }

        case kConnectTypeGetDevice:
        {
            // The server returns a record of the single deployment

            NSDictionary *device = [data objectForKey:@"data"];

            returnData = connexion.representedObject != nil
            ? @{ @"data" : device, @"object" : connexion.representedObject }
            : @{ @"data" : device };

            [nc postNotificationName:@"BuildAPIGotDevice" object:returnData];
            break;
        }

        case kConnectTypeGetDeviceLogs:
        {
            // The server returns an array of one or more log entries, which we add to an
            // emptied master array. The list is returned one page at a time, so we need
            // to check for the supplied URL of the next page in sequence

            NSDictionary *links = [data objectForKey:@"links"];
            NSString *nextURL = [self getNextURL:[self nextPageLink:links]];
            BOOL isFirstPage = [self isFirstPage:links];

            if (logs == nil) logs = [[NSMutableArray alloc] init];

            if (isFirstPage && logs.count > 0) [logs removeAllObjects];

            NSArray *batch = [data objectForKey:@"data"];

            for (NSDictionary *entry in batch) [logs addObject:entry];

            if (nextURL.length != 0 && logs.count < maxListCount)
            {
                NSMutableURLRequest *request = [self makeGETrequest:nextURL :YES];

                if (request)
                {
                    [self launchConnection:request :kConnectTypeGetDeviceLogs :connexion.representedObject];
                    break;
                }
                else
                {
                    errorMessage = @"Could not create a request to list all of a device's log entries — the list may be incomplete.";
                    [self reportError];
                }
            }

            NSDictionary *dict = connexion.representedObject != nil
            ? @{ @"data" : logs, @"count" : [NSNumber numberWithInteger:logs.count], @"object" : connexion.representedObject }
            : @{ @"data" : logs, @"count" : [NSNumber numberWithInteger:logs.count] };

            [nc postNotificationName:@"BuildAPIGotLogs" object:dict];
            break;
        }

        case kConnectTypeGetDeviceHistory:
        {
            // The server returns an array of one or more log entries, which we add to an
            // emptied master array. The list is returned one page at a time, so we need
            // to check for the supplied URL of the next page in sequence

            NSDictionary *links = [data objectForKey:@"links"];
            NSString *nextURL = [self getNextURL:[self nextPageLink:links]];
            BOOL isFirstPage = [self isFirstPage:links];

            if (history == nil) history = [[NSMutableArray alloc] init];

            if (isFirstPage && history.count > 0) [history removeAllObjects];

            NSArray *batch = [data objectForKey:@"data"];

            for (NSDictionary *entry in batch) [history addObject:entry];

            if (nextURL.length != 0 && history.count < maxListCount)
            {
                // There is at least one more page of data, so go and get it

                NSMutableURLRequest *request = [self makeGETrequest:nextURL :YES];

                if (request)
                {
                    [self launchConnection:request :kConnectTypeGetDeviceHistory :connexion.representedObject];
                    break;
                }
                else
                {
                    errorMessage = @"Could not create a request to list all of a device's history — the list may be incomplete.";
                    [self reportError];
                }
            }

            NSDictionary *dict = connexion.representedObject != nil
            ? @{ @"data" : history, @"object" : connexion.representedObject }
            : @{ @"data" : history };

            [nc postNotificationName:@"BuildAPIGotHistory" object:dict];
            break;
        }


        case kConnectTypeGetAccessToken:
        {
            // The server returns the requested access token directly

            if ((connexion.errorCode == 403) && useTwoFactor)
            {
                // We are using 2FA and the initial contact has resulted in a login token which we need to
                // hand back now to the host app

                NSString *lt = [data objectForKey:@"login_token"];

                NSDictionary *dict = connexion.representedObject != nil
                ? @{ @"action" : @"needotp", @"token" : lt, @"object" : connexion.representedObject }
                : @{ @"action" : @"needotp", @"token" : lt };

                [nc postNotificationName:@"BuildAPINeedOTP" object:dict];
                break;
            }

            if (token == nil) token = [[Token alloc] init];
            token.accessToken = [data valueForKey:@"access_token"];
            token.expiryDate = [data valueForKey:@"expires_at"];
            token.refreshToken = [data valueForKey:@"refresh_token"];
			NSNumber *n = [data valueForKey:@"expires_in"];
			token.lifetime = n.integerValue;
			isLoggedIn = YES;
            tokenConnexion = nil;

            // TODO check that we actually have the data we require

#ifdef DEBUG
    NSLog(@"Initial Token: %@", token.accessToken);
    NSLog(@"      Expires: %@", token.expiryDate);
    NSLog(@"   Expires in: %li", (long)token.lifetime);
#endif

            // Get user's account information before we do anything else

            [self getMyAccount];

            // Do we have any pending connections we need to process?
            // NOTE 'launchPendingConnections' returns immediately if there are no pending connections

            [self launchPendingConnections];

            NSDictionary *dict = connexion.representedObject != nil
            ? @{ @"action" : @"loggedin", @"object" : connexion.representedObject }
            : @{ @"action" : @"loggedin" };

            [nc postNotificationName:@"BuildAPILoggedIn" object:dict];
            break;
        }

        case kConnectTypeRefreshAccessToken:
        {
            // The server returns the requested access token directly

            token.accessToken = [data valueForKey:@"access_token"];
            token.expiryDate = [data valueForKey:@"expires_at"];
			NSNumber *n = [data valueForKey:@"expires_in"];
			token.lifetime = n.integerValue;
            tokenConnexion = nil;

#ifdef DEBUG
    NSLog(@"Refreshed Token: %@", token.accessToken);
    NSLog(@"        Expires: %@", token.expiryDate);
NSLog(@"   Expires in: %li", (long)token.lifetime);
#endif

            // Do we have any pending connections we need to process?
            // NOTE 'launchPendingConnections' returns immediately if there are no pending connections

            [self launchPendingConnections];

            break;
        }

        case kConnectTypeGetMyAccount:
        {
            // The server returns the user's own account information

            data = [data objectForKey:@"data"];

            me = @{ @"type" : @"account",
                    @"id" : [data objectForKey:@"id"] };

#ifdef DEBUG
    NSLog(@"My Account ID: %@", [me objectForKey:@"id"]);
#endif

            break;
        }

        case kConnectTypeGetLogStreamID:
        {
            // We've got the stream ID so we are ready to activate the log stream
            // NOTE no devices have yet been subscribed - this happens after connection

            data = [data objectForKey:@"data"];
            logStreamID = [data objectForKey:@"id"];
			
#ifdef DEBUG
			NSLog(@"Log Stream ID received: %@", logStreamID);
#endif

            NSDictionary *attributes = [data objectForKey:@"attributes"];
            logStreamURL = [NSURL URLWithString:[attributes objectForKey:@"url"]];

            // Preserve the first device's ID for use later

            deviceToStream = [connexion.representedObject objectForKey:@"device"];

            // Set up the log stream

            [self startStream:logStreamURL];

            break;
        }

        case kConnectTypeStreamActive:
        {
            break;
        }

        case kConnectTypeAddLogStream:
        {
            // We have added a device to the log stream

            if (connexion.representedObject != nil)
            {
                id source = [connexion.representedObject objectForKey:@"object"];
                NSString *devid = [connexion.representedObject objectForKey:@"device"];

                NSDictionary *dict = source != nil
                ? @{ @"device" : devid, @"object" : source }
                : @{ @"device" : devid };

                [loggingDevices addObject:devid];

                numberOfLogStreams = loggingDevices.count;

                [nc postNotificationName:@"BuildAPIDeviceAddedToStream" object:dict];
            }

            break;
        }

        case kConnectTypeEndLogStream:
        {
            if (connexion.representedObject != nil)
            {
                id source = [connexion.representedObject objectForKey:@"object"];
                NSString *devid = [connexion.representedObject objectForKey:@"device"];

                NSDictionary *dict = source != nil
                ? @{ @"device" : devid, @"object" : source }
                : @{ @"device" : devid };

                [loggingDevices removeObject:devid];

                numberOfLogStreams = loggingDevices.count;

                if (loggingDevices.count == 0) [self closeStream];

                [nc postNotificationName:@"BuildAPIDeviceRemovedFromStream" object:dict];
            }

            break;
        }
    }
}



#pragma mark - Utility Methods


- (void)reportError
{
    [self reportError:-1];
}



- (void)reportError:(NSInteger)errCode
{
    // Signal the host app that we have an error message for it to display (in 'errorMessage')

    NSDictionary *error;
    NSString *message = errorMessage;

    error = errCode == -1
    ? @{ @"message" : message }
    : @{ @"message" : message,
         @"code" : [NSNumber numberWithInteger:errCode] };

    [[NSNotificationCenter defaultCenter] postNotificationName:@"BuildAPIError" object:error];
}



- (NSString *)processAPIError:(NSDictionary *)error
{
    // Parses an impCentral API error for relay to the host app

    NSArray *types = @[ @"VX", @"Validation Error", @"CX", @"Contraint Error", @"NF", @"Resource Not Found",
                        @"PX", @"Permissions Error", @"XX", @"Internal Error",  @"WA", @"Warning"];

    NSString *code = [error valueForKey:@"code"];
    NSString *status = [error valueForKey:@"status"];
    NSString *message = [error valueForKey:@"detail"];
	NSString *action = [error valueForKey:@"action"];
    NSString *prefix = [code substringToIndex:2];
    NSUInteger index = 99;

    for (NSUInteger i = 0; i < types.count; i += 2)
    {
        NSString *aPrefix = [types objectAtIndex:i];

        if ([aPrefix compare:prefix] == NSOrderedSame)
        {
            index = i + 1;
            break;
        }
    }

    prefix = index != 99 ? [types objectAtIndex:index] : @"Unknown";
	return [NSString stringWithFormat:@"[API %@] %@ (%@) Action: %@", prefix, message, status, action];
}



- (BOOL)checkFilter:(NSString *)filter :(NSArray *)validFilters
{
    // Compares the passed value of 'filter' to a list of possible filters,
    // passed into 'validFilters', and returns YES or NO according to whether
    // the filter is on the list. Not on the list? You don't get in

    BOOL filterIsOK = NO;

    for (NSString *aFilter in validFilters)
    {
        if ([aFilter compare:filter] == NSOrderedSame)
        {
            filterIsOK = YES;
            break;
        }
    }

    return filterIsOK;
}



#pragma mark - Base64 Methods


- (NSString *)encodeBase64String:(NSString *)plainString
{
    NSData *data = [plainString dataUsingEncoding:NSUTF8StringEncoding];
    return [data base64EncodedStringWithOptions:0];
}



- (NSString *)decodeBase64String:(NSString *)base64String
{
    NSData *data = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}





@end
