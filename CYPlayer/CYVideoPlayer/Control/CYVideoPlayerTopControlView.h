//
//  CYVideoPlayerTopControlView.h
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/11/29.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerBaseView.h"

NS_ASSUME_NONNULL_BEGIN

@protocol CYVideoPlayerTopControlViewDelegate;

@interface CYVideoPlayerTopControlView : CYVideoPlayerBaseView

@property (nonatomic, weak, readwrite, nullable) id<CYVideoPlayerTopControlViewDelegate> delegate;
@property (nonatomic, strong, readonly) UIButton *backBtn;
@property (nonatomic, strong, readonly) UIButton *previewBtn;
@property (nonatomic, strong, readonly) UIButton *moreBtn;
@property (nonatomic, strong, readonly) UIButton *titleBtn;

@end

@protocol CYVideoPlayerTopControlViewDelegate <NSObject>
			
@optional
- (void)topControlView:(CYVideoPlayerTopControlView *)view clickedBtnTag:(CYVideoPlayControlViewTag)tag;

@end

NS_ASSUME_NONNULL_END
