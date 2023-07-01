//
//  CYFFmpegPlayer.m
//  CYPlayer
//
//  Created by 黄威 on 2018/7/19.
//  Copyright © 2018年 Sutan. All rights reserved.
//

#import "CYFFmpegPlayer.h"
#import "CYPlayerDecoder.h"
#import "CYAudioManager.h"
#import "CYLogger.h"
#import "CYPlayerGLView.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import <Masonry/Masonry.h>
#import "CYGCDManager.h"

//Views
#import "CYVideoPlayerControlView.h"
#import "CYLoadingView.h"
#import "CYVideoPlayerMoreSettingsView.h"
#import "CYVideoPlayerMoreSettingSecondaryView.h"
#import "CYVideoPlayerPresentView.h"


//Models
#import "CYVolBrigControl.h"
#import "CYPlayerGestureControl.h"
#import "CYOrentationObserver.h"
#import "CYTimerControl.h"
#import "CYVideoPlayerRegistrar.h"
#import "CYVideoPlayerSettings.h"
#import "CYVideoPlayerResources.h"
#import "CYPrompt.h"
#import "CYVideoPlayerMoreSetting.h"
#import "CYPCMAudioManager.h"
#import "CYSonicManager.h"

//Others
#import <objc/message.h>
#import <sys/sysctl.h>
#import <mach/mach.h>


//#define USE_OPENAL @"UseCYPCMAudioManager"

#define USE_AUDIOTOOL @"UseCYAudioManager"

#define CYPLAYER_MAX_TIMEOUT 120.0 //秒

#define MoreSettingWidth (MAX([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height) * 0.382)

#define CYColorWithHEX(hex) [UIColor colorWithRed:(float)((hex & 0xFF0000) >> 16)/255.0 green:(float)((hex & 0xFF00) >> 8)/255.0 blue:(float)(hex & 0xFF)/255.0 alpha:1.0]

#define CY_DocumentDir [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]
#define CY_CachesDir [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]
#define CY_BundlePath(res) [[NSBundle mainBundle] pathForResource:res ofType:nil]
#define CY_DocumentPath(res) [CY_DocumentDir stringByAppendingPathComponent:res]
#define CY_CachesPath(res) [CY_CachesDir stringByAppendingPathComponent:res]


inline static void _cyErrorLog(id msg) {
    NSLog(@"__error__: %@", msg);
}

inline static void _cyHiddenViews(NSArray<UIView *> *views) {
    [views enumerateObjectsUsingBlock:^(UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.alpha = 0.0;
        obj.hidden = YES;
    }];
}

inline static void _cyShowViews(NSArray<UIView *> *views) {
    [views enumerateObjectsUsingBlock:^(UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.alpha = 1.0;
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


NSString * const CYPlayerParameterMinBufferedDuration = @"CYPlayerParameterMinBufferedDuration";
NSString * const CYPlayerParameterMaxBufferedDuration = @"CYPlayerParameterMaxBufferedDuration";
NSString * const CYPlayerParameterDisableDeinterlacing = @"CYPlayerParameterDisableDeinterlacing";

static NSMutableDictionary * gHistory = nil;//播放记录


#define LOCAL_MIN_BUFFERED_DURATION   1
#define LOCAL_MAX_BUFFERED_DURATION   4
#define NETWORK_MIN_BUFFERED_DURATION 2.0
#define NETWORK_MAX_BUFFERED_DURATION 8.0
#define MAX_BUFFERED_DURATION_MEMORY_USED_PERCENT 100//100 相当于关闭
#define HAS_PLENTY_OF_MEMORY [self getAvailableMemorySize] >= 0//0相当于关闭

@interface CYFFmpegPlayer ()<
CYVideoPlayerControlViewDelegate,
CYSliderDelegate,
CYPCMAudioManagerDelegate,
CYAudioManagerDelegate>
{
    CGFloat             _moviePosition;//播放到的位置
    CGFloat             _audioPosition;//播放到的位置
    NSDictionary        *_parameters;
    NSString            *_path;
    BOOL                _interrupted;
    BOOL                _buffered;
    BOOL                _savedIdleTimer;
    BOOL                _isDraging;
    
    dispatch_queue_t    _asyncDecodeQueue;
    dispatch_queue_t    _videoQueue;
    dispatch_queue_t    _audioQueue;
    dispatch_queue_t    _progressQueue;
    NSMutableArray      *_videoFrames;
    NSMutableArray      *_audioFrames;
    NSMutableArray      *_subtitles;
    CGFloat             _minBufferedDuration;
    CGFloat             _maxBufferedDuration;
    NSData              *_currentAudioFrame;
    CGFloat             _videoBufferedDuration;
    CGFloat             _audioBufferedDuration;
    NSUInteger          _currentAudioFramePos;
    BOOL                _disableUpdateHUD;
    NSTimeInterval      _tickCorrectionTime;
    NSTimeInterval      _tickCorrectionPosition;
    NSUInteger          _tickCounter;
    
    //生成预览图
    CYPlayerDecoder      *_generatedPreviewImagesDecoder;
    NSMutableArray      *_generatedPreviewImagesVideoFrames;
    BOOL                _generatedPreviewImageInterrupted;
    
    //UI
    //    CYPlayerGLView       *_glView;
    UIImageView         *_imageView;
    
    //Gesture
    BOOL                _positionUpdating;
    CGFloat             _targetPosition;
    
    //缓冲到内存的进度
    CGFloat             _videoRAMBufferPostion;
    CGFloat             _audioRAMBufferPostion;
    
    //判断失败的时间
    CFAbsoluteTime      _cantPlayStartTime;
#ifdef DEBUG
    UILabel             *_messageLabel;
    NSTimeInterval      _debugStartTime;
    NSUInteger          _debugAudioStatus;
    NSDate              *_debugAudioStatusTS;
#endif
    CFAbsoluteTime      _videoTickStartTime;//用于"渲染执行效率"的计算
    CFAbsoluteTime      _interval_from_last_buffer_laoding;//计算两次缓冲时间间隔,动态调整最小缓冲时间
    
    //当前清晰度
    CYFFmpegPlayerDefinitionType _definitionType;
    BOOL _isChangingDefinition;
    NSInteger _currentSelections;
    BOOL _isChangingSelections;
    
}

@property (readwrite) BOOL playing;
@property (readwrite) BOOL decoding;
@property (readwrite) BOOL unarchiving;
@property (readwrite, strong) CYArtworkFrame *artworkFrame;

@property (nonatomic, strong, readonly) CYOrentationObserver *orentation;
@property (nonatomic, strong, readonly) dispatch_queue_t workQueue;

@property (nonatomic, assign, readwrite) CYFFmpegPlayerPlayState state;
@property (nonatomic, assign, readwrite) BOOL hiddenMoreSettingView;
@property (nonatomic, assign, readwrite) BOOL hiddenMoreSecondarySettingView;
@property (nonatomic, assign, readwrite) BOOL hiddenLeftControlView;
@property (nonatomic, assign, readwrite)  BOOL hasBeenGeneratedPreviewImages;
@property (nonatomic, assign, readwrite) BOOL userClickedPause;
@property (nonatomic, assign, readwrite) BOOL stopped;
@property (nonatomic, assign, readwrite) BOOL touchedScrollView;
@property (nonatomic, assign, readwrite) BOOL suspend; // Set it when the [`pause` + `play` + `stop`] is called.
@property (nonatomic, assign, readwrite) BOOL enableAudio;
@property (nonatomic, strong, readwrite) NSError *error;

@end

@implementation CYFFmpegPlayer
{
    CYVideoPlayerPresentView *_presentView;
    CYVideoPlayerControlView *_controlView;
    CYVideoPlayerMoreSettingsView *_moreSettingView;
    CYVideoPlayerMoreSettingSecondaryView *_moreSecondarySettingView;
    CYMoreSettingsFooterViewModel *_moreSettingFooterViewModel;
    CYVolBrigControl *_volBrigControl;
    CYLoadingView *_loadingView;
    CYPlayerGestureControl *_gestureControl;
    CYVideoPlayerBaseView *_view;
    CYOrentationObserver *_orentation;
    dispatch_queue_t _workQueue;
    CYVideoPlayerRegistrar *_registrar;
}

+ (instancetype)sharedPlayer {
    static id _instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

+ (void)initialize
{
    if (!gHistory)
    {
        gHistory = [[NSMutableDictionary alloc] initWithCapacity:20];
        
        NSLog(@"%@", gHistory);
    }
}

- (instancetype)init
{
    if (self = [super init]) {
        [self resetSetting];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsPlayerNotification:) name:CYSettingsPlayerNotification object:nil];
        
    }
    return self;
}

+ (id) movieViewWithContentPath: (NSString *) path
                     parameters: (NSDictionary *) parameters
{
    return [[self alloc] initWithContentPath: path parameters: parameters];;
}

- (id) initWithContentPath: (NSString *) path
                parameters: (NSDictionary *) parameters
{
    NSAssert(path.length > 0, @"empty path");
    
    self = [super init];
    if (self) {
        [self resetSetting];
        [self setupPlayerWithPath:path parameters:parameters];
        self.rate = 1.0;
        [[CYSonicManager sonicManager] setPlaySpeed:1.0];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsPlayerNotification:) name:CYSettingsPlayerNotification object:nil];
    }
    return self;
}

- (void)setupPlayerWithPath:(NSString *)path parameters: (NSDictionary *) parameters
{
    id<CYAudioManager> audioManager = [CYAudioManager audioManager];
    BOOL canUseAudio = [audioManager activateAudioSession];
    //    BOOL canUseAudio = YES;
    
    [self view];
    [self orentation];
    [self volBrig];
    __weak typeof(self) _self = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [_self settingPlayer:^(CYVideoPlayerSettings * _Nonnull settings) {
            
        }];
    });
    [self registrar];
    
    [self _unknownState];
    
    [self _itemPrepareToPlay];
    
    if (!_progressQueue)
    {
        //        _progressQueue = dispatch_queue_create("CYPlayer Progress", DISPATCH_QUEUE_SERIAL);
        _progressQueue  = dispatch_get_main_queue();
    }
    
    if (!_videoQueue)
    {
        //        _videoQueue = dispatch_queue_create("CYPlayer Video", DISPATCH_QUEUE_SERIAL);
        _videoQueue  = dispatch_get_main_queue();
    }
    
    if (!_audioQueue)
    {
        _audioQueue = dispatch_queue_create("CYPlayer Audio", DISPATCH_QUEUE_SERIAL);
        //        _audioQueue  = dispatch_get_main_queue();
    }
    
    _moviePosition = 0;
    //        self.wantsFullScreenLayout = YES;
    
    _parameters = parameters;
    _path = path;
    
    __block CYPlayerDecoder *decoder = [[CYPlayerDecoder alloc] init];
    CYVideoDecodeType type = CYVideoDecodeTypeVideo;
    if (canUseAudio)
    {
        type |= CYVideoDecodeTypeAudio;
    }
    else
    {
        LoggerAudio(0, @"Can not open Audio Session");
    }
    [decoder setDecodeType:type];//
    
    self.controlView.decoder = decoder;
    
    __weak __typeof(&*self)weakSelf = self;
    
    decoder.interruptCallback = ^BOOL(){
        __strong __typeof(&*self)strongSelf = weakSelf;
        return strongSelf ? [strongSelf interruptDecoder] : YES;
    };
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        __strong __typeof(&*self)strongSelf = weakSelf;
        
        NSError *error = nil;
        [decoder openFile:path error:&error];
        [decoder setupVideoFrameFormat:CYVideoFrameFormatYUV];
        [decoder setUseHWDecompressor:strongSelf.settings.useHWDecompressor];
        if (strongSelf) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                __strong __typeof(&*self)strongSelf2 = weakSelf;
                if (strongSelf2 && !strongSelf.stopped) {
                    [strongSelf2 setMovieDecoder:decoder withError:error];
                }
                else if (error) {
                    [weakSelf _itemPlayFailed];
                }
            });
        }
    });
}


- (void)changeSelectionsPath:(NSString *)path
{
    _path = path;
    
    //开始播放
    self.rate = 1.0;
    [[CYSonicManager sonicManager] setPlaySpeed:self.rate];
    
    __block CYPlayerDecoder *decoder = [[CYPlayerDecoder alloc] init];
    CYVideoDecodeType type = _decoder.decodeType;
    [decoder setDecodeType:type];
    __weak __typeof(&*self)weakSelf = self;
    
    decoder.interruptCallback = ^BOOL(){
        __strong __typeof(&*self)strongSelf = weakSelf;
        return strongSelf ? [strongSelf interruptDecoder] : YES;
    };
    [self pause];
    self.autoplay = YES;
    self.suspend = NO;//手动暂停会挂起,这里要取消挂起才会自动播放
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        __strong __typeof(&*self)strongSelf = weakSelf;
        
        NSError *error = nil;
        [decoder openFile:path error:&error];
        [decoder setupVideoFrameFormat:CYVideoFrameFormatYUV];
        
        if (strongSelf) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                __strong __typeof(&*self)strongSelf2 = weakSelf;
                if (strongSelf2 && !strongSelf.stopped) {
                    [decoder setPosition:0];
                    strongSelf2->_moviePosition = 0;
                    //关闭原先的解码器
                    //                    [strongSelf.decoder closeFile];
                    strongSelf2.controlView.decoder = decoder;
                    //清除旧的缓存
                    [strongSelf2 freeBufferedFrames];
                    //播放器连接新的解码器decoder
                    [strongSelf2 setMovieDecoder:decoder withError:error];
                    
                    //                    [strongSelf2 showTitle:@"切换完成"];
                    strongSelf2->_isChangingSelections = NO;
                }
                else if (error) {
                    [weakSelf _itemPlayFailed];
                    strongSelf2->_isChangingSelections = NO;
                }
            });
        }
    });
}

- (void)changeDefinitionPath:(NSString *)path
{
    _path = path;
    
    __block CYPlayerDecoder *decoder = [[CYPlayerDecoder alloc] init];
    CYVideoDecodeType type = _decoder.decodeType;
    [decoder setDecodeType:type];
    __weak __typeof(&*self)weakSelf = self;
    
    decoder.interruptCallback = ^BOOL(){
        __strong __typeof(&*self)strongSelf = weakSelf;
        return strongSelf ? [strongSelf interruptDecoder] : YES;
    };
    self.autoplay = YES;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        __strong __typeof(&*self)strongSelf = weakSelf;
        
        NSError *error = nil;
        [decoder openFile:path error:&error];
        [decoder setupVideoFrameFormat:CYVideoFrameFormatYUV];
        
        if (strongSelf) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                __strong __typeof(&*self)strongSelf2 = weakSelf;
                if (strongSelf2 && !strongSelf.stopped) {
                    [decoder setPosition:strongSelf.decoder.position];
                    //关闭原先的解码器
                    //                    [strongSelf.decoder closeFile];
                    strongSelf2.controlView.decoder = decoder;
                    //播放器连接新的解码器decoder
                    [strongSelf2 setMovieDecoder:decoder withError:error];
                    
                    [strongSelf2 showTitle:@"切换完成"];
                    strongSelf2->_isChangingDefinition = NO;
                }
                else if (error) {
                    [weakSelf _itemPlayFailed];
                    strongSelf2->_isChangingDefinition = NO;
                }
            });
        }
    });
}

- (void)changeLiveDefinitionPath:(NSString *)path
{
    _path = path;
    
    __block CYPlayerDecoder *decoder = [[CYPlayerDecoder alloc] init];
    CYVideoDecodeType type = _decoder.decodeType;
    [decoder setDecodeType:type];
    __weak __typeof(&*self)weakSelf = self;
    
    decoder.interruptCallback = ^BOOL(){
        __strong __typeof(&*self)strongSelf = weakSelf;
        return strongSelf ? [strongSelf interruptDecoder] : YES;
    };
    self.autoplay = YES;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        __strong __typeof(&*self)strongSelf = weakSelf;
        
        NSError *error = nil;
        [decoder openFile:path error:&error];
        [decoder setupVideoFrameFormat:CYVideoFrameFormatYUV];
        
        if (strongSelf) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                __strong __typeof(&*self)strongSelf2 = weakSelf;
                if (strongSelf2 && !strongSelf.stopped) {
                    //关闭原先的解码器
                    //                    [strongSelf.decoder closeFile];
                    strongSelf2.controlView.decoder = decoder;
                    //播放器连接新的解码器decoder
                    [strongSelf2 setMovieDecoder:decoder withError:error];
                    
                    [strongSelf2 showTitle:@"切换完成"];
                    strongSelf2->_isChangingDefinition = NO;
                }
                else if (error) {
                    [weakSelf _itemPlayFailed];
                    strongSelf2->_isChangingDefinition = NO;
                }
            });
        }
    });
}

- (void)refreshSelectionsBtnStatus
{
    if (_isChangingSelections)
    {
        [self.controlView.bottomControlView.selectionsBtn setTitle:@"正在切换" forState:UIControlStateNormal];
        self.controlView.bottomControlView.selectionsBtn.enabled = NO;
    }
    else
    {
        [self.controlView.bottomControlView.selectionsBtn setTitle:@"选集" forState:UIControlStateNormal];
        self.controlView.bottomControlView.selectionsBtn.enabled = YES;
    }
}

