//
//  CYPromptConfig.h
//  CYPromptProject
//
//  Created by yellowei on 2017/12/14.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CYPromptConfig : NSObject

/// default is UIEdgeInsetsMake( 8, 8, 8, 8 ).
@property (nonatomic, assign) UIEdgeInsets insets;

/// default is 8.
@property (nonatomic, assign) CGFloat cornerRadius;

/// default is black.
@property (nonatomic, strong) UIColor *backgroundColor;

/// default is systemFont( 14 ).
@property (nonatomic, assign) UIFont *font;

/// default is white.
@property (nonatomic, strong) UIColor *fontColor;

/// default is ( superview.width * 0.6 ).
@property (nonatomic, assign) CGFloat maxWidth;

- (void)reset;

@end

NS_ASSUME_NONNULL_END
