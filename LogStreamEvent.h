

//  Created by Tony Smith on 22/05/2017.
//  Copyright © 2017 Tony Smith. All rights reserved.


#import <Foundation/Foundation.h>

@interface LogStreamEvent : NSObject


@property (nonatomic, strong) id eid;					// Event ID
@property (nonatomic, strong) NSString *event;			// Name of the Event
@property (nonatomic, strong) NSString *data;			// Data received from the EventSource
@property (nonatomic, assign) NSInteger readyState;		// Current state of the connection to the source
@property (nonatomic, strong) NSError *error;			// Errors with the connection to the source


@end
