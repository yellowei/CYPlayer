//
//  CYVideoPlayerBaseView.h
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/11/30.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CYVideoPlayerControlViewEnumHeader.h"
#import "CYVideoPlayerSettings.h"

NS_ASSUME_NONNULL_BEGIN

@interface CYVideoPlayerBaseView : UIView

@property (nonatomic, strong, readonly) UIView *containerView;

@property (nonatomic, copy, readwrite, nullable) void(^setting)(CYVideoPlayerSettings *setting);

@end

NS_ASSUME_NONNULL_END
