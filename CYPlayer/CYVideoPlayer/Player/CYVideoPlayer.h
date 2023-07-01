//
//  CYVideoPlayer.h
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/11/29.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "CYVideoPlayerState.h"
#import "CYVideoPlayerAssetCarrier.h"
#import "CYVideoPlayerMoreSettingSecondary.h"
#import "CYVideoPlayerSettings.h"
#import "CYPrompt.h"
#import "CYPlayerGestureControl.h"

NS_ASSUME_NONNULL_BEGIN

@class CYVideoPlayer;

@protocol CYVideoPlayerDelegate <NSObject>

- (void)CYVideoPlayer:(CYVideoPlayer *)player onShareBtnCick:(UIButton *)btn;

- (void)CYVideoPlayerStartAutoPlaying:(CYVideoPlayer *)player;

- (void)CYVideoPlayer:(CYVideoPlayer *)player ChangeStatus:(CYVideoPlayerPlayState)state;


@end

typedef void(^LockScreen)(BOOL isLock);

@interface CYVideoPlayer : NSObject

+ (instancetype)sharedPlayer;

+ (instancetype)player;

- (instancetype)init;

@property (nonatomic, strong) CYPlayerGestureControl * gestureControl;

@property (nonatomic, weak) id<CYVideoPlayerDelegate> delegate;
/*!
 *  present View. support autoLayout.
 *
 *  播放器视图
 */
@property (nonatomic, strong, readonly) UIView *view;

/*!
 *  error. support observe. default is nil.
 *
 *  播放报错, 如果需要, 可以使用观察者, 来观察他的改变.
 */
@property (nonatomic, strong, readonly, nullable) NSError *error;

@property (nonatomic, assign, readonly) CYVideoPlayerPlayState state;

/*!
 *  获取当前截图
 **/
- (UIImage *__nullable)screenshot;

/*!
 *  unit sec.
 *
 *  当前播放时间.
 */
- (NSTimeInterval)currentTime;

- (NSTimeInterval)totalTime;

@end


#pragma mark - State

@interface CYVideoPlayer (State)

@property (nonatomic, assign, readwrite, getter=isHiddenControl) BOOL hideControl;
@property (nonatomic, assign, readwrite, getter=isLockedScrren) BOOL lockScreen;

- (void)_cancelDelayHiddenControl;

- (void)_delayHiddenControl;

- (void)_prepareState;

- (void)_playState;

- (void)_pauseState;

- (void)_playEndState;

- (void)_playFailedState;

- (void)_unknownState;

@end


#pragma mark - 

@interface CYVideoPlayer (Setting)
/*!
 *  clicked back btn exe block.
 *
 *  点击返回按钮的回调.
 */
@property (nonatomic, copy, readwrite) void(^clickedBackEvent)(CYVideoPlayer *player);

- (void)playWithURL:(NSURL *)playURL;

/*!
 *  unit: sec.
 *
 *  单位是秒.
 **/
- (void)playWithURL:(NSURL *)playURL jumpedToTime:(NSTimeInterval)time;

/*!
 *  Video URL
 *
 *  视频播放地址
 */
@property (nonatomic, strong, readwrite, nullable) NSURL *assetURL;

/*!
 *  Create It By Video URL.
 *
 *  创建一个播放资源.
 *  如果在`tableView或者collectionView`中播放, 使用它来初始化播放资源.
 *  它也可以直接从某个时刻开始播放. 单位是秒.
 **/
@property (nonatomic, strong, readwrite, nullable) CYVideoPlayerAssetCarrier *asset;

/*!
 *  clicked More button to display items.
 *
 *  点击更多按钮, 弹出来的选项.
 **/
@property (nonatomic, strong, readwrite, nullable) NSArray<CYVideoPlayerMoreSetting *> *moreSettings;

/*!
 *  配置播放器, 注意: 这个`block`在子线程运行.
 **/
- (void)settingPlayer:(void(^)(CYVideoPlayerSettings *settings))block;
- (void)resetSetting;// 重置配置


/*!
 *  Call when the rate changes.
 *
 *  调速时调用.
 **/
@property (nonatomic, copy, readwrite, nullable) void(^rateChanged)(CYVideoPlayer *player);

/*!
 *  Call when the rate changes.
 *
 *  调速时调用.
 *  当滑动内部的`rate slider`时候调用. 外部改变`rate`不会调用.
 **/
@property (nonatomic, copy, readwrite, nullable) void(^internallyChangedRate)(CYVideoPlayer *player, float rate);
@property (nonatomic, assign, readwrite) float rate; /// 0.5 .. 1.5