- (void)refreshDefinitionBtnStatus
{
    NSString * title = @"";
    if (_isChangingDefinition)
    {
        [self.controlView.bottomControlView.definitionBtn setTitle:@"正在切换" forState:UIControlStateNormal];
        self.controlView.bottomControlView.definitionBtn.enabled = NO;
    }
    else
    {
        switch (_definitionType) {
            case CYFFmpegPlayerDefinitionLLD:
            {
                title = @"流畅";
            }
                break;
            case CYFFmpegPlayerDefinitionLSD:
            {
                title = @"标清";
            }
                break;
            case CYFFmpegPlayerDefinitionLHD:
            {
                title = @"高清";
            }
                break;
            case CYFFmpegPlayerDefinitionLUD:
            {
                title = @"超清";
            }
                break;
                
            default:
            {
                title = @"标清";
            }
                break;
        }
        
        [self.controlView.bottomControlView.definitionBtn setTitle:title forState:UIControlStateNormal];
        self.controlView.bottomControlView.definitionBtn.enabled = YES;
    }
}


- (void) dealloc
{
#ifdef USE_OPENAL
    [[CYPCMAudioManager audioManager] stopAndCleanBuffer];
#endif
    
#ifdef USE_AUDIOTOOL
//    [self enableAudioTick:NO];
#endif
    while ((_decoder.validVideo ? _videoFrames.count : 0) + (_decoder.validAudio ? _audioFrames.count : 0) > 0) {
        
        @synchronized(_videoFrames) {
            if (_videoFrames.count > 0)
            {
                [_videoFrames removeObjectAtIndex:0];
            }
        }
        
        const CGFloat duration = _decoder.isNetwork ? .0f : 0.1f;
        //        [_decoder decodeFrames:duration];
        @synchronized(_audioFrames) {
            if (_audioFrames.count > 0)
            {
                [_audioFrames removeObjectAtIndex:0];
            }
        }
        LoggerStream(1, @"%@ waiting dealloc", self);
    }
    
    self.playing = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_asyncDecodeQueue) {
        // Not needed as of ARC.
        //        dispatch_release(_asyncDecodeQueue);
        _asyncDecodeQueue = NULL;
    }
    
    if (_progressQueue) {
        // Not needed as of ARC.
        //        dispatch_release(_asyncDecodeQueue);
        _progressQueue = NULL;
    }
    
    if (_videoQueue) {
        // Not needed as of ARC.
        //        dispatch_release(_asyncDecodeQueue);
        _videoQueue = NULL;
    }
    
    if (_audioQueue) {
        // Not needed as of ARC.
        //        dispatch_release(_asyncDecodeQueue);
        _audioQueue = NULL;
    }
    
    LoggerStream(1, @"%@ dealloc", self);
}

- (void)loadView {
    
    if (_decoder) {
        
        [self setupPresentView];
        
    }
}

- (void)didReceiveMemoryWarning
{
    if (self.playing) {
        
        [self pause];
        [self freeBufferedFrames];
        
        if (_maxBufferedDuration > 0) {
            
            _minBufferedDuration = _maxBufferedDuration = 0;
            [self play];
            
            LoggerStream(0, @"didReceiveMemoryWarning, disable buffering and continue playing");
            
        } else {
            
            // force ffmpeg to free allocated memory
            [_decoder closeFile];
            [_decoder openFile:nil error:nil];
            
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                        message:NSLocalizedString(@"Out of memory", nil)
                                       delegate:nil
                              cancelButtonTitle:NSLocalizedString(@"Close", nil)
                              otherButtonTitles:nil] show];
        }
        
    } else {
        
        [self freeBufferedFrames];
        [_decoder closeFile];
        [_decoder openFile:nil error:nil];
    }
}


# pragma mark - UI处理
- (UIView *)view {
    if ( _view )
    {
        [_presentView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(_presentView.superview);
        }];
        return _view;
    }
    _view = [CYVideoPlayerBaseView new];
    _view.backgroundColor = [UIColor blackColor];
    [_view addSubview:self.presentView];
    [_view addSubview:self.controlView];
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
        if ( !self.decoder ) return;
        if (self.rate == rate) { return; }
//        [self pause];
//        [self _startLoading];
        self.rate = rate;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            //        dispatch_async(dispatch_get_main_queue(), ^{
            //刷新audioManagr缓存队列中未来得及播放完的数据
#ifdef USE_OPENAL
            [[CYPCMAudioManager audioManager] stopAndCleanBuffer];
#endif
//            [_self freeBufferedFrames];
//            [_self play];
        });
        
        
        
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


# pragma mark - 公开方法
- (double)currentTime
{
    return self.decoder.validVideo ? _moviePosition : _audioPosition;
}

- (NSTimeInterval)totalTime {
    return self.decoder.duration;
}

- (void)viewDidAppear
{
    if (_decoder) {
        
        [self restorePlay];
        
    } else {
        
    }
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:[UIApplication sharedApplication]];
}

- (void)viewDidDisappear
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_decoder) {
        
        [self stop];
        
        NSMutableDictionary * gHis = [self getHistory];
        if (_moviePosition == 0 || _decoder.isEOF)
            [gHis removeObjectForKey:_decoder.path];
        else if (!_decoder.isNetwork)
            [gHis setValue:[NSNumber numberWithFloat:_moviePosition]
                    forKey:_decoder.path];
    }
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:_savedIdleTimer];
    
    _buffered = NO;
    _positionUpdating = NO;
    _interrupted = YES;
    
    LoggerStream(1, @"viewWillDisappear %@", self);
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
    if (self.userClickedPause ||
        self.state == CYFFmpegPlayerPlayState_PlayFailed ||
        self.state == CYFFmpegPlayerPlayState_PlayEnd ||
        self.state == CYFFmpegPlayerPlayState_Unknown ) return;
    
    [self _startLoading];
    self.state = CYFFmpegPlayerPlayState_Buffing;
}

-(void) _play
{
    if (!_buffered)
    {
        [self _stopLoading];
    }
    
    if (self.playing)
        return;
    
    if (!_decoder.validVideo &&
        !_decoder.validAudio) {
        
        return;
    }
    
    if (_interrupted)
        return;
    
    self.playing = YES;
    _interrupted = NO;
    _disableUpdateHUD = NO;
    _tickCorrectionTime = 0;
    _tickCounter = 0;
    
#ifdef DEBUG
    _debugStartTime = -1;
#endif
    
    
    //    [self asyncDecodeFrames];
    [self concurrentAsyncDecodeFrames];
    
    __weak typeof(&*self)weakSelf = self;
//    //刮起当前生成图片的进程
//    dispatch_suspend([CYGCDManager sharedManager].generate_preview_images_dispatch_queue);
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        dispatch_resume([CYGCDManager sharedManager].generate_preview_images_dispatch_queue);
//    });
    
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    dispatch_after(popTime, _progressQueue, ^(void){
        
        [weakSelf progressTick];
        
        if (weakSelf.decoder.validAudio)
        {
#ifdef USE_OPENAL
            [weakSelf audioTick];
            [[CYPCMAudioManager audioManager] setPlayRate:weakSelf.rate];
#endif
#ifdef USE_AUDIOTOOL
            [weakSelf enableAudioTick:YES];
#endif
        }
        
        if (weakSelf.decoder.validVideo)
        {
            [weakSelf videoTick];
        }
    });
    
    
    
    LoggerStream(1, @"play movie");
}

- (void) _pause
{
    if (!self.playing)
        return;
    
    self.playing = NO;
    //_interrupted = YES;
#ifdef USE_OPENAL
    [[CYPCMAudioManager audioManager] setPlayRate:0];
#endif
    
#ifdef USE_AUDIOTOOL
    [self enableAudioTick:NO];
#endif
    LoggerStream(1, @"pause movie");
}

- (void)_stop
{
    if (!self.playing)
        return;
    
    self.playing = NO;
    _interrupted = YES;
    _generatedPreviewImageInterrupted = YES;
#ifdef USE_OPENAL
    [[CYPCMAudioManager audioManager] setPlayRate:0];//及时停止声音
#endif
    
#ifdef USE_AUDIOTOOL
    [self enableAudioTick:NO];
#endif
    LoggerStream(1, @"pause movie");
}

- (void) setMoviePosition: (CGFloat) position
{
    BOOL playMode = self.playing;
    
    self.playing = NO;
    _buffered = NO;
    _disableUpdateHUD = YES;
    
    __weak typeof(&*self)weakSelf = self;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [weakSelf updatePosition:position playMode:playMode];
    });
}

- (void) setMoviePosition: (CGFloat) position playMode:(BOOL)playMode
{
    self.playing = NO;
    _buffered = NO;
    _disableUpdateHUD = YES;
    
    __weak typeof(&*self)weakSelf = self;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [weakSelf updatePosition:position playMode:playMode];
    });
}

- (void)generatedPreviewImagesWithCount:(NSInteger)imagesCount completionHandler:(CYPlayerImageGeneratorCompletionHandler)handler
{
    __block CYPlayerDecoder *decoder = [[CYPlayerDecoder alloc] init];
    [decoder setDecodeType:CYVideoDecodeTypeVideo];
    
    __weak __typeof(&*self)weakSelf = self;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), [CYGCDManager sharedManager].generate_preview_images_dispatch_queue, ^{
        
        if (weakSelf.decoder.path.length > 0) {
            NSError *error = nil;
            [decoder openFile:weakSelf.decoder.path error:&error];
            [weakSelf setGeneratedPreviewImagesDecoder:decoder imagesCount:imagesCount withError:error completionHandler:handler];
        }
        
        
        
    });
}

+ (void)generatedPreviewImagesWithPath:(NSString *)path
                                 Count:(NSInteger)imagesCount
                     completionHandler:(CYPlayerImageGeneratorCompletionHandler)handler
{
    
    NSString * isEnter = [[NSUserDefaults standardUserDefaults] objectForKey:path];
    if ([isEnter isEqualToString:@"1"]) {
        return;
    }
    [[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:path];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    __block CFAbsoluteTime enterQueueTime = CFAbsoluteTimeGetCurrent();
    dispatch_block_t  block = dispatch_block_create_with_qos_class(DISPATCH_BLOCK_BARRIER, QOS_CLASS_USER_INITIATED, 0, ^{
        CFAbsoluteTime executeTime = CFAbsoluteTimeGetCurrent();
        CFAbsoluteTime linkTime = (executeTime- enterQueueTime);
        if (linkTime > 30) {//二十秒以后的任务先取消掉吧
            NSLog(@"生成预览图超时：enterQueueTime-%.2fs, executeTime-%.2fs,  linkTime-%.2fs", enterQueueTime, executeTime, linkTime);
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:path];
            [[NSUserDefaults standardUserDefaults] synchronize];
            return;
        }
        CYFFmpegPlayer * player = [CYFFmpegPlayer new];
        CYPlayerDecoder *decoder = [[CYPlayerDecoder alloc] init];
        [decoder setDecodeType:CYVideoDecodeTypeVideo];
        NSError *error = nil;
        [decoder openFile:path error:&error];
        [player set2GeneratedPreviewImagesDecoder:decoder imagesCount:imagesCount withError:error completionHandler:^(NSMutableArray<CYVideoFrameRGB *> * _Nullable frames, NSError * _Nullable error) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:path];
            [[NSUserDefaults standardUserDefaults] synchronize];
            handler(frames, error);
        }];
    });
    
    dispatch_async([CYGCDManager sharedManager].generate_preview_images_dispatch_queue, block);
    
}


+ (void)generatedPreviewImagesWithPath:(NSString *)path
                     completionHandler:(void (^)(NSMutableArray * frames, NSError * error))handler
{
    
    NSString * imagePath = [self getImagePathWithPath:path];
    
    if (imagePath.length > 0){
        
        handler([@[imagePath] mutableCopy], nil);
        
    } else {
        
        [self generatedPreviewImagesWithPath:path Count:1 completionHandler:^(NSMutableArray<CYVideoFrameRGB *> * _Nullable frames, NSError *error) {
            
            if (!error && frames.count > 0) {
                
                NSString * cyTmpPath = [self getImageCachePath];
                NSString * outPath = [cyTmpPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_",[path lastPathComponent]]];
                outPath = [outPath stringByAppendingString:@".jpg"];
                
                CYVideoFrameRGB * _Nullable rgbFrame = [frames firstObject];
                UIImage * img = [rgbFrame asImage];
                if (img) {
                    BOOL result = [UIImagePNGRepresentation(img) writeToFile:outPath atomically:YES];
                    
                    if (result == YES) {
                        [[NSUserDefaults standardUserDefaults] setObject:outPath forKey:path];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        handler([@[outPath] mutableCopy], nil);
                        return;
                    }else {
                        error = [NSError errorWithDomain:cyplayerErrorDomain
                                                    code:-1
                                                userInfo:@{@"originError":[NSString stringWithFormat:@"%@",[error description]]}];
                    }
                    
                }
            }
            handler([@[] mutableCopy], error);
        }];
        
    }
}

- (void)setupPlayerWithPath:(NSString *)path
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    // increase buffering for .wmv, it solves problem with delaying audio frames
    if ([path.pathExtension isEqualToString:@"wmv"] ||
        [path.pathExtension isEqualToString:@"mov"])
        parameters[CYPlayerParameterMinBufferedDuration] = @(5.0);
    
    // disable deinterlacing for iPhone, because it's complex operation can cause stuttering
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        parameters[CYPlayerParameterDisableDeinterlacing] = @(YES);
    
    [self setupPlayerWithPath:path parameters:parameters];
}


# pragma mark - 私有方法

+ (NSString *)getImageCachePath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = CY_CachesPath(@"ffmpeg_cache");
    
    BOOL isDir = FALSE;
    BOOL isDirExist = [fileManager fileExistsAtPath:filePath isDirectory:&isDir];
    if(!(isDirExist && isDir)){
        BOOL bCreateDir = [fileManager createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:nil];
        if(!bCreateDir){
            NSLog(@"Create ffmpeg_cache Directory Failed.");
            return nil;
        }else {
            return filePath;
        }
    }else{
        return filePath;
    }
}

+ (NSString *)getImagePathWithPath:(NSString *)path
{
    NSString * imagePath = [[NSUserDefaults standardUserDefaults] objectForKey:path];
    if (!imagePath || imagePath.length <= 0) {
        return nil;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:imagePath]) {
        return nil;
    }
    return imagePath;
}

# pragma mark player
- (void) restorePlay
{
    NSNumber *n = [[self getHistory] valueForKey:_decoder.path];
    if (n)
        [self updatePosition:n.floatValue playMode:YES];
    else
        [self play];
}

- (void)rePlay
{
    if (_decoder.isEOF)
    {
        [self.decoder setPosition:0];
        [self replayFromInterruptWithDecoder:self.decoder];
    }
    else
    {
        [self setMoviePosition:0 playMode:YES];
    }
}

- (void)setGeneratedPreviewImagesDecoder: (CYPlayerDecoder *) decoder
                             imagesCount:(NSInteger)imagesCount
                               withError: (NSError *) error
                       completionHandler:(CYPlayerImageGeneratorCompletionHandler)handler
{
    LoggerStream(2, @"setMovieDecoder");
    if (!error && decoder && !self.stopped)
    {
        _generatedPreviewImagesDecoder        = decoder;
        _generatedPreviewImageInterrupted     = NO;
        _generatedPreviewImagesVideoFrames   = [NSMutableArray array];
        [decoder setupVideoFrameFormat:CYVideoFrameFormatRGB];
        
        
        __weak typeof(CYFFmpegPlayer *)weakSelf = self;
        CYPlayerDecoder *weakDecoder = decoder;
        
        const CGFloat duration = decoder.isNetwork ? .0f : 0.1f;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf showTitle:@"开始生成预览图"];
        });
        @autoreleasepool {
            CGFloat timeInterval = weakDecoder.duration / imagesCount;
            NSError * error = nil;
            int i = 0;
            CYFFmpegPlayer *strongSelf = weakSelf;
            while ( i < imagesCount && strongSelf && !strongSelf->_generatedPreviewImageInterrupted &&
                   !strongSelf->_interrupted)
                //                for (int i = 0; i < imagesCount; i++)
            {
                CYPlayerDecoder *decoder = weakDecoder;
                if (![decoder.path isEqualToString:weakSelf.decoder.path]) {
                    if (strongSelf) {
                        [strongSelf->_generatedPreviewImagesVideoFrames removeAllObjects];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakSelf showTitle:@"链接已切换，重新生成预览图"];
                        });
                    }
                    break;;
                }
                
                if (decoder && decoder.validVideo && decoder.isEOF == NO)
                {
                    NSArray *frames = [decoder decodePreviewImagesFrames:duration];
                    if (frames.count && [frames firstObject])
                    {
                        
                        if (strongSelf)
                        {
                            @synchronized(strongSelf->_generatedPreviewImagesVideoFrames)
                            {
                                //                                        for (CYPlayerFrame *frame in frames)
                                CYVideoFrame * frame = [frames firstObject];
                                {
                                    if (frame.type == CYPlayerFrameTypeVideo)
                                    {
                                        [strongSelf->_generatedPreviewImagesVideoFrames addObject:frame];
                                        [decoder setPosition:(timeInterval * (i+1))];
                                        i++;
                                    }
                                }
                            }
                        }
                    }
                }
                else
                {
                    if (strongSelf->_generatedPreviewImagesVideoFrames.count < imagesCount) {
                        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"Generated Failed!" };
                        
                        error = [NSError errorWithDomain:cyplayerErrorDomain
                                                    code:-1
                                                userInfo:userInfo];
                    }
                    strongSelf->_generatedPreviewImageInterrupted = YES;
                    break;
                }
//                if (weakSelf.decoder.fps >= 25 && weakSelf.decoder.frameWidth >= 1680) {
//                    sleep(3);
//                }else {
//                    sleep(1);
//                }
                
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong CYFFmpegPlayer *strongSelf2 = weakSelf;
                if (!strongSelf2) {
                    return;
                }
                strongSelf2->_generatedPreviewImageInterrupted = YES;
                strongSelf2->_generatedPreviewImagesDecoder = nil;
                handler(strongSelf2->_generatedPreviewImagesVideoFrames, error);
            });
            
        }
    }
    else
    {
        
    }
}

