/*
 
 Copyright (c) 2013 Max Lungarella <cybrmx@gmail.com>
 
 Created on 11/08/2013.
 
 This file is part of AmiKoDesitin.
 
 AmiKoDesitin is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program. If not, see <http://www.gnu.org/licenses/>.
 
 ------------------------------------------------------------------------ */

#import "MLSearchWebView.h"

@implementation WKWebView (MLSearchWebView)

- (NSInteger) highlightAllOccurencesOfString: (NSString*)str
{
#ifdef DEBUG
    NSLog(@"%s line %d", __FUNCTION__, __LINE__);
#endif
    // Load JavaScript file
    NSError *error;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"MLSearchWebView" ofType:@"js"];
    NSString *jsCode = [NSString stringWithContentsOfFile:path
                                                 encoding:NSUTF8StringEncoding
                                                    error:&error];
    if (error)
        NSLog(@"%@", error.localizedDescription);

    // Inject it into webpage
    [self evaluateJavaScript:jsCode
           completionHandler:^(NSString* result, NSError *error) {
        if (error)
            NSLog(@"%s line %d, %@", __FUNCTION__, __LINE__, error.localizedDescription);
    }];
    
    // Call Javascript function
    dispatch_semaphore_t sema1 = dispatch_semaphore_create(0);
    NSString *startSearch = [NSString stringWithFormat:@"MyApp_HighlightAllOccurencesOfString('%@')", str];
    [self evaluateJavaScript:startSearch
           completionHandler:^(NSString* result, NSError *error) {
        if (error)
            NSLog(@"%s line %d, %@", __FUNCTION__, __LINE__, error.localizedDescription);
        
        // This is NOT the main thread
        dispatch_semaphore_signal(sema1);
    }];
    
    // This is the main thread: cannot use DISPATCH_TIME_FOREVER
    while (dispatch_semaphore_wait(sema1, DISPATCH_TIME_NOW)) {  //  zero on success, or non-zero if the timeout occurred
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]]; }
    
    // Access variable defined in Javascript code
    __block NSString *result = @"0";
    dispatch_semaphore_t sema2 = dispatch_semaphore_create(0);
    [self evaluateJavaScript:@"MyApp_SearchResultCount"
           completionHandler:^(NSString* myResult, NSError *error) {
        if (error)
            NSLog(@"%s line %d, %@", __FUNCTION__, __LINE__, error.localizedDescription);
        else
            result = myResult;

        // This is NOT the main thread
        dispatch_semaphore_signal(sema2);
    }];

    // This is the main thread: cannot use DISPATCH_TIME_FOREVER
    while (dispatch_semaphore_wait(sema2, DISPATCH_TIME_NOW)) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]]; }

    return [result integerValue];
}

- (void) moveToStart
{
    [self nextHighlight:0];
}

- (void) nextHighlight:(int)index
{
    if (index<0)
        index = 0;
    
#ifdef DEBUG
    NSLog(@"%s line %d, index: %d", __FUNCTION__, __LINE__, index);
#endif
    NSString *scrollPosition = [NSString stringWithFormat:@"MyArr[%d].scrollIntoView()", index];
    [self evaluateJavaScript:scrollPosition
           completionHandler:^(NSString* result, NSError *error) {
        if (error)
            NSLog(@"%s line %d, %@", __FUNCTION__, __LINE__, error.localizedDescription);
    }];
}

- (void) removeAllHighlights
{
    [self evaluateJavaScript:@"MyApp_RemoveAllHighlights()"
           completionHandler:^(NSString* result, NSError *error) {
        if (error)
            NSLog(@"%s line %d, %@", __FUNCTION__, __LINE__, error.localizedDescription);
    }];
}

@end
