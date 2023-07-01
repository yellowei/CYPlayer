//
//  CYVideoPlayerCenterControlView.h
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/12/4.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerBaseView.h"

NS_ASSUME_NONNULL_BEGIN

@protocol CYVideoPlayerCenterControlViewDelegate;

@interface CYVideoPlayerCenterControlView : CYVideoPlayerBaseView

@property (nonatomic, weak, readwrite, nullable) id<CYVideoPlayerCenterControlViewDelegate> delegate;

@property (nonatomic, strong, readonly) UIButton *failedBtn;
@property (nonatomic, strong, readonly) UIButton *replayBtn;

@end

@protocol CYVideoPlayerCenterControlViewDelegate <NSObject>
			
@optional
- (void)centerControlView:(CYVideoPlayerCenterControlView *)view clickedBtnTag:(CYVideoPlayControlViewTag)tag;

@end

NS_ASSUME_NONNULL_END
