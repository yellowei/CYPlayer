//
//  CYVideoPlayer.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/11/29.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayer.h"
#import "CYVideoPlayerAssetCarrier.h"
#import <Masonry/Masonry.h>
#import "CYVideoPlayerPresentView.h"
#import "CYVideoPlayerControlView.h"
#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>
#import "CYVideoPlayerResources.h"
#import <MediaPlayer/MPVolumeView.h>
#import "CYVideoPlayerMoreSettingsView.h"
#import "CYVideoPlayerMoreSettingSecondaryView.h"
#import "CYOrentationObserver.h"
#import "CYVideoPlayerRegistrar.h"
#import "CYVolBrigControl.h"
#import "CYTimerControl.h"
#import "CYVideoPlayerView.h"
#import "CYLoadingView.h"
#import "CYPlayerGestureControl.h"

#define MoreSettingWidth (MAX([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height) * 0.382)

#define CYColorWithHEX(hex) [UIColor colorWithRed:(float)((hex & 0xFF0000) >> 16)/255.0 green:(float)((hex & 0xFF00) >> 8)/255.0 blue:(float)(hex & 0xFF)/255.0 alpha:1.0]

inline static void _cyErrorLog(id msg) {
    NSLog(@"__error__: %@", msg);
}

inline static void _cyHiddenViews(NSArray<UIView *> *views) {
    [views enumerateObjectsUsingBlock:^(UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.alpha = 0.00;
        obj.hidden = YES;
    }];
}

inline static void _cyShowViews(NSArray<UIView *> *views) {
    [views enumerateObjectsUsingBlock:^(UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.alpha = 1;
        obj.hidden = NO;
    }];
}

inline static void _cyAnima(void(^block)(void)) {
    if ( block ) {
        [UIView animateWithDuration:0.3 animations:^{
            block();
        }];
    }
}

inline static NSString *_formatWithSec(NSInteger sec) {
    NSInteger seconds = sec % 60;
    NSInteger minutes = sec / 60;
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
}




#pragma mark -

@interface CYVideoPlayer ()<CYVideoPlayerControlViewDelegate, CYSliderDelegate>

@property (nonatomic, strong, readonly) CYVideoPlayerPresentView *presentView;
@property (nonatomic, strong, readonly) CYVideoPlayerControlView *controlView;
@property (nonatomic, strong, readonly) CYVideoPlayerMoreSettingsView *moreSettingView;
@property (nonatomic, strong, readonly) CYVideoPlayerMoreSettingSecondaryView *moreSecondarySettingView;
@property (nonatomic, strong, readonly) CYOrentationObserver *orentation;
@property (nonatomic, strong, readonly) CYMoreSettingsFooterViewModel *moreSettingFooterViewModel;
@property (nonatomic, strong, readonly) CYVideoPlayerRegistrar *registrar;
@property (nonatomic, strong, readonly) CYVolBrigControl *volBrigControl;
//@property (nonatomic, strong, readonly) CYPlayerGestureControl *gestureControl;
@property (nonatomic, strong, readonly) CYLoadingView *loadingView;
@property (nonatomic, strong, readonly) dispatch_queue_t workQueue;


@property (nonatomic, assign, readwrite) CYVideoPlayerPlayState state;
@property (nonatomic, assign, readwrite) BOOL hiddenMoreSettingView;
@property (nonatomic, assign, readwrite) BOOL hiddenMoreSecondarySettingView;
@property (nonatomic, assign, readwrite) BOOL hiddenLeftControlView;
@property (nonatomic, assign, readwrite) BOOL userClickedPause;
@property (nonatomic, assign, readwrite) BOOL suspend; // Set it when the [`pause` + `play` + `stop`] is called.
@property (nonatomic, assign, readwrite) BOOL playOnCell;
@property (nonatomic, assign, readwrite) BOOL scrollIn;
@property (nonatomic, assign, readwrite) BOOL touchedScrollView;
@property (nonatomic, assign, readwrite) BOOL stopped; // Set it when the [`play` + `stop`] is called.
@property (nonatomic, strong, readwrite) NSError *error;

- (void)_play;
- (void)_pause;

@end





#pragma mark - State
@implementation CYVideoPlayer (State)

- (CYTimerControl *)timerControl {
    CYTimerControl *timerControl = objc_getAssociatedObject(self, _cmd);
    if ( timerControl ) return timerControl;
    timerControl = [CYTimerControl new];
    objc_setAssociatedObject(self, _cmd, timerControl, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return timerControl;
}

- (void)_cancelDelayHiddenControl {
    [self.timerControl reset];
}

- (void)_delayHiddenControl {
    __weak typeof(self) _self = self;
    [self.timerControl start:^(CYTimerControl * _Nonnull control) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ( self.state == CYVideoPlayerPlayState_Pause ) return;
        _cyAnima(^{
            self.hideControl = YES;
        });
    }];
}

