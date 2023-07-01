//
//  CYFFmpegViewController.m
//  CYPlayer
//
//  Created by 黄威 on 2018/7/19.
//  Copyright © 2018年 Sutan. All rights reserved.
//

#import "CYFFmpegViewController.h"
#import "CYFFmpegPlayer.h"
#import <Masonry.h>
#import "UIViewController+CYExtension.h"

#define kiPad  ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) //ipad

@interface CYFFmpegViewController ()<CYFFmpegPlayerDelegate>
{
    NSArray *_localMovies;
    NSArray *_remoteMovies;
    CYFFmpegPlayer *vc;
    CYFFmpegPlayer *vc1;
    CGFloat _rate;
}

@property (nonatomic, strong) UIView * contentView;
@property (nonatomic, strong) UIView * contentView1;
@property (nonatomic, strong) UIButton * infoBtn;
@property (nonatomic, strong) UIButton *addRateBtn;
@property (nonatomic, strong) UILabel *rateLabel;
@property (nonatomic, strong) UIButton *reduceRateBtn;


@end

@implementation CYFFmpegViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    [self openLandscape];
    
    _remoteMovies = @[
        
        //            @"http://eric.cast.ro/stream2.flv",
        //            @"http://liveipad.wasu.cn/cctv2_ipad/z.m3u8",
        @"http://www.wowza.com/_h264/BigBuckBunny_175k.mov",
        // @"http://www.wowza.com/_h264/BigBuckBunny_115k.mov",
        @"rtsp://184.72.239.149/vod/mp4:BigBuckBunny_115k.mov",
        @"http://santai.tv/vod/test/test_format_1.3gp",
        @"http://santai.tv/vod/test/test_format_1.mp4",
        @"rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov",
        @"http://static.tripbe.com/videofiles/20121214/9533522808.f4v.mp4",
        @"rtmp://live.hkstv.hk.lxdns.com/live/hks",
        //@"rtsp://184.72.239.149/vod/mp4://BigBuckBunny_175k.mov",
        //@"http://santai.tv/vod/test/BigBuckBunny_175k.mov",
        
        //            @"rtmp://aragontvlivefs.fplive.net/aragontvlive-live/stream_normal_abt",
        //            @"rtmp://ucaster.eu:1935/live/_definst_/discoverylacajatv",
        //            @"rtmp://edge01.fms.dutchview.nl/botr/bunny.flv"
    ];
    
    
    UIView * contentView = [UIView new];
    contentView.backgroundColor = [UIColor blackColor];
    self.contentView = contentView;
    [self.view addSubview:contentView];
    [contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.offset(0);
        make.leading.trailing.offset(0);
        make.height.equalTo(contentView.mas_width).multipliedBy(9.0 / 16.0);
    }];
    
//    UIView * contentView1 = [UIView new];
//    contentView1.backgroundColor = [UIColor blackColor];
//    self.contentView1 = contentView1;
//    [self.view addSubview:contentView1];
//    [contentView1 mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.top.equalTo(@400);
//        make.leading.trailing.offset(0);
//        make.height.equalTo(contentView.mas_width).multipliedBy(9.0 / 16.0);
//    }];
    
    [self addPlayer];
//    [self addPlayer1];
    
    [self addInfoBtn];
    //    [self addRateView];
}

- (void)addPlayer1
{
    NSString *path;
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    //    path = _remoteMovies[4];
    path = self.path.length > 0 ? self.path :  _remoteMovies[6];
    
    // increase buffering for .wmv, it solves problem with delaying audio frames
    if ([path.pathExtension isEqualToString:@"wmv"])
        parameters[CYPlayerParameterMinBufferedDuration] = @(5.0);
    
    // disable deinterlacing for iPhone, because it's complex operation can cause stuttering
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        parameters[CYPlayerParameterDisableDeinterlacing] = @(YES);
    
    
    
    
    vc1 = [CYFFmpegPlayer movieViewWithContentPath:path parameters:nil];
    [vc1 settingPlayer:^(CYVideoPlayerSettings *settings) {
        settings.definitionTypes = CYFFmpegPlayerDefinitionLLD | CYFFmpegPlayerDefinitionLHD | CYFFmpegPlayerDefinitionLSD | CYFFmpegPlayerDefinitionLUD;
        settings.enableSelections = YES;
        settings.setCurrentSelectionsIndex = ^NSInteger{
            return 3;//假设上次播放到了第四节
        };
        settings.nextAutoPlaySelectionsPath = ^NSString *{
            return @"https://vodplay.yellowei360.com/liveRecord/46eca58c0ccf5b857fa76cb3c9fea487/dentalink-vod/515197938314592256/2020-08-17-12-18-39_2020-08-17-12-48-39.m3u8";
        };
        //        settings.useHWDecompressor = YES;
        //        settings.enableProgressControl = NO;
    }];
    vc1.delegate = self;
    vc1.autoplay = YES;
    vc1.generatPreviewImages = YES;
    [self.contentView1 addSubview:vc1.view];
    
    [vc1.view mas_makeConstraints:^(MASConstraintMaker *make) {
        if (kiPad)
        {
            make.center.offset(0);
            make.leading.trailing.offset(0);
            make.height.equalTo(vc.view.mas_width).multipliedBy(9.0 / 16.0);
        }
        else
        {
            make.center.offset(0);
            make.top.bottom.offset(0);
            make.width.equalTo(vc.view.mas_height).multipliedBy(16.0 / 9.0);
        }
    }];
    
    
    __weak __typeof(&*self)weakSelf = self;
    vc1.lockscreen = ^(BOOL isLock) {
        if (isLock)
        {
            [weakSelf lockRotation];
        }
        else
        {
            [weakSelf unlockRotation];
        }
    };
    
    _rate = 1.0;
}

