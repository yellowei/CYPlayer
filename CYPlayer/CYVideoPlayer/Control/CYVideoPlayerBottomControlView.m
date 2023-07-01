//
//  CYVideoPlayerBottomControlView.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/11/29.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerBottomControlView.h"
#import "CYUIFactory.h"
#import "CYVideoPlayerResources.h"
#import <Masonry/Masonry.h>
#import "CYVideoPlayerControlMaskView.h"

@interface CYVideoPlayerBottomControlView ()

@property (nonatomic, strong, readonly) CYVideoPlayerControlMaskView *controlMaskView;
@property (nonatomic, strong) CYVideoPlayerSettings *tempSetting;

@end

@implementation CYVideoPlayerBottomControlView
@synthesize controlMaskView = _controlMaskView;
@synthesize separateLabel = _separateLabel;
@synthesize durationTimeLabel = _durationTimeLabel;
@synthesize playBtn = _playBtn;
@synthesize pauseBtn = _pauseBtn;
@synthesize definitionBtn = _definitionBtn;
@synthesize selectionsBtn = _selectionsBtn;
@synthesize currentTimeLabel = _currentTimeLabel;
@synthesize progressSlider = _progressSlider;
@synthesize fullBtn = _fullBtn;
@synthesize rateButton = _rateButton;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    [self _bottomSetupView];
    __weak typeof(self) _self = self;
    self.setting = ^(CYVideoPlayerSettings * _Nonnull setting) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        self.tempSetting = setting;
        [self.playBtn setImage:setting.playBtnImage forState:UIControlStateNormal];
        [self.pauseBtn setImage:setting.pauseBtnImage forState:UIControlStateNormal];
        [self.fullBtn setImage:setting.fullBtnImage_nor forState:UIControlStateNormal];
        [self.fullBtn setImage:setting.fullBtnImage_sel forState:UIControlStateSelected];
        self.progressSlider.traceImageView.backgroundColor = setting.progress_traceColor;
        self.progressSlider.trackImageView.backgroundColor = setting.progress_trackColor;
        self.progressSlider.thumbImageView.image = setting.progress_thumbImage_nor;
        self.progressSlider.thumbnail_nor = setting.progress_thumbImage_nor;
        self.progressSlider.thumbnail_sel = setting.progress_thumbImage_sel;
        self.progressSlider.bufferProgressColor = setting.progress_bufferColor;
        self.progressSlider.trackHeight = setting.progress_traceHeight;
        if (setting.enableProgressControl)
        {
            self.progressSlider.hidden = NO;
            self.separateLabel.hidden = NO;
            self.durationTimeLabel.hidden = NO;
            self.currentTimeLabel.hidden = NO;
            self.playBtn.hidden = NO;
            self.pauseBtn.hidden = NO;
        }
        else
        {
            self.progressSlider.hidden = YES;
            self.separateLabel.hidden = YES;
            self.durationTimeLabel.hidden = YES;
            self.currentTimeLabel.hidden = NO;
            self.playBtn.hidden = NO;
            self.pauseBtn.hidden = NO;
        }
        
        //倍速
        self.rateButton.hidden = YES;
        
        //是否可选清晰度
        if (setting.definitionTypes !=  CYFFmpegPlayerDefinitionNone)
        {
            self.definitionBtn.hidden = NO;
        }
        else
        {
            self.definitionBtn.hidden = YES;
        }
        
        //是否可选集
        if (setting.enableSelections == YES)
        {
            self.selectionsBtn.hidden = NO;
        }
        else
        {
            self.selectionsBtn.hidden = YES;
        }
        
        [self refreshConstrainsWithSettings:setting];
        
