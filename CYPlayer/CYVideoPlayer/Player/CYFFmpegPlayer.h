//
//  CYFFmpegPlayer.h
//  CYPlayer
//
//  Created by 黄威 on 2018/7/19.
//  Copyright © 2018年 Sutan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "CYPlayerGestureControl.h"
#import "CYPlayerDecoder.h"
#import "CYVideoPlayerControlView.h"
#import "CYVideoPlayerSettings.h"
#import "CYPlayerGLView.h"
#import "CYFFmpegMetalView.h"

@class
//CYPlayerDecoder,
CYVideoPlayerSettings,
CYPrompt,
CYVideoFrame,
CYVideoPlayerMoreSetting;

typedef void(^LockScreen)(BOOL isLock);

typedef NS_ENUM(NSUInteger, CYFFmpegPlayerPlayState) {
    CYFFmpegPlayerPlayState_Unknown = 0,
    CYFFmpegPlayerPlayState_Prepare,
    CYFFmpegPlayerPlayState_Playing,
    CYFFmpegPlayerPlayState_Buffing,
    CYFFmpegPlayerPlayState_Pause,
    CYFFmpegPlayerPlayState_PlayEnd,
    CYFFmpegPlayerPlayState_PlayFailed,
    CYFFmpegPlayerPlayState_Ready
};


typedef void (^CYPlayerImageGeneratorCompletionHandler)(NSMutableArray<CYVideoFrameRGB *> * _Nullable frames, NSError * _Nullable error);

typedef void (^CYPlayerSelectionsHandler)(NSInteger selectionsNumber);


extern NSString * _Nonnull const CYPlayerParameterMinBufferedDuration;    // Float
extern NSString * _Nonnull const CYPlayerParameterMaxBufferedDuration;    // Float
extern NSString * _Nonnull const CYPlayerParameterDisableDeinterlacing;   // BOOL

# pragma mark - CYFFmpegPlayer

@class CYFFmpegPlayer,
CYVideoPlayerControlView,
CYLoadingView,
CYVolBrigControl,
CYVideoPlayerMoreSettingsView,
CYVideoPlayerMoreSettingSecondaryView;

@protocol CYFFmpegPlayerDelegate <NSObject>

- (void)CYFFmpegPlayer:(CYFFmpegPlayer *)player onShareBtnCick:(UIButton *)btn;

- (void)CYFFmpegPlayerStartAutoPlaying:(CYFFmpegPlayer *)player;

- (void)CYFFmpegPlayer:(CYFFmpegPlayer *)player ChangeStatus:(CYFFmpegPlayerPlayState)state;

- (void)CYFFmpegPlayer:(CYFFmpegPlayer *)player UpdatePosition:(CGFloat)position Duration:(CGFloat)duration isDrag:(BOOL)isdrag;

- (void)CYFFmpegPlayer:(CYFFmpegPlayer *)player ControlViewDisplayStatus:(BOOL)isHidden;

- (void)CYFFmpegPlayer:(CYFFmpegPlayer *)player ChangeDefinition:(CYFFmpegPlayerDefinitionType)definition;

- (void)CYFFmpegPlayer:(CYFFmpegPlayer *)player SetSelectionsNumber:(CYPlayerSelectionsHandler)setNumHandler;

- (void)CYFFmpegPlayer:(CYFFmpegPlayer *)player changeSelections:(NSInteger)selectionsNum;

//- (void)CYFFmpegPlayer:(CYFFmpegPlayer *)player changeRate:(double)rate;


@end

@interface CYFFmpegPlayer : NSObject

+ (instancetype _Nonnull )sharedPlayer;

+ (id _Nullable ) movieViewWithContentPath: (NSString *_Nonnull) path
                                parameters: (NSDictionary *_Nullable) parameters;

- (void)setupPlayerWithPath:(NSString * _Nonnull)path;

- (void)setupPlayerWithPath:(NSString * _Nonnull)path parameters: (NSDictionary * _Nullable) parameters;

- (void)changeDefinitionPath:(NSString * _Nonnull)path;
- (void)changeSelectionsPath:(NSString * _Nonnull)path;
- (void)changeLiveDefinitionPath:(NSString * _Nonnull)path;


@property (nonatomic, strong) CYPlayerDecoder * _Nonnull decoder;

@property (nonatomic, weak) id<CYFFmpegPlayerDelegate> _Nullable delegate;

/*!
 *  present View. support autoLayout.
 *
 *  播放器视图
 */
@property (nonatomic, strong) UIView *view;
@property (nonatomic, strong) UIView * presentView;
@property (nonatomic, strong) CYPlayerGLView * glView;
@property (nonatomic, strong) CYFFmpegMetalView * metalView;
@property (nonatomic, strong) CYVideoPlayerControlView *controlView;
@property (nonatomic, strong) CYVolBrigControl *volBrigControl;
@property (nonatomic, strong) CYLoadingView *loadingView;
@property (nonatomic, strong) CYVideoPlayerMoreSettingsView *moreSettingView;
@property (nonatomic, strong) CYVideoPlayerMoreSettingSecondaryView *moreSecondarySettingView;
@property (nonatomic, strong) CYPlayerGestureControl *gestureControl;

@property (readonly) BOOL playing;

@property (nonatomic, assign, readonly) CYFFmpegPlayerPlayState state;

@property (nonatomic, assign, readwrite) BOOL generatPreviewImages;