- (void)setLockScreen:(BOOL)lockScreen {
    if ( self.isLockedScrren == lockScreen )
    {
        return;
    }
    objc_setAssociatedObject(self, @selector(isLockedScrren), @(lockScreen), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    //外部调用
    if (self.lockscreen)
    {
        self.lockscreen(lockScreen);
    }
    
    [self _cancelDelayHiddenControl];
    _cyAnima(^{
        if ( lockScreen ) {
            [self _lockScreenState];
        }
        else {
            [self _unlockScreenState];
        }
    });
}

- (BOOL)isLockedScrren {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setHideControl:(BOOL)hideControl {
    [self.timerControl reset];
    if ( hideControl ) [self _hideControlState];
    else {
        [self _showControlState];
        [self _delayHiddenControl];
    }
    
    BOOL oldValue = self.isHiddenControl;
    if ( oldValue != hideControl ) {
        objc_setAssociatedObject(self, @selector(isHiddenControl), @(hideControl), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if ( self.controlViewDisplayStatus ) self.controlViewDisplayStatus(self, !hideControl);
    }
}

- (BOOL)isHiddenControl {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)_unknownState {
    // hidden
//    _cyHiddenViews(@[self.controlView]);
    self.state = CYVideoPlayerPlayState_Unknown;
}

- (void)_prepareState {
    // show
    _cyShowViews(@[self.controlView]);
    
    // hidden
    self.controlView.previewView.hidden = YES;
    _cyHiddenViews(@[
                     self.controlView.draggingProgressView,
                     self.controlView.topControlView.previewBtn,
                     self.controlView.leftControlView.lockBtn,
                     self.controlView.centerControlView.failedBtn,
                     self.controlView.centerControlView.replayBtn,
                     self.controlView.bottomControlView.playBtn,
                     self.controlView.bottomProgressSlider,
                     ]);
    
    if ( self.orentation.fullScreen ) {
        _cyShowViews(@[self.controlView.topControlView.moreBtn,self.controlView.topControlView.titleBtn,]);
        [self.controlView.topControlView.moreBtn setImage:[UIImage imageNamed:[CYVideoPlayerResources bundleComponentWithImageName:@"cy_video_player_more"]] forState:UIControlStateNormal];
        self.hiddenLeftControlView = NO;
        if ( self.asset.hasBeenGeneratedPreviewImages ) {
            _cyShowViews(@[self.controlView.topControlView.previewBtn]);
        }
    }
    else {
        self.hiddenLeftControlView = YES;
        _cyHiddenViews(@[self.controlView.topControlView.moreBtn,
                         self.controlView.topControlView.previewBtn,]);
        _cyShowViews(@[self.controlView.topControlView.titleBtn,]);
        //        _cyHiddenViews(@[self.controlView.topControlView.previewBtn,]);
        [self.controlView.topControlView.moreBtn setImage:[UIImage imageNamed:@"btn_navi_share"] forState:UIControlStateNormal];
    }
    
    self.state = CYVideoPlayerPlayState_Prepare;
}

- (void)_playState {
    
    // show
    _cyShowViews(@[self.controlView.bottomControlView.pauseBtn]);
    
    // hidden
    // hidden
    _cyHiddenViews(@[
                     self.controlView.bottomControlView.playBtn,
                     self.controlView.centerControlView.replayBtn,
                     ]);
    
    self.state = CYVideoPlayerPlayState_Playing;
}

- (void)_pauseState {
    
    // show
    _cyShowViews(@[self.controlView.bottomControlView.playBtn]);
    
    // hidden
    _cyHiddenViews(@[self.controlView.bottomControlView.pauseBtn]);
    
    self.state = CYVideoPlayerPlayState_Pause;
}

- (void)_playEndState {
    
    // show
    _cyShowViews(@[self.controlView.centerControlView.replayBtn,
                   self.controlView.bottomControlView.playBtn]);
    
    // hidden
    _cyHiddenViews(@[self.controlView.bottomControlView.pauseBtn]);
    
    
    self.state = CYVideoPlayerPlayState_PlayEnd;
}

- (void)_playFailedState {
    // show
    _cyShowViews(@[self.controlView.centerControlView.failedBtn]);
    
    // hidden
    _cyHiddenViews(@[self.controlView.centerControlView.replayBtn]);
    
    self.state = CYVideoPlayerPlayState_PlayFailed;
}

- (void)_lockScreenState {
    
    // show
    _cyShowViews(@[self.controlView.leftControlView.lockBtn]);
    
    // hidden
    _cyHiddenViews(@[self.controlView.leftControlView.unlockBtn]);
    self.hideControl = YES;
}

- (void)_unlockScreenState {
    
    // show
    _cyShowViews(@[self.controlView.leftControlView.unlockBtn]);
    self.hideControl = NO;
    
    // hidden
    _cyHiddenViews(@[self.controlView.leftControlView.lockBtn]);
    
}

- (void)_hideControlState {

    // show
    _cyShowViews(@[self.controlView.bottomProgressSlider]);
    
    // hidden
    self.controlView.previewView.hidden = YES;
    
    // transform hidden
    self.controlView.topControlView.transform = CGAffineTransformMakeTranslation(0, -CYControlTopH);
    self.controlView.bottomControlView.transform = CGAffineTransformMakeTranslation(0, CYControlBottomH);

    if ( self.orentation.fullScreen ) {
        if ( self.isLockedScrren ) self.hiddenLeftControlView = NO;
        else self.hiddenLeftControlView = YES;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ( self.orentation.fullScreen ) {
//        [[UIApplication sharedApplication] setStatusBarHidden:YES animated:YES];
    }
    else {
//        [[UIApplication sharedApplication] setStatusBarHidden:NO animated:YES];
    }
#pragma clang diagnostic pop
}

- (void)_showControlState {
    
    // hidden
    _cyHiddenViews(@[self.controlView.bottomProgressSlider]);
    self.controlView.previewView.hidden = YES;
    
    // transform show
    if ( self.playOnCell && !self.orentation.fullScreen ) {
        self.controlView.topControlView.transform = CGAffineTransformMakeTranslation(0, -CYControlTopH);
    }
    else {
        self.controlView.topControlView.transform = CGAffineTransformIdentity;
    }
    self.controlView.bottomControlView.transform = CGAffineTransformIdentity;
    
    self.hiddenLeftControlView = !self.orentation.fullScreen;
    
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
//    [[UIApplication sharedApplication] setStatusBarHidden:NO animated:YES];
#pragma clang diagnostic pop
}

@end


#pragma mark - CYVideoPlayer
#import "CYMoreSettingsFooterViewModel.h"

@implementation CYVideoPlayer {
    CYVideoPlayerPresentView *_presentView;
    CYVideoPlayerControlView *_controlView;
    CYVideoPlayerMoreSettingsView *_moreSettingView;
    CYVideoPlayerMoreSettingSecondaryView *_moreSecondarySettingView;
    CYOrentationObserver *_orentation;
    CYVideoPlayerView *_view;
    CYMoreSettingsFooterViewModel *_moreSettingFooterViewModel;
    CYVideoPlayerRegistrar *_registrar;
    CYVolBrigControl *_volBrigControl;
    CYLoadingView *_loadingView;
    CYPlayerGestureControl *_gestureControl;
    dispatch_queue_t _workQueue;
    CYVideoPlayerAssetCarrier *_asset;
}

+ (instancetype)sharedPlayer {
    static id _instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

+ (instancetype)player {
    return [[self alloc] init];
}

#pragma mark

- (instancetype)init {
    self = [super init];
    if ( !self )  return nil;
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayAndRecord error:&error];
    if ( error ) {
        _cyErrorLog([NSString stringWithFormat:@"%@", error.userInfo]);
    }

    [self view];
    [self orentation];
    [self volBrig];
    __weak typeof(self) _self = self;
    [self settingPlayer:^(CYVideoPlayerSettings * _Nonnull settings) {
        __strong typeof(_self) self = _self;
        if ( !self ) return ;
        [self resetSetting];
    }];
    [self registrar];
    
    // default values
    self.autoplay = YES;
    self.generatePreviewImages = YES;
    
    [self _unknownState];
    
    self.rate = 1;
    
    return self;
}

- (void)dealloc {
    self.state = CYVideoPlayerPlayState_Unknown;
    [self stop];
    NSLog(@"%s - %zd", __func__, __LINE__);
}

- (UIImage *)screenshot {
    return [_asset screenshot];
}

- (NSTimeInterval)currentTime {
    return _asset.currentTime;
}

- (NSTimeInterval)totalTime {
    return _asset.duration;
}

#pragma mark -

- (dispatch_queue_t)workQueue {
    if ( _workQueue ) return _workQueue;
    _workQueue = dispatch_queue_create("com.CYVideoPlayer.workQueue", DISPATCH_QUEUE_SERIAL);
    return _workQueue;
}

- (void)_addOperation:(void(^)(CYVideoPlayer *player))block {
    __weak typeof(self) _self = self;
    dispatch_async(self.workQueue, ^{
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ( block ) block(self);
    });
}

- (UIView *)view {
    if ( _view )
    {
        [_presentView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(_presentView.superview);
        }];
        return _view;
    }
    _view = [CYVideoPlayerView new];
    _view.backgroundColor = [UIColor blackColor];
    [_view addSubview:self.presentView];
    [_presentView addSubview:self.controlView];
    [_controlView addSubview:self.moreSettingView];
    [_controlView addSubview:self.moreSecondarySettingView];
    [self gesturesHandleWithTargetView:_controlView];
    self.hiddenMoreSettingView = YES;
    self.hiddenMoreSecondarySettingView = YES;
    _controlView.delegate = self;
    _controlView.bottomControlView.progressSlider.delegate = self;
    
    [_presentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(_presentView.superview);
    }];
    
    [_controlView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(_controlView.superview);
    }];
    
    [_moreSettingView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.trailing.offset(0);
        make.width.offset(MoreSettingWidth);
    }];
    
    [_moreSecondarySettingView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(_moreSettingView);
    }];
    
    _loadingView = [CYLoadingView new];
    [_controlView addSubview:_loadingView];
    [_loadingView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.offset(0);
    }];
    
    __weak typeof(self) _self = self;
    _view.setting = ^(CYVideoPlayerSettings * _Nonnull setting) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        self.loadingView.lineColor = setting.loadingLineColor;
    };
    
    return _view;
}