//        if (self.definitionBtn.hidden && self.selectionsBtn.hidden)
//        {
//            [self.currentTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
//                //        make.centerY.equalTo(_playBtn);
//                make.centerY.equalTo(self.playBtn);
//                make.leading.equalTo(self.playBtn.mas_trailing).offset(0);
//            }];
//
//            [self.separateLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
//                //        make.centerY.equalTo(_playBtn);
//                make.centerY.equalTo(self.playBtn);
//                make.leading.equalTo(self.currentTimeLabel.mas_trailing);
//            }];
//
//            [self.durationTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
//                //        make.centerY.equalTo(_playBtn);
//                make.centerY.equalTo(self.playBtn);
//                make.leading.equalTo(self.separateLabel.mas_trailing);
//            }];
//        }
//        else
//        {
//            [self.currentTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
//                //        make.centerY.equalTo(_playBtn);
//                make.top.equalTo(self.playBtn);
//                make.leading.equalTo(self.playBtn.mas_trailing).offset(0);
//            }];
//
//            [self.separateLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
//                //        make.centerY.equalTo(_playBtn);
//                make.top.equalTo(self.playBtn);
//                make.leading.equalTo(self.currentTimeLabel.mas_trailing);
//            }];
//
//            [self.durationTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
//                //        make.centerY.equalTo(_playBtn);
//                make.top.equalTo(self.playBtn);
//                make.leading.equalTo(self.separateLabel.mas_trailing);
//            }];
//
//        }
        
        _is_FullScreen = self.fullBtn.selected;

    };
    return self;
}

