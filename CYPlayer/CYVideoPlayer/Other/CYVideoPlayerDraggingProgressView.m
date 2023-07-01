//
//  CYVideoPlayerDraggingProgressView.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/12/4.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerDraggingProgressView.h"
#import "CYUIFactory.h"
#import "CYVideoPlayerResources.h"
#import <Masonry/Masonry.h>
#import "CYSlider.h"
#import "CYVideoPlayerAssetCarrier.h"
#import "CYPlayerDecoder.h"

inline static NSString *_formatWithSec(NSInteger sec) {
    NSInteger seconds = sec % 60;
    NSInteger minutes = sec / 60;
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
}

@interface CYVideoPlayerDraggingProgressView ()



@end

@implementation CYVideoPlayerDraggingProgressView

@synthesize progressLabel = _progressLabel;
@synthesize imageView = _imageView;
@synthesize progressSlider = _progressSlider;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    [self _draggingProgressSetupView];
    __weak typeof(self) _self = self;
    self.setting = ^(CYVideoPlayerSettings * _Nonnull setting) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        self.progressSlider.trackImageView.backgroundColor = setting.progress_trackColor;
        self.progressSlider.traceImageView.backgroundColor = setting.progress_traceColor;
    };
    return self;
}

- (void)_draggingProgressSetupView {
    [self addSubview:self.imageView];
    [self addSubview:self.progressLabel];
    [self addSubview:self.progressSlider];
    
    [_imageView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(_progressLabel.mas_top).offset(-12);
        make.centerX.offset(0);
        //        make.width.offset(120);
        make.width.equalTo(_imageView.superview.mas_width).multipliedBy(1.0 / 3.0);
        make.height.equalTo(_imageView.mas_width).multipliedBy(9.f / 16);
    }];
    
    [_progressLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(_progressLabel.superview.mas_centerY).offset(20);
        make.centerX.offset(0);
    }];
    
    [_progressSlider mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(_progressLabel.mas_bottom).offset(8);
        make.centerX.offset(0);
        //        make.width.offset(54);
        make.width.equalTo(_progressSlider.superview.mas_width).multipliedBy(1.0 / 5.0);
        make.height.offset(3);
    }];
}

- (void)setProgress:(float)progress {
    if ( isnan(progress) || progress < 0 ) progress = 0;
    else if ( progress > 1 ) progress = 1;
    _progress = progress;
    _progressSlider.value = progress;
    if (_asset)
    {
        _progressLabel.text = _formatWithSec(_asset.duration * progress);
    }
    else if (_decoder)
    {
        _progressLabel.text = _formatWithSec(_decoder.duration * progress);
    }
    
    [self changeDragging];
}

- (void)setHiddenProgressSlider:(BOOL)hiddenProgressSlider {
    _hiddenProgressSlider = hiddenProgressSlider;
    _progressSlider.hidden = hiddenProgressSlider;
}

- (void)changeDragging {
    NSTimeInterval time = _asset.duration * _progress;
    __weak typeof(self) _self = self;
    [_asset screenshotWithTime:time size:_size completion:^(CYVideoPlayerAssetCarrier * _Nonnull asset, CYVideoPreviewModel * _Nonnull images, NSError * _Nullable error) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.imageView.alpha = 1;
            self.imageView.image = images.image;
        });
    }];
}

- (CYSlider *)progressSlider {
    if ( _progressSlider ) return _progressSlider;
    _progressSlider = [CYSlider new];
    _progressSlider.trackHeight = 3;
    _progressSlider.pan.enabled = NO;
    _progressSlider.tag = CYVideoPlaySliderTag_Dragging;
    _progressSlider.layer.borderColor = [UIColor blackColor].CGColor;
    _progressSlider.layer.borderWidth = 0.5;
    return _progressSlider;
}

- (UILabel *)progressLabel {
    if ( _progressLabel ) return _progressLabel;
    _progressLabel = [CYUILabelFactory labelWithText:@"00:00" textColor:[UIColor whiteColor] alignment:NSTextAlignmentCenter font:[UIFont boldSystemFontOfSize:42]];
    _progressLabel.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
    _progressLabel.layer.cornerRadius = 5.0;
    _progressLabel.layer.masksToBounds = YES;
    _progressLabel.clipsToBounds = YES;
    return _progressLabel;
}

- (UIImageView *)imageView {
    if ( _imageView ) return _imageView;
    _imageView = [CYShapeImageViewFactory imageViewWithCornerRadius:4];
    _imageView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.2];
    _imageView.layer.borderColor = [UIColor colorWithWhite:0 alpha:0.4].CGColor;
    _imageView.layer.borderWidth = 0.6;
    return _imageView;
}

@end
