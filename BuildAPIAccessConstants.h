
//  BuildAPIAccess 3.2.0
//  Copyright (c) 2015-19 Tony Smith. All rights reserved.
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



#ifndef BuildAPIContants_h
#define BuildAPIContants_h

// Build API Access Version


#define kBuildAPIAccessVersion                  @"3.2.0"

// Connection Types / Actions

#define kConnectTypeNone                        0

#define kConnectTypeGetProducts                 10
#define kConnectTypeCreateProduct               11
#define kConnectTypeUpdateProduct               12
#define kConnectTypeDeleteProduct               13
#define kConnectTypeGetProduct                  14

#define kConnectTypeGetDeviceGroups             20
#define kConnectTypeCreateDeviceGroup           21
#define kConnectTypeUpdateDeviceGroup           22
#define kConnectTypeDeleteDeviceGroup           23
#define kConnectTypeGetDeviceGroup              24
#define kConnectTypeRestartDevices              25

#define kConnectTypeGetDeployments              30
#define kConnectTypeCreateDeployment            31
#define kConnectTypeUpdateDeployment            32
#define kConnectTypeDeleteDeployment            33
#define kConnectTypeGetDeployment               34
#define kConnectTypeSetMinDeployment            35

#define kConnectTypeGetDevices                  40
#define kConnectTypeUpdateDevice                41
#define kConnectTypeDeleteDevice                42
#define kConnectTypeAssignDevice                43
#define kConnectTypeAssignDevices               44
#define kConnectTypeUnassignDevice              45
#define kConnectTypeUnassignDevices             46
#define kConnectTypeRestartDevice               47
#define kConnectTypeGetDevice                   48
#define kConnectTypeGetDeviceLogs               49
#define kConnectTypeGetDeviceHistory            50

#define kConnectTypeGetWebhooks                 60
#define kConnectTypeCreateWebhook               61
#define kConnectTypeUpdateWebhook               62
#define kConnectTypeDeleteWebhook               63
#define kConnectTypeGetWebhook                  64

#define kConnectTypeGetAccessToken              80
#define kConnectTypeRefreshAccessToken          81
#define kConnectTypeGetMyAccount                82
#define kConnectTypeGetAnAccount                83
#define kConnectTypeLogGetStreamID              84
#define kConnectTypeLogStreamActive             85
#define kConnectTypeLogStreamAdd                86
#define kConnectTypeLogStreamEnd                87

#define kConnectTypeGetLoginToken               90
#define kConnectTypeGetLibraries                91

// impCentral URL, version

#define kBaseAPIURL                             @"https://api.electricimp.com"
#define kAzureAPIURL                            @"https://api.az.electricimp.io"
#define kAPIVersion                             @"/v5/"

#define kImpCloudTypeAWS                        0
#define kImpCloudTypeAzure                      1

// Logging

#define kConnectTypeLogStream                   99
#define kMaxHistoricalLogs                      1000
#define kLogTimeout                             300.0
#define klogRetryInterval                       10.0
#define kLogMaxDevicesPerLog                    8

// Pagination

#define kPaginationDefault                      20

// Errors

#define kErrorNoError                           0
#define kErrorNetworkError                      1

#define kErrorLoginSuccess                      10
#define kErrorLoginNoUsername                   11
#define kErrorLoginNoPassword                   12
#define kErrorLoginNoCredentials                13
#define kErrorLoginRejectCredentials            14

#define kConnectTimeoutInterval                 120


#endif



#ifndef LogStreamContants_h
#define LogStreamContants_h

// Data delimiters

#define kLogStreamKeyValueDelimiter             @": "
#define kLogStreamEventSeparatorLFLF            @"\n\n"
#define kLogStreamEventSeparatorCRCR            @"\r\r"
#define kLogStreamEventSeparatorCRLFCRLF        @"\r\n\r\n"
#define kLogStreamEventKeyValuePairSeparator    @"\n"

// Event keys

#define kLogStreamEventDataKey                  @"data"
#define kLogStreamEventIDKey                    @"id"
#define kLogStreamEventEventKey                 @"event"
#define kLogStreamEventRetryKey                 @"retry"

// Event types

#define kLogStreamEventTypeNone                 0
#define kLogStreamEventTypeStateChange          1
#define kLogStreamEventTypeMessage              2
#define kLogStreamEventTypeError                3

// Event States

#define kLogStreamEventStateUnknown             0
#define kLogStreamEventStateConnecting          1
#define kLogStreamEventStateOpen                2
#define kLogStreamEventStateClosed              3
#define kLogStreamEventStateSubscribed          4
#define kLogStreamEventStateUnsubscribed        5


#endif
