
//  Copyright © 2017 Tony Smith. All rights reserved.
//  Issued under the MIT licence

//  BuildAPIAccess 3.0.0


#import <Foundation/Foundation.h>
#import "BuildAPIAccessConstants.h"


@interface LogStreamEvent : NSObject


// Required by BuildAPI access class
// LogStreamEvent is simply a packaging object for Server-Sent Event (SSE)
// events issued by the impCentral API's logging system


@property (nonatomic, strong) id eid;					// Event ID
@property (nonatomic, strong) NSString *event;			// Name of the Event
@property (nonatomic, strong) NSString *data;			// Data received from the EventSource
@property (nonatomic, assign) NSInteger type;			// Current state of the connection to the source
@property (nonatomic, assign) NSInteger state;			// Current state of the connection to the source
@property (nonatomic, strong) NSError *error;			// Errors with the connection to the source


@end
