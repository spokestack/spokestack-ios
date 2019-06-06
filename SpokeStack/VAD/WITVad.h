//
//  WITVad.h
//  Wit
//
//  Created by Aric Lasry on 8/6/14.
//  Copyright (c) 2014 Willy Blandin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#import "WITCvad.h"

typedef void (^PrinterBlock)(NSString *);
@protocol WITVadDelegate;

@interface WITVad : NSObject

@property (nonatomic, weak) id<WITVadDelegate> delegate;

@property (nonatomic, assign, readonly) BOOL stoppedUsingVad;


- (void)vadSpeechFrame:(NSData *)samples;

@end


@protocol WITVadDelegate <NSObject>

-(void) activate:(NSData *)audioData;

-(void) deactivate;

@end