- (CYVideoPlayerPresentView *)presentView {
    if ( _presentView ) return _presentView;
    _presentView = [CYVideoPlayerPresentView new];
    _presentView.clipsToBounds = YES;
    __weak typeof(self) _self = self;
    _presentView.readyForDisplay = ^(CYVideoPlayerPresentView * _Nonnull view, CGRect videoRect) {
        __strong typeof(_self) self = _self;
        if ( !self ) return ;
        if ( self.asset.hasBeenGeneratedPreviewImages ) { return ; }
        if ( !self.generatePreviewImages ) return;
        CGRect bounds = videoRect;
        CGFloat width = [UIScreen mainScreen].bounds.size.width * 0.4;
        CGFloat height = width * bounds.size.height / bounds.size.width;
        CGSize size = CGSizeMake(width, height);
        self.controlView.draggingProgressView.size = size;
        [_self.asset generatedPreviewImagesWithMaxItemSize:size completion:^(CYVideoPlayerAssetCarrier * _Nonnull asset, NSArray<CYVideoPreviewModel *> * _Nullable images, NSError * _Nullable error) {
            if ( error ) {
                _cyErrorLog(@"Generate Preview Image Failed!");
            }
            else {
                __strong typeof(_self) self = _self;
                if ( !self ) return;
                if ( self.orentation.fullScreen ) {
                    _cyAnima(^{
                        _cyShowViews(@[self.controlView.topControlView.previewBtn]);
                    });
                }
                self.controlView.previewView.previewImages = images;
            }
        }];
    };
    return _presentView;
}

- (CYVideoPlayerControlView *)controlView {
    if ( _controlView ) return _controlView;
    _controlView = [CYVideoPlayerControlView new];
    _controlView.clipsToBounds = YES;
    return _controlView;
}


- (CYVideoPlayerMoreSettingsView *)moreSettingView {
    if ( _moreSettingView ) return _moreSettingView;
    _moreSettingView = [CYVideoPlayerMoreSettingsView new];
    _moreSettingView.backgroundColor = [UIColor blackColor];
    return _moreSettingView;
}

- (CYVideoPlayerMoreSettingSecondaryView *)moreSecondarySettingView {
    if ( _moreSecondarySettingView ) return _moreSecondarySettingView;
    _moreSecondarySettingView = [CYVideoPlayerMoreSettingSecondaryView new];
    _moreSecondarySettingView.backgroundColor = [UIColor blackColor];
    _moreSettingFooterViewModel = [CYMoreSettingsFooterViewModel new];
    __weak typeof(self) _self = self;
    _moreSettingFooterViewModel.needChangeBrightness = ^(float brightness) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        self.volBrigControl.brightness = brightness;
    };
    
    _moreSettingFooterViewModel.needChangePlayerRate = ^(float rate) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ( !self.asset ) return;
        self.rate = rate;
        if ( self.internallyChangedRate ) self.internallyChangedRate(self, rate);
    };
    
    _moreSettingFooterViewModel.needChangeVolume = ^(float volume) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        self.volBrigControl.volume = volume;
    };
    
    _moreSettingFooterViewModel.initialVolumeValue = ^float{
        __strong typeof(_self) self = _self;
        if ( !self ) return 0;
        return self.volBrigControl.volume;
    };
    
    _moreSettingFooterViewModel.initialBrightnessValue = ^float{
        __strong typeof(_self) self = _self;
        if ( !self ) return 0;
        return self.volBrigControl.brightness;
    };
    
    _moreSettingFooterViewModel.initialPlayerRateValue = ^float{
        __strong typeof(_self) self = _self;
        if ( !self ) return 0;
       return self.rate;
    };
    
    _moreSettingView.footerViewModel = _moreSettingFooterViewModel;
    return _moreSecondarySettingView;
}

#pragma mark -

- (void)setHiddenMoreSettingView:(BOOL)hiddenMoreSettingView {
    if ( hiddenMoreSettingView == _hiddenMoreSettingView ) return;
    _hiddenMoreSettingView = hiddenMoreSettingView;
    if ( hiddenMoreSettingView ) {
        _moreSettingView.transform = CGAffineTransformMakeTranslation(MoreSettingWidth, 0);
    }
    else {
        _moreSettingView.transform = CGAffineTransformIdentity;
    }
}

- (void)setHiddenMoreSecondarySettingView:(BOOL)hiddenMoreSecondarySettingView {
    if ( hiddenMoreSecondarySettingView == _hiddenMoreSecondarySettingView ) return;
    _hiddenMoreSecondarySettingView = hiddenMoreSecondarySettingView;
    if ( hiddenMoreSecondarySettingView ) {
        _moreSecondarySettingView.transform = CGAffineTransformMakeTranslation(MoreSettingWidth, 0);
    }
    else {
        _moreSecondarySettingView.transform = CGAffineTransformIdentity;
    }
}

- (void)setHiddenLeftControlView:(BOOL)hiddenLeftControlView {
    if ( hiddenLeftControlView == _hiddenLeftControlView ) return;
    _hiddenLeftControlView = hiddenLeftControlView;
    if ( _hiddenLeftControlView )
    {
        self.controlView.leftControlView.transform = CGAffineTransformMakeTranslation(-CYControlLeftH, 0);
    }
    else
    {
        self.controlView.leftControlView.transform =  CGAffineTransformIdentity;
    }
}