- (void)addPlayer
{
    NSString *path;
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    //    path = _remoteMovies[4];
    path = self.path.length > 0 ? self.path :  _remoteMovies[6];
    
    // increase buffering for .wmv, it solves problem with delaying audio frames
    if ([path.pathExtension isEqualToString:@"wmv"])
        parameters[CYPlayerParameterMinBufferedDuration] = @(5.0);
    
    // disable deinterlacing for iPhone, because it's complex operation can cause stuttering
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        parameters[CYPlayerParameterDisableDeinterlacing] = @(YES);
    
    
    vc = [CYFFmpegPlayer movieViewWithContentPath:path parameters:nil];
    [vc settingPlayer:^(CYVideoPlayerSettings *settings) {
        settings.definitionTypes = CYFFmpegPlayerDefinitionLLD | CYFFmpegPlayerDefinitionLHD | CYFFmpegPlayerDefinitionLSD | CYFFmpegPlayerDefinitionLUD;
        settings.enableSelections = YES;
        settings.setCurrentSelectionsIndex = ^NSInteger{
            return 3;//假设上次播放到了第四节
        };
        settings.nextAutoPlaySelectionsPath = ^NSString *{
            return @"https://vodplay.yellowei360.com/liveRecord/46eca58c0ccf5b857fa76cb3c9fea487/dentalink-vod/515197938314592256/2020-08-17-12-18-39_2020-08-17-12-48-39.m3u8";
        };
//        settings.useHWDecompressor = YES;
        //        settings.enableProgressControl = NO;
    }];
    vc.delegate = self;
    vc.autoplay = YES;
    vc.generatPreviewImages = NO;
    [self.contentView addSubview:vc.view];
    
    [vc.view mas_makeConstraints:^(MASConstraintMaker *make) {
        if (kiPad)
        {
            make.center.offset(0);
            make.leading.trailing.offset(0);
            make.height.equalTo(vc.view.mas_width).multipliedBy(9.0 / 16.0);
        }
        else
        {
            make.center.offset(0);
            make.top.bottom.offset(0);
            make.width.equalTo(vc.view.mas_height).multipliedBy(16.0 / 9.0);
        }
    }];
    
    
    __weak __typeof(&*self)weakSelf = self;
    vc.lockscreen = ^(BOOL isLock) {
        if (isLock)
        {
            [weakSelf lockRotation];
        }
        else
        {
            [weakSelf unlockRotation];
        }
    };
    
    _rate = 1.0;
}

- (void)addInfoBtn
{
    self.infoBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
    [self.infoBtn setTitle:@"info" forState:UIControlStateNormal];
    [self.view addSubview:self.infoBtn];
    [self.infoBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.infoBtn addTarget:self action:@selector(onInfoBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.infoBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.infoBtn.superview.mas_centerX);
        make.width.height.equalTo(@50);
        make.top.equalTo(self.contentView.mas_bottom).offset(20);
    }];
}

- (void)addRateView{
    
    self.rateLabel = [[UILabel alloc] init];
    self.rateLabel.textColor = [UIColor whiteColor];
    self.rateLabel.font = [UIFont systemFontOfSize:15];
    self.rateLabel.textAlignment = NSTextAlignmentCenter;
    self.rateLabel.text = @"倍数";
    [self.view addSubview:self.rateLabel];
    [self.rateLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.infoBtn.superview.mas_centerX);
        make.width.height.equalTo(@50);
        make.top.equalTo(self.infoBtn.mas_bottom).offset(20);
    }];
    
    self.reduceRateBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
    [self.reduceRateBtn setTitle:@"-" forState:UIControlStateNormal];
    [self.view addSubview:self.reduceRateBtn];
    [self.reduceRateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.reduceRateBtn addTarget:self action:@selector(reduceBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.reduceRateBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.rateLabel.mas_left).offset(-20);
        make.width.height.equalTo(@50);
        make.top.equalTo(self.infoBtn.mas_bottom).offset(20);
    }];
    
    self.addRateBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
    [self.addRateBtn setTitle:@"+" forState:UIControlStateNormal];
    [self.view addSubview:self.addRateBtn];
    [self.addRateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.addRateBtn addTarget:self action:@selector(rateBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.addRateBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.rateLabel.mas_right).offset(20);
        make.width.height.equalTo(@50);
        make.top.equalTo(self.infoBtn.mas_bottom).offset(20);
    }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES];
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.navigationController setNavigationBarHidden:NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [vc stop];
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