- (void)set2GeneratedPreviewImagesDecoder:(CYPlayerDecoder *) decoder
                              imagesCount:(NSInteger)imagesCount
                                withError:(NSError *) error
                        completionHandler:(CYPlayerImageGeneratorCompletionHandler)handler
{
    LoggerStream(2, @"setMovieDecoder");
    _generatedPreviewImagesDecoder        = decoder;
    _generatedPreviewImageInterrupted     = NO;
    _generatedPreviewImagesVideoFrames   = [NSMutableArray array];
    [decoder setupVideoFrameFormat:CYVideoFrameFormatRGB];
    
    
    CYFFmpegPlayer *weakSelf = self;
    CYPlayerDecoder *weakDecoder = decoder;
    
    const CGFloat duration = decoder.isNetwork ? .0f : 0.1f;
    @autoreleasepool {
        CGFloat timeInterval = weakDecoder.duration / imagesCount;
        NSError * error = nil;
        int i = 0;
        CYFFmpegPlayer *strongSelf = weakSelf;
        while (i < imagesCount && strongSelf && !strongSelf->_generatedPreviewImageInterrupted &&
               !strongSelf->_interrupted)
        {
            CYPlayerDecoder *decoder = weakDecoder;
            
            if (decoder && decoder.validVideo && decoder.isEOF == NO)
            {
                if (imagesCount == 1) {
                    [decoder setPosition:timeInterval / 2.0];
                }
                
                NSArray *frames = [decoder decodePreviewImagesFrames:duration];
                if (frames.count && [frames firstObject])
                {
                    
                    if (strongSelf)
                    {
                        @synchronized(strongSelf->_generatedPreviewImagesVideoFrames)
                        {
                            //                                        for (CYPlayerFrame *frame in frames)
                            CYVideoFrame * frame = [frames firstObject];
                            {
                                if (frame.type == CYPlayerFrameTypeVideo)
                                {
                                    [strongSelf->_generatedPreviewImagesVideoFrames addObject:frame];
                                    [decoder setPosition:(timeInterval * (i+1))];
                                    i++;
                                }
                            }
                        }
                    }
                }
            }
            else
            {
                if (strongSelf->_generatedPreviewImagesVideoFrames.count < imagesCount) {
                    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"Generated Failed!" };
                    
                    error = [NSError errorWithDomain:cyplayerErrorDomain
                                                code:-1
                                            userInfo:userInfo];
                }
                strongSelf->_generatedPreviewImageInterrupted = YES;
                break;
            }
            
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong CYFFmpegPlayer *strongSelf2 = weakSelf;
            if (!strongSelf2) {
                return;
            }
            strongSelf2->_generatedPreviewImageInterrupted = YES;
            strongSelf2->_generatedPreviewImagesDecoder = nil;
            handler(strongSelf2->_generatedPreviewImagesVideoFrames, error);
        });
        
    }
    
}

- (void) setMovieDecoder: (CYPlayerDecoder *) decoder
               withError: (NSError *) error
{
    LoggerStream(2, @"setMovieDecoder");
    
    if (!error && decoder) {
        _decoder        = decoder;
        if (!_asyncDecodeQueue) _asyncDecodeQueue = dispatch_queue_create("CYPlayer AsyncDecode", DISPATCH_QUEUE_SERIAL);
        if (!_videoFrames)_videoFrames    = [NSMutableArray array];
        if (!_audioFrames)_audioFrames    = [NSMutableArray array];
        
        if (_decoder.subtitleStreamsCount) {
            if (!_subtitles) _subtitles = [NSMutableArray array];
        }
        
        if (_decoder.isNetwork) {
            
            _minBufferedDuration = NETWORK_MIN_BUFFERED_DURATION;
            _maxBufferedDuration = NETWORK_MAX_BUFFERED_DURATION;
            
        } else {
            
            _minBufferedDuration = LOCAL_MIN_BUFFERED_DURATION;
            _maxBufferedDuration = LOCAL_MAX_BUFFERED_DURATION;
        }
        
        if (!_decoder.validVideo)
        {
            _minBufferedDuration *= 2.0; // increase for audio
            _maxBufferedDuration *= 20.0;
        }
        
        // allow to tweak some parameters at runtime
        if (_parameters.count) {
            
            id val;
            
            val = [_parameters valueForKey: CYPlayerParameterMinBufferedDuration];
            if ([val isKindOfClass:[NSNumber class]])
                _minBufferedDuration = [val floatValue];
            
            val = [_parameters valueForKey: CYPlayerParameterMaxBufferedDuration];
            if ([val isKindOfClass:[NSNumber class]])
                _maxBufferedDuration = [val floatValue];
            
            val = [_parameters valueForKey: CYPlayerParameterDisableDeinterlacing];
            if ([val isKindOfClass:[NSNumber class]])
                _decoder.disableDeinterlacing = [val boolValue];
            
            if (_maxBufferedDuration < _minBufferedDuration)
                _maxBufferedDuration = _minBufferedDuration * 2;
        }
        
        LoggerStream(2, @"buffered limit: %.1f - %.1f", _minBufferedDuration, _maxBufferedDuration);
        
        [self setupPresentView];
        __weak typeof(self) _self = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [_self _itemReadyToPlay];
        });
        
    } else {
        [self setupPresentView];
        if (!_interrupted) {
            [self handleDecoderMovieError: error];
            self.error = error;
            [self _itemPlayFailed];
        }
    }
}

- (void) setupPresentView
{
    @synchronized (_glView) {
        UIView *frameView = [self presentView];
        if (frameView) {
            if ([frameView isKindOfClass:[CYPlayerGLView class]]) {
                if (_decoder.validVideo && [_decoder getVideoFrameFormat] == CYVideoFrameFormatYUV) {
                    [((CYPlayerGLView *)frameView) setDecoder:_decoder];
                    [((CYPlayerGLView *)frameView) updateVertices];
                }else {
                    [frameView removeFromSuperview];
                    frameView = nil;
                }
            }else if ([frameView isKindOfClass:[UIImageView class]]){
                if (_decoder.validVideo && [_decoder getVideoFrameFormat] == CYVideoFrameFormatYUV) {
                    [frameView removeFromSuperview];
                    frameView = nil;
                }
            }
        }
        
        if (!frameView) {
            CGRect bounds = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.width * 9.0/16.0);
            
            //            if (@available(iOS 8.0, *))
            //            {
            //                if (_decoder.validVideo && [_decoder getVideoFrameFormat] == CYVideoFrameFormatYUV) {
            //                    _metalView = [[CYFFmpegMetalView alloc] initWithFrame:bounds];
            //                }
            //            }
            //            else
            {
                if (_decoder.validVideo && [_decoder getVideoFrameFormat] == CYVideoFrameFormatYUV) {
                    _glView = [[CYPlayerGLView alloc] initWithFrame:bounds decoder:_decoder];
                    _glView.contentScaleFactor = [UIScreen mainScreen].scale;
                }
            }
            
            
            if (!_glView && !_metalView) {
                
                LoggerVideo(0, @"fallback to use RGB video frame and UIKit");
                [_decoder setupVideoFrameFormat:CYVideoFrameFormatRGB];
                _imageView = [[UIImageView alloc] initWithFrame:bounds];
                _imageView.backgroundColor = [UIColor blackColor];
            }
            
            frameView = [self presentView];
            frameView.contentMode = UIViewContentModeScaleAspectFit;
            frameView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
            
            [self.view insertSubview:frameView atIndex:0];
            [frameView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.edges.equalTo(@0);
            }];
        }
        
        if (_decoder.validVideo) {
            __weak typeof(self) _self = self;
            if (!self.generatPreviewImages || [self.decoder.path hasPrefix:@"rtmp"] || [self.decoder.path hasPrefix:@"rtsp"]) {
                return;
            }
            //先隐藏previewbtn
            _cyAnima(^{
                _cyHiddenViews(@[self.controlView.topControlView.previewBtn]);
                [self.controlView.topControlView.previewBtn mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.width.equalTo(@0);
                }];
            });
            self.controlView.previewView.previewFrames = @[];
            
            [self generatedPreviewImagesWithCount:20 completionHandler:^(NSMutableArray<CYVideoFrame *> *frames, NSError *error) {
                __strong typeof(_self) self = _self;
                if ( !self ) return;
                if (error)
                {
                    _self.hasBeenGeneratedPreviewImages = NO;
                    return;
                }
                _self.hasBeenGeneratedPreviewImages = YES;
                if ( _self.orentation.fullScreen ) {
                    _cyAnima(^{
                        _cyShowViews(@[_self.controlView.topControlView.previewBtn]);
                        [self.controlView.topControlView.previewBtn mas_updateConstraints:^(MASConstraintMaker *make) {
                            make.width.equalTo(@49);
                        }];
                    });
                }
                _self.controlView.previewView.previewFrames = frames;
            }];
            
        }
        else
        {
            
            _imageView.image = [CYVideoPlayerResources imageNamed:@"music_icon.png"];
            _imageView.contentMode = UIViewContentModeCenter;
        }
        
        if (_decoder.duration == MAXFLOAT) {
            
        } else {
            
        }
        
        if (_decoder.subtitleStreamsCount) {
            
        }
    }
    
}

- (void) handleDecoderMovieError: (NSError *) error
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Close", nil)
                                              otherButtonTitles:nil];
    //    [alertView show];
}

- (UIView *)presentView
{
    UIView * result = _glView ? _glView : _imageView;
    //    if (@available(iOS 8.0, *)) {
    //        result = _metalView ? _metalView : _imageView;
    //    }
    return result;
}

- (BOOL) interruptDecoder
{
    //if (!_decoder)
    //    return NO;
    return _interrupted;
}


- (void) freeBufferedFrames
{
    @synchronized(_videoFrames) {
        [_videoFrames removeAllObjects];
    }
    
    @synchronized(_audioFrames) {
        
        [_audioFrames removeAllObjects];
        _currentAudioFrame = nil;
    }
    
    if (_subtitles) {
        @synchronized(_subtitles) {
            [_subtitles removeAllObjects];
        }
    }
    
    _videoBufferedDuration = 0;
    _audioBufferedDuration = 0;
}
//测试用
- (void) freeHalfBufferedFrames
{
    @synchronized(_videoFrames) {
        [_videoFrames removeObjectsInRange:NSMakeRange(_videoFrames.count / 2, _videoFrames.count - _videoFrames.count / 2)];
        
    }
    
    @synchronized(_audioFrames) {
        
        //        [_audioFrames removeObjectsInRange:NSMakeRange(_audioFrames.count / 2, _audioFrames.count - _audioFrames.count / 2)];
    }
    
    if (_subtitles) {
        @synchronized(_subtitles) {
            //            [_subtitles removeObjectsInRange:NSMakeRange(_subtitles.count / 2, _subtitles.count - _subtitles.count / 2)];
        }
    }
    _videoBufferedDuration *= 0.5;
    //    _audioBufferedDuration *= 0.5;
}


- (void) applicationWillResignActive: (NSNotification *)notification
{
    [self pause];
    
    LoggerStream(1, @"applicationWillResignActive");
}

- (void)settingsPlayerNotification:(NSNotification *)notifi {
    [self.decoder setUseHWDecompressor:self.settings.useHWDecompressor];
}


- (void) asyncDecodeFrames
{
    if (self.decoding)
    {
        return;
    }
    self.decoding = YES;
    
    __weak CYFFmpegPlayer *weakSelf = self;
    __weak CYPlayerDecoder *weakDecoder = _decoder;
    
    const CGFloat duration = _decoder.isNetwork ? 1.0f : 0.1f;
    dispatch_async(_asyncDecodeQueue, ^{
        __strong CYFFmpegPlayer *strongSelf = weakSelf;
        if (strongSelf)
        {
            if (!weakSelf.playing)
                return;
            
            BOOL good = YES;
            while (good && !weakSelf.stopped) {
                CFAbsoluteTime startTime =CFAbsoluteTimeGetCurrent();
                good = NO;
                
                @autoreleasepool {
                    
                    if (weakDecoder && (weakDecoder.validVideo || weakDecoder.validAudio)) {
                        
                        NSArray *frames = nil;
                        if (strongSelf->_positionUpdating)//正在跳播
                        {
                            frames = [weakDecoder decodeTargetFrames:duration :strongSelf->_targetPosition];
                        }
                        else
                        {
                            frames = [weakDecoder decodeFrames:duration];
                            //                            frames = [weakDecoder decodeTargetFrames:duration :strongSelf->_audioPosition];
                        }
                        
                        //                        for (CYPlayerFrame * frame in frames) {
                        //                            [weakSelf archiveFrame:frame];
                        //                        }
                        
                        if (frames.count) {
                            
                            good = [weakSelf addFrames:frames];
                        }
                        frames = nil;
                    }
                }
                CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
                //NSLog(@"Linked asyncDecodeFrames in %f ms", linkTime *1000.0);
            }
            
            weakSelf.decoding = NO;
        }
    });
}

- (void) concurrentAsyncDecodeFrames
{
    if (self.decoding)
    {
        return;
    }
    self.decoding = YES;
    
    __weak CYFFmpegPlayer *weakSelf = self;
    __weak CYPlayerDecoder *weakDecoder = _decoder;
    
    const CGFloat duration = _decoder.isNetwork ? 0.1f : 0.01f;
    dispatch_async(_asyncDecodeQueue, ^{
        __strong CYFFmpegPlayer *strongSelf = weakSelf;
        if (strongSelf)
        {
            if (!weakSelf.playing)
                return;
            CFAbsoluteTime startTime =CFAbsoluteTimeGetCurrent();
            
            @autoreleasepool {
                
                if (weakDecoder && (weakDecoder.validVideo || weakDecoder.validAudio)) {
                    
                    NSArray *frames = nil;
                    if (strongSelf->_positionUpdating)//正在跳播
                    {
                        [weakDecoder asyncDecodeFrames:duration targetPosition:strongSelf->_targetPosition compeletionHandler:^(NSArray<CYPlayerFrame *> *frames, BOOL compeleted) {
                            [weakSelf insertFrames:frames];
                            if (compeleted)
                            {
                                weakSelf.decoding = NO;
                            }
                        }];
                    }
                    else
                    {
                        [weakDecoder concurrentDecodeFrames:duration compeletionHandler:^(NSArray<CYPlayerFrame *> *frames, BOOL compeleted) {
                            [weakSelf insertFrames:frames];
                            if (compeleted)
                            {
                                weakSelf.decoding = NO;
                            }
                        }];
                    }
                }
            }
            CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
            //NSLog(@"Linked asyncDecodeFrames in %f ms", linkTime *1000.0);
        }
    });
}

- (void) insertFrames: (NSArray *)frames
{
    if (_decoder.validVideo) {
        
        @synchronized(_videoFrames) {
            
            for (CYPlayerFrame *frame in frames)
                if (frame.type == CYPlayerFrameTypeVideo)
                {
                    if (!_positionUpdating)
                    {
                        NSInteger targetIndex = _videoFrames.count;
                        BOOL hasInserted = NO;
                        for( int i = 0; i < _videoFrames.count; i ++ )
                        {
                            CYVideoFrame * targetFrame = [_videoFrames objectAtIndex:i];
                            if (frame.position <= targetFrame.position)
                            {
                                targetIndex = i;
                                if (frame.position == targetFrame.position) {
                                    hasInserted = YES;
                                }
                                break;
                            }
                        }
                        if (!hasInserted) {
                            [_videoFrames insertObject:frame atIndex:targetIndex];
                            _videoBufferedDuration += frame.duration;
                        }else {
                            LoggerVideo(0, @"skip hasInserted video frames");
                        }
                        
                    }
                    else
                    {
                        if (frame.position >= _targetPosition)
                        {
                            NSInteger targetIndex = _videoFrames.count;
                            BOOL hasInserted = NO;
                            for( int i = 0; i < _videoFrames.count; i ++ )
                            {
                                CYVideoFrame * targetFrame = [_videoFrames objectAtIndex:i];
                                if (frame.position <= targetFrame.position)
                                {
                                    targetIndex = i;
                                    if (frame.position == targetFrame.position) {
                                        hasInserted = YES;
                                    }
                                    break;
                                }
                            }
                            if (!hasInserted) {
                                [_videoFrames insertObject:frame atIndex:targetIndex];
                                _videoBufferedDuration += frame.duration;
                            }else {
                                LoggerVideo(0, @"skip hasInserted video frames");
                            }
                            
                        }
                    }
                }
        }
    }
    
    if (_decoder.validAudio) {
        
        @synchronized(_audioFrames) {
            
            for (CYPlayerFrame *frame in frames)
                if (frame.type == CYPlayerFrameTypeAudio)
                {
                    if (!_positionUpdating)
                    {
                        NSInteger targetIndex = _audioFrames.count;
                        BOOL hasInserted = NO;
                        for( int i = 0; i < _audioFrames.count; i ++ )
                        {
                            CYAudioFrame * targetFrame = [_audioFrames objectAtIndex:i];
                            if (frame.position <= targetFrame.position)
                            {
                                targetIndex = i;
                                if (frame.position == targetFrame.position) {
                                    hasInserted = YES;
                                }
                                break;
                            }
                        }
                        if (!hasInserted) {
                            [_audioFrames insertObject:frame atIndex:targetIndex];
                            _audioBufferedDuration += frame.duration;
                        }else {
                            LoggerVideo(0, @"skip hasInserted audio frames");
                        }
                    }
                    else
                    {
                        if (frame.position >= _targetPosition)
                        {
                            NSInteger targetIndex = _audioFrames.count;
                            BOOL hasInserted = NO;
                            for( int i = 0; i < _audioFrames.count; i ++ )
                            {
                                CYAudioFrame * targetFrame = [_audioFrames objectAtIndex:i];
                                if (frame.position <= targetFrame.position)
                                {
                                    targetIndex = i;
                                    if (frame.position == targetFrame.position) {
                                        hasInserted = YES;
                                    }
                                    break;
                                }
                            }
                            if (!hasInserted) {
                                [_audioFrames insertObject:frame atIndex:targetIndex];
                                _audioBufferedDuration += frame.duration;
                            }else {
                                LoggerVideo(0, @"skip hasInserted audio frames");
                            }
                        }
                    }
                }
        }
        
        if (!_decoder.validVideo) {
            
            for (CYPlayerFrame *frame in frames)
                if (frame.type == CYPlayerFrameTypeArtwork)
                    self.artworkFrame = (CYArtworkFrame *)frame;
        }
    }
    
    if (_decoder.validSubtitles) {
        
        @synchronized(_subtitles) {
            
            for (CYPlayerFrame *frame in frames)
                if (frame.type == CYPlayerFrameTypeSubtitle)
                {
                    if (!_positionUpdating)
                    {
                        NSInteger targetIndex = _subtitles.count;
                        BOOL hasInserted = NO;
                        for( int i = 0; i < _subtitles.count; i ++ )
                        {
                            CYSubtitleFrame * targetFrame = [_subtitles objectAtIndex:i];
                            if (frame.position <= targetFrame.position)
                            {
                                targetIndex = i;
                                if (frame.position == targetFrame.position) {
                                    hasInserted = YES;
                                }
                                break;
                            }
                        }
                        if (!hasInserted) {
                            [_subtitles insertObject:frame atIndex:targetIndex];
                        }else {
                            LoggerVideo(0, @"skip hasInserted subtitles frames");
                        }
                    }
                    else
                    {
                        if (frame.position >= _targetPosition)
                        {
                            NSInteger targetIndex = _subtitles.count;
                            BOOL hasInserted = NO;
                            for( int i = 0; i < _subtitles.count; i ++ )
                            {
                                CYSubtitleFrame * targetFrame = [_subtitles objectAtIndex:i];
                                if (frame.position <= targetFrame.position)
                                {
                                    targetIndex = i;
                                    if (frame.position == targetFrame.position) {
                                        hasInserted = YES;
                                    }
                                    break;
                                }
                            }
                            if (!hasInserted) {
                                [_subtitles insertObject:frame atIndex:targetIndex];
                            }else {
                                LoggerVideo(0, @"skip hasInserted subtitles frames");
                            }
                        }
                    }
                }
        }
    }
}