# pragma mark - Getter/Setter
- (UIButton *)playBtn {
    if ( _playBtn ) return _playBtn;
    _playBtn = [CYUIButtonFactory buttonWithImageName:nil target:self sel:@selector(clickedBtn:) tag:CYVideoPlayControlViewTag_Play];
    [_playBtn setImageEdgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
    return _playBtn;
}

- (UIButton *)pauseBtn {
    if ( _pauseBtn ) return _pauseBtn;
    _pauseBtn = [CYUIButtonFactory buttonWithImageName:nil target:self sel:@selector(clickedBtn:) tag:CYVideoPlayControlViewTag_Pause];
    [_pauseBtn setImageEdgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
    return _pauseBtn;
}

- (UIButton *)definitionBtn
{
    if (_definitionBtn) return _definitionBtn;
    _definitionBtn = [CYUIButtonFactory buttonWithTitle:@"超清" titleColor:[UIColor whiteColor] font:[UIFont systemFontOfSize:12] target:self sel:@selector(onDefinitionBtnClick:)];
//    _definitionBtn.layer.cornerRadius = 2.0;
//    _definitionBtn.layer.borderWidth = 0.5;
//    _definitionBtn.layer.borderColor = [UIColor whiteColor].CGColor;
    _definitionBtn.backgroundColor = [UIColor clearColor];
    return _definitionBtn;
}

- (UIButton *)selectionsBtn
{
    if (_selectionsBtn) return _selectionsBtn;
    _selectionsBtn = [CYUIButtonFactory buttonWithTitle:@"选集" titleColor:[UIColor whiteColor] font:[UIFont systemFontOfSize:12] target:self sel:@selector(onSelectionsBtnClick:)];
//    _selectionsBtn.layer.cornerRadius = 2.0;
//    _selectionsBtn.layer.borderWidth = 0.5;
//    _selectionsBtn.layer.borderColor = [UIColor whiteColor].CGColor;
    _selectionsBtn.backgroundColor = [UIColor clearColor];
    return _selectionsBtn;
}

- (CYSlider *)progressSlider {
    if ( _progressSlider ) return _progressSlider;
    _progressSlider = [CYSlider new];
    _progressSlider.tag = CYVideoPlaySliderTag_Progress;
    _progressSlider.enableBufferProgress = YES;
    return _progressSlider;
}

- (UIButton *)fullBtn {
    if ( _fullBtn ) return _fullBtn;
    _fullBtn = [CYUIButtonFactory buttonWithImageName:nil target:self sel:@selector(clickedBtn:) tag:CYVideoPlayControlViewTag_Full];
    [_fullBtn setImageEdgeInsets:UIEdgeInsetsMake(14, 14, 14, 14)];
    return _fullBtn;
}

- (UIButton *)rateButton{
    if (_rateButton) return _rateButton;
    _rateButton = [CYUIButtonFactory buttonWithTitle:@"倍数" titleColor:[UIColor whiteColor] font:[UIFont systemFontOfSize:12] target:self sel:@selector(onRateBtnClick:)];
    _rateButton.backgroundColor = [UIColor clearColor];
    return _rateButton;
}

- (UILabel *)separateLabel {
    if ( _separateLabel ) return _separateLabel;
    _separateLabel = [CYUILabelFactory labelWithText:@"/" textColor:[UIColor whiteColor] alignment:NSTextAlignmentCenter font:[UIFont systemFontOfSize:13]];
    return _separateLabel;
}

- (UILabel *)durationTimeLabel {
    if ( _durationTimeLabel ) return _durationTimeLabel;
    _durationTimeLabel = [CYUILabelFactory labelWithText:@"00:00" textColor:[UIColor whiteColor] alignment:NSTextAlignmentCenter font:[UIFont systemFontOfSize:13]];
    return _durationTimeLabel;
}

- (UILabel *)currentTimeLabel {
    if ( _currentTimeLabel ) return _currentTimeLabel;
    _currentTimeLabel = [CYUILabelFactory labelWithText:@"00:00" textColor:[UIColor whiteColor] alignment:NSTextAlignmentCenter font:[UIFont systemFontOfSize:13]];
    return _currentTimeLabel;
}

- (CYVideoPlayerControlMaskView *)controlMaskView {
    if ( _controlMaskView ) return _controlMaskView;
    _controlMaskView = [[CYVideoPlayerControlMaskView alloc] initWithStyle:CYMaskStyle_bottom];
    return _controlMaskView;
}

# pragma mark - Private Methods
- (void)refreshConstrainsWithSettings:(CYVideoPlayerSettings *)settings
{
    BOOL hasDefinitionOrSelectionsControl = settings.enableSelections || settings.definitionTypes != CYFFmpegPlayerDefinitionNone;
    BOOL enableProgressControl =     settings.enableProgressControl;
    
    if (hasDefinitionOrSelectionsControl && enableProgressControl)
    {
        //超清和选集 倍速
        [_currentTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
                    make.centerY.equalTo(_playBtn);
//            make.top.equalTo(_playBtn);
            make.leading.equalTo(_playBtn.mas_trailing).offset(0);
        }];
        
        [_separateLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
                    make.centerY.equalTo(_playBtn);
//            make.top.equalTo(_playBtn);
            make.leading.equalTo(_currentTimeLabel.mas_trailing);
        }];
        
        [_durationTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
                    make.centerY.equalTo(_playBtn);
//            make.top.equalTo(_playBtn);
            make.leading.equalTo(_separateLabel.mas_trailing);
        }];
        
        
        if (_is_FullScreen) {
            _rateButton.hidden = NO;

             [_progressSlider mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.leading.equalTo(_durationTimeLabel.mas_trailing).offset(8);
                make.height.centerY.equalTo(_playBtn);
                make.trailing.equalTo(_rateButton.mas_leading).offset(-8);
            }];
            //倍速
            [_rateButton mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.width.equalTo(_selectionsBtn.mas_width);
                make.centerY.equalTo(_playBtn);
                make.height.equalTo(@(20));
                make.leading.equalTo(_progressSlider.mas_trailing).offset(8);
            }];
             //清晰度btn
            [_definitionBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.width.equalTo(_selectionsBtn.mas_width);
                make.centerY.equalTo(_playBtn);
                make.height.equalTo(@(20));
                make.leading.equalTo(_rateButton.mas_trailing);
            }];
            [_selectionsBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.leading.equalTo(_definitionBtn.mas_trailing).offset(4);
                make.trailing.equalTo(_fullBtn.mas_leading);
                make.width.equalTo(_definitionBtn.mas_width);
                make.centerY.equalTo(_playBtn);
                make.height.equalTo(@(20));
            }];
        }else{
            _rateButton.hidden = YES;
             [_progressSlider mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.leading.equalTo(_durationTimeLabel.mas_trailing).offset(8);
                make.height.centerY.equalTo(_playBtn);
                make.trailing.equalTo(_definitionBtn.mas_leading).offset(-8);
            }];
            //倍速
            [_rateButton mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.width.equalTo(@0);
                make.height.equalTo(@(0));
            }];
             //清晰度btn
            [_definitionBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.width.equalTo(_selectionsBtn.mas_width);
                make.centerY.equalTo(_playBtn);
                make.height.equalTo(@(20));
                make.leading.equalTo(_progressSlider.mas_trailing).offset(8);
            }];
            
            [_selectionsBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.leading.equalTo(_definitionBtn.mas_trailing).offset(4);
                make.trailing.equalTo(_fullBtn.mas_leading);
                make.width.equalTo(_definitionBtn.mas_width);
                make.centerY.equalTo(_playBtn);
                make.height.equalTo(@(20));
            }];
        }
        
       
    }
    else if (!hasDefinitionOrSelectionsControl && enableProgressControl)
    {
        //
        [_currentTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            //        make.centerY.equalTo(_playBtn);
            make.centerY.equalTo(_playBtn);
            make.leading.equalTo(_playBtn.mas_trailing).offset(0);
        }];
        
        [_separateLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            //        make.centerY.equalTo(_playBtn);
            make.centerY.equalTo(_playBtn);
            make.leading.equalTo(_currentTimeLabel.mas_trailing);
        }];
        
        [_durationTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            //        make.centerY.equalTo(_playBtn);
            make.centerY.equalTo(_playBtn);
            make.leading.equalTo(_separateLabel.mas_trailing);
        }];
        
        if (_is_FullScreen) {
            _rateButton.hidden = NO;
            [_progressSlider mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.leading.equalTo(_durationTimeLabel.mas_trailing).offset(8);
                make.height.centerY.equalTo(_playBtn);
                make.trailing.equalTo(_rateButton.mas_leading).offset(-8);
            }];
            //倍速
            [_rateButton mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.width.equalTo(@(30));
                make.centerY.equalTo(_playBtn);
                make.height.equalTo(@(20));
                make.leading.equalTo(_progressSlider.mas_trailing);
                make.trailing.equalTo(_fullBtn.mas_leading);

            }];
            
        }else{
            _rateButton.hidden = YES;
            [_progressSlider mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.leading.equalTo(_durationTimeLabel.mas_trailing).offset(8);
                make.height.centerY.equalTo(_playBtn);
                make.trailing.equalTo(_fullBtn.mas_leading).offset(-8);
            }];
            
            [_rateButton mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.width.equalTo(@0);
                make.height.equalTo(@(0));
            }];
        }
        //清晰度btn
        [_definitionBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(@0);
            make.height.equalTo(@0);
        }];
        
        [_selectionsBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(@0);
            make.height.equalTo(@0);
        }];
    }
    else if (hasDefinitionOrSelectionsControl && !enableProgressControl)
    {
        [_currentTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(_playBtn);
            make.leading.equalTo(_playBtn.mas_trailing).offset(0);
        }];
        
        [_separateLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(_playBtn);
            make.leading.equalTo(_currentTimeLabel.mas_trailing);
        }];
        
        [_durationTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(_playBtn);
            make.leading.equalTo(_separateLabel.mas_trailing);
        }];
        
        //清晰度btn
        [_definitionBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(_playBtn);
            make.leading.equalTo(_durationTimeLabel.mas_trailing).offset(8);
            make.width.equalTo(@30);
            make.height.equalTo(@20);
        }];
        
        [_selectionsBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(_playBtn);
            make.leading.equalTo(_definitionBtn.mas_trailing).offset(8);
            make.width.equalTo(@30);
            make.height.equalTo(@20);
        }];
        
        
        [_progressSlider mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(@0);
            make.height.equalTo(@0);
        }];
    }
    else if (!hasDefinitionOrSelectionsControl && !enableProgressControl)
    {
        [_currentTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(_playBtn);
            make.leading.equalTo(_playBtn.mas_trailing).offset(0);
        }];
        
        [_separateLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(_playBtn);
            make.leading.equalTo(_currentTimeLabel.mas_trailing);
        }];
        
        [_durationTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(_playBtn);
            make.leading.equalTo(_separateLabel.mas_trailing);
        }];
        
        //清晰度btn
        [_definitionBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(@0);
            make.height.equalTo(@0);
        }];
        
        [_selectionsBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(@0);
            make.height.equalTo(@0);
        }];
        
        
        [_progressSlider mas_remakeConstraints:^(MASConstraintMaker *make) {
             make.width.equalTo(@0);
            make.height.equalTo(@0);
        }];
    }
}


