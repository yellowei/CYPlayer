//
//  CYVideoPlayerPresentView.h
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/11/29.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "CYVideoPlayerState.h"

@class CYVideoPlayerAssetCarrier;

NS_ASSUME_NONNULL_BEGIN

@interface CYVideoPlayerPresentView : UIView

@property (nonatomic, weak, readwrite, nullable) CYVideoPlayerAssetCarrier *asset;

@property (nonatomic, copy, readwrite, nullable) void(^readyForDisplay)(CYVideoPlayerPresentView *view, CGRect videoRect);

@property (nonatomic, strong, readwrite, nullable) UIImage *placeholder;

@property (nonatomic, assign, readwrite) CYVideoPlayerPlayState state;

@end

NS_ASSUME_NONNULL_END