- (BOOL) addFrames: (NSArray *)frames
{
    if (_decoder.validVideo) {
        
        @synchronized(_videoFrames) {
            
            for (CYPlayerFrame *frame in frames)
                if (frame.type == CYPlayerFrameTypeVideo) {
                    if (_positionUpdating)
                    {
                        if (frame.position >= _targetPosition)
                        {
                            [_videoFrames addObject:frame];
                            _videoBufferedDuration += frame.duration;
                        }
                    }
                    else
                    {
                        [_videoFrames addObject:frame];
                        _videoBufferedDuration += frame.duration;
                    }
                    
                }
        }
    }
    
    if (_decoder.validAudio) {
        
        @synchronized(_audioFrames) {
            
            for (CYPlayerFrame *frame in frames)
                if (frame.type == CYPlayerFrameTypeAudio) {
                    if (_positionUpdating)
                    {
                        if (frame.position >= _targetPosition)
                        {
                            [_audioFrames addObject:frame];
                            //                    if (!_decoder.validVideo)
                            _audioBufferedDuration += frame.duration;
                        }
                    }
                    else
                    {
                        [_audioFrames addObject:frame];
                        //                    if (!_decoder.validVideo)
                        _audioBufferedDuration += frame.duration;
                    }
                }
        }
        
        if (!_decoder.validVideo) {
            
            for (CYPlayerFrame *frame in frames)
                if (frame.type == CYPlayerFrameTypeArtwork)
                    self.artworkFrame = (CYArtworkFrame *)frame;
        }
    }
    
    if (_decoder.validSubtitles) {
        
        @synchronized(_subtitles) {
            
            for (CYPlayerFrame *frame in frames)
                if (frame.type == CYPlayerFrameTypeSubtitle) {
                    if (_positionUpdating)
                    {
                        if (frame.position >= _targetPosition)
                        {
                            [_subtitles addObject:frame];
                        }
                    }
                    else
                    {
                        [_subtitles addObject:frame];
                    }
                }
        }
    }
    
    return self.playing && (_videoBufferedDuration < _maxBufferedDuration || _audioBufferedDuration < _maxBufferedDuration) && ([self getMemoryUsedPercent] < MAX_BUFFERED_DURATION_MEMORY_USED_PERCENT) && HAS_PLENTY_OF_MEMORY;
}

- (void) videoTick
{
    __weak typeof(&*self)weakSelf = self;
    CFAbsoluteTime tickStartTime = CFAbsoluteTimeGetCurrent();
    //#ifdef DEBUG
    if (!_videoTickStartTime) {
        _videoTickStartTime = CFAbsoluteTimeGetCurrent();
    }
    else{
        CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - _videoTickStartTime);
        //         NSLog(@"Linked presentVideoFrame in %f ms", linkTime *1000.0);
        _decoder.dynamicFPS_Block = ^CGFloat{
            if ([weakSelf getTotalMemorySize] >= 2000) {
                return 1 / (CGFloat)linkTime;
            }else {
                if (weakSelf.decoder.frameHeight * weakSelf.decoder.frameWidth >= 1440 * 810) {
                    return 20;
                }else {
                    return 1 / (CGFloat)linkTime;
                }
            }
        };
        _videoTickStartTime = CFAbsoluteTimeGetCurrent();
    }
    //#endif
    
    CGFloat interval = 0;
    if (!_buffered)
    {
        if (_positionUpdating )
        {
            _positionUpdating = NO;
        }
        
        //        tickStartTime = CFAbsoluteTimeGetCurrent();
        interval = [self presentVideoFrame];
        //        CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - tickStartTime);
        //        NSLog(@"Linked presentVideoFrame in %f ms", linkTime *1000.0);
    }
    
    if (self.playing)
    {
        NSUInteger leftAFrames = (_decoder.validAudio ? _audioFrames.count : 0);
        
        NSUInteger leftVFrames = (_decoder.validVideo ? _videoFrames.count : 0);
        
        //        NSUInteger leftFrames = leftAFrames + leftVFrames;
        
        //        if ([self getMemoryUsedPercent] <= MAX_BUFFERED_DURATION_MEMORY_USED_PERCENT && HAS_PLENTY_OF_MEMORY)
        {
            BOOL need_decode = NO;
            if (!need_decode && _decoder.validVideo && (leftVFrames <= 0 || leftAFrames <= 0)) {
                need_decode = YES;
            }
            
            if (!need_decode && _decoder.validAudio && (leftAFrames <= 0 )) {
                need_decode = YES;
            }
            
            if (!need_decode && _audioBufferedDuration < _minBufferedDuration) {
                need_decode = YES;
            }
            
            //            if (need_decode && _videoBufferedDuration >= _maxBufferedDuration) {
            //                need_decode = NO;
            //            }
            
            if (need_decode){
                //            [self asyncDecodeFrames];
                [self concurrentAsyncDecodeFrames];
            }
            
            if (_videoBufferedDuration >= _maxBufferedDuration * 2) {
                [self freeHalfBufferedFrames];
            }
        }
        //        else
        //        {
        //            NSLog(@"内存告警: 剩余内存 %.2fMB, 已用内存 %.2f%%", [self getAvailableMemorySize], [self getMemoryUsedPercent]);
        //        }
        
        //        const NSTimeInterval correction = [self tickCorrection];
        //        NSTimeInterval time = MAX(interval + correction, 0.01);
        NSTimeInterval time = 0;
        if (self.rate == 0) {
            self.rate = 1.0;
        }
        if (interval > 0) {
            time = interval;
        }else{
            time = (1.0 / CYPlayerDecoderMaxFPS) / self.rate;
        }
        
        CFAbsoluteTime tickLinkTime = CFAbsoluteTimeGetCurrent() - tickStartTime;
        CGFloat popTime = (time - tickLinkTime - 0.005);
        //        NSLog(@"%f",popTime*1000);
        dispatch_time_t popDispatchTime = dispatch_time(DISPATCH_TIME_NOW,  popTime* NSEC_PER_SEC);
        dispatch_after(popDispatchTime, _videoQueue, ^(void){
            [weakSelf videoTick];
        });
        
    }
    
    
}


- (CGFloat) audioCallbackFillData: (float *) outData
                        numFrames: (UInt32) numFrames
                      numChannels: (UInt32) numChannels
{
    CGFloat duration = 0.0;
#ifdef USE_AUDIOTOOL
    //fillSignalF(outData,numFrames,numChannels);
    //return;
    if (_buffered && _audioFrames.count <= 0) {
        memset(outData, 0, numFrames * numChannels * sizeof(float));
        return 0.0;
    }
    
    @autoreleasepool
    {
        while ( numFrames > 0) {
            
            if (!_currentAudioFrame) {
                //_currentAudioFrame 为空
                @synchronized(_audioFrames) {
                    
                    NSUInteger count = _audioFrames.count;
                    
                    if (count > 0) {
                        
                        CYAudioFrame *frame = _audioFrames[0];
                        
#ifdef DUMP_AUDIO_DATA
                        LoggerAudio(2, @"Audio frame position: %f", frame.position);
#endif
                        [_audioFrames removeObjectAtIndex:0];
                        _audioPosition = frame.position;
                        _currentAudioFramePos = 0;
                        _audioBufferedDuration -= frame.duration;
                        //                            _currentAudioFrame = frame.samples;
                        _currentAudioFrame = [[CYSonicManager sonicManager] setFloatData:frame.samples];
                        duration = frame.duration;
                    }
                }
            }
            
            if (_positionUpdating) {
                _positionUpdating = NO;
            }
            
            if (_currentAudioFrame) {
                
                const void *bytes = (Byte *)(_currentAudioFrame.bytes) + _currentAudioFramePos;
                const NSUInteger bytesLeft = (_currentAudioFrame.length - _currentAudioFramePos);
                const NSUInteger frameSizeOf = numChannels * sizeof(float);
                const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
                const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
                
                //从bytes拷贝到outData 长度为bytesToCopy
                memcpy(outData, bytes, bytesToCopy);
                numFrames -= framesToCopy;
                outData += framesToCopy * numChannels;
                
                if (bytesToCopy < bytesLeft){
                    _currentAudioFramePos += bytesToCopy;
                }
                else{
                    _currentAudioFrame = nil;
                }
                
            } else {
                
                memset(outData, 0, numFrames * numChannels * sizeof(float));
                //LoggerStream(1, @"silence audio");
#ifdef DEBUG
                _debugAudioStatus = 3;
                _debugAudioStatusTS = [NSDate date];
#endif
                break;
            }
        }
    }
    
#endif
    return duration;
}


- (void) enableAudioTick: (BOOL) on
{
#ifdef USE_AUDIOTOOL
    id<CYAudioManager> audioManager = [CYAudioManager audioManager];
    
    if (on && _decoder.validAudio) {
        audioManager.delegate = self;
        __weak typeof(&*self)weakSelf = self;
        audioManager.outputBlock = ^(float *outData, UInt32 numFrames, UInt32 numChannels) {
            CFAbsoluteTime startTime =CFAbsoluteTimeGetCurrent();
            CGFloat duration = [weakSelf audioCallbackFillData: outData numFrames:numFrames numChannels:numChannels];
            CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
            //            NSLog(@"Linked audioCallbackFillData in %f ms", linkTime *1000.0);
            sleep(ABS(duration - (CGFloat)linkTime));
        };
        
        [audioManager play];
        
        LoggerAudio(2, @"audio device smr: %d fmt: %d chn: %d",
                    (int)audioManager.samplingRate,
                    (int)audioManager.numBytesPerSample,
                    (int)audioManager.numOutputChannels);
        
    } else {
        
        [audioManager pause];
        audioManager.outputBlock = nil;
        audioManager.delegate = nil;
    }
    
#endif
}


- (void)audioTick
{
    
#ifdef USE_OPENAL
    __weak typeof(&*self)weakSelf = self;
    CYPCMAudioManager * audioManager = [CYPCMAudioManager audioManager];
    
    CGFloat interval = 0;
    if (!_buffered)
    {
        if (_positionUpdating )
        {
            _positionUpdating = NO;
        }
        interval = [self presentAudioFrame];
    }
    else
    {
        //        const int bufSize = 100;
        int bufSize = av_samples_get_buffer_size(NULL,
                                                 (int)audioManager.avcodecContextNumOutputChannels,
                                                 audioManager.audioCtx->frame_size,
                                                 AV_SAMPLE_FMT_S16,
                                                 1);
        bufSize = bufSize > 0 ? bufSize : 100;
        char * empty_audio_data = (char *)calloc(bufSize, sizeof(char));
        memset(empty_audio_data, 0, bufSize);
        NSData * empty_audio = [NSData dataWithBytes:empty_audio_data length:bufSize];
        [audioManager setData:empty_audio];//播放
        //        interval = delta;
    }
    
    if (self.playing) {
        const NSUInteger leftFrames =
        (_decoder.validVideo ? _videoFrames.count : 0) +
        (_decoder.validAudio ? _audioFrames.count : 0);
        
        if ((!leftFrames ||
             !(_videoBufferedDuration > _maxBufferedDuration) ||
             !(_audioBufferedDuration > _maxBufferedDuration))
            &&
            ([self getMemoryUsedPercent] <= MAX_BUFFERED_DURATION_MEMORY_USED_PERCENT) && HAS_PLENTY_OF_MEMORY)
        {
            
            //            [self asyncDecodeFrames];
            [self concurrentAsyncDecodeFrames];
        }
        
        const NSTimeInterval correction = [self tickCorrection];
        const NSTimeInterval time = MAX(interval + correction, 0.01);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC);
        dispatch_after(popTime, _audioQueue, ^(void){
            [weakSelf audioTick];
        });
    }
#endif
}

- (void)progressTick
{
    __weak typeof(&*self)weakSelf = self;
    if (_buffered &&
        (
         (
          (_videoBufferedDuration > _minBufferedDuration) ||
          (_audioBufferedDuration > _minBufferedDuration)
          ) ||
         _decoder.isEOF ||
         ([self getMemoryUsedPercent] > MAX_BUFFERED_DURATION_MEMORY_USED_PERCENT || !(HAS_PLENTY_OF_MEMORY))
         )
        )
    {
        _tickCorrectionTime = 0;
        _cantPlayStartTime = 0;
        _buffered = NO;
        if (([self getMemoryUsedPercent] > MAX_BUFFERED_DURATION_MEMORY_USED_PERCENT) || !(HAS_PLENTY_OF_MEMORY))
        {
            [self play];
        }
        else
        {
            if ((_videoBufferedDuration > _minBufferedDuration) ||
                (_audioBufferedDuration > _minBufferedDuration))
            {
                [self play];
            }
        }
        
    }
    
    if (self.playing) {
        
        const NSUInteger leftFrames =
        (_decoder.validVideo ? _videoFrames.count : 0) +
        (_decoder.validAudio ? _audioFrames.count : 0);
        
        CGFloat curr_position = _decoder.validVideo ? _moviePosition : _audioPosition;
        if ( leftFrames == 0 )
        {
            if (_decoder.isEOF) {
                if (_decoder.duration - curr_position <= 1.0 &&
                    _decoder.duration > 0 &&
                    _decoder.duration != NSNotFound)
                {
                    [self _itemPlayEnd];
                    
                    return;
                }
                //                if ([_decoder.path hasPrefix:@"rtsp"] || [_decoder.path hasPrefix:@"rtmp"] || [[_decoder.path lastPathComponent] containsString:@"m3u8"])
                //                {
                //                    [self _pause];
                //                    CGFloat interval = 0;
                //                    const NSTimeInterval correction = [self tickCorrection];
                //                    const NSTimeInterval time = MAX(interval + correction, 0.01);
                //                    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
                //                    dispatch_after(popTime, _progressQueue, ^(void){
                //                        [weakSelf replayFromInterruptWithDecoder:weakSelf.decoder];
                //                    });
                //                    return;
                //                }
                //                else
                {
                    [self _itemPlayFailed];
                    
                    return;
                }
            }
            else
            {
                if (_cantPlayStartTime <= 0)
                {
                    _cantPlayStartTime = CFAbsoluteTimeGetCurrent();
                }
                CFAbsoluteTime currTime = CFAbsoluteTimeGetCurrent();
                NSString * currTimeStr = [NSString stringWithFormat:@"%f", currTime * 1000.0];
                CGFloat curr = [currTimeStr doubleValue];
                NSString * cantPlayStartTimeStr = [NSString stringWithFormat:@"%f", _cantPlayStartTime * 1000.0];
                CGFloat cant = [cantPlayStartTimeStr doubleValue];
                CGFloat durationTime = curr - cant;
                if (durationTime >= CYPLAYER_MAX_TIMEOUT * 1000)
                {
//                    _interrupted = YES;
                    [self _itemPlayFailed];
                    _cantPlayStartTime = 0.0;
                    //                    return;
                }
            }
            
            if (_minBufferedDuration > 0) {
                
                if (!_buffered)
                {
                    _buffered = YES;
                    if (!_interval_from_last_buffer_laoding) {
                        _interval_from_last_buffer_laoding = CFAbsoluteTimeGetCurrent();
                    }
                    else{
                        CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - _interval_from_last_buffer_laoding);
                        CGFloat delta = ABS(_minBufferedDuration - linkTime);
                        
                        if (delta > 0.5 && delta < _minBufferedDuration) {
                            if (_decoder.isNetwork) {
                                if (_minBufferedDuration + delta < (NETWORK_MAX_BUFFERED_DURATION)){
                                    _minBufferedDuration += delta;
                                }
                            } else {
                                if (_minBufferedDuration + delta < (LOCAL_MAX_BUFFERED_DURATION)){
                                    _minBufferedDuration += delta;
                                }
                            }
                        }
#ifdef DEBUG
                        NSLog(@"_interval_from_last_buffer_laoding: %.4f, delta: %.2f, minBufferDuration: %.2f", linkTime, delta, _minBufferedDuration);
#endif
                        
                        _interval_from_last_buffer_laoding = CFAbsoluteTimeGetCurrent();
                    }
                }
                
                if (self.state != CYFFmpegPlayerPlayState_Buffing) {
                    [self _buffering];
                }
                
            }
        }
        else if ((_videoFrames.count == 0 &&
                  _audioFrames.count != 0 &&
                  _decoder.validVideo == YES) ||
                 ((_audioFrames.count == 0 &&
                   _videoFrames.count != 0 &&
                   _decoder.validAudio == YES)))
        {
            if (_decoder.isEOF) {
                if (_decoder.duration - curr_position <= 1.0 &&
                    _decoder.duration > 0 &&
                    _decoder.duration != NSNotFound)
                {
                    [self _itemPlayEnd];
                    return;
                }
                //                if ([_decoder.path hasPrefix:@"rtsp"] || [_decoder.path hasPrefix:@"rtmp"] || [[_decoder.path lastPathComponent] containsString:@"m3u8"])
                //                {
                //                    [self _pause];
                //                    CGFloat interval = 0;
                //                    const NSTimeInterval correction = [self tickCorrection];
                //                    const NSTimeInterval time = MAX(interval + correction, 0.01);
                //                    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
                //                    dispatch_after(popTime, _progressQueue, ^(void){
                //                        [weakSelf replayFromInterruptWithDecoder:weakSelf.decoder];
                //                    });
                //                    return;
                //                }
                else
                {
                    //                    [self _itemPlayFailed];
                    //
                    //                    return;
                }
            }
        }
        
        
        if ([self.decoder validVideo])
        {
            
            //            if ([self getMemoryUsedPercent] <= MAX_BUFFERED_DURATION_MEMORY_USED_PERCENT && HAS_PLENTY_OF_MEMORY)
            //            {
            //                NSLog(@"_videoBufferedDuration: %f _maxBufferedDuration: %f",_videoBufferedDuration, _maxBufferedDuration);
            //                 if (!leftFrames ||
            //                                (_videoBufferedDuration < _maxBufferedDuration)
            //                                )
            //                            {
            //                                //            [self asyncDecodeFrames];
            //                                [self concurrentAsyncDecodeFrames];
            //                            }
            //            }
            
        }
        else if (![self.decoder validVideo] && [self.decoder validAudio])
        {
            if ([self getMemoryUsedPercent] <= MAX_BUFFERED_DURATION_MEMORY_USED_PERCENT && HAS_PLENTY_OF_MEMORY)
            {
                if (!leftFrames ||
                    (_audioBufferedDuration < _maxBufferedDuration))
                {
                    //            [self asyncDecodeFrames];
                    [self concurrentAsyncDecodeFrames];
                }
            }
        }
        
        CGFloat interval = 0.1;
        //        const NSTimeInterval correction = [self tickCorrection];
        const NSTimeInterval time = interval;//MAX(interval + correction, 0.01);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW,  0.01 * NSEC_PER_SEC);
        dispatch_after(popTime, _progressQueue, ^(void){
            [weakSelf progressTick];
        });
    }
    
    [self refreshProgressViews];
}