- (CYOrentationObserver *)orentation
{
    if (_orentation)
    {
        return _orentation;
    }
    _orentation = [[CYOrentationObserver alloc] initWithTarget:self.presentView container:self.view];
    __weak typeof(self) _self = self;
    
    //横屏允许条件
    _orentation.rotationCondition = ^BOOL(CYOrentationObserver * _Nonnull observer) {
        __strong typeof(_self) self = _self;
        if ( !self ) return NO;
        if ( self.stopped ) {
            if ( observer.isFullScreen ) return YES;
            else return NO;
        }
        if ( self.touchedScrollView ) return NO;
        switch (self.state) {
            case CYVideoPlayerPlayState_Unknown:
            case CYVideoPlayerPlayState_Prepare:
            case CYVideoPlayerPlayState_PlayFailed: return NO;
            default: break;
        }
        if ( self.playOnCell && !self.scrollIn ) return NO;
        if ( self.disableRotation ) return NO;
        if ( self.isLockedScrren ) return NO;
        return YES;
    };
    
    //横屏回调
    _orentation.orientationChanged = ^(CYOrentationObserver * _Nonnull observer) {
        __strong typeof(_self) self = _self;
        if ( !self )
        {
            return;
        }
        self.hideControl = NO;
        _cyAnima(^{
            self.controlView.previewView.hidden = YES;
            self.hiddenMoreSecondarySettingView = YES;
            self.hiddenMoreSettingView = YES;
            self.hiddenLeftControlView = !observer.isFullScreen;
            if ( observer.isFullScreen ) {
                _cyShowViews(@[self.controlView.topControlView.moreBtn,self.controlView.topControlView.titleBtn,]);
                [self.controlView.topControlView.moreBtn setImage:[UIImage imageNamed:[CYVideoPlayerResources bundleComponentWithImageName:@"cy_video_player_more"]] forState:UIControlStateNormal];
                if ( self.asset.hasBeenGeneratedPreviewImages ) {
                    _cyShowViews(@[self.controlView.topControlView.previewBtn]);
                }
                
                [self.controlView mas_remakeConstraints:^(MASConstraintMaker *make) {
                    make.center.offset(0);
                    make.height.equalTo(self.controlView.superview);
                    make.width.equalTo(self.controlView.mas_height).multipliedBy(16.0 / 9.0);
                }];
                
                //优化横屏播放器topview的显示
                [self.controlView.topControlView.backBtn mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.top.offset(20);
                }];
                
                [self.controlView.topControlView.titleBtn mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.top.offset(20);
                }];
                
                [self.controlView.topControlView.previewBtn mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.top.offset(20);
                }];
                
                [self.controlView.topControlView.moreBtn mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.top.offset(20);
                }];
                
                //横屏按钮界面处理
                self.controlView.bottomControlView.fullBtn.selected = YES;
            }
            else {
                _cyHiddenViews(@[self.controlView.topControlView.moreBtn,
                                 self.controlView.topControlView.previewBtn,]);
//                _cyHiddenViews(@[self.controlView.topControlView.previewBtn,]);
                _cyShowViews(@[self.controlView.topControlView.titleBtn,]);
                [self.controlView.topControlView.moreBtn setImage:[UIImage imageNamed:@"btn_navi_share"] forState:UIControlStateNormal];
                
                [self.controlView mas_remakeConstraints:^(MASConstraintMaker *make) {
                    make.edges.equalTo(self.controlView.superview);
                }];
                
                // 优化竖屏播放器topview的显示
                [self.controlView.topControlView.backBtn mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.top.offset(0);
                }];
                
                [self.controlView.topControlView.titleBtn mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.top.offset(0);
                }];
                
                [self.controlView.topControlView.previewBtn mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.top.offset(0);
                }];
                
                [self.controlView.topControlView.moreBtn mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.top.offset(0);
                }];
                
                //横屏按钮界面处理
                self.controlView.bottomControlView.fullBtn.selected = NO;
                
            }
        });//_cyAnima(^{})
        if ( self.rotatedScreen ) self.rotatedScreen(self, observer.isFullScreen);
    };//orientationChanged
    
    return _orentation;
}

- (CYVideoPlayerRegistrar *)registrar {
    if ( _registrar ) return _registrar;
    _registrar = [CYVideoPlayerRegistrar new];
    
    __weak typeof(self) _self = self;
    _registrar.willResignActive = ^(CYVideoPlayerRegistrar * _Nonnull registrar) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        self.lockScreen = YES;
        [self _pause];
    };
    
    _registrar.didBecomeActive = ^(CYVideoPlayerRegistrar * _Nonnull registrar) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        self.lockScreen = NO;
        if ( self.playOnCell && !self.scrollIn ) return;
        if ( self.state == CYVideoPlayerPlayState_PlayEnd ||
            self.state == CYVideoPlayerPlayState_Unknown ||
            self.state == CYVideoPlayerPlayState_PlayFailed ) return;
        if ( !self.userClickedPause ) [self play];
    };
    
    _registrar.oldDeviceUnavailable = ^(CYVideoPlayerRegistrar * _Nonnull registrar) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ( !self.userClickedPause ) [self play];
    };
    
//    _registrar.categoryChange = ^(CYVideoPlayerRegistrar * _Nonnull registrar) {
//        __strong typeof(_self) self = _self;
//        if ( !self ) return;
//
//    };
    
    return _registrar;
}

- (CYVolBrigControl *)volBrig {
    if ( _volBrigControl ) return _volBrigControl;
    _volBrigControl  = [CYVolBrigControl new];
    __weak typeof(self) _self = self;
    _volBrigControl.volumeChanged = ^(float volume) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ( self.moreSettingFooterViewModel.volumeChanged ) self.moreSettingFooterViewModel.volumeChanged(volume);
    };
    
    _volBrigControl.brightnessChanged = ^(float brightness) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ( self.moreSettingFooterViewModel.brightnessChanged ) self.moreSettingFooterViewModel.brightnessChanged(self.volBrigControl.brightness);
    };
    
    return _volBrigControl;
}

