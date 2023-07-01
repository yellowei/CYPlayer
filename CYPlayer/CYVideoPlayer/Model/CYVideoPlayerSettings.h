//
//  CYVideoPlayerSettings.h
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/9/25.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, CYFFmpegPlayerDefinitionType) {
    CYFFmpegPlayerDefinitionNone = 0,
    CYFFmpegPlayerDefinitionLLD = 1 << 0,//流畅(LLD)
    CYFFmpegPlayerDefinitionLSD = 1 << 1,//标清(LSD)
    CYFFmpegPlayerDefinitionLHD = 1 << 2,//高清(LHD)
    CYFFmpegPlayerDefinitionLUD = 1 << 3//超清(LUD)
};

extern NSNotificationName const CYSettingsPlayerNotification;

typedef NSInteger(^CYPlayerSettingsSetCurrentSelectionsIndex)();

typedef NSString *(^CYPlayerSettingsNextAutoPlaySelectionsPath)();

typedef NSString *(^CYPlayerSettingPreviousPlaySelectionsPath)();


@class UIImage, UIColor;

@interface CYVideoPlayerSettings : NSObject
// MARK: btns
@property (nonatomic, strong, readwrite) UIImage *backBtnImage;
@property (nonatomic, strong, readwrite) UIImage *playBtnImage;
@property (nonatomic, strong, readwrite) UIImage *pauseBtnImage;
@property (nonatomic, strong, readwrite) UIImage *replayBtnImage;
@property (nonatomic, strong, readwrite) NSString *replayBtnTitle;
@property (nonatomic, assign, readwrite) float replayBtnFontSize;
@property (nonatomic, strong, readwrite) UIImage *fullBtnImage_nor;
@property (nonatomic, strong, readwrite) UIImage *fullBtnImage_sel;
@property (nonatomic, strong, readwrite) UIImage *previewBtnImage;
@property (nonatomic, strong, readwrite) UIImage *moreBtnImage;
@property (nonatomic, copy, readwrite)   NSString *title;
@property (nonatomic, strong, readwrite) UIImage *lockBtnImage;
@property (nonatomic, strong, readwrite) UIImage *unlockBtnImage;

// MARK: progress slider
/// 轨迹
@property (nonatomic, strong, readwrite) UIColor *progress_traceColor;
/// 轨道
@property (nonatomic, strong, readwrite) UIColor *progress_trackColor;
/// 拇指图片
@property (nonatomic, strong, readwrite) UIImage *progress_thumbImage;
@property (nonatomic, strong, readwrite) UIImage *progress_thumbImage_nor;
@property (nonatomic, strong, readwrite) UIImage *progress_thumbImage_sel;
/// 缓冲颜色
@property (nonatomic, strong, readwrite) UIColor *progress_bufferColor;
/// 轨道高度
@property (nonatomic, assign, readwrite) float progress_traceHeight;

// MARK:  more slider
/// 轨迹
@property (nonatomic, strong, readwrite) UIColor *more_traceColor;
/// 轨道
@property (nonatomic, strong, readwrite) UIColor *more_trackColor;
/// 轨道高度
@property (nonatomic, assign, readwrite) float more_trackHeight;

// MARK: Loading
@property (nonatomic, strong, readwrite) UIColor *loadingLineColor;

// MARK: Control
@property (nonatomic, assign, readwrite) BOOL enableProgressControl;

/// 是否使用硬件解码
@property (nonatomic, assign, readwrite) BOOL useHWDecompressor;


/// 清晰度选项类型
@property (nonatomic, assign, readwrite) CYFFmpegPlayerDefinitionType definitionTypes;

/// 可选集
@property (nonatomic, assign, readwrite) BOOL enableSelections;

/// 外部设置当前播放第几集
@property (nonatomic, copy, readwrite) CYPlayerSettingsSetCurrentSelectionsIndex setCurrentSelectionsIndex;

/// 外部设置待下一集自动播放的链接
@property (nonatomic, copy, readwrite) CYPlayerSettingsNextAutoPlaySelectionsPath nextAutoPlaySelectionsPath;

/// 配置上一集的播放链接
@property (nonatomic, copy) CYPlayerSettingPreviousPlaySelectionsPath previousSelectionPath;


+ (instancetype)sharedVideoPlayerSettings;

@end
