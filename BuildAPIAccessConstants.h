
//  Copyright (c) 2015-16 Tony Smith. All rights reserved.
//  Issued under the MIT licence

// BuildAPIAccess 1.1.1


#ifndef BuildAPIContants_h
#define BuildAPIContants_h


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

#define kConnectTypeGetRevisions			99
#define kConnectTypeGetRevision				99
#define kConnectTypeLogin					100

#define kBaseAPIURL @"https://build.electricimp.com"
#define kAPIVersion @"/v4/"

#define kAllLogs 0
#define kStreamLogs -1

#define kServerSendsSuccess 1
#define kServerSendsFailure 0


#endif