- (void)gesturesHandleWithTargetView:(UIView *)targetView {
    
    _gestureControl = [[CYPlayerGestureControl alloc] initWithTargetView:targetView];

    __weak typeof(self) _self = self;
    _gestureControl.triggerCondition = ^BOOL(CYPlayerGestureControl * _Nonnull control, UIGestureRecognizer *gesture) {
        __strong typeof(_self) self = _self;
        if ([self.control_delegate respondsToSelector:@selector(CYVideoPlayer:triggerCondition:gesture:)]) {
            return [self.control_delegate CYVideoPlayer:self triggerCondition:control gesture:gesture];
        }
        if ( !self ) return NO;
        if ( self.isLockedScrren ) return NO;
        CGPoint point = [gesture locationInView:gesture.view];
        if ( CGRectContainsPoint(self.moreSettingView.frame, point) ||
             CGRectContainsPoint(self.moreSecondarySettingView.frame, point) ||
             CGRectContainsPoint(self.controlView.previewView.frame, point) ) {
            return NO;
        }
        if ( [gesture isKindOfClass:[UIPanGestureRecognizer class]] &&
             self.playOnCell &&
            !self.orentation.fullScreen ) return NO;
        else return YES;
    };
    
    _gestureControl.singleTapped = ^(CYPlayerGestureControl * _Nonnull control) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ([self.control_delegate respondsToSelector:@selector(CYVideoPlayer:singleTapped:)]) {
            [self.control_delegate CYVideoPlayer:self singleTapped:control];
        }
        _cyAnima(^{
            if ( !self.hiddenMoreSettingView ) {
                self.hiddenMoreSettingView = YES;
            }
            else if ( !self.hiddenMoreSecondarySettingView ) {
                self.hiddenMoreSecondarySettingView = YES;
            }
            else {
                self.hideControl = !self.isHiddenControl;
            }
        });
        
    };
    
    _gestureControl.doubleTapped = ^(CYPlayerGestureControl * _Nonnull control) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ([self.control_delegate respondsToSelector:@selector(CYVideoPlayer:doubleTapped:)]) {
            [self.control_delegate CYVideoPlayer:self doubleTapped:control];
        }
        switch (self.state) {
            case CYVideoPlayerPlayState_Unknown:
            case CYVideoPlayerPlayState_Prepare:
                break;
            case CYVideoPlayerPlayState_Buffing:
            case CYVideoPlayerPlayState_Playing: {
                [self pause];
                self.userClickedPause = YES;
            }
                break;
            case CYVideoPlayerPlayState_Pause:
            case CYVideoPlayerPlayState_PlayEnd: {
                [self play];
                self.userClickedPause = NO;
            }
                break;
            case CYVideoPlayerPlayState_PlayFailed:
                break;
        }
    };
    
    _gestureControl.beganPan = ^(CYPlayerGestureControl * _Nonnull control, CYPanDirection direction, CYPanLocation location) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ([self.control_delegate respondsToSelector:@selector(CYVideoPlayer:beganPan:direction:location:)]) {
            [self.control_delegate CYVideoPlayer:self beganPan:control direction:direction location:location];
        }
        switch (direction) {
            case CYPanDirection_H: {
                [self _pause];
                _cyAnima(^{
                    _cyShowViews(@[self.controlView.draggingProgressView]);
                });
                if ( self.orentation.fullScreen )
                {
                    self.controlView.draggingProgressView.hiddenProgressSlider = NO;
                }
                else
                {
                    self.controlView.draggingProgressView.hiddenProgressSlider = YES;
                }
                
                self.controlView.draggingProgressView.progress = self.asset.progress;
                self.hideControl = YES;
            }
                break;
            case CYPanDirection_V: {
                switch (location) {
                    case CYPanLocation_Right: break;
                    case CYPanLocation_Left: {
                        [[UIApplication sharedApplication].keyWindow addSubview:self.volBrigControl.brightnessView];
                        [self.volBrigControl.brightnessView mas_remakeConstraints:^(MASConstraintMaker *make) {
                            make.size.mas_offset(CGSizeMake(155, 155));
                            make.center.equalTo([UIApplication sharedApplication].keyWindow);
                        }];
                        self.volBrigControl.brightnessView.transform = self.controlView.superview.transform;
                        _cyAnima(^{
                            _cyShowViews(@[self.volBrigControl.brightnessView]);
                        });
                    }
                        break;
                    case CYPanLocation_Unknown: break;
                }
            }
                break;
            case CYPanDirection_Unknown:
                break;
        }
        
    };
    
    _gestureControl.changedPan = ^(CYPlayerGestureControl * _Nonnull control, CYPanDirection direction, CYPanLocation location, CGPoint translate) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ([self.control_delegate respondsToSelector:@selector(CYVideoPlayer:changedPan:direction:location:)]) {
            [self.control_delegate CYVideoPlayer:self changedPan:control direction:direction location:location];
        }
        switch (direction) {
            case CYPanDirection_H: {
                self.controlView.draggingProgressView.progress += translate.x * 0.00003;//进度手势灵敏度
            }
                break;
            case CYPanDirection_V: {
                switch (location) {
                    case CYPanLocation_Left: {
                        CGFloat value = self.volBrigControl.brightness - translate.y * 0.006;
                        if ( value < 1.0 / 16 ) value = 1.0 / 16;
                        self.volBrigControl.brightness = value;
                    }
                        break;
                    case CYPanLocation_Right: {
                        CGFloat value = translate.y * 0.012;
                        self.volBrigControl.volume -= value;
                    }
                        break;
                    case CYPanLocation_Unknown: break;
                }
            }
                break;
            default:
                break;
        }
        
    };
    
    _gestureControl.endedPan = ^(CYPlayerGestureControl * _Nonnull control, CYPanDirection direction, CYPanLocation location) {
        if ([_self.control_delegate respondsToSelector:@selector(CYVideoPlayer:endedPan:direction:location:)]) {
            [_self.control_delegate CYVideoPlayer:_self endedPan:control direction:direction location:location];
        }
        switch ( direction ) {
            case CYPanDirection_H:{
                _cyAnima(^{
                    _cyHiddenViews(@[_self.controlView.draggingProgressView]);
                });
                [_self jumpedToTime:_self.controlView.draggingProgressView.progress * _self.asset.duration completionHandler:^(BOOL finished) {
                    __strong typeof(_self) self = _self;
                    if ( !self ) return;
                    [self play];
                }];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    _self.controlView.draggingProgressView.hiddenProgressSlider = NO;
                });
            }
                break;
            case CYPanDirection_V:{
                if ( location == CYPanLocation_Left ) {
                    _cyAnima(^{
                        __strong typeof(_self) self = _self;
                        if ( !self ) return;
                        _cyHiddenViews(@[self.volBrigControl.brightnessView]);
                    });
                }
            }
                break;
            case CYPanDirection_Unknown: break;
        }
        
    };
}

#pragma mark ======================================================
- (void)sliderClick:(CYSlider *)slider
{
    switch (slider.tag) {
        case CYVideoPlaySliderTag_Progress: {
            [self _pause];
            NSInteger currentTime = slider.value * self.asset.duration;
            __weak typeof(self) _self = self;
            [self jumpedToTime:currentTime completionHandler:^(BOOL finished) {
                __strong typeof(_self) self = _self;
                if ( !self ) return;
                [self play];
                [self _delayHiddenControl];
                _cyAnima(^{
                    _cyHiddenViews(@[self.controlView.draggingProgressView]);
                });
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    self.controlView.draggingProgressView.hiddenProgressSlider = NO;
                });
            }];
        }
            break;
            
        default:
            break;
    }
}

- (void)sliderWillBeginDragging:(CYSlider *)slider {
    switch (slider.tag) {
        case CYVideoPlaySliderTag_Progress: {
            [self _pause];
            NSInteger currentTime = slider.value * self.asset.duration;
            [self _refreshingTimeLabelWithCurrentTime:currentTime duration:self.asset.duration];
            _cyAnima(^{
                _cyShowViews(@[self.controlView.draggingProgressView]);
            });
            [self _cancelDelayHiddenControl];
            self.controlView.draggingProgressView.progress = slider.value;
            if ( self.orentation.fullScreen )
            {
                self.controlView.draggingProgressView.hiddenProgressSlider = NO;
            }
            else
            {
                self.controlView.draggingProgressView.hiddenProgressSlider = YES;
            }
        }
            break;
            
        default:
            break;
    }
}

- (void)sliderDidDrag:(CYSlider *)slider {
    switch (slider.tag) {
        case CYVideoPlaySliderTag_Progress: {
            NSInteger currentTime = slider.value * self.asset.duration;
            [self _refreshingTimeLabelWithCurrentTime:currentTime duration:self.asset.duration];
            __weak __typeof(&*self)weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.controlView.draggingProgressView.progress = slider.value;
            });
            
        }
            break;
            
        default:
            break;
    }
}

- (void)sliderDidEndDragging:(CYSlider *)slider {
    switch (slider.tag) {
        case CYVideoPlaySliderTag_Progress: {
            NSInteger currentTime = slider.value * self.asset.duration;
            __weak typeof(self) _self = self;
            [self jumpedToTime:currentTime completionHandler:^(BOOL finished) {
                __strong typeof(_self) self = _self;
                if ( !self ) return;
                [self play];
                [self _delayHiddenControl];
                _cyAnima(^{
                    _cyHiddenViews(@[self.controlView.draggingProgressView]);
                });
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    self.controlView.draggingProgressView.hiddenProgressSlider = NO;
                });
            }];
        }
            break;
            
        default:
            break;
    }
}

#pragma mark ======================================================

- (void)controlView:(CYVideoPlayerControlView *)controlView clickedBtnTag:(CYVideoPlayControlViewTag)tag {
    switch (tag) {
        case CYVideoPlayControlViewTag_Back: {
            if ( self.orentation.isFullScreen ) {
                if ( self.disableRotation ) return;
                else [self.orentation _changeOrientation];
            }
            else {
                if ( self.clickedBackEvent ) self.clickedBackEvent(self);
            }
        }
            break;
        case CYVideoPlayControlViewTag_Full: {
            [self.orentation _changeOrientation];
        }
            break;
            
        case CYVideoPlayControlViewTag_Play: {
            [self play];
            self.userClickedPause = NO;
        }
            break;
        case CYVideoPlayControlViewTag_Pause: {
            [self pause];
            self.userClickedPause = YES;
        }
            break;
        case CYVideoPlayControlViewTag_Replay: {
            _cyAnima(^{
                if ( !self.isLockedScrren ) self.hideControl = NO;
            });
            [self play];
        }
            break;
        case CYVideoPlayControlViewTag_Preview: {
            [self _cancelDelayHiddenControl];
            _cyAnima(^{
                self.controlView.previewView.hidden = !self.controlView.previewView.isHidden;
            });
        }
            break;
        case CYVideoPlayControlViewTag_Lock: {
            // 解锁
            self.lockScreen = NO;
        }
            break;
        case CYVideoPlayControlViewTag_Unlock: {
            // 锁屏
            self.lockScreen = YES;
            [self showTitle:@"已锁定"];
        }
            break;
        case CYVideoPlayControlViewTag_LoadFailed: {
            self.asset = [[CYVideoPlayerAssetCarrier alloc] initWithAssetURL:self.asset.assetURL beginTime:self.asset.beginTime scrollView:self.asset.scrollView indexPath:self.asset.indexPath superviewTag:self.asset.superviewTag];
        }
            break;
        case CYVideoPlayControlViewTag_More: {
            if (self.orentation.isFullScreen)
            {
                _cyAnima(^{
                    self.hiddenMoreSettingView = NO;
                    self.hideControl = YES;
                });
            }
            else
            {
                if ([self.delegate respondsToSelector:@selector(CYVideoPlayer:onShareBtnCick:)])
                {
                    [self.delegate CYVideoPlayer:self onShareBtnCick:self.controlView.topControlView.moreBtn];
                }
            }
        }
            break;
    }
}