- (void)_bottomSetupView {
    [self.containerView addSubview:self.controlMaskView];
    [self.containerView addSubview:self.playBtn];
    [self.containerView addSubview:self.pauseBtn];
    [self.containerView addSubview:self.definitionBtn];
    [self.containerView addSubview:self.selectionsBtn];
    [self.containerView addSubview:self.currentTimeLabel];
    [self.containerView addSubview:self.separateLabel];
    [self.containerView addSubview:self.durationTimeLabel];
    [self.containerView addSubview:self.progressSlider];
    [self.containerView addSubview:self.fullBtn];
    [self.containerView addSubview:self.rateButton];
    
    [_controlMaskView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(_controlMaskView.superview);
    }];
    
    [_playBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.leading.offset(0);
        make.size.offset(49);
        make.bottom.offset(-8);
    }];
    
    [_pauseBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(_playBtn);
    }];
    
    [_currentTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(_playBtn);
//        make.top.equalTo(_playBtn);
        make.leading.equalTo(_playBtn.mas_trailing).offset(0);
    }];
    
    [_separateLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(_playBtn);
//        make.top.equalTo(_playBtn);
        make.leading.equalTo(_currentTimeLabel.mas_trailing);
    }];
    
    [_durationTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(_playBtn);
//        make.top.equalTo(_playBtn);
        make.leading.equalTo(_separateLabel.mas_trailing);
    }];
    
    [_progressSlider mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.leading.equalTo(_durationTimeLabel.mas_trailing).offset(8);
        make.height.centerY.equalTo(_playBtn);
//        make.trailing.equalTo(_fullBtn.mas_leading).offset(-8);
        make.trailing.equalTo(_rateButton.mas_leading).offset(-8);
    }];
    
    //倍数
    [_rateButton mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(_selectionsBtn.mas_width);
        make.centerY.equalTo(_playBtn);
        make.leading.equalTo(_progressSlider.mas_trailing);
        make.height.equalTo(@20);
    }];
    
    //清晰度btn
    [_definitionBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(_selectionsBtn.mas_width);
        make.centerY.equalTo(_playBtn);
        make.leading.equalTo(_rateButton.mas_trailing);
        make.height.equalTo(@20);
    }];
    
    [_selectionsBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.leading.equalTo(_definitionBtn.mas_trailing).offset(4);
        make.width.equalTo(_definitionBtn.mas_width);
        make.centerY.equalTo(_playBtn);
        make.height.equalTo(@20);
        make.trailing.equalTo(_fullBtn.mas_leading).offset(-8);
    }];
    
    
    [_fullBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.size.equalTo(_playBtn);
        make.centerY.equalTo(_playBtn);
        make.trailing.offset(0);
    }];
    
    
    [CYUIFactory boundaryProtectedWithView:_currentTimeLabel];
    [CYUIFactory boundaryProtectedWithView:_separateLabel];
    [CYUIFactory boundaryProtectedWithView:_durationTimeLabel];
    [CYUIFactory boundaryProtectedWithView:_progressSlider];
}




# pragma mark - Events
- (void)onDefinitionBtnClick:(UIButton *)sender
{
    if ([_delegate respondsToSelector:@selector(bottomControlViewOnDefinitionBtnClick:)]) {
        [_delegate bottomControlViewOnDefinitionBtnClick:self];
    }
}

- (void)onSelectionsBtnClick:(UIButton *)sender
{
    if ([_delegate respondsToSelector:@selector(bottomControlViewOnSelectionsBtnClick:)])
    {
        [_delegate bottomControlViewOnSelectionsBtnClick:self];
    }
}

- (void)clickedBtn:(UIButton *)btn {
    if ( ![_delegate respondsToSelector:@selector(bottomControlView:clickedBtnTag:)] ) return;
    [_delegate bottomControlView:self clickedBtnTag:btn.tag];
}

- (void)onRateBtnClick:(UIButton *)sender{
    if ([_delegate respondsToSelector:@selector(bottomControlViewOnRateBtnClick:)]) {
        [_delegate bottomControlViewOnRateBtnClick:self];
    }
}


- (void)setIs_FullScreen:(BOOL)is_FullScreen{
    _is_FullScreen = is_FullScreen;
    [self refreshConstrainsWithSettings:self.tempSetting];
}


@end