- (void)refreshProgressViews
{
    __weak typeof(&*self)weakSelf = self;
    dispatch_async(_progressQueue, ^{
        __strong typeof(&*self)strongSelf = weakSelf;
        if (strongSelf)
        {
            const CGFloat duration = strongSelf->_decoder.duration;
            CGFloat position = strongSelf->_audioPosition - strongSelf->_decoder.startTime;
            if (weakSelf.decoder.validVideo)
            {
                position = strongSelf->_moviePosition - strongSelf->_decoder.startTime;
            }
            if ((strongSelf->_tickCounter++ % 3) == 0 && strongSelf->_isDraging == NO) {
                const CGFloat loadedPosition = weakSelf.decoder.position;
                [weakSelf _refreshingTimeProgressSliderWithCurrentTime:position duration:duration];
                [weakSelf _refreshingTimeLabelWithCurrentTime:position duration:duration];
                [weakSelf _refreshingTimeProgressSliderWithLoadedTime:loadedPosition duration:duration];
            }
            
            if ([weakSelf.delegate respondsToSelector:@selector(CYFFmpegPlayer:UpdatePosition:Duration:isDrag:)])
            {
                [weakSelf.delegate CYFFmpegPlayer:weakSelf UpdatePosition:position Duration:duration isDrag:strongSelf->_isDraging];
            }
            
            if (strongSelf.settings.definitionTypes != CYFFmpegPlayerDefinitionNone) {
                if (strongSelf->_definitionType == 0) {
                    if (strongSelf.settings.definitionTypes & CYFFmpegPlayerDefinitionLLD) {
                        strongSelf->_definitionType = CYFFmpegPlayerDefinitionLLD;
                    }else if (strongSelf.settings.definitionTypes & CYFFmpegPlayerDefinitionLSD) {
                        strongSelf->_definitionType = CYFFmpegPlayerDefinitionLSD;
                    }else if (strongSelf.settings.definitionTypes & CYFFmpegPlayerDefinitionLHD) {
                        strongSelf->_definitionType = CYFFmpegPlayerDefinitionLHD;
                    }else if (strongSelf.settings.definitionTypes & CYFFmpegPlayerDefinitionLUD) {
                        strongSelf->_definitionType = CYFFmpegPlayerDefinitionLUD;
                    }
                    
                }
                [strongSelf refreshDefinitionBtnStatus];
            }
            
            if (strongSelf.settings.enableSelections) {
                [strongSelf refreshSelectionsBtnStatus];
            }
        }
    });
}

- (CGFloat) tickCorrection
{
    if (_buffered)
        return 0;
    
    const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    if (!_tickCorrectionTime) {
        
        _tickCorrectionTime = now;
        _tickCorrectionPosition = _moviePosition;
        return 0;
    }
    
    NSTimeInterval dPosition = _moviePosition - _tickCorrectionPosition;
    NSTimeInterval dTime = now - _tickCorrectionTime;
    NSTimeInterval correction = dPosition - dTime;
    
    //if ((_tickCounter % 200) == 0)
    //    LoggerStream(1, @"tick correction %.4f", correction);
    
    if (correction > 2.f || correction < -2.f) {
        
        LoggerStream(1, @"tick correction reset %.2f", correction);
        correction = 0;
        _tickCorrectionTime = 0;
    }
    
    return correction;
}

- (CGFloat) presentAudioFrame
{
#ifdef USE_OPENAL
    CGFloat interval = 0;
    
    CYPCMAudioManager * audioManager = [CYPCMAudioManager audioManager];
    audioManager.delegate = self;
    
    @synchronized(_audioFrames)
    {
        NSUInteger count = _audioFrames.count;
        CYAudioFrame * audioFrame = [_audioFrames firstObject];
        if ([audioFrame isKindOfClass: NSClassFromString(@"CYAudioFrame")] &&
            count > 0)
        {
            if (_decoder.validAudio)
            {
                _audioPosition = audioFrame.position;
                CGFloat delta = _audioPosition - _moviePosition;
                CGFloat limit_val = 0.1;
                //                if (limit_val < 1) { limit_val = 1; }
                if (delta <= limit_val && delta >= -(limit_val))//音视频处于同步
                {
                    
                    [_audioFrames removeObjectAtIndex:0];
                    _audioBufferedDuration -= audioFrame.duration;
                    [audioManager setData:audioFrame.samples];//播放
                    interval = audioFrame.duration;
                }
                else if (delta > limit_val)//音频快了
                {
                    [_audioFrames removeObjectAtIndex:0];
                    _audioBufferedDuration -= audioFrame.duration;
                    [audioManager setData:audioFrame.samples];//播放
                    interval = audioFrame.duration;
                }
                else//音频慢了
                {
                    [_audioFrames removeObjectAtIndex:0];
                    _audioBufferedDuration -= audioFrame.duration;
                    [audioManager setData:audioFrame.samples];//播放
                    interval = audioFrame.duration;
                    //                    interval = 0;
                }
            }
        }
    }
    
    return interval;
#endif
    return 0;
}

- (CGFloat) presentVideoFrame
{
    CGFloat interval = 0;
    
    if (_decoder.validVideo) {
        
        CYVideoFrame *frame;
        
        @synchronized(_videoFrames) {
            
            if (_videoFrames.count > 0) {
                
                frame = _videoFrames[0];
                _moviePosition = frame.position;
                
                CGFloat delta = _moviePosition - _audioPosition;
                CGFloat limit_val = 0.1;
                //                NSLog(@"");
                //                if (limit_val < 1) { limit_val = 1; }
                if (delta <= limit_val && delta >= -(limit_val))//音视频处于同步
                {
                    
                    [_videoFrames removeObjectAtIndex:0];
                    _videoBufferedDuration -= frame.duration;
                    interval = [self presentVideoFrame:frame];//呈现视频
                }
                else if (delta > limit_val)//视频快了
                {
                    //视频快了不做处理
                    //                    [_videoFrames removeObjectAtIndex:0];
                    //                    _videoBufferedDuration -= frame.duration;
                    //                    interval = [self presentVideoFrame:frame];//呈现视频
                    //                    interval = delta;
                }
                else//视频慢了
                {
                    [_videoFrames removeObjectAtIndex:0];
                    _videoBufferedDuration -= frame.duration;
                    interval = [self presentVideoFrame:frame];//呈现视频
                    interval = 0.01;//videotick间隔时间最小化,以加速视频呈现
                    
                    //                    //快进视频帧（跳一针）
                    //                    if (_videoFrames.count > 0) {
                    //                        [_videoFrames removeObjectAtIndex:0];
                    //                    }
                }
            }
        }
        //        NSLog(@"%f",_videoBufferedDuration);
        
    } else if (_decoder.validAudio) {
        
        //interval = _videoBufferedDuration * 0.5;
        
        if (self.artworkFrame) {
            
            _imageView.image = [self.artworkFrame asImage];
            self.artworkFrame = nil;
        }
    }
    
    if (_decoder.validSubtitles)
        [self presentSubtitles];
    
#ifdef DEBUG
    if (self.playing && _debugStartTime < 0)
        _debugStartTime = [NSDate timeIntervalSinceReferenceDate] - _moviePosition;
#endif
    
    return interval;
}

- (CGFloat) presentVideoFrame: (CYVideoFrame *) frame
{
    if([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
    {
        if (_glView)
        {
            
            @synchronized (_glView) {
                [_glView render:frame];
            }
            
        }
        else if (_metalView)
        {
            @synchronized (_metalView) {
                [_metalView renderWithPixelBuffer:((CYVideoFrameYUV *)frame).pixelBuffer];
            }
        }
        else
        {
            
            CYVideoFrameRGB *rgbFrame = (CYVideoFrameRGB *)frame;
            _imageView.image = [rgbFrame asImage];
        }
    }
    _moviePosition = frame.position;
    
    return frame.duration;
}

- (void) presentSubtitles
{
    NSArray *actual, *outdated;
    
    if ([self subtitleForPosition:_moviePosition
                           actual:&actual
                         outdated:&outdated]){
        
        if (outdated.count) {
            @synchronized(_subtitles) {
                [_subtitles removeObjectsInArray:outdated];
            }
        }
        
        if (actual.count) {
            
            NSMutableString *ms = [NSMutableString string];
            for (CYSubtitleFrame *subtitle in actual.reverseObjectEnumerator) {
                if (ms.length) [ms appendString:@"\n"];
                [ms appendString:subtitle.text];
            }
            
#warning 处理subtitle
            
        } else {
            
            
        }
    }
}

- (BOOL) subtitleForPosition: (CGFloat) position
                      actual: (NSArray **) pActual
                    outdated: (NSArray **) pOutdated
{
    if (!_subtitles.count)
        return NO;
    
    NSMutableArray *actual = nil;
    NSMutableArray *outdated = nil;
    
    for (CYSubtitleFrame *subtitle in _subtitles) {
        
        if (position < subtitle.position) {
            
            break; // assume what subtitles sorted by position
            
        } else if (position >= (subtitle.position + subtitle.duration)) {
            
            if (pOutdated) {
                if (!outdated)
                    outdated = [NSMutableArray array];
                [outdated addObject:subtitle];
            }
            
        } else {
            
            if (pActual) {
                if (!actual)
                    actual = [NSMutableArray array];
                [actual addObject:subtitle];
            }
        }
    }
    
    if (pActual) *pActual = actual;
    if (pOutdated) *pOutdated = outdated;
    
    return actual.count || outdated.count;
}

- (void) updatePosition: (CGFloat) position
               playMode: (BOOL) playMode
{
    if (_buffered)
    {
        return;
    }
    
    _buffered = YES;//这个需要写在_positionUpdating的前面，不然_positionUpdating刚设置为yes接着会被videotick重置为NO
    _positionUpdating = YES;
    //    [self pause];
    __weak CYFFmpegPlayer *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf _startLoading];
    });
    [self freeBufferedFrames];
    //刷新audioManagr缓存队列中未来得及播放完的数据
#ifdef USE_OPENAL
    [[CYPCMAudioManager audioManager] stopAndCleanBuffer];
#endif
    
    position = MIN(_decoder.duration - 1, MAX(0, position));
    position = MAX(position, 0);
    _targetPosition = position;
    
    if (playMode)
    {
        dispatch_async(_asyncDecodeQueue, ^{
            {
                __strong CYFFmpegPlayer *strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf setDecoderPosition: position];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                __strong CYFFmpegPlayer *strongSelf = weakSelf;
                if (strongSelf) {
                    [strongSelf setMoviePositionFromDecoder];
                    [weakSelf play];
                    strongSelf->_isDraging = NO;
                }
            });
        });
    }
    else
    {
        dispatch_async(_asyncDecodeQueue, ^{
            {
                __strong CYFFmpegPlayer *strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf setDecoderPosition: position];
                [strongSelf decodeFrames];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                __strong CYFFmpegPlayer *strongSelf = weakSelf;
                if (strongSelf) {
                    
                    [strongSelf setMoviePositionFromDecoder];
                    [strongSelf presentVideoFrame];
                    strongSelf->_isDraging = NO;
                    strongSelf->_buffered = NO;
                    strongSelf->_positionUpdating = NO;
                    [weakSelf _stopLoading];
                }
            });
        });
    }
}

- (void) setDecoderPosition: (CGFloat) position
{
    _decoder.position = position;
}

- (void) setMoviePositionFromDecoder
{
    _moviePosition = _decoder.position;
    _audioPosition = [_decoder position];
}

- (BOOL) decodeFrames
{
    NSAssert(dispatch_get_current_queue() == _asyncDecodeQueue, @"bugcheck");
    
    NSArray *frames = nil;
    
    if (_decoder.validVideo ||
        _decoder.validAudio) {
        
        frames = [_decoder decodeFrames:0];
    }
    
    if (frames.count) {
        return [self addFrames: frames];
    }
    return NO;
}

- (NSMutableDictionary *)getHistory
{
    return gHistory;
}

# pragma mark controlview
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

- (CYVideoPlayerRegistrar *)registrar {
    if ( _registrar ) return _registrar;
    _registrar = [CYVideoPlayerRegistrar new];
    
    __weak typeof(self) _self = self;
    _registrar.willResignActive = ^(CYVideoPlayerRegistrar * _Nonnull registrar) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        self.lockScreen = YES;
        if (self.settings.useHWDecompressor) {
            [self.decoder setUseHWDecompressor:NO];
        }
    };
    
    _registrar.didBecomeActive = ^(CYVideoPlayerRegistrar * _Nonnull registrar) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        self.lockScreen = NO;
        if (self.settings.useHWDecompressor) {
            [self.decoder setUseHWDecompressor:YES];
        }
        if ( self.state == CYFFmpegPlayerPlayState_PlayEnd ||
            self.state == CYFFmpegPlayerPlayState_Unknown ||
            self.state == CYFFmpegPlayerPlayState_PlayFailed ) return;
        //        if ( !self.userClickedPause ) [self play];
    };
    
    _registrar.oldDeviceUnavailable = ^(CYVideoPlayerRegistrar * _Nonnull registrar) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ( !self.userClickedPause ) [self pause];
    };
    
    _registrar.categoryChange = ^(CYVideoPlayerRegistrar * _Nonnull registrar) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ( !self.userClickedPause ) [self pause];
    };
    
    _registrar.newDeviceAvailable = ^(CYVideoPlayerRegistrar * _Nonnull registrar) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ( !self.userClickedPause ) [self pause];
    };
    
    return _registrar;
}

- (CYVolBrigControl *)volBrig {
    if ( _volBrigControl ) return _volBrigControl;
    _volBrigControl  = [CYVolBrigControl new];
    __weak typeof(self) _self = self;
    _volBrigControl.volumeChanged = ^(float volume) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ( self->_moreSettingFooterViewModel.volumeChanged ) self->_moreSettingFooterViewModel.volumeChanged(volume);
    };
    
    _volBrigControl.brightnessChanged = ^(float brightness) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
         if ( self->_moreSettingFooterViewModel.brightnessChanged ) self->_moreSettingFooterViewModel.brightnessChanged(brightness);
    };
    
    return _volBrigControl;
}