- (void)controlView:(CYVideoPlayerControlView *)controlView didSelectPreviewItem:(CYVideoPreviewModel *)item {
    [self _pause];
    __weak typeof(self) _self = self;
    [self seekToTime:item.localTime completionHandler:^(BOOL finished) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        [self play];
    }];
}

#pragma mark

- (void)_itemPrepareToPlay {
    [self _startLoading];
    self.hideControl = YES;
    self.userClickedPause = NO;
    self.hiddenMoreSettingView = YES;
    self.hiddenMoreSecondarySettingView = YES;
    self.controlView.bottomProgressSlider.value = 0;
    self.controlView.bottomProgressSlider.bufferProgress = 0;
    if ( self.moreSettingFooterViewModel.volumeChanged ) {
        self.moreSettingFooterViewModel.volumeChanged(self.volBrigControl.volume);
    }
    if ( self.moreSettingFooterViewModel.brightnessChanged ) {
        self.moreSettingFooterViewModel.brightnessChanged(self.volBrigControl.brightness);
    }
    [self _prepareState];
}

- (void)_itemPlayFailed {
    [self _stopLoading];
    [self _playFailedState];
    self.error = self.asset.playerItem.error;
    _cyErrorLog(self.error);
}

- (void)_itemReadyToPlay {
    
    self.state = CYVideoPlayerPlayState_Ready;
    _cyAnima(^{
        self.hideControl = NO;
    });
    if ( self.autoplay && !self.userClickedPause && !self.suspend ) {
        if ([self.delegate respondsToSelector:@selector(CYVideoPlayerStartAutoPlaying:)])
        {
            [self.delegate CYVideoPlayerStartAutoPlaying:self];
        }
        [self play];
    }
}

- (void)_refreshingTimeLabelWithCurrentTime:(NSTimeInterval)currentTime duration:(NSTimeInterval)duration {
    self.controlView.bottomControlView.currentTimeLabel.text = _formatWithSec(currentTime);
    self.controlView.bottomControlView.durationTimeLabel.text = _formatWithSec(duration);
}

- (void)_refreshingTimeProgressSliderWithCurrentTime:(NSTimeInterval)currentTime duration:(NSTimeInterval)duration {
    self.controlView.bottomProgressSlider.value = self.controlView.bottomControlView.progressSlider.value = currentTime / duration;
}

- (void)_itemPlayEnd {
    [self _pause];
    [self jumpedToTime:0 completionHandler:nil];
    [self _playEndState];
}

- (void)_play {
    [self _stopLoading];
    [self.asset.player play];
}

- (void)_pause {
    [self.asset.player pause];
}


- (void)_startLoading {
    if ( _loadingView.isAnimating ) return;
    [_loadingView start];
}

- (void)_stopLoading {
    if ( !_loadingView.isAnimating ) return;
    [_loadingView stop];
}

- (void)_buffering {
    if ( !self.asset ||
        self.userClickedPause ||
        self.state == CYVideoPlayerPlayState_PlayFailed ||
        self.state == CYVideoPlayerPlayState_PlayEnd ||
        self.state == CYVideoPlayerPlayState_Unknown ||
        self.state == CYVideoPlayerPlayState_Playing ) return;
    
    [self _startLoading];
    [self _pause];
    self.state = CYVideoPlayerPlayState_Buffing;
    __weak typeof(self) _self = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(_self) self = _self;
        if ( !self ) return ;
        if ( !self.asset ||
            self.userClickedPause ||
            self.state == CYVideoPlayerPlayState_PlayFailed ||
            self.state == CYVideoPlayerPlayState_PlayEnd ||
            self.state == CYVideoPlayerPlayState_Unknown ||
            self.state == CYVideoPlayerPlayState_Playing ) return;
        
        if ( !self.asset.playerItem.isPlaybackLikelyToKeepUp ) {
            [self _buffering];
        }
        else {
            [self _stopLoading];
            if ( !self.suspend ) [self play];
        }
    });
}

- (void)setState:(CYVideoPlayerPlayState)state {
    if ( state == _state ) return;
    _state = state;
    _presentView.state = state;
    if ([self.delegate respondsToSelector:@selector(CYVideoPlayer:ChangeStatus:)])
    {
        [self.delegate CYVideoPlayer:self ChangeStatus:_state];
    }
}

@end





#pragma mark -

@implementation CYVideoPlayer (Setting)

