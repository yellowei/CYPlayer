//
//  CYLoadingView.h
//  CYPlayer
//
//  Created by 黄威 on 2017/12/28.
//  Copyright © 2017年 黄威. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CYLoadingView : UIView

// default is whiteColor.
@property (nonatomic, strong, null_resettable) UIColor *lineColor;
// default is 1.
@property (nonatomic, assign) double speed;

@property (nonatomic, assign, readonly, getter=isAnimating) BOOL animating;

- (void)start;

- (void)stop;

@end