- (CYOrentationObserver *)orentation
{
    if (_orentation)
    {
        return _orentation;
    }
    _orentation = [[CYOrentationObserver alloc] initWithTarget:self.presentView container:self.view];
    __weak typeof(self) _self = self;
    
    _orentation.rotationCondition = ^BOOL(CYOrentationObserver * _Nonnull observer) {
        __strong typeof(_self) self = _self;
        if ( !self ) return NO;
        if ( self.stopped ) {
            if ( observer.isFullScreen ) return YES;
            else return NO;
        }
        if ( self.touchedScrollView ) return NO;
        switch (self.state) {
            case CYFFmpegPlayerPlayState_Unknown:
            case CYFFmpegPlayerPlayState_Prepare:
            case CYFFmpegPlayerPlayState_PlayFailed: return NO;
            default: break;
        }
        if ( self.disableRotation ) return NO;
        if ( self.isLockedScrren ) return NO;
        return YES;
    };
    
    _orentation.orientationChanged = ^(CYOrentationObserver * _Nonnull observer) {
        __strong typeof(_self) self = _self;
        if ( !self )
        {
            return;
        }
        self.hideControl = NO;
        _cyAnima(^{
            //            self.controlView.previewView.hidden = YES;
            _cyHiddenViews(@[self.controlView.previewView]);
            self.hiddenMoreSecondarySettingView = YES;
            self.hiddenMoreSettingView = YES;
            self.hiddenLeftControlView = !observer.isFullScreen;
            if ( observer.isFullScreen ) {
                _cyShowViews(@[self.controlView.topControlView.moreBtn,]);
                if ( self.hasBeenGeneratedPreviewImages )
                {
                    _cyShowViews(@[self.controlView.topControlView.previewBtn]);
                    [self.controlView.topControlView.previewBtn mas_updateConstraints:^(MASConstraintMaker *make) {
                        make.width.equalTo(@49);
                    }];
                }
                
                [self.controlView mas_remakeConstraints:^(MASConstraintMaker *make) {
                    //                    make.center.offset(0);
                    //                    make.height.equalTo(self.controlView.superview);
                    //                    make.width.equalTo(self.controlView.mas_height).multipliedBy(16.0 / 9.0);
                    make.edges.equalTo(self.controlView.superview);
                }];
                //横屏按钮界面处理
                self.controlView.bottomControlView.fullBtn.selected = YES;
                self.controlView.bottomControlView.is_FullScreen = YES;
            }
            else {
                _cyHiddenViews(@[self.controlView.topControlView.moreBtn,
                                 self.controlView.topControlView.previewBtn,]);
                [self.controlView.topControlView.previewBtn mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.width.equalTo(@0);
                }];
                [self.controlView mas_remakeConstraints:^(MASConstraintMaker *make) {
                    make.edges.equalTo(self.controlView.superview);
                }];
                //横屏按钮界面处理
                self.controlView.bottomControlView.fullBtn.selected = NO;
                self.controlView.bottomControlView.is_FullScreen = NO;
            }
        });//_cyAnima(^{})
        if ( self.rotatedScreen ) self.rotatedScreen(self, observer.isFullScreen);
    };//orientationChanged
    
    return _orentation;
}

- (void)setState:(CYFFmpegPlayerPlayState)state {
    if ( state == _state ) return;
    _state = state;
    if ([self.delegate respondsToSelector:@selector(CYFFmpegPlayer:ChangeStatus:)])
    {
        [self.delegate CYFFmpegPlayer:self ChangeStatus:_state];
    }
}

- (dispatch_queue_t)workQueue {
    if ( _workQueue ) return _workQueue;
    _workQueue = dispatch_queue_create("com.CYVideoPlayer.workQueue", DISPATCH_QUEUE_SERIAL);
    return _workQueue;
}

- (void)_addOperation:(void(^)(CYFFmpegPlayer *player))block {
    __weak typeof(self) _self = self;
    dispatch_async(self.workQueue, ^{
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ( block ) block(self);
    });
}

- (void)gesturesHandleWithTargetView:(UIView *)targetView {
    
    _gestureControl = [[CYPlayerGestureControl alloc] initWithTargetView:targetView];
    
    __weak typeof(self) _self = self;
    _gestureControl.triggerCondition = ^BOOL(CYPlayerGestureControl * _Nonnull control, UIGestureRecognizer *gesture) {
        __strong typeof(_self) self = _self;
        if (!self) {return NO;}
        //        if (self->_buffered) { return NO; }
        if ([self.control_delegate respondsToSelector:@selector(CYFFmpegPlayer:triggerCondition:gesture:)]) {
            return [self.control_delegate CYFFmpegPlayer:self triggerCondition:control gesture:gesture];
        }
        if ( self.isLockedScrren ) return NO;
        CGPoint point = [gesture locationInView:gesture.view];
        BOOL result = YES;
        if (CGRectContainsPoint(self.moreSettingView.frame, point) || CGRectContainsPoint(self.moreSecondarySettingView.frame, point))
        {
            result = NO;
        }
        
        if (CGRectContainsPoint(self.controlView.previewView.frame, point))
        {
            if (self.controlView.previewView.alpha != 0.0)
            {
                result = NO;
            }
        }
        
        if (CGRectContainsPoint(self.controlView.selectTableView.frame, point))
        {
            if (self.controlView.selectTableView.alpha != 0.0)
            {
                result = NO;
            }
        }
        
        return result;
    };
    
    
    _gestureControl.singleTapped = ^(CYPlayerGestureControl * _Nonnull control) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ([self.control_delegate respondsToSelector:@selector(CYFFmpegPlayer:singleTapped:)]) {
            [self.control_delegate CYFFmpegPlayer:self singleTapped:control];
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
            
            if (self.controlView.selectTableView.alpha != 0.0) {
                _cyHiddenViews(@[self.controlView.selectTableView]);
            }
            
        });
    };
    
    _gestureControl.doubleTapped = ^(CYPlayerGestureControl * _Nonnull control) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        //        if (self->_buffered) return;
        if ([self.control_delegate respondsToSelector:@selector(CYFFmpegPlayer:doubleTapped:)]) {
            [self.control_delegate CYFFmpegPlayer:self doubleTapped:control];
        }
        switch (self.state) {
            case CYFFmpegPlayerPlayState_Unknown:
            case CYFFmpegPlayerPlayState_Prepare:
                break;
            case CYFFmpegPlayerPlayState_Buffing:
            case CYFFmpegPlayerPlayState_Playing: {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self pause];
                    [self showTitle:@"已暂停"];
                });
                self.userClickedPause = YES;
            }
                break;
            case CYFFmpegPlayerPlayState_Pause:
            case CYFFmpegPlayerPlayState_PlayEnd:
            case CYFFmpegPlayerPlayState_Ready: {
                [self play];
                self.userClickedPause = NO;
            }
                break;
            case CYFFmpegPlayerPlayState_PlayFailed:
                break;
        }
        
    };
    
    _gestureControl.beganPan = ^(CYPlayerGestureControl * _Nonnull control, CYPanDirection direction, CYPanLocation location) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if (self->_buffered) return;
        if (self->_positionUpdating) { return; }
        if ([self.control_delegate respondsToSelector:@selector(CYFFmpegPlayer:beganPan:direction:location:)]) {
            [self.control_delegate CYFFmpegPlayer:self beganPan:control direction:direction location:location];
        }
        switch (direction) {
            case CYPanDirection_H: {
                
                if (![self settings].enableProgressControl) {
                    return;
                }
                
                if (self->_decoder.duration <= 0)//没有进度信息
                {
                    return;
                }
                
                //                [self _pause];
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
                
                
                if ([self.decoder validVideo])
                {
                    self.controlView.draggingProgressView.progress = self->_moviePosition / self->_decoder.duration;
                }
                else if ([self.decoder validAudio])
                {
                    self.controlView.draggingProgressView.progress = self->_audioPosition / self->_decoder.duration;
                }
                else
                {
                    self.controlView.draggingProgressView.progress = self->_decoder.position / self->_decoder.duration;
                }
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
        if ( self->_buffered ) return;
        if (self->_positionUpdating) { return; }
        if ([self.control_delegate respondsToSelector:@selector(CYFFmpegPlayer:changedPan:direction:location:)]) {
            [self.control_delegate CYFFmpegPlayer:self changedPan:control direction:direction location:location];
        }
        switch (direction) {
            case CYPanDirection_H: {
                if (![self settings].enableProgressControl) {
                    return;
                }
                
                if (self->_decoder.duration <= 0)//没有进度信息
                {
                    return;
                }
                NSLog(@"%f", translate.x * 0.0003);
                self.controlView.draggingProgressView.progress += translate.x * 0.0003;
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
                        CGFloat value = translate.y * 0.006;
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
        if ([_self.control_delegate respondsToSelector:@selector(CYFFmpegPlayer:endedPan:direction:location:)]) {
            [_self.control_delegate CYFFmpegPlayer:_self endedPan:control direction:direction location:location];
        }
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        if ( self->_buffered ) return;
        if (self->_positionUpdating) { return; }
        switch ( direction ) {
            case CYPanDirection_H:{
                if (![self settings].enableProgressControl) {
                    return;
                }
                
                if (self->_decoder.duration <= 0) { return; }//没有进度信息
                
                if (!self->_positionUpdating) { self->_positionUpdating = YES; } //手势互斥
                
                _cyAnima(^{
                    _cyHiddenViews(@[_self.controlView.draggingProgressView]);
                });
                [_self setMoviePosition:_self.controlView.draggingProgressView.progress * _self.controlView.draggingProgressView.decoder.duration playMode:YES];
                //                [_self play];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    _self.controlView.draggingProgressView.hiddenProgressSlider = NO;
                });
            }
                break;
            case CYPanDirection_V:{
                if ( location == CYPanLocation_Left ) {
                    _cyAnima(^{
                        _cyHiddenViews(@[self.volBrigControl.brightnessView]);
                    });
                }
            }
                break;
            case CYPanDirection_Unknown: break;
        }
    };
}

- (void)_itemPrepareToPlay {
    [self _startLoading];
    _interrupted = NO;
    self.hideControl = YES;
    self.userClickedPause = NO;
    self.hiddenMoreSettingView = YES;
    self.hiddenMoreSecondarySettingView = YES;
    self.controlView.bottomProgressSlider.value = 0;
    self.controlView.bottomProgressSlider.bufferProgress = 0;
    if ( self->_moreSettingFooterViewModel.volumeChanged ) {
        self->_moreSettingFooterViewModel.volumeChanged(self.volBrigControl.volume);
    }
    if ( self->_moreSettingFooterViewModel.brightnessChanged ) {
        self->_moreSettingFooterViewModel.brightnessChanged(self.volBrigControl.brightness);
    }
    [self _prepareState];
}

- (void)_itemPlayFailed {
    [self _stopLoading];
    _interrupted = YES;
    [self _pause];
    [self _playFailedState];
    _cyErrorLog(self.error);
}

- (void)_itemReadyToPlay {
    _cyAnima(^{
        self.hideControl = NO;
    });
    [self _readyState];
    if ( self.isAutoplay && !self.userClickedPause && !self.suspend ) {
        if ([self.delegate respondsToSelector:@selector(CYFFmpegPlayerStartAutoPlaying:)])
        {
            [self.delegate CYFFmpegPlayerStartAutoPlaying:self];
        }
        [self play];
    }
    [self refreshProgressViews];
}

- (void)_itemPlayEnd {
    [self _stopLoading];
    [self _pause];
    [self setDecoderPosition:0.0];
    _audioPosition = 0.0;
    _moviePosition = 0.0;
    [self refreshProgressViews];
    [self _playEndState];
}

- (void)_refreshingTimeLabelWithCurrentTime:(NSTimeInterval)currentTime duration:(NSTimeInterval)duration {
    if (currentTime == NSNotFound || isnan(currentTime) || currentTime == MAXFLOAT) {
        return;
    }
    if (currentTime > duration || duration == NSNotFound || isnan(duration) || duration == MAXFLOAT)
    {
        //        self.controlView.bottomControlView.currentTimeLabel.text = _formatWithSec(currentTime);
        //        self.controlView.bottomControlView.durationTimeLabel.text = @"LIVE?";
        self.controlView.bottomControlView.currentTimeLabel.text = @"LIVE";
    }
    else
    {
        if (currentTime >= 0 && duration >= 0) {
            self.controlView.bottomControlView.currentTimeLabel.text = _formatWithSec(currentTime);
            self.controlView.bottomControlView.durationTimeLabel.text = _formatWithSec(duration);
        }
    }
}

- (void)_refreshingTimeProgressSliderWithCurrentTime:(NSTimeInterval)currentTime duration:(NSTimeInterval)duration {
    CGFloat progress = currentTime / duration;
    if (isnan(progress) || progress == NSNotFound || progress == MAXFLOAT) {
        progress = 0.0;
    }
    self.controlView.bottomProgressSlider.value = self.controlView.bottomControlView.progressSlider.value = progress;
}

- (void)_refreshingTimeProgressSliderWithLoadedTime:(NSTimeInterval)loadedTime duration:(NSTimeInterval)duration {
    CGFloat progress = loadedTime / duration;
    if (isnan(progress) || progress == NSNotFound || progress == MAXFLOAT) {
        progress = 0.0;
    }
    self.controlView.bottomControlView.progressSlider.bufferProgress = progress;
}

# pragma mark tools
- (double)getAvailableMemorySize
{
    vm_statistics_data_t vmStats;
    mach_msg_type_number_t infoCount = HOST_VM_INFO_COUNT;
    kern_return_t kernReturn = host_statistics(mach_host_self(), HOST_VM_INFO, (host_info_t)&vmStats, &infoCount);
    if (kernReturn != KERN_SUCCESS)
    {
        return NSNotFound;
    }
    
    return ((vm_page_size * vmStats.free_count)) / 1024.0 / 1024.0;// + vm_page_size * vmStats.inactive_count
}

+ (CGFloat)memoryUsage2 {
    int64_t memoryUsageInByte = 0;
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t kernelReturn = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t) &vmInfo, &count);
    if(kernelReturn == KERN_SUCCESS) {
        memoryUsageInByte = (int64_t) vmInfo.phys_footprint;
        NSLog(@"Memory in use (in bytes): %lld", memoryUsageInByte);
    } else {
        NSLog(@"Error with task_info(): %s", mach_error_string(kernelReturn));
    }
    return memoryUsageInByte / 1024.0 / 1024.0;
}

- (double)usedMemory
{
    task_basic_info_data_t taskInfo;
    mach_msg_type_number_t infoCount =TASK_BASIC_INFO_COUNT;
    kern_return_t kernReturn =task_info(mach_task_self(),
                                        TASK_BASIC_INFO,
                                        (task_info_t)&taskInfo,
                                        &infoCount);
    if (kernReturn != KERN_SUCCESS) {
        return NSNotFound;
    }
    return taskInfo.resident_size / 1024.0 / 1024.0;
    
}

- (double)memoryUsage
{
    vm_size_t memory = memory_usage();
    return memory / 1000.0 /1000.0;
}


vm_size_t memory_usage(void) {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    return (kerr == KERN_SUCCESS) ? info.resident_size : 0; // size in bytes
}

- (double)getMemoryUsedPercent
{
    
    double result = 1;
    
    result = [self getAvailableMemorySize] / [self getTotalMemorySize];
    
    result = 1 - result;
    
    return result >= 0 ? result * 100 : 100;
}

- (double)getTotalMemorySize
{
    return [NSProcessInfo processInfo].physicalMemory / 1024.0 / 1024.0;
}


# pragma mark - 代理
# pragma mark CYSliderDelegate
- (void)sliderClick:(CYSlider *)slider
{
    switch (slider.tag) {
        case CYVideoPlaySliderTag_Progress: {
            if (!_decoder || _buffered || _positionUpdating) { return;}
            if (!_positionUpdating) { _positionUpdating = YES; }
            
            NSInteger currentTime = slider.value * _decoder.duration;
            [self setMoviePosition:currentTime playMode:YES];
            [self _delayHiddenControl];
            _cyAnima(^{
                _cyHiddenViews(@[self.controlView.draggingProgressView]);
            });
            
            
        }
            break;
            
        default:
            break;
    }
}

- (void)sliderWillBeginDragging:(CYSlider *)slider {
    switch (slider.tag) {
        case CYVideoPlaySliderTag_Progress: {
            if (!_decoder || _buffered || _positionUpdating) { return;}
            _isDraging = YES;
            //            [self _pause];
            NSInteger currentTime = slider.value * _decoder.duration;
            [self _refreshingTimeLabelWithCurrentTime:currentTime duration:_decoder.duration];
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
            if (!_decoder || _buffered || _positionUpdating) { return;}
            NSInteger currentTime = slider.value * _decoder.duration;
            [self _refreshingTimeLabelWithCurrentTime:currentTime duration:_decoder.duration];
            self.controlView.draggingProgressView.progress = slider.value;
        }
            break;
            
        default:
            break;
    }
}

- (void)sliderDidEndDragging:(CYSlider *)slider {
    switch (slider.tag) {
        case CYVideoPlaySliderTag_Progress: {
            if (!_decoder || _buffered || _positionUpdating) { return;}
            if (!_positionUpdating) { _positionUpdating = YES; }
            
            NSInteger currentTime = slider.value * _decoder.duration;
            [self setMoviePosition:currentTime playMode:self.playing];
            [self _delayHiddenControl];
            _cyAnima(^{
                _cyHiddenViews(@[self.controlView.draggingProgressView]);
            });
            [self _buffering];
        }
            break;
            
        default:
            break;
    }
}

