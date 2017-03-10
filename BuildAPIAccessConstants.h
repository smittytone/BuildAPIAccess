
//  Copyright (c) 2015-17 Tony Smith. All rights reserved.
//  Issued under the MIT licence

//  BuildAPIAccess 3.0.0


#ifndef BuildAPIContants_h
#define BuildAPIContants_h

#define kBuildAPIAccessVersion @"3.0.0"


#define kConnectTypeNone					0
#define kConnectTypeGetModels				1
#define kConnectTypeGetDevices				2
#define kConnectTypePostCode				3
#define kConnectTypeNewModel                4
#define kConnectTypeRestartDevice           5
#define kConnectTypeAssignDeviceToModel     6
#define kConnectTypeDeleteModel             7
#define kConnectTypeDeleteDevice            8
#define kConnectTypeUpdateDevice            9
#define kConnectTypeUpdateModel             10
#define kConnectTypeGetCodeLatestBuild      11
#define kConnectTypeGetCodeRev              12
#define kConnectTypeGetLogEntries           13
#define kConnectTypeGetLogEntriesRanged		14
#define kConnectTypeGetLogEntriesStreamed   15

#define kConnectTypeGetProducts				20
#define kConnectTypeCreateProduct			21
#define kConnectTypeUpdateProduct			22

#define kConnectTypeGetDeviceGroups			30
#define kConnectTypeCreateDeviceGroup		31
#define kConnectTypeUpdateDeviceGroup		32

#define kConnectTypeGetDeployments			40
#define kConnectTypeGetDeployment			41

#define kConnectTypeGetDevices              50

#define kConnectTypeGetToken				60
#define kConnectTypeGetMyAccount			61

#define kConnectTypeGetRevisions			99
#define kConnectTypeGetRevision				99
#define kConnectTypeLogin					100


#define kBaseAPIURL @"https://api.ei.run" //@"https://api.electricimp.com"
#define kAPIVersion @"/v5/"


#define kAllLogs 0
#define kStreamLogs -1
#define kStreamTimeout 300


#define kServerSendsSuccess 1
#define kServerSendsFailure 0

#define kPaginationDefault	20

#define kDeviceGroupTypeDevelopment		1
#define kDeviceGroupTypeFactory			2
#define kDeviceGroupTypeProduction		3

#endif