- (void)viewDidAppear;
- (void)viewDidDisappear;
- (void)generatedPreviewImagesWithCount:(NSInteger)imagesCount completionHandler:(CYPlayerImageGeneratorCompletionHandler _Nullable )handler;

+ (void)generatedPreviewImagesWithPath:(NSString *_Nullable)path
                     completionHandler:(void (^_Nullable)(NSMutableArray * _Nullable frames, NSError * _Nullable error))handler;

+ (void)generatedPreviewImagesWithPath:(NSString * _Nullable)path
                                 Count:(NSInteger)imagesCount
completionHandler:(CYPlayerImageGeneratorCompletionHandler _Nullable)handler;

- (void) setMoviePosition: (CGFloat) position playMode:(BOOL)playMode;
- (double)currentTime;
- (NSTimeInterval)totalTime;

@end

# pragma mark -

@interface CYFFmpegPlayer (State)


@property (nonatomic, assign, readwrite, getter=isHiddenControl) BOOL hideControl;

@property (nonatomic, assign, readwrite, getter=isLockedScrren) BOOL lockScreen;


- (void)_cancelDelayHiddenControl;

- (void)_delayHiddenControl;

- (void)_prepareState;

- (void)_readyState;

- (void)_playState;

- (void)_pauseState;

- (void)_playEndState;

- (void)_playFailedState;

- (void)_unknownState;

@end

# pragma mark -

@interface CYFFmpegPlayer (Setting)

/*!
 *  clicked back btn exe block.
 *
 *  点击返回按钮的回调.
 */
@property (nonatomic, copy, readwrite) void(^clickedBackEvent)(CYFFmpegPlayer *player);

/*!
 *  Whether screen rotation is disabled. default is NO.
 *
 *  是否禁用屏幕旋转, 默认是NO.
 */
@property (nonatomic, assign, readwrite) BOOL disableRotation;

@property (nonatomic, assign, readwrite) float rate; /// 0.5 .. 1.5

@property (nonatomic, copy, readwrite, nullable) void(^rotatedScreen)(CYFFmpegPlayer *player, BOOL isFullScreen);

@property (nonatomic, copy, readwrite, nullable) void(^controlViewDisplayStatus)(CYFFmpegPlayer *player, BOOL displayed);

/*!
 *  Call when the rate changes.
 *
 *  调速时调用.
 *  当滑动内部的`rate slider`时候调用. 外部改变`rate`不会调用.
 **/
@property (nonatomic, copy, readwrite, nullable) void(^internallyChangedRate)(CYFFmpegPlayer *player, float rate);

/*!
 *  配置播放器, 注意: 这个`block`在子线程运行.
 **/
- (void)settingPlayer:(void(^)(CYVideoPlayerSettings *settings))block;
- (void)resetSetting;// 重置配置
- (CYVideoPlayerSettings *)settings;


/*!
 *  Call when the rate changes.
 *
 *  调速时调用.
 **/
@property (nonatomic, copy, readwrite, nullable) void(^rateChanged)(CYFFmpegPlayer *player);

/*!
 *  default is YES.
 *
 *  是否自动播放, 默认是 YES.
 */
@property (nonatomic, assign, readwrite, getter=isAutoplay) BOOL autoplay;

/*!
 *  clicked More button to display items.
 *
 *  点击更多按钮, 弹出来的选项.
 **/
@property (nonatomic, strong, readwrite, nullable) NSArray<CYVideoPlayerMoreSetting *> *moreSettings;

@end


#pragma mark - CYVideoPlayer (Control)
@protocol CYFFmpegControlDelegate <NSObject>

@optional
- (BOOL)CYFFmpegPlayer:(CYFFmpegPlayer *)player triggerCondition:(CYPlayerGestureControl *)control gesture:(UIGestureRecognizer *)gesture;
- (void)CYFFmpegPlayer:(CYFFmpegPlayer *)player singleTapped:(CYPlayerGestureControl *)control;
- (void)CYFFmpegPlayer:(CYFFmpegPlayer *)player doubleTapped:(CYPlayerGestureControl *)control;
- (void)CYFFmpegPlayer:(CYFFmpegPlayer *)player beganPan:(CYPlayerGestureControl *)control direction:(CYPanDirection)direction location:(CYPanLocation)location;
- (void)CYFFmpegPlayer:(CYFFmpegPlayer *)player changedPan:(CYPlayerGestureControl *)control direction:(CYPanDirection)direction location:(CYPanLocation)location;
- (void)CYFFmpegPlayer:(CYFFmpegPlayer *)player endedPan:(CYPlayerGestureControl *)control direction:(CYPanDirection)direction location:(CYPanLocation)location;

@end



@interface CYFFmpegPlayer (Control)



- (BOOL)play;

- (BOOL)pause;

- (void)stop;

- (void)playNextVideo;

- (void)playPreviousVideo;

- (void)hideBackBtn;

- (void)showBackBtn;

@property (nonatomic, copy) LockScreen lockscreen;

@property (nonatomic, weak) id<CYFFmpegControlDelegate> control_delegate;

@end

#pragma mark -

@interface CYFFmpegPlayer (Prompt)

@property (nonatomic, strong, readonly) CYPrompt *prompt;

/*!
 *  duration default is 1.0
 */
- (void)showTitle:(NSString *)title;

/*!
 *  duration if value set -1, promptView will always show.
 */
- (void)showTitle:(NSString *)title duration:(NSTimeInterval)duration;

- (void)hiddenTitle;

@end
