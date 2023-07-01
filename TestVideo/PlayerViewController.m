//
//  PlayerViewController.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/11/29.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "PlayerViewController.h"
#import <CYFFmpeg/CYFFmpeg.h>
#import <Masonry.h>
#import "UIViewController+CYExtension.h"
#import "CYPlayer.h"

#define Player  [CYVideoPlayer sharedPlayer]

#define kiPad  ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) //ipad

@interface PlayerViewController ()

@property (nonatomic, strong) UIView * contentView;

@end

@implementation PlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithRed:221.0/255.0 green:39.0/255.0 blue:150.0/255.0 alpha:0.5];
    
    UIView * contentView = [UIView new];
    contentView.backgroundColor = [UIColor blackColor];
    self.contentView = contentView;
    [self.view addSubview:contentView];
    [contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.offset(0);
        make.leading.trailing.offset(0);
        make.height.equalTo(contentView.mas_width).multipliedBy(9.0 / 16.0);
    }];
    
    [contentView addSubview:Player.view];
    Player.autoplay = NO;
    [Player.view mas_makeConstraints:^(MASConstraintMaker *make) {
        if (kiPad)
        {
            make.center.offset(0);
            make.leading.trailing.offset(0);
            make.height.equalTo(Player.view.mas_width).multipliedBy(9.0 / 16.0);
        }
        else
        {
            make.center.offset(0);
            make.top.bottom.offset(0);
            make.width.equalTo(Player.view.mas_height).multipliedBy(16.0 / 9.0);
        }
    }];
    
    Player.placeholder = [UIImage imageNamed:@"test"];
//    http://video.cdn.lanwuzhe.com/1493370091000dfb1
//    http://vod.lanwuzhe.com/d09d3a5f9ba4491fa771cd63294ad349%2F0831eae12c51428fa7aed3825c511370-5287d2089db37e62345123a1be272f8b.mp4
//    Player.asset = [[CYVideoPlayerAssetCarrier alloc] initWithAssetURL:[[NSBundle mainBundle] URLForResource:@"sample.mp4" withExtension:nil] beginTime:10];
    
//    Player.asset = [[CYVideoPlayerAssetCarrier alloc] initWithAssetURL:[NSURL URLWithString:@"http://vod.lanwuzhe.com/d09d3a5f9ba4491fa771cd63294ad349%2F0831eae12c51428fa7aed3825c511370-5287d2089db37e62345123a1be272f8b.mp4"] beginTime:10];
    
    if (self.assetURL)
    {
        Player.asset = [[CYVideoPlayerAssetCarrier alloc] initWithAssetURL:self.assetURL beginTime:0];
    }
    
    __weak typeof(self) weakSelf = self;
    Player.clickedBackEvent = ^(CYVideoPlayer * _Nonnull player) {
        if ( !weakSelf ) return;
        [Player stop];
        [weakSelf.navigationController popViewControllerAnimated:YES];
    };
    
    Player.lockscreen = ^(BOOL isLock) {
        if (isLock)
        {
            [weakSelf lockRotation];
        }
        else
        {
            [weakSelf unlockRotation];
        }
    };
    
    [self _setPlayerMoreSettingItems];
    
    // Do any additional setup after loading the view.
}

- (void)_setPlayerMoreSettingItems {
    
    CYVideoPlayerMoreSettingSecondary *QQ = [[CYVideoPlayerMoreSettingSecondary alloc] initWithTitle:@"" image:[UIImage imageNamed:@"qq"] clickedExeBlock:^(CYVideoPlayerMoreSetting * _Nonnull model) {
        [Player showTitle:@"分享到QQ"];
    }];
    
    CYVideoPlayerMoreSettingSecondary *wechat = [[CYVideoPlayerMoreSettingSecondary alloc] initWithTitle:@"" image:[UIImage imageNamed:@"wechat"] clickedExeBlock:^(CYVideoPlayerMoreSetting * _Nonnull model) {
        [Player showTitle:@"分享到wechat"];
    }];
    
    CYVideoPlayerMoreSettingSecondary *weibo = [[CYVideoPlayerMoreSettingSecondary alloc] initWithTitle:@"" image:[UIImage imageNamed:@"weibo"] clickedExeBlock:^(CYVideoPlayerMoreSetting * _Nonnull model) {
        [Player showTitle:@"分享到weibo"];
    }];
    
    CYVideoPlayerMoreSetting *share = [[CYVideoPlayerMoreSetting alloc] initWithTitle:@"share" image:[UIImage imageNamed:@"share"] showTowSetting:YES twoSettingTopTitle:@"分享到" twoSettingItems:@[QQ, wechat, weibo] clickedExeBlock:^(CYVideoPlayerMoreSetting * _Nonnull model) {
        [Player showTitle:@"clicked Share"];
    }];
    
    CYVideoPlayerMoreSetting *download = [[CYVideoPlayerMoreSetting alloc] initWithTitle:@"下载" image:[UIImage imageNamed:@"download"] clickedExeBlock:^(CYVideoPlayerMoreSetting * _Nonnull model) {
        [Player showTitle:@"clicked download"];
    }];
    
    CYVideoPlayerMoreSetting *collection = [[CYVideoPlayerMoreSetting alloc] initWithTitle:@"收藏" image:[UIImage imageNamed:@"collection"] clickedExeBlock:^(CYVideoPlayerMoreSetting * _Nonnull model) {
        [Player showTitle:@"clicked collection"];
    }];
    
    CYVideoPlayerMoreSetting.titleFontSize = 10;
    
    Player.moreSettings = @[share, download, collection];
}

- (void)dealloc {
    [Player stop];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    [self openLandscape];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [self closeLandscape];
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

@end
