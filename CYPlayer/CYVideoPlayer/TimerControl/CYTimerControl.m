//
//  CYTimerControl.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/12/6.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYTimerControl.h"

@interface CYTimerControl ()

@property (nonatomic, copy, readwrite) void(^block)(CYTimerControl *control);

@end

@implementation CYTimerControl

- (instancetype)init {
    self = [super init];
    if ( self ) {
        _interval = 3.0;
    }
    return self;
}

- (void)_exeBlock {
    if ( _block ) _block(self);
    _block = nil;
}

- (void)start:(void(^)(CYTimerControl *control))block {
    _block = block;
    [self performSelector:@selector(_exeBlock) withObject:nil afterDelay:_interval];
}

- (void)reset {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_exeBlock) object:nil];
}

@end
