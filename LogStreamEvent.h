
//  BuildAPIAccess
//  Copyright (c) 2017-18 Tony Smith. All rights reserved.
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

//  BuildAPIAccess 3.1.1


#import <Foundation/Foundation.h>
#import "BuildAPIAccessConstants.h"


@interface LogStreamEvent : NSObject


// Required by BuildAPI access class
// LogStreamEvent is simply a packaging object for Server-Sent Events (SSE)
// issued by the impCentral API's log-streaming system

// Properties

@property (nonatomic, strong) id        eid;        // Event ID
@property (nonatomic, strong) NSString  *event;     // Name of the Event
@property (nonatomic, strong) NSString  *data;      // Data received from the EventSource
@property (nonatomic, strong) NSError   *error;     // Errors with the connection to the source
@property (nonatomic, assign) NSInteger type;       // Current state of the connection to the source
@property (nonatomic, assign) NSInteger state;      // Current state of the connection to the source


@end