- (void)setClickedBackEvent:(void (^)(CYVideoPlayer *player))clickedBackEvent {
    objc_setAssociatedObject(self, @selector(clickedBackEvent), clickedBackEvent, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void (^)(CYVideoPlayer * _Nonnull))clickedBackEvent {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)playWithURL:(NSURL *)playURL {
    [self playWithURL:playURL jumpedToTime:0];
}

// unit: sec.
- (void)playWithURL:(NSURL *)playURL jumpedToTime:(NSTimeInterval)time {
    self.asset = [[CYVideoPlayerAssetCarrier alloc] initWithAssetURL:playURL beginTime:time];
}

- (void)setAssetURL:(NSURL *)assetURL {
    [self playWithURL:assetURL jumpedToTime:0];
}

- (NSURL *)assetURL {
    return self.asset.assetURL;
}

- (void)setAsset:(CYVideoPlayerAssetCarrier *)asset {
    [self _clear];
    _asset = asset;
    if ( !asset || !asset.assetURL ) return;
    _view.alpha = 1;
    _presentView.asset = asset;
    _controlView.asset = asset;
    
    [self _itemPrepareToPlay];
    
    __weak typeof(self) _self = self;
    
    asset.playerItemStateChanged = ^(CYVideoPlayerAssetCarrier * _Nonnull asset, AVPlayerItemStatus status) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ( self.state == CYVideoPlayerPlayState_PlayEnd ) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            switch (status) {
                case AVPlayerItemStatusUnknown: break;
                case AVPlayerItemStatusFailed: {
                    [self _itemPlayFailed];
                }
                    break;
                case AVPlayerItemStatusReadyToPlay: {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        __strong typeof(_self) self = _self;
                        if ( !self ) return ;
                        [self _itemReadyToPlay];
                    });
                }
                    break;
            }
        });

    };
    
    asset.playTimeChanged = ^(CYVideoPlayerAssetCarrier * _Nonnull asset, NSTimeInterval currentTime, NSTimeInterval duration) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        [self _refreshingTimeProgressSliderWithCurrentTime:currentTime duration:duration];
        [self _refreshingTimeLabelWithCurrentTime:currentTime duration:duration];
    };
    
    asset.playDidToEnd = ^(CYVideoPlayerAssetCarrier * _Nonnull asset) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        [self _itemPlayEnd];
        if ( self.playDidToEnd ) self.playDidToEnd(self);
    };
    
    asset.loadedTimeProgress = ^(float progress) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        self.controlView.bottomControlView.progressSlider.bufferProgress = progress;
    };
    
    asset.beingBuffered = ^(BOOL state) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ( self.state == CYVideoPlayerPlayState_Buffing ) return;
        [self _buffering];
    };
    
    if ( asset.indexPath ) {
        /// 默认滑入
        self.playOnCell = YES;
        self.scrollIn = YES;
    }
    else {
        self.playOnCell = NO;
        self.scrollIn = NO;
    }
    
    // scroll view
    if ( asset.scrollView ) {
        /// 滑入
        asset.scrollIn = ^(CYVideoPlayerAssetCarrier * _Nonnull asset, UIView * _Nonnull superview) {
            __strong typeof(_self) self = _self;
            if ( !self ) return;
            if ( self.scrollIn ) return;
            self.scrollIn = YES;
            self.hideControl = NO;
            self.view.alpha = 1;
            if ( superview && self.view.superview != superview ) {
                [self.view removeFromSuperview];
                [superview addSubview:self.view];
                [self.view mas_remakeConstraints:^(MASConstraintMaker *make) {
                    make.edges.equalTo(self.view.superview);
                }];
            }
            //            if ( !self.userPaused &&
            //                 self.state != SJVideoPlayerPlayState_PlayEnd ) [self play];
        };
        
        /// 滑出
        asset.scrollOut = ^(CYVideoPlayerAssetCarrier * _Nonnull asset) {
            __strong typeof(_self) self = _self;
            if ( !self ) return;
            if ( !self.scrollIn ) return;
            self.scrollIn = NO;
            self.view.alpha = 0.001;
            if ( !self.userPaused &&
                self.state != CYVideoPlayerPlayState_PlayEnd ) [self pause];
        };
        
        ///
        asset.touchedScrollView = ^(CYVideoPlayerAssetCarrier * _Nonnull asset, BOOL tracking) {
            __strong typeof(_self) self = _self;
            if ( !self ) return;
            self.touchedScrollView = tracking;
        };
    }
}

- (CYVideoPlayerAssetCarrier *)asset {
    return _asset;
}

- (void)_clear {
    _presentView.asset = nil;
    _controlView.asset = nil;
    _asset = nil;
}

- (void)setMoreSettings:(NSArray<CYVideoPlayerMoreSetting *> *)moreSettings {
    objc_setAssociatedObject(self, @selector(moreSettings), moreSettings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSMutableSet<CYVideoPlayerMoreSetting *> *moreSettingsM = [NSMutableSet new];
    [moreSettings enumerateObjectsUsingBlock:^(CYVideoPlayerMoreSetting * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self addSetting:obj container:moreSettingsM];
    }];
    
    [moreSettingsM enumerateObjectsUsingBlock:^(CYVideoPlayerMoreSetting * _Nonnull obj, BOOL * _Nonnull stop) {
        [self dressSetting:obj];
    }];
    self.moreSettingView.moreSettings = moreSettings;
}

- (void)addSetting:(CYVideoPlayerMoreSetting *)setting container:(NSMutableSet<CYVideoPlayerMoreSetting *> *)moreSttingsM {
    [moreSttingsM addObject:setting];
    if ( !setting.showTowSetting ) return;
    [setting.twoSettingItems enumerateObjectsUsingBlock:^(CYVideoPlayerMoreSettingSecondary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self addSetting:(CYVideoPlayerMoreSetting *)obj container:moreSttingsM];
    }];
}

- (void)dressSetting:(CYVideoPlayerMoreSetting *)setting {
    if ( !setting.clickedExeBlock ) return;
    void(^clickedExeBlock)(CYVideoPlayerMoreSetting *model) = [setting.clickedExeBlock copy];
    __weak typeof(self) _self = self;
    if ( setting.isShowTowSetting ) {
        setting.clickedExeBlock = ^(CYVideoPlayerMoreSetting * _Nonnull model) {
            clickedExeBlock(model);
            __strong typeof(_self) self = _self;
            if ( !self ) return;
            self.moreSecondarySettingView.twoLevelSettings = model;
            _cyAnima(^{
                self.hiddenMoreSettingView = YES;
                self.hiddenMoreSecondarySettingView = NO;
            });
        };
        return;
    }
    
    setting.clickedExeBlock = ^(CYVideoPlayerMoreSetting * _Nonnull model) {
        clickedExeBlock(model);
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        _cyAnima(^{
            self.hiddenMoreSettingView = YES;
            if ( !model.isShowTowSetting ) self.hiddenMoreSecondarySettingView = YES;
        });
    };
}

- (NSArray<CYVideoPlayerMoreSetting *> *)moreSettings {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)settingPlayer:(void (^)(CYVideoPlayerSettings * _Nonnull))block {
    [self _addOperation:^(CYVideoPlayer *player) {
        if ( block ) block([player settings]);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:CYSettingsPlayerNotification object:[player settings]];
        });
    }];
}