# pragma mark CYVideoPlayerControlViewDelegate
- (void)controlView:(CYVideoPlayerControlView *)controlView clickedBtnTag:(CYVideoPlayControlViewTag)tag {
    switch (tag) {
        case CYVideoPlayControlViewTag_Back: {
            if ( self.orentation.isFullScreen ) {
                if ( self.disableRotation ) return;
                else [self.orentation _changeOrientation];
            }
            else {
                if ( self.clickedBackEvent ) self.clickedBackEvent(self);
                else [self showTitle:@"clickedBackEvent nil" duration:3];
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
            __weak typeof(&*self)weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf pause];
                [weakSelf showTitle:@"已暂停"];
            });
            self.userClickedPause = YES;
        }
            break;
        case CYVideoPlayControlViewTag_Replay: {
            _cyAnima(^{
                if ( !self.isLockedScrren ) self.hideControl = NO;
            });
            [self rePlay];
        }
            break;
        case CYVideoPlayControlViewTag_Preview: {
            [self _cancelDelayHiddenControl];
            _cyAnima(^{
                //                self.controlView.previewView.hidden = !self.controlView.previewView.isHidden;
                if (self.controlView.previewView.alpha == 0.00) {
                    _cyShowViews(@[self.controlView.previewView]);
                }else{
                    _cyHiddenViews(@[self.controlView.previewView]);
                }
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
            [self replayFromInterruptWithDecoder:_decoder];
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
                if ([self.delegate respondsToSelector:@selector(CYFFmpegPlayer:onShareBtnCick:)])
                {
                    [self.delegate CYFFmpegPlayer:self onShareBtnCick:self.controlView.topControlView.moreBtn];
                }
            }
        }
            break;
    }
}

- (void)replayFromInterruptWithDecoder:(CYPlayerDecoder *)old_decoder
{
    
    if (self.state == CYFFmpegPlayerPlayState_Prepare)
    {
        return;
    }
    //    if (!decoder)
    //    {
    //        [self setupPlayerWithPath:_path];
    //        return;
    //    }
    [self _itemPrepareToPlay];
    NSString * path = _path;
    id<CYAudioManager> audioManager = [CYAudioManager audioManager];
    BOOL canUseAudio = [audioManager activateAudioSession];
    __block CYPlayerDecoder *decoder = [[CYPlayerDecoder alloc] init];
    CYVideoDecodeType type = CYVideoDecodeTypeVideo;
    if (canUseAudio) {
        type |= CYVideoDecodeTypeAudio;
    }
    if (old_decoder) {
        type = old_decoder.decodeType;
    }
    [decoder setDecodeType:type];
    __weak __typeof(&*self)weakSelf = self;
    
    _interrupted = NO;
    decoder.interruptCallback = ^BOOL(){
        __strong __typeof(&*self)strongSelf = weakSelf;
        return strongSelf ? [strongSelf interruptDecoder] : YES;
    };
    self.autoplay = YES;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        __strong __typeof(&*self)strongSelf = weakSelf;
        
        NSError *error = nil;
        [decoder openFile:path error:&error];
        [decoder setupVideoFrameFormat:CYVideoFrameFormatYUV];
        
        if (strongSelf) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                __strong __typeof(&*self)strongSelf2 = weakSelf;
                if (strongSelf2 && !strongSelf.stopped && !error) {
                    [decoder setPosition:old_decoder.position];
                    //关闭原先的解码器
                    //                    [strongSelf.decoder closeFile];
                    strongSelf2.controlView.decoder = decoder;
                    //播放器连接新的解码器decoder
                    [strongSelf2 setMovieDecoder:decoder withError:error];
                }
                else if (error) {
                    [weakSelf handleDecoderMovieError: error];
                    weakSelf.error = error;
                    [weakSelf _itemPlayFailed];
                }
                else
                {
                    [weakSelf _itemPlayFailed];
                }
            });
        }
    });
    
    //    __weak __typeof(&*self)weakSelf = self;
    //    decoder.interruptCallback = ^BOOL(){
    //        __strong __typeof(&*self)strongSelf = weakSelf;
    //        return strongSelf ? [strongSelf interruptDecoder] : YES;
    //    };
    //
    //    //    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
    //
    //    //    });
    //    dispatch_async(dispatch_get_global_queue(0, 0), ^{
    //        __strong __typeof(&*self)strongSelf = weakSelf;
    //
    //        __block NSError *error = nil;
    //        [decoder openFile:decoder.path error:&error];
    //
    //        if (strongSelf) {
    //            dispatch_sync(dispatch_get_main_queue(), ^{
    //                __strong __typeof(&*self)strongSelf2 = weakSelf;
    //                if (strongSelf2) {
    //
    //                    LoggerStream(2, @"setMovieDecoder");
    //
    //                    if (!error && decoder) {
    //                        strongSelf2->_decoder        = decoder;
    //                        strongSelf2->_asyncDecodeQueue  = dispatch_queue_create("CYPlayer AsyncDecode", DISPATCH_QUEUE_SERIAL);
    //                        strongSelf2->_videoFrames    = [NSMutableArray array];
    //                        strongSelf2->_audioFrames    = [NSMutableArray array];
    //
    //                        if (strongSelf2->_decoder.subtitleStreamsCount) {
    //                            strongSelf2->_subtitles = [NSMutableArray array];
    //                        }
    //
    //                        if (strongSelf2->_decoder.isNetwork) {
    //
    //                            strongSelf2->_minBufferedDuration = NETWORK_MIN_BUFFERED_DURATION;
    //                            strongSelf2->_maxBufferedDuration = NETWORK_MAX_BUFFERED_DURATION;
    //
    //                        } else {
    //
    //                            strongSelf2->_minBufferedDuration = LOCAL_MIN_BUFFERED_DURATION;
    //                            strongSelf2->_maxBufferedDuration = LOCAL_MAX_BUFFERED_DURATION;
    //                        }
    //
    //                        if (!strongSelf2->_decoder.validVideo)
    //                            strongSelf2->_minBufferedDuration *= 10.0; // increase for audio
    //
    //                        // allow to tweak some parameters at runtime
    //                        if (strongSelf2->_parameters.count) {
    //
    //                            id val;
    //
    //                            val = [strongSelf2->_parameters valueForKey: CYPlayerParameterMinBufferedDuration];
    //                            if ([val isKindOfClass:[NSNumber class]])
    //                                strongSelf2->_minBufferedDuration = [val floatValue];
    //
    //                            val = [strongSelf2->_parameters valueForKey: CYPlayerParameterMaxBufferedDuration];
    //                            if ([val isKindOfClass:[NSNumber class]])
    //                                strongSelf2->_maxBufferedDuration = [val floatValue];
    //
    //                            val = [strongSelf2->_parameters valueForKey: CYPlayerParameterDisableDeinterlacing];
    //                            if ([val isKindOfClass:[NSNumber class]])
    //                                strongSelf2->_decoder.disableDeinterlacing = [val boolValue];
    //
    //                            if (strongSelf2->_maxBufferedDuration < strongSelf2->_minBufferedDuration)
    //                                strongSelf2->_maxBufferedDuration = strongSelf2->_minBufferedDuration * 2;
    //                        }
    //
    //                        LoggerStream(2, @"buffered limit: %.1f - %.1f", strongSelf2->_minBufferedDuration, strongSelf2->_maxBufferedDuration);
    //                        [strongSelf2 updatePosition:weakSelf.decoder.validVideo ? strongSelf->_moviePosition : strongSelf->_audioPosition playMode:YES];
    //                        [strongSelf2 play];
    //
    //
    //                    } else {
    //                        if (!strongSelf2->_interrupted) {
    //                            [strongSelf2 handleDecoderMovieError: error];
    //                            strongSelf2.error = error;
    //                            [strongSelf2 _itemPlayFailed];
    //                        }
    //                    }
    //
    //                }
    //            });
    //        }
    //    });
}

- (void)controlView:(CYVideoPlayerControlView *)controlView didSelectPreviewFrame:(CYVideoFrame *)frame
{
    //    [self _pause];
    NSInteger currentTime = frame.position;
    [self setMoviePosition:currentTime];
    [self _delayHiddenControl];
    _cyAnima(^{
        _cyHiddenViews(@[self.controlView.draggingProgressView]);
    });
}

- (void)controlViewOnDefinitionBtnClick:(CYVideoPlayerControlView *)controlView
{
    __weak typeof(self) _self = self;
    
    _cyAnima(^{
        _cyShowViews(@[self.controlView.selectTableView]);
        self.hideControl = YES;
    });
    
    //构造视频清晰度数据
    __block NSMutableArray * definitions = [[NSMutableArray alloc] initWithCapacity:4];
    if (self.settings.definitionTypes & CYFFmpegPlayerDefinitionLLD) {
        if (_definitionType == CYFFmpegPlayerDefinitionLLD) {
            [definitions addObject:@">>流畅"];
        }else {
            [definitions addObject:@"流畅"];
        }
    }
    if (self.settings.definitionTypes & CYFFmpegPlayerDefinitionLSD) {
        if (_definitionType == CYFFmpegPlayerDefinitionLSD) {
            [definitions addObject:@">>标清"];
        }else {
            [definitions addObject:@"标清"];
        }
    }
    if (self.settings.definitionTypes & CYFFmpegPlayerDefinitionLHD) {
        if (_definitionType == CYFFmpegPlayerDefinitionLHD) {
            [definitions addObject:@">>高清"];
        }else {
            [definitions addObject:@"高清"];
        }
    }
    if (self.settings.definitionTypes & CYFFmpegPlayerDefinitionLUD) {
        if (_definitionType == CYFFmpegPlayerDefinitionLUD) {
            [definitions addObject:@">>超清"];
        }else {
            [definitions addObject:@"超清"];
        }
    }
    
    self.controlView.selectTableView.dataArray = definitions;
    
    self.controlView.selectTableView.numberOfRowsInSection = ^NSInteger(UITableView * _Nonnull tableView, NSInteger section) {
        return definitions.count;
    };
    
    self.controlView.selectTableView.cellForRowAtIndexPath = ^UITableViewCell *(UITableView * _Nonnull tableView, NSIndexPath * _Nonnull indexPath) {
        UITableViewCell * cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont fontWithName:@"PingFang-SC-Medium" size:20];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        NSString * text = definitions[indexPath.row];
        cell.textLabel.text = text;
        if ([text containsString:@">>"])
        {
            cell.textLabel.text = [text stringByReplacingOccurrencesOfString:@">>" withString:@""];
            cell.textLabel.textColor = CYColorWithHEX(0x00c5b5);
        }
        return cell;
    };
    
    self.controlView.selectTableView.heightForRowAtIndexPath = ^CGFloat(UITableView * _Nonnull tableView, NSIndexPath * _Nonnull indexPath) {
        __strong typeof(_self) self = _self;
        return self.controlView.selectTableView.frame.size.height / definitions.count;
    };
    
    self.controlView.selectTableView.didSelectRowAtIndexPath = ^(UITableView * _Nonnull tableView, NSIndexPath * _Nonnull indexPath) {
        __strong typeof(_self) self = _self;
        if ([self.delegate respondsToSelector:@selector(CYFFmpegPlayer:ChangeDefinition:)])
        {
            NSString * definitionStr = [definitions objectAtIndex:indexPath.row];
            CYFFmpegPlayerDefinitionType definiType = 0;
            if ([definitionStr containsString:@"流畅"])
            {
                definiType = CYFFmpegPlayerDefinitionLLD;
            }
            else if ([definitionStr containsString:@"标清"])
            {
                definiType = CYFFmpegPlayerDefinitionLSD;
            }
            else if ([definitionStr containsString:@"高清"])
            {
                definiType = CYFFmpegPlayerDefinitionLHD;
            }
            else if ([definitionStr containsString:@"超清"])
            {
                definiType = CYFFmpegPlayerDefinitionLUD;
            }
            if (self->_definitionType != definiType) {
                self->_definitionType = definiType;
                [self.delegate CYFFmpegPlayer:self ChangeDefinition:definiType];
                //切换清晰度的btn界面处理
                self->_isChangingDefinition = YES;
            }
        }
        _cyAnima(^{
            _cyHiddenViews(@[self.controlView.selectTableView]);
        });
    };
    
    [self.controlView.selectTableView reloadTableView];
}

- (void)controlViewOnSelectionsBtnClick:(CYVideoPlayerControlView *)controlView
{
    if (![self.delegate respondsToSelector:@selector(CYFFmpegPlayer:SetSelectionsNumber:)]) {
        return;
    }
    
    _cyAnima(^{
        _cyShowViews(@[self.controlView.selectTableView]);
        self.hideControl = YES;
    });
    
    __weak typeof(self) _self = self;
    [self.delegate CYFFmpegPlayer:self SetSelectionsNumber:^(NSInteger selectionsNumber) {
        __strong typeof(_self) self = _self;
        if (!self) {
            return;
        }
        __block NSInteger selectionsNum = selectionsNumber;
        self.controlView.selectTableView.numberOfRowsInSection = ^NSInteger(UITableView * _Nonnull tableView, NSInteger section) {
            return selectionsNum;
        };
        
        if (self.settings.setCurrentSelectionsIndex)
        {
            self->_currentSelections = self.settings.setCurrentSelectionsIndex();
        }
        
        self.controlView.selectTableView.cellForRowAtIndexPath = ^UITableViewCell *(UITableView * _Nonnull tableView, NSIndexPath * _Nonnull indexPath) {
            __strong typeof(_self) self = _self;
            UITableViewCell * cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.textColor = [UIColor whiteColor];
            cell.textLabel.font = [UIFont fontWithName:@"PingFang-SC-Medium" size:19];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.textLabel.text = [NSString stringWithFormat:@"第%ld节",(long)indexPath.row + 1];
            if (self->_currentSelections == indexPath.row) {
                cell.textLabel.textColor = CYColorWithHEX(0x00c5b5);
            }
            return cell;
        };
        
        self.controlView.selectTableView.heightForRowAtIndexPath = ^CGFloat(UITableView * _Nonnull tableView, NSIndexPath * _Nonnull indexPath) {
            __strong typeof(_self) self = _self;
            if (selectionsNumber > 4) {
                return 30.0;
            }
            return self.controlView.selectTableView.frame.size.height / selectionsNumber;
        };
        
        self.controlView.selectTableView.didSelectRowAtIndexPath = ^(UITableView * _Nonnull tableView, NSIndexPath * _Nonnull indexPath) {
            __strong typeof(_self) self = _self;
            if ([self.delegate respondsToSelector:@selector(CYFFmpegPlayer:changeSelections:)])
            {
                if (self->_currentSelections != indexPath.row) {
                    self->_currentSelections = indexPath.row;
                    [self.delegate CYFFmpegPlayer:self changeSelections:indexPath.row];
                    //切换清晰度的btn界面处理
                    self->_isChangingSelections = YES;
                }
            }
            _cyAnima(^{
                _cyHiddenViews(@[self.controlView.selectTableView]);
            });
        };
        
        [self.controlView.selectTableView reloadTableView];
        [self.controlView.selectTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_currentSelections inSection:0]];
    }];
}

- (void)controlViewOnRateBtnClick:(CYVideoPlayerControlView *)controlView{
    
    __weak typeof(self) _self = self;
    
    _cyAnima(^{
        __strong typeof(_self) self = _self;
        _cyShowViews(@[self.controlView.selectTableView]);
        self.hideControl = YES;
    });
    
    //倍速选项
    NSArray * rates = @[@(0.5),@(0.75),@(1.0),@(1.25),@(1.5),@(2.0)];
    __block NSMutableArray *ratesMarray = [NSMutableArray arrayWithArray:rates];
    self.controlView.selectTableView.dataArray = ratesMarray;
    
    self.controlView.selectTableView.numberOfRowsInSection = ^NSInteger(UITableView * _Nonnull tableView, NSInteger section) {
        return ratesMarray.count;
    };
    
    self.controlView.selectTableView.cellForRowAtIndexPath = ^UITableViewCell *(UITableView * _Nonnull tableView, NSIndexPath * _Nonnull indexPath) {
        __strong typeof(_self) self = _self;
        UITableViewCell * cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont fontWithName:@"PingFang-SC-Medium" size:20];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        NSString * text = ratesMarray[indexPath.row];
        if (self.rate == [text doubleValue]) {
            cell.textLabel.textColor = CYColorWithHEX(0x00c5b5);
        }
        cell.textLabel.text = [NSString stringWithFormat:@"%@X",text];
        return cell;
    };
    
    self.controlView.selectTableView.heightForRowAtIndexPath = ^CGFloat(UITableView * _Nonnull tableView, NSIndexPath * _Nonnull indexPath) {
        __strong typeof(_self) self = _self;
        return self.controlView.selectTableView.frame.size.height / ratesMarray.count;
    };
    
    self.controlView.selectTableView.didSelectRowAtIndexPath = ^(UITableView * _Nonnull tableView, NSIndexPath * _Nonnull indexPath) {
        __strong typeof(_self) self = _self;
        //        if ([self.delegate respondsToSelector:@selector(CYFFmpegPlayer:changeRate:)])
        //        {
        NSString * rate = [ratesMarray objectAtIndex:indexPath.row];
        self.rate = [rate doubleValue];
        
        //            [self.delegate CYFFmpegPlayer:self changeRate:[rate doubleValue]];
        //        }
        _cyAnima(^{
            _cyHiddenViews(@[self.controlView.selectTableView]);
        });
    };
    
    [self.controlView.selectTableView reloadTableView];
}

@end

# pragma mark -

@implementation CYFFmpegPlayer (State)

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
        if ( self.state == CYFFmpegPlayerPlayState_Pause ) return;
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
        if ([self.delegate respondsToSelector:@selector(CYFFmpegPlayer:ControlViewDisplayStatus:)])  {
            [self.delegate CYFFmpegPlayer:self ControlViewDisplayStatus:!hideControl];
        }
    }
}

- (BOOL)isHiddenControl {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)_unknownState {
    // hidden
    _cyHiddenViews(@[self.controlView]);
    self.state = CYFFmpegPlayerPlayState_Unknown;
}