/*!
 *  loading show this.
 *
 *  占位图. 初始化播放loading的时候显示.
 **/
- (void)setPlaceholder:(UIImage *)placeholder;

/*!
 *  default is YES.
 *
 *  是否自动播放, 默认是 YES.
 */
@property (nonatomic, assign, readwrite, getter=isAutoplay) BOOL autoplay;

/*!
 *  default is YES.
 *
 *  是否自动生成预览视图, 默认是 YES. 如果为NO, 则预览按钮将不会显示.
 */
@property (nonatomic, assign, readwrite) BOOL generatePreviewImages;

/*!
 *  Whether screen rotation is disabled. default is NO.
 *
 *  是否禁用屏幕旋转, 默认是NO.
 */
@property (nonatomic, assign, readwrite) BOOL disableRotation;

/*!
 *  Call when the screen is rotated.
 *
 *  屏幕旋转的时候调用.
 **/
@property (nonatomic, copy, readwrite, nullable) void(^rotatedScreen)(CYVideoPlayer *player, BOOL isFullScreen);
@property (nonatomic, assign, readonly) BOOL isFullScreen; // 是否全屏

/*!
 *  播放完毕的时候调用.
 **/
@property (nonatomic, copy, readwrite, nullable) void(^playDidToEnd)(CYVideoPlayer *player);

/*!
 *  Call when the control view is hidden or displayed.
 *
 *  控制视图隐藏或显示的时候调用.
 **/
@property (nonatomic, copy, readwrite, nullable) void(^controlViewDisplayStatus)(CYVideoPlayer *player, BOOL displayed);
@property (nonatomic, assign, readonly) BOOL controlViewDisplayed; // 控制视图是否显示

@end


#pragma mark - CYVideoPlayer (Control)
@protocol CYVideoPlayerControlDelegate <NSObject>

@optional
- (BOOL)CYVideoPlayer:(CYVideoPlayer *)player triggerCondition:(CYPlayerGestureControl *)control gesture:(UIGestureRecognizer *)gesture;
- (void)CYVideoPlayer:(CYVideoPlayer *)player singleTapped:(CYPlayerGestureControl *)control;
- (void)CYVideoPlayer:(CYVideoPlayer *)player doubleTapped:(CYPlayerGestureControl *)control;
- (void)CYVideoPlayer:(CYVideoPlayer *)player beganPan:(CYPlayerGestureControl *)control direction:(CYPanDirection)direction location:(CYPanLocation)location;
- (void)CYVideoPlayer:(CYVideoPlayer *)player changedPan:(CYPlayerGestureControl *)control direction:(CYPanDirection)direction location:(CYPanLocation)location;
- (void)CYVideoPlayer:(CYVideoPlayer *)player endedPan:(CYPlayerGestureControl *)control direction:(CYPanDirection)direction location:(CYPanLocation)location;

@end

@interface CYVideoPlayer (Control)

/*!
 *  The user clicked paused.
 *
 *  用户点击暂停或者双击暂停的时候, 会设置它. 当我们调用`pause`, 不会设置它.
 *  可以根据这个状态, 来判断是我们调用的pause, 还是用户主动pause的.
 *  当返回播放界面时, 如果是我们自己调用`pause`, 则可以使用`play`, 使其继续播放.
 **/
@property (nonatomic, assign, readonly) BOOL userPaused;

@property (nonatomic, weak) id<CYVideoPlayerControlDelegate> control_delegate;

- (BOOL)play;

- (BOOL)pause;

- (void)stop;

/// 停止播放并淡出
- (void)stopAndFadeOut;

/*!
 *  停止旋转.
 *
 *  相当于 `player.disableRotation = YES;` .
 **/
- (void)stopRotation;

/*!
 *  开启旋转.
 *
 *  相当于 `player.disableRotation = NO;` .
 **/
- (void)enableRotation;

/*!
 *  跳转到指定位置, 不建议使用
 *  如果要跳转到某个位置, 可以在初始化时, 设置`CYVideoPlayerAssetCarrier`的`beginTime`.
 **/
- (void)jumpedToTime:(NSTimeInterval)time completionHandler:(void (^ __nullable)(BOOL finished))completionHandler;

- (void)seekToTime:(CMTime)time completionHandler:(void (^ __nullable)(BOOL finished))completionHandler;

/*!
 *  获取随机截图
 **/
- (UIImage *)randomScreenshot;

- (NSArray<CYVideoPreviewModel *> *)getPreviewImages;


@property (nonatomic, copy) LockScreen lockscreen;

@end


#pragma mark -

@interface CYVideoPlayer (Prompt)

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

NS_ASSUME_NONNULL_END
