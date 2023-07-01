//
//  CYPrompt.h
//  CYPromptProject
//
//  Created by yellowei on 2017/9/26.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CYPromptConfig.h"

NS_ASSUME_NONNULL_BEGIN

@class UIView;

@interface CYPrompt : NSObject

+ (instancetype)promptWithPresentView:(__weak UIView *)presentView;

- (instancetype)initWithPresentView:(__weak UIView *)presentView;

/// update config.
@property (nonatomic, strong, readonly) void(^update)(void(^block)(CYPromptConfig *config));

/// reset config.
- (void)reset;

/*!
 *  duration if value set -1. promptView will always show.
 *
 *  duration 如果设置为 -1, 提示视图将会一直显示.
 */
- (void)showTitle:(NSString *)title duration:(NSTimeInterval)duration;

- (void)hidden;

@end

NS_ASSUME_NONNULL_END
