//
//  CYVideoPlayerControlMaskView.h
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/9/25.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, CYMaskStyle) {
    CYMaskStyle_bottom,
    CYMaskStyle_top,
};

@interface CYVideoPlayerControlMaskView : UIView

- (instancetype)initWithStyle:(CYMaskStyle)style;

@end

NS_ASSUME_NONNULL_END