# pragma mark - Event
- (void)onInfoBtnClick:(UIButton *)sender
{
    if (vc.decoder)
    {
        NSString * info = [[vc.decoder info] description];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Info" message:(info.length ? info : @"") delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
        [alert show];
    }
}


- (void)rateBtnClick:(UIButton *)sender{
    if (vc.decoder) {
        _rate+=0.5;
        vc.rate = _rate;
        _rateLabel.text = [NSString stringWithFormat:@"%.2f",_rate];
    }
}

- (void)reduceBtnClick:(UIButton *)sender{
    if (vc.decoder) {
        _rate -= 0.5;
        vc.rate = _rate;
        _rateLabel.text = [NSString stringWithFormat:@"%.2f",_rate];
    }
}


# pragma mark - 系统横竖屏切换调用

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    if (size.width > size.height)
    {
        [self.contentView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.bottom.equalTo(@(0));
            make.left.equalTo(@(0));
            make.right.equalTo(@(0));
        }];
    }
    else
    {
        [self.contentView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.center.offset(0);
            make.leading.trailing.offset(0);
            make.height.equalTo(self.contentView.mas_width).multipliedBy(9.0 / 16.0);
        }];
    }
}


# pragma mark - CYFFmpegPlayerDelegate
- (void)CYFFmpegPlayer:(CYFFmpegPlayer *)player ChangeDefinition:(CYFFmpegPlayerDefinitionType)definition
{
    NSString * url = @"";
    switch (definition) {
        case CYFFmpegPlayerDefinitionLLD:
        {
            url = @"http://vodplay.yellowei360.com/9f76b359339f4bbc919f35e39e55eed4/1d5b7ad50866e8e80140d658c5e59f8e-fd.mp4";
        }
            break;
        case CYFFmpegPlayerDefinitionLSD:
        {
            url = @"http://vodplay.yellowei360.com/9f76b359339f4bbc919f35e39e55eed4/efa9514952ef5e242a4dfa4ee98765fb-ld.mp4";
        }
            break;
        case CYFFmpegPlayerDefinitionLHD:
        {
            url = @"http://vodplay.yellowei360.com/9f76b359339f4bbc919f35e39e55eed4/04ad8e1641699cd71819fe38ec2be506-sd.mp4";
        }
            break;
        case CYFFmpegPlayerDefinitionLUD:
        {
            url = @"http://vodplay.yellowei360.com/9f76b359339f4bbc919f35e39e55eed4/b43889cb2eb86103abb977d2b246cb83-hd.mp4";
        }
            break;
            
        default:
        {
            url = @"http://vodplay.yellowei360.com/9f76b359339f4bbc919f35e39e55eed4/efa9514952ef5e242a4dfa4ee98765fb-ld.mp4";
        }
            break;
    }
    //    NSString * localV = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"mp4"];
    [vc changeDefinitionPath:url];
}

- (void)CYFFmpegPlayer:(CYFFmpegPlayer *)player SetSelectionsNumber:(CYPlayerSelectionsHandler)setNumHandler
{
    setNumHandler(20);
}

- (void)CYFFmpegPlayer:(CYFFmpegPlayer *)player changeSelections:(NSInteger)selectionsNum
{
    NSString * url = @"";
    switch (selectionsNum) {
        case 0:
        {
            url = @"http://vodplay.yellowei360.com/9f76b359339f4bbc919f35e39e55eed4/1d5b7ad50866e8e80140d658c5e59f8e-fd.mp4";
        }
            break;
        case 1:
        {
            url = @"http://vodplay.yellowei360.com/9f76b359339f4bbc919f35e39e55eed4/efa9514952ef5e242a4dfa4ee98765fb-ld.mp4";
        }
            break;
        case 2:
        {
            url = @"http://vodplay.yellowei360.com/9f76b359339f4bbc919f35e39e55eed4/04ad8e1641699cd71819fe38ec2be506-sd.mp4";
        }
            break;
        case 3:
        {
            url = @"http://vodplay.yellowei360.com/9f76b359339f4bbc919f35e39e55eed4/b43889cb2eb86103abb977d2b246cb83-hd.mp4";
        }
            break;
            
        default:
        {
            url = @"http://vodplay.yellowei360.com/9f76b359339f4bbc919f35e39e55eed4/efa9514952ef5e242a4dfa4ee98765fb-ld.mp4";
        }
            break;
    }
    //    NSString * localV = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"mp4"];
    [vc settingPlayer:^(CYVideoPlayerSettings *settings) {
        settings.setCurrentSelectionsIndex = ^NSInteger{
            return selectionsNum;
        };
    }];
    [vc changeSelectionsPath:url];
}

- (void)CYFFmpegPlayer:(CYFFmpegPlayer *)player changeRate:(double)rate{
    vc.rate = rate;
}

@end
