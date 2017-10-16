
//  Copyright (c) 2015-17 Tony Smith. All rights reserved.
//  Issued under the MIT licence

//  BuildAPIAccess 3.0.0


#ifndef BuildAPIContants_h
#define BuildAPIContants_h

// Build API Access Version

#define kBuildAPIAccessVersion @"3.0.0"

// Connection Types / Actions

#define kConnectTypeNone					0

#define kConnectTypeGetProducts				10
#define kConnectTypeCreateProduct			11
#define kConnectTypeUpdateProduct			12
#define kConnectTypeDeleteProduct			13
#define kConnectTypeGetProduct				14

#define kConnectTypeGetDeviceGroups			20
#define kConnectTypeCreateDeviceGroup		21
#define kConnectTypeUpdateDeviceGroup		22
#define kConnectTypeDeleteDeviceGroup		23
#define kConnectTypeGetDeviceGroup			24
#define kConnectTypeRestartDevices			25

#define kConnectTypeGetDeployments			30
#define kConnectTypeCreateDeployment		31
#define kConnectTypeUpdateDeployment		32
#define kConnectTypeDeleteDeployment		33
#define kConnectTypeGetDeployment			34

#define kConnectTypeGetDevices              40
#define kConnectTypeUpdateDevice			41
#define kConnectTypeDeleteDevice			42
#define kConnectTypeAssignDevice			43
#define kConnectTypeUnassignDevice			44
#define kConnectTypeRestartDevice			45
#define kConnectTypeGetDevice				46
#define kConnectTypeGetDeviceLogs			48
#define kConnectTypeGetDeviceHistory		49

#define kConnectTypeGetWebhooks				50
#define kConnectTypeCreateWebhook			51
#define kConnectTypeUpdateWebhook			52
#define kConnectTypeDeleteWebhook			53
#define kConnectTypeGetWebhook				54

#define kConnectTypeGetToken				80
#define kConnectTypeRefreshToken			81
#define kConnectTypeGetMyAccount			82
#define kConnectTypeGetLogStreamID			83
#define kConnectTypeStreamActive			84
#define kConnectTypeAddLogStream			85
#define kConnectTypeEndLogStream			86

// impCentral URL, version

#define kBaseAPIURL							@"https://api.electricimp.com"
#define kAPIVersion							@"/v5/"
// @"https://preview-api.electricimp.com"

// Logging

#define kConnectTypeLogStream				99
#define kMaxHistoricalLogs					200

// Pagination

#define kPaginationDefault					20

// Errors

#define kErrorNoError						0
#define kErrorNetworkError					1

#define kErrorLoginSuccess					10
#define kErrorLoginNoUsername				11
#define kErrorLoginNoPassword				12
#define kErrorLoginNoCredentials			13
#define kErrorLoginRejectCredentials		14


#endif



#ifndef LogStreamContants_h
#define LogStreamContants_h

// Data delimiters

#define kLogStreamKeyValueDelimiter				@":"
#define kLogStreamEventSeparatorLFLF			@"\n\n"
#define kLogStreamEventSeparatorCRCR			@"\r\r"
#define kLogStreamEventSeparatorCRLFCRLF		@"\r\n\r\n"
#define kLogStreamEventKeyValuePairSeparator	@"\n"

// Event keys

#define kLogStreamEventDataKey					@"data"
#define kLogStreamEventIDKey					@"id"
#define kLogStreamEventEventKey					@"event"
#define kLogStreamEventRetryKey					@"retry"

// Event types

#define kLogStreamEventStateChange				1
#define kLogStreamEventConnectionOpen			2
#define kLogStreamEventMessage					3
#define	kLogStreamEventError					4

// Event States

#define kLogStreamEventStateConnecting			0
#define kLogStreamEventStateOpen				1
#define kLogStreamEventStateClosed				2

#endif