- (CYVideoPlayerSettings *)settings {
    CYVideoPlayerSettings *setting = objc_getAssociatedObject(self, _cmd);
    if ( setting ) return setting;
    setting = [CYVideoPlayerSettings sharedVideoPlayerSettings];
    objc_setAssociatedObject(self, _cmd, setting, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return setting;
}

- (void)resetSetting {
    CYVideoPlayerSettings *setting = self.settings;
    //    setting.backBtnImage = [CYVideoPlayerResources imageNamed:@"cy_video_player_back"];
    //    setting.moreBtnImage = [CYVideoPlayerResources imageNamed:@"cy_video_player_more"];
    setting.backBtnImage = [CYVideoPlayerResources imageNamed:@"cy_video_player_back"];
    setting.moreBtnImage = [CYVideoPlayerResources imageNamed:@"cy_video_player_more"];
    setting.previewBtnImage = [CYVideoPlayerResources imageNamed:@""];
    setting.playBtnImage = [CYVideoPlayerResources imageNamed:@"cy_video_player_play"];
    setting.pauseBtnImage = [CYVideoPlayerResources imageNamed:@"cy_video_player_pause"];
    setting.fullBtnImage_nor = [CYVideoPlayerResources imageNamed:@"cy_video_player_fullscreen_nor"];
    setting.fullBtnImage_sel = [CYVideoPlayerResources imageNamed:@"cy_video_player_fullscreen_sel"];
    setting.lockBtnImage = [CYVideoPlayerResources imageNamed:@"cy_video_player_lock"];
    setting.unlockBtnImage = [CYVideoPlayerResources imageNamed:@"cy_video_player_unlock"];
    setting.replayBtnImage = [CYVideoPlayerResources imageNamed:@"cy_video_player_replay"];
    setting.replayBtnTitle = @"重播";
    setting.progress_traceColor = CYColorWithHEX(0x00c5b5);
    setting.progress_bufferColor = [UIColor colorWithWhite:0 alpha:0.2];
    setting.progress_trackColor =  [UIColor whiteColor];
    //    setting.progress_thumbImage = [CYVideoPlayerResources imageNamed:@"cy_video_player_thumbnail"];
    setting.progress_thumbImage_nor = [CYVideoPlayerResources imageNamed:@"cy_video_player_thumbnail_nor"];
    setting.progress_thumbImage_sel = [CYVideoPlayerResources imageNamed:@"cy_video_player_thumbnail_sel"];
    setting.progress_traceHeight = 3;
    setting.more_traceColor = CYColorWithHEX(0x00c5b5);
    setting.more_trackColor = [UIColor whiteColor];
    setting.more_trackHeight = 5;
    setting.loadingLineColor = [UIColor whiteColor];
    setting.title = @"";
    setting.enableProgressControl = YES;
}

- (void)setPlaceholder:(UIImage *)placeholder {
    _presentView.placeholder = placeholder;
}

- (void)setAutoplay:(BOOL)autoplay {
    objc_setAssociatedObject(self, @selector(isAutoplay), @(autoplay), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isAutoplay {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setGeneratePreviewImages:(BOOL)generatePreviewImages {
    objc_setAssociatedObject(self, @selector(generatePreviewImages), @(generatePreviewImages), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)generatePreviewImages {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setDisableRotation:(BOOL)disableRotation {
    objc_setAssociatedObject(self, @selector(disableRotation), @(disableRotation), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)disableRotation {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setRotatedScreen:(void (^)(CYVideoPlayer * _Nonnull, BOOL))rotatedScreen {
    objc_setAssociatedObject(self, @selector(rotatedScreen), rotatedScreen, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void (^)(CYVideoPlayer * _Nonnull, BOOL))rotatedScreen {
    return objc_getAssociatedObject(self, _cmd);
}

- (BOOL)isFullScreen {
    return self.orentation.isFullScreen;
}

- (void)setPlayDidToEnd:(void (^)(CYVideoPlayer * _Nonnull))playDidToEnd {
    objc_setAssociatedObject(self, @selector(playDidToEnd), playDidToEnd, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void (^)(CYVideoPlayer * _Nonnull))playDidToEnd {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setControlViewDisplayStatus:(void (^)(CYVideoPlayer * _Nonnull, BOOL))controlViewDisplayStatus {
    objc_setAssociatedObject(self, @selector(controlViewDisplayStatus), controlViewDisplayStatus, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void (^)(CYVideoPlayer * _Nonnull, BOOL))controlViewDisplayStatus {
    return objc_getAssociatedObject(self, _cmd);
}

- (BOOL)controlViewDisplayed {
    return !self.isHiddenControl;
}

- (void)setRate:(float)rate {
    if ( self.rate == rate ) return;
    objc_setAssociatedObject(self, @selector(rate), @(rate), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if ( !self.asset ) return;
    self.asset.player.rate = rate;
    self.userClickedPause = NO;
    _cyAnima(^{
        [self _playState];
    });
    if ( self.moreSettingFooterViewModel.playerRateChanged )
        self.moreSettingFooterViewModel.playerRateChanged(rate);
    if ( self.rateChanged ) self.rateChanged(self);
}

- (float)rate {
    return [objc_getAssociatedObject(self, _cmd) floatValue];
}

- (void (^)(CYVideoPlayer * _Nonnull))rateChanged {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setRateChanged:(void (^)(CYVideoPlayer * _Nonnull))rateChanged {
    objc_setAssociatedObject(self, @selector(rateChanged), rateChanged, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setInternallyChangedRate:(void (^)(CYVideoPlayer * _Nonnull, float))internallyChangedRate {
    objc_setAssociatedObject(self, @selector(internallyChangedRate), internallyChangedRate, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void (^)(CYVideoPlayer * _Nonnull, float))internallyChangedRate {
    return objc_getAssociatedObject(self, _cmd);
}

@end





#pragma mark -

@implementation CYVideoPlayer (Control)

- (BOOL)userPaused {
    return self.userClickedPause;
}

- (id<CYVideoPlayerControlDelegate>)control_delegate
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setControl_delegate:(id<CYVideoPlayerControlDelegate>)control_delegate
{
    objc_setAssociatedObject(self, @selector(control_delegate), control_delegate, OBJC_ASSOCIATION_ASSIGN);
}


- (BOOL)play {
    self.suspend = NO;
    self.stopped = NO;
    
    if ( !self.asset ) return NO;
    self.userClickedPause = NO;
    if ( self.state != CYVideoPlayerPlayState_Playing ) {
        _cyAnima(^{
            [self _playState];
        });
    }
    [self _play];
    return YES;
}


- (BOOL)pause {
    self.suspend = YES;
    
    if ( !self.asset ) return NO;
    if ( self.state != CYVideoPlayerPlayState_Pause ) {
        _cyAnima(^{
            [self _pauseState];
            self.hideControl = NO;
        });
    }
    [self _pause];
    if ( !self.playOnCell || self.orentation.fullScreen ) [self showTitle:@"已暂停"];
    return YES;
}

- (void)stop {
    self.suspend = NO;
    self.stopped = YES;
    
    if ( !self.asset ) return;
    if ( self.state != CYVideoPlayerPlayState_Unknown ) {
        _cyAnima(^{
            [self _unknownState];
        });
        [self _stopLoading];
    }
    [self _clear];
}

- (void)stopAndFadeOut {
    self.suspend = NO;
    self.stopped = YES;
    // state
    if ( self.state != CYVideoPlayerPlayState_Unknown ) {
        _cyAnima(^{
            [self _unknownState];
        });
    }
    // pause
    [self _pause];
    // fade out
    [UIView animateWithDuration:0.5 animations:^{
        self.view.alpha = 0.001;
    } completion:^(BOOL finished) {
        [self stop];
        [_view removeFromSuperview];
    }];
}

- (void)jumpedToTime:(NSTimeInterval)time completionHandler:(void (^ __nullable)(BOOL finished))completionHandler {
    if ( isnan(time) ) { return;}
    CMTime seekTime = CMTimeMakeWithSeconds(time, NSEC_PER_SEC);
    [self seekToTime:seekTime completionHandler:completionHandler];
}

- (void)seekToTime:(CMTime)time completionHandler:(void (^ __nullable)(BOOL finished))completionHandler {
    [self _startLoading];
    __weak typeof(self) _self = self;
    [self.asset seekToTime:time completionHandler:^(BOOL finished) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        [self _stopLoading];
        if ( completionHandler ) completionHandler(finished);
    }];
}

- (UIImage *)randomScreenshot {
    return [self.asset randomScreenshot];
}

- (NSArray<CYVideoPreviewModel *> *)getPreviewImages
{
    return self.controlView.previewView.previewImages;
}


- (void)stopRotation {
    self.disableRotation = YES;
}

- (void)enableRotation {
    self.disableRotation = NO;
}

- (void)setLockscreen:(LockScreen)lockscreen
{
    objc_setAssociatedObject(self, @selector(lockscreen), lockscreen, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (LockScreen)lockscreen
{
    return objc_getAssociatedObject(self, _cmd);
}

@end


@implementation CYVideoPlayer (Prompt)

- (CYPrompt *)prompt {
    CYPrompt *prompt = objc_getAssociatedObject(self, _cmd);
    if ( prompt ) return prompt;
    prompt = [CYPrompt promptWithPresentView:self.presentView];
    objc_setAssociatedObject(self, _cmd, prompt, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return prompt;
}

- (void)showTitle:(NSString *)title {
    [self showTitle:title duration:1];
}

- (void)showTitle:(NSString *)title duration:(NSTimeInterval)duration {
    [self.prompt showTitle:title duration:duration];
}

- (void)hiddenTitle {
    [self.prompt hidden];
}

@end
