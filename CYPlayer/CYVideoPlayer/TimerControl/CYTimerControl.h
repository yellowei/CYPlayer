//
//  CYTimerControl.h
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/12/6.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CYTimerControl : NSObject

/// default is 3;
@property (nonatomic, assign, readwrite) float interval;

- (void)start:(void(^)(CYTimerControl *control))block;

- (void)reset;

@end

NS_ASSUME_NONNULL_END