- (void)_prepareState {
    // show
    _cyShowViews(@[self.controlView]);
    
    // hidden
    //    self.controlView.previewView.alpha = 0;
    //    self.controlView.previewView.hidden = YES;
    _cyHiddenViews(@[
        self.controlView.previewView,
        self.controlView.draggingProgressView,
        self.controlView.topControlView.previewBtn,
        //                     self.controlView.leftControlView.lockBtn,
        self.controlView.centerControlView.failedBtn,
        self.controlView.centerControlView.replayBtn,
        self.controlView.bottomControlView.pauseBtn,
        self.controlView.bottomProgressSlider,
        self.controlView.draggingProgressView.imageView,
        self.controlView.selectTableView,
        
                   ]);
    
    [self _unlockScreenState];
    
    [self.controlView.topControlView.previewBtn mas_updateConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@0);
    }];
    
    if ( self.orentation.fullScreen ) {
        _cyShowViews(@[self.controlView.topControlView.moreBtn,]);
        self.hiddenLeftControlView = NO;
        if ( self.hasBeenGeneratedPreviewImages )
        {
            _cyShowViews(@[self.controlView.topControlView.previewBtn]);
            [self.controlView.topControlView.previewBtn mas_updateConstraints:^(MASConstraintMaker *make) {
                make.width.equalTo(@49);
            }];
        }
    }
    else {
        self.hiddenLeftControlView = YES;
        _cyHiddenViews(@[self.controlView.topControlView.moreBtn,
                         self.controlView.topControlView.previewBtn,]);
        [self.controlView.topControlView.previewBtn mas_updateConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(@0);
        }];
    }
    
    self.state = CYFFmpegPlayerPlayState_Prepare;
}

- (void)_readyState {
    self.state = CYFFmpegPlayerPlayState_Ready;
}

- (void)_playState {
    
    // show
    _cyShowViews(@[self.controlView.bottomControlView.pauseBtn]);
    
    // hidden
    // hidden
    _cyHiddenViews(@[
        self.controlView.bottomControlView.playBtn,
        self.controlView.centerControlView.replayBtn,
        self.controlView.centerControlView.failedBtn
                   ]);
    
    self.state = CYFFmpegPlayerPlayState_Playing;
}

- (void)_pauseState {
    
    // show
    _cyShowViews(@[self.controlView.bottomControlView.playBtn]);
    
    // hidden
    _cyHiddenViews(@[self.controlView.bottomControlView.pauseBtn]);
    
    self.state = CYFFmpegPlayerPlayState_Pause;
}

- (void)_playEndState {
    
    if (self.settings.nextAutoPlaySelectionsPath) {
        
        NSString * path = self.settings.nextAutoPlaySelectionsPath();
        
        if (path.length > 0) {
            [self changeSelectionsPath:path];
        }else {
            goto end;
        }
    }
    else {
        
    end: {
        // show
        _cyShowViews(@[self.controlView.centerControlView.replayBtn,
                       self.controlView.bottomControlView.playBtn]);
        
        // hidden
        _cyHiddenViews(@[self.controlView.bottomControlView.pauseBtn]);
        
        
        self.state = CYFFmpegPlayerPlayState_PlayEnd;
    }
    }
}

- (void)_playFailedState {
    // show
    [self showBackBtn];
    _cyShowViews(@[self.controlView.centerControlView,
                   self.controlView.centerControlView.failedBtn]);
    
    // hidden
    _cyHiddenViews(@[self.controlView.centerControlView.replayBtn]);
    
    self.state = CYFFmpegPlayerPlayState_PlayFailed;
    self.playing = NO;
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
    _cyHiddenViews(@[
        self.controlView.previewView,
        //        self.controlView.selectTableView,
                   ]);
    //    self.controlView.previewView.hidden = YES;
    
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
        [[UIApplication sharedApplication] setStatusBarHidden:YES animated:YES];
    }
    else {
        [[UIApplication sharedApplication] setStatusBarHidden:NO animated:YES];
    }
#pragma clang diagnostic pop
}

- (void)_showControlState {
    
    // hidden
    _cyHiddenViews(@[self.controlView.bottomProgressSlider,
                     self.controlView.previewView,
                     //                     self.controlView.selectTableView,
                   ]);
    //    _cyHiddenViews(@[self.controlView.previewView]);
    //    self.controlView.previewView.hidden = YES;
    
    // transform show
    if (self.orentation.fullScreen ) {
        self.controlView.topControlView.transform = CGAffineTransformMakeTranslation(0, 0);
        [[UIApplication sharedApplication] setStatusBarHidden:YES animated:YES];
    }
    else {
        self.controlView.topControlView.transform = CGAffineTransformIdentity;
        [[UIApplication sharedApplication] setStatusBarHidden:NO animated:YES];
    }
    self.controlView.bottomControlView.transform = CGAffineTransformIdentity;
    
    self.hiddenLeftControlView = !self.orentation.fullScreen && !self.isLockedScrren;
    
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    //        [[UIApplication sharedApplication] setStatusBarHidden:NO animated:YES];
#pragma clang diagnostic pop
}

@end

# pragma mark -

@implementation CYFFmpegPlayer (Setting)
- (void)setClickedBackEvent:(void (^)(CYFFmpegPlayer *player))clickedBackEvent {
    objc_setAssociatedObject(self, @selector(clickedBackEvent), clickedBackEvent, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void (^)(CYFFmpegPlayer * _Nonnull))clickedBackEvent {
    return objc_getAssociatedObject(self, _cmd);
}

- (float)rate {
    return [objc_getAssociatedObject(self, _cmd) floatValue];
}

- (void)setRate:(float)rate {
    if ( self.rate == rate ) return;
    objc_setAssociatedObject(self, @selector(rate), @(rate), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if ( !self.decoder ) return;
    self.decoder.rate = rate;
    self.userClickedPause = NO;
    _cyAnima(^{
        [self _playState];
    });
    if ( self->_moreSettingFooterViewModel.playerRateChanged )
        self->_moreSettingFooterViewModel.playerRateChanged(rate);
    if ( self.rateChanged ) self.rateChanged(self);
}

- (void)settingPlayer:(void (^)(CYVideoPlayerSettings * _Nonnull))block {
    [self _addOperation:^(CYFFmpegPlayer *player) {
        if ( block ) block([player settings]);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:CYSettingsPlayerNotification object:[player settings]];
        });
    }];
}

- (void)setInternallyChangedRate:(void (^)(CYFFmpegPlayer * _Nonnull, float))internallyChangedRate {
    objc_setAssociatedObject(self, @selector(internallyChangedRate), internallyChangedRate, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void (^)(CYFFmpegPlayer * _Nonnull, float))internallyChangedRate {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)_clear {
    _controlView.asset = nil;
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
    if (setting.title.length <= 0)
    {
        setting.title = @"";
    }
    setting.enableProgressControl = YES;
    
    setting.definitionTypes = CYFFmpegPlayerDefinitionNone;
    setting.enableSelections = NO;
    setting.useHWDecompressor = NO;
}

- (void (^)(CYFFmpegPlayer * _Nonnull))rateChanged {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setRateChanged:(void (^)(CYFFmpegPlayer * _Nonnull))rateChanged {
    objc_setAssociatedObject(self, @selector(rateChanged), rateChanged, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (BOOL)disableRotation {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setDisableRotation:(BOOL)disableRotation {
    objc_setAssociatedObject(self, @selector(disableRotation), @(disableRotation), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setRotatedScreen:(void (^)(CYFFmpegPlayer * _Nonnull, BOOL))rotatedScreen {
    objc_setAssociatedObject(self, @selector(rotatedScreen), rotatedScreen, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void (^)(CYFFmpegPlayer * _Nonnull, BOOL))rotatedScreen {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setControlViewDisplayStatus:(void (^)(CYFFmpegPlayer * _Nonnull, BOOL))controlViewDisplayStatus {
    objc_setAssociatedObject(self, @selector(controlViewDisplayStatus), controlViewDisplayStatus, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void (^)(CYFFmpegPlayer * _Nonnull, BOOL))controlViewDisplayStatus {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setAutoplay:(BOOL)autoplay {
    objc_setAssociatedObject(self, @selector(isAutoplay), @(autoplay), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isAutoplay {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

@end

# pragma mark -

@implementation CYFFmpegPlayer (Control)

- (id<CYFFmpegControlDelegate>)control_delegate
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setControl_delegate:(id<CYFFmpegControlDelegate>)control_delegate
{
    objc_setAssociatedObject(self, @selector(control_delegate), control_delegate, OBJC_ASSOCIATION_ASSIGN);
}


- (BOOL)play {
    if (!_decoder) { return NO; }
    self.suspend = NO;
    self.stopped = NO;
    
    //    if ( !self.asset ) return NO;
    self.userClickedPause = NO;
    if ( self.state != CYFFmpegPlayerPlayState_Playing ) {
        _cyAnima(^{
            [self _playState];
        });
    }
    [self _play];
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    return YES;
}


- (BOOL)pause {
    if (!_decoder) { return NO; }
    
    self.suspend = YES;
    
    //    if ( !self.asset ) return NO;
    if ( self.state != CYFFmpegPlayerPlayState_Pause ) {
        _cyAnima(^{
            [self _pauseState];
            self.hideControl = NO;
        });
    }
    [self _pause];
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    //    if ( self.orentation.fullScreen )
    //    {
    //        [self showTitle:@"已暂停"];
    //    }
    return YES;
}

- (void)stop {
    self.suspend = NO;
    self.stopped = YES;
    [self _stop];
    //    if ( !self.asset ) return;
    if ( self.state != CYFFmpegPlayerPlayState_Unknown ) {
        _cyAnima(^{
            [self _unknownState];
        });
    }
    [self _clear];
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

- (void)setLockscreen:(LockScreen)lockscreen
{
    objc_setAssociatedObject(self, @selector(lockscreen), lockscreen, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (LockScreen)lockscreen
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)hideBackBtn {
    _cyHiddenViews(@[
        self.controlView.topControlView.previewBtn,
        //                     self.controlView.leftControlView,
        //                     self.controlView.centerControlView,
        //                     self.controlView.bottomControlView,
        self.controlView.draggingProgressView,
                   ]);
    self.hiddenLeftControlView = YES;
    [self.controlView.topControlView.previewBtn mas_updateConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@0);
    }];
    _cyAnima(^{
        self.hideControl = YES;
    });
}

- (void)showBackBtn {
    _cyShowViews(@[self.controlView,
                   //                   self.controlView.bottomControlView,
                   self.controlView.topControlView,
                   self.controlView.topControlView.backBtn,
                   self.controlView.centerControlView,
                   self.controlView.topControlView.titleBtn]);
    _cyHiddenViews(@[
        self.controlView.topControlView.previewBtn,
        //                     self.controlView.leftControlView,
        //                     self.controlView.centerControlView,
        //                     self.controlView.bottomControlView,
        self.controlView.draggingProgressView,
                   ]);
    self.hiddenLeftControlView = YES;
    [self.controlView.topControlView.previewBtn mas_updateConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@0);
    }];
    _cyShowViews(@[self.controlView, self.controlView.topControlView, self.controlView.topControlView.backBtn, self.controlView.topControlView.titleBtn]);
    _cyAnima(^{
        self.hideControl = NO;
    });
}

- (void)playNextVideo {
    if (self.settings.nextAutoPlaySelectionsPath) {
        NSString * path = self.settings.nextAutoPlaySelectionsPath();
        if (path.length > 0) {
            [self changeSelectionsPath:path];
        }
    }
}

- (void)playPreviousVideo{
    if (self.settings.previousSelectionPath) {
        NSString *path = self.settings.previousSelectionPath();
        if (path.length > 0) {
            [self changeSelectionsPath:path];
        }
    }
}

@end

# pragma mark -

@implementation CYFFmpegPlayer (Prompt)

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

# pragma mark - Test
- (NSString*)localBufferPath
{
    NSFileManager * fileManager = [NSFileManager defaultManager];
    NSArray *Paths=NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES );
    NSString *MyDocpath=[Paths objectAtIndex:0];
    MyDocpath = [MyDocpath stringByAppendingPathComponent:@"CYPlayer"];
    if (self.decoder)
    {
        NSString * fileName = [self.decoder.path lastPathComponent];
        MyDocpath = [MyDocpath stringByAppendingPathComponent:fileName];
    }
    BOOL isDir = NO;
    // fileExistsAtPath 判断一个文件或目录是否有效，isDirectory判断是否一个目录
    BOOL existed = [fileManager fileExistsAtPath:MyDocpath isDirectory:&isDir];
    if ( !(isDir == YES && existed == YES) ) {//如果文件夹不存在
        [fileManager createDirectoryAtPath:MyDocpath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return MyDocpath;
}


- (void)archiveFrame:(CYPlayerFrame *)frame
{
    //归档
    NSFileManager * fileManager = [NSFileManager defaultManager];
    //1:准备路径
    NSString *path = [self localBufferPath];
    if (frame.type == CYPlayerFrameTypeAudio) {
        path = [path stringByAppendingPathComponent:@"audio"];
        BOOL isDir = NO;
        // fileExistsAtPath 判断一个文件或目录是否有效，isDirectory判断是否一个目录
        BOOL existed = [fileManager fileExistsAtPath:path isDirectory:&isDir];
        if ( !(isDir == YES && existed == YES) ) {//如果文件夹不存在
            [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        }
        NSNumber * posi_tmp = [NSNumber numberWithDouble:frame.position];
        path = [path stringByAppendingPathComponent:[posi_tmp stringValue]];
    }else if (frame.type == CYPlayerFrameTypeVideo) {
        path = [path stringByAppendingPathComponent:@"video"];
        BOOL isDir = NO;
        // fileExistsAtPath 判断一个文件或目录是否有效，isDirectory判断是否一个目录
        BOOL existed = [fileManager fileExistsAtPath:path isDirectory:&isDir];
        if ( !(isDir == YES && existed == YES) ) {//如果文件夹不存在
            [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        }
        NSNumber * posi_tmp = [NSNumber numberWithDouble:frame.position];
        path = [path stringByAppendingPathComponent:[posi_tmp stringValue]];
    }else if (frame.type == CYPlayerFrameTypeArtwork) {
        path = [path stringByAppendingPathComponent:@"artwork"];
        BOOL isDir = NO;
        // fileExistsAtPath 判断一个文件或目录是否有效，isDirectory判断是否一个目录
        BOOL existed = [fileManager fileExistsAtPath:path isDirectory:&isDir];
        if ( !(isDir == YES && existed == YES) ) {//如果文件夹不存在
            [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        }
        NSNumber * posi_tmp = [NSNumber numberWithDouble:frame.position];
        path = [path stringByAppendingPathComponent:[posi_tmp stringValue]];
    }else if (frame.type == CYPlayerFrameTypeSubtitle) {
        path = [path stringByAppendingPathComponent:@"subtitle"];
        BOOL isDir = NO;
        // fileExistsAtPath 判断一个文件或目录是否有效，isDirectory判断是否一个目录
        BOOL existed = [fileManager fileExistsAtPath:path isDirectory:&isDir];
        if ( !(isDir == YES && existed == YES) ) {//如果文件夹不存在
            [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        }
        NSNumber * posi_tmp = [NSNumber numberWithDouble:frame.position];
        path = [path stringByAppendingPathComponent:[posi_tmp stringValue]];
    }
    
    //2:准备存储数据对象(用可变数组进行接收)
    NSMutableData *data = [NSMutableData new];
    //3:创建归档对象
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc]initForWritingWithMutableData:data];
    //4:开始归档
    [archiver encodeObject:frame forKey:@"frame"];
    //5:完成归档
    [archiver finishEncoding];
    //6:写入文件
    BOOL result = [data writeToFile:path atomically:YES];
    if (!result) {
        NSLog(@"归档失败postion:%f", frame.position);
    }
}

- (NSArray *)unarchiveFrameWithPostion:(CGFloat)position type:(CYPlayerFrameType)type
{
    NSMutableArray * frames = [[NSMutableArray alloc] initWithCapacity:60];
    
    //1:准备路径
    //    NSString *path = [self localBufferPath];
    //    if (type == CYPlayerFrameTypeAudio) {
    //        path = [path stringByAppendingPathComponent:@"audio"];
    //        path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%f",frame.position]];
    //    }else if (frame.type == CYPlayerFrameTypeVideo) {
    //        path = [path stringByAppendingPathComponent:@"video"];
    //        path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%f",frame.position]];
    //    }
    
    return frames;
}


- (void) asyncUnarchiveFrames
{
    if (self.unarchiving)
    {
        return;
    }
    self.unarchiving = YES;
    
    __weak CYFFmpegPlayer *weakSelf = self;
    __weak CYPlayerDecoder *weakDecoder = _decoder;
    
    const CGFloat duration = _decoder.isNetwork ? .0f : 0.1f;
    dispatch_async(_asyncDecodeQueue, ^{
        __strong CYFFmpegPlayer *strongSelf = weakSelf;
        if (strongSelf)
        {
            if (!weakSelf.playing)
                return;
            
            BOOL good = YES;
            while (good && !weakSelf.stopped) {
                CFAbsoluteTime startTime =CFAbsoluteTimeGetCurrent();
                good = NO;
                
                @autoreleasepool {
                    
                    if (weakDecoder && (weakDecoder.validVideo || weakDecoder.validAudio)) {
                        
                        //                        NSArray *[frames = [weakSelf unarchiveFrameWithPostion:<#(CGFloat)#> type:<#(CYPlayerFrameType)#>
                        
                        //                        if (frames.count) {
                        //
                        //                            good = [weakSelf addFrames:frames];
                        //                        }
                        //                        frames = nil;
                    }
                }
                CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
                //NSLog(@"Linked in %f ms", linkTime *1000.0);
            }
            
            weakSelf.unarchiving = NO;
        }
    });
}

@end

