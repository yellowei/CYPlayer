//
//  CYVideoPlayerControlView.h
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/11/29.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerBaseView.h"
#import "CYVideoPlayerControlViewEnumHeader.h"
#import "CYVideoPlayerTopControlView.h"
#import "CYVideoPlayerLeftControlView.h"
#import "CYVideoPlayerBottomControlView.h"
#import "CYVideoPlayerCenterControlView.h"
#import "CYVideoPlayerPreviewView.h"
#import "CYVideoPlayerDraggingProgressView.h"
#import "CYVideoPlayerSelectTableView.h"


#define CYControlTopH (90)
#define CYControlLeftH (49)
#define CYControlBottomH (100)


NS_ASSUME_NONNULL_BEGIN

@class CYVideoPreviewModel, CYVideoPlayerAssetCarrier, CYPlayerDecoder;

@protocol CYVideoPlayerControlViewDelegate;

@interface CYVideoPlayerControlView : CYVideoPlayerBaseView

@property (nonatomic, weak, readwrite, nullable) id<CYVideoPlayerControlViewDelegate> delegate;
@property (nonatomic, weak, readwrite, nullable) CYVideoPlayerAssetCarrier *asset;
@property (nonatomic, weak, readwrite, nullable) CYPlayerDecoder *decoder;

@property (nonatomic, strong, readonly) CYVideoPlayerTopControlView *topControlView;
@property (nonatomic, strong, readonly) CYVideoPlayerPreviewView *previewView;
@property (nonatomic, strong, readonly) CYVideoPlayerLeftControlView *leftControlView;
@property (nonatomic, strong, readonly) CYVideoPlayerCenterControlView *centerControlView;
@property (nonatomic, strong, readonly) CYVideoPlayerSelectTableView * selectTableView;
@property (nonatomic, strong, readonly) CYVideoPlayerBottomControlView *bottomControlView;
@property (nonatomic, strong, readonly) CYSlider *bottomProgressSlider;
@property (nonatomic, strong, readonly) CYVideoPlayerDraggingProgressView *draggingProgressView;

@end

@protocol CYVideoPlayerControlViewDelegate <NSObject>
			
@optional
- (void)controlView:(CYVideoPlayerControlView *)controlView clickedBtnTag:(CYVideoPlayControlViewTag)tag;
- (void)controlView:(CYVideoPlayerControlView *)controlView didSelectPreviewItem:(CYVideoPreviewModel *)item;
- (void)controlView:(CYVideoPlayerControlView *)controlView didSelectPreviewFrame:(CYVideoFrame *)frame;
- (void)controlViewOnDefinitionBtnClick:(CYVideoPlayerControlView *)controlView;

- (void)controlViewOnSelectionsBtnClick:(CYVideoPlayerControlView *)controlView;

- (void)controlViewOnRateBtnClick:(CYVideoPlayerControlView *)controlView;


@end

NS_ASSUME_NONNULL_END
