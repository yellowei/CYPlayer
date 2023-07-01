[![Version](https://img.shields.io/cocoapods/v/CYPlayer.svg?style=flat)](http://cocoapods.org/pods/CYPlayer)
[![release](https://badgen.net/github/release/yellowei/CYPlayer)](https://github.com/yellowei/CYPlayer/releases)
[![issues](https://img.shields.io/github/issues/yellowei/CYPlayer)](https://github.com/yellowei/CYPlayer/issues)
[![forks](https://img.shields.io/github/forks/yellowei/CYPlayer)](https://github.com/yellowei/CYPlayer/fork)
[![stars](https://img.shields.io/github/stars/yellowei/CYPlayer)](https://github.com/yellowei/CYPlayer/star)
[![license](https://img.shields.io/github/license/yellowei/CYPlayer)](https://github.com/yellowei/CYPlayer/blob/master/LICENSE)


# CYPlayer

CYPlayer是一个基于FFmpeg作为解码内核的播放器SDK，并且同时支持AVKit，支持左右滑动手势来调整视频播放进度、上下滑动手势调节音量大小等等各种手势，并且支持全屏播放， 支持横竖屏控制，采用自动布局Autolayout（Masonry）。

此外，CYPlayer已经在Cocoapods发布，直接通过pods安装就可以使用。代码已做了UI和解码核心的分离，将解码核心ffmpeg部分单独打包为CYFFmpeg（如果只需用到ffmpeg，直接pods安装此CYFFmpeg即可），CYFFmpeg支持还支持ffmpeg命令行方式的调用。

如果觉得不错就star吧~

![Logo](https://raw.githubusercontent.com/yellowei/CYPlayer/master/icon-2.png)     ![ffmpeg](https://raw.githubusercontent.com/yellowei/CYPlayer/master/ffmpeg_logo.png)


## 通过cocoapods安装播放器到项目

```
pod 'CYPlayer'
```

### demo

[OC示例 - https://github.com/yellowei/TestCYPlayer](https://github.com/yellowei/TestCYPlayer)

[Swift示例 - https://github.com/yellowei/TestCYPlayerSwift](https://github.com/yellowei/TestCYPlayerSwift)

[SwiftUI示例 - https://github.com/yellowei/TestCYPlayerSwiftUI](https://github.com/yellowei/TestCYPlayerSwiftUI)



## 播放器基本特性

- [x] ✅ 支持动态帧率控制，适配各种性能的机型，随系统性能动态调节解码帧率;

- [x] ✅ 动态内存控制，适配小内存的iPhone，防止在老设备crash；

- [x] ✅ 基于Masonry的AutoLayout；

- [x] ✅ 拿来可用，带控制交互界面，可自定义, 默认提供了变速播放功能, 清晰度选择功能；

- [x] ✅ 音频采用Sonic优化，**支持倍速播放**；

- [x] ✅ 基于CYFFMpeg动态库；

- [x] ✅ 支持x86_64模拟器调试和armv7/arm64真机调试；

- [x] ✅ Enable Bitcode=YES；

- [x] ✅ 开箱即用。


## [CYFFmpeg-基于ffmpeg的iOS动态库](https://github.com/yellowei/CYFFmpeg)

用于ios的ffmpeg动态库

实际上0.3.1版本开始，集成ffmpeg、x264、fdk-acc、ffmpeg-cmdctl、sambclient（samba）、openssl于一体

#### 关于解码动态库CYFFmpeg

- [x] ✅ CYFFmpeg可以通过CocoaPods进行安装；

- [x] ✅ 构建为动态库版本；

- [x] ✅ 支持Samba协议，多线程优化；

- [x] ✅ 支持Http、Https(CYFFmpeg 0.3.1)协议；

- [x] ✅ 支持RTMP、HLS、RTSP协议；

- [x] ✅ 基于ffmpeg 3.4.2；

- [x] ✅ 支持ffmpeg命令行方式调用；

```objective-c
//ffmpeg -i Downloads.mp4 -r 1 -ss 00:20 -vframes 1 %3d.jpg
char* a[] = {
    "ffmpeg",
    "-ss",
    timeInterval,
    "-i",
    movie,
    "-f",
    "image2",
    "-r",
    "25",
    "-vframes",
    "1",
    outPic
};
//加锁
dispatch_semaphore_wait([CYGCDManager sharedManager].av_read_frame_lock, DISPATCH_TIME_FOREVER);
int result = ffmpeg_main(sizeof(a)/sizeof(*a), a);
dispatch_semaphore_signal([CYGCDManager sharedManager].av_read_frame_lock);
```

- [x] ✅ 支持x86_64模拟器、armv7/arm64真机运行；

- [x] ✅ Enable Bitcode=YES；

- [x] ✅ 开箱即用。

===========================

## 示例动图


<img src="https://raw.githubusercontent.com/yellowei/CYPlayer/master/prew-1.png" width="251" height="480" align="middle" /><img src="https://raw.githubusercontent.com/yellowei/CYPlayer/master/prew-2.png" width="480" height="251" align="middle" />


## 简单的代码

### Objective-C中的使用

ViewController.m

```Objective-C

#import "ViewController.h"
#import <CYPlayer/CYPlayer.h>
#import <Masonry.h>

@interface ViewController ()
{
    CYFFmpegPlayer * vc1;// 全局化, 便于控制
}

@property (nonatomic, strong) UIView * contentView; //给一个contentView承载播放器的视图, 也可直接add到当前控制器的self.view
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    UIView * contentView = [UIView new];
    contentView.backgroundColor = [UIColor blackColor];
    self.contentView = contentView;
    [self.view addSubview:contentView];
    //设置自动布局
    [contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.offset(0);
        make.leading.trailing.offset(0);
        make.height.equalTo(contentView.mas_width).multipliedBy(9.0 / 16.0);
    }];
    
    // 初始化播放器
    vc1 = [CYFFmpegPlayer movieViewWithContentPath:@"https://vodplay.com/liveRecord/46eca58c0ccf5b857fa76cb3c9fea487/dentalink-vod/515197938314592256/2020-08-17-12-18-39_2020-08-17-12-48-39.m3u8" parameters:nil];
    [vc1 settingPlayer:^(CYVideoPlayerSettings *settings) {
        settings.definitionTypes = CYFFmpegPlayerDefinitionLLD | CYFFmpegPlayerDefinitionLHD | CYFFmpegPlayerDefinitionLSD | CYFFmpegPlayerDefinitionLUD;
        settings.enableSelections = YES;
        settings.setCurrentSelectionsIndex = ^NSInteger{
            return 3;//假设上次播放到了第四节
        };
        settings.nextAutoPlaySelectionsPath = ^NSString *{
            return @"https://vodplay.com/liveRecord/46eca58c0ccf5b857fa76cb3c9fea487/dentalink-vod/515197938314592256/2020-08-17-12-18-39_2020-08-17-12-48-39.m3u8";
        };
        //        settings.useHWDecompressor = YES;
        //        settings.enableProgressControl = NO;
    }];

    vc1.autoplay = YES;
    vc1.generatPreviewImages = NO;//是否生成预览图片
    [self.contentView addSubview:vc1.view];
    //播放器视图添加到父视图之后,一定要设置播放器视图的frame,不然会导致opengl无法渲染以致播放失败
    [vc1.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.offset(0);
        make.top.bottom.offset(0);
        make.width.equalTo(vc1.view.mas_height).multipliedBy(16.0 / 9.0);
    }];
}

- (void)dealloc
{
    [vc1 stop];//记得要停止播放
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

```

开启自动横竖屏切换需在AppDelegate中添加如下方法
AppDelegate.m
```Objective-C

-(UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window{

    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscapeRight | UIInterfaceOrientationPortraitUpsideDown | UIInterfaceOrientationLandscapeLeft;
}

```

### Swift中的使用


Podfile中需要加入"use_frameworks!"
```ruby
#ruby
# Uncomment the next line to define a global platform for your project
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'

target 'TestCYPlayer' do
  # Uncomment the next line if you're using Swift or would like to use dynamic frameworks
    use_frameworks!

    pod 'CYPlayer'
end

```

ViewController.swift

```swift

import UIKit
import CYPlayer
import Masonry

class ViewController: UIViewController {
    var contentView : UIView?
    var player : CYFFmpegPlayer?
    

    override func viewDidLoad() {
        super.viewDidLoad()
        //创建cententview
        self.contentView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: 0, height: 0))
        self.view.addSubview(self.contentView!)
        self.contentView?.mas_makeConstraints({ (make) in
            make?.leading.trailing().offset()(0)
            make?.center.offset()(0)
            make?.height.equalTo()(contentView?.mas_width)?.multipliedBy()(9.0 / 16.0)
        })
        
        //初始化播放器
        player  = CYFFmpegPlayer.movieView(withContentPath: "https://vodplay.com/liveRecord/46eca58c0ccf5b857fa76cb3c9fea487/dentalink-vod/515197938314592256/2020-08-17-12-18-39_2020-08-17-12-48-39.m3u8", parameters: nil) as? CYFFmpegPlayer
        
        
        let definition =  CYFFmpegPlayerDefinitionType.LHD.rawValue | CYFFmpegPlayerDefinitionType.LLD.rawValue | CYFFmpegPlayerDefinitionType.LSD.rawValue | CYFFmpegPlayerDefinitionType.LUD.rawValue
        player?.settingPlayer({ (settings) in
            settings?.definitionTypes = CYFFmpegPlayerDefinitionType.init(rawValue: definition)!
            settings?.enableSelections = true
            settings?.setCurrentSelectionsIndex =  { () -> Int in
                return 3
            }
            settings?.nextAutoPlaySelectionsPath = { () -> String in
                return "https://vodplay.com/liveRecord/46eca58c0ccf5b857fa76cb3c9fea487/dentalink-vod/515197938314592256/2020-08-17-12-18-39_2020-08-17-12-48-39.m3u8"
            }
        })
        
        player?.isAutoplay = true
        player?.generatPreviewImages = true
        self.contentView?.addSubview((player?.view)!)
        //播放器视图添加到父视图之后,一定要设置播放器视图的frame,不然会导致opengl无法渲染以致播放失败
        player?.view.mas_makeConstraints({ (make) in
            make?.center.offset()(0)
            make?.top.bottom().offset()(0)
            make?.width.equalTo()(player?.view.mas_height)?.multipliedBy()(16.0 / 9.0)
        })
    }


    deinit {
        player?.stop()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        if size.width > size.height {
            
            contentView?.mas_remakeConstraints({ (make) in
                make?.top.bottom().equalTo()(0)
                make?.left.right().equalTo()(0)
            })
        } else {
            contentView?.mas_remakeConstraints({ (make) in
                make?.leading.trailing().offset()(0)
                make?.center.offset()(0)
                make?.height.equalTo()(contentView?.mas_width)?.multipliedBy()(9.0 / 16.0)
            })
        }
    }
}
```

开启自动横竖屏切换需在AppDelegate中添加如下方法

AppDelegate.swift

```swift

func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
    let mask = UIInterfaceOrientationMask.portrait.rawValue | UIInterfaceOrientationMask.landscapeLeft.rawValue | UIInterfaceOrientationMask.landscapeRight.rawValue | UIInterfaceOrientationMask.portraitUpsideDown.rawValue
    return UIInterfaceOrientationMask.init(rawValue: mask)
}

```

## 注意

```
因为新版Xcode不再提供32位模拟器

CYFFmpeg0.3.1开始, 编译架构取消了i386, 仍然支持x86_64模拟器和所有真机

不再需要设置"OTHER_LDFLAGS"的"-read_only_relocs suppress"
```


基于CYFFmpeg0.2.2版本以及之前版本的需要做以下事情

```
pod安装CYPlayer后,如果遇到xcode无法调试的问题

请到xocde工程Pod目录下CYPlayer找到"Support Files/CYPlayer.xcconfig"文件

删除OTHER_LDFLAGS中的-read_only_relocs suppress, 尝试真机能否运行
```


## 相关阅读


[《iOS中基于ffmpeg开发的播放器打开多个samba链接的解决方案》](https://www.jianshu.com/p/2838b9ddecaf)

[《ffmpeg中samba网络协议的兼容分析(一)》](https://www.jianshu.com/p/ada84499f386)

[《ffmpeg中samba网络协议的兼容分析(一)》](https://www.jianshu.com/p/06b5794a7213)

[《ffmpeg中samba网络协议的兼容分析(一)》](https://www.jianshu.com/p/ada84499f386)


