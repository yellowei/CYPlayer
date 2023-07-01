//
//  CYVideoPlayerTopControlView.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/11/29.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerTopControlView.h"
#import "CYUIFactory.h"
#import "CYVideoPlayerResources.h"
#import <Masonry/Masonry.h>
#import "CYVideoPlayerControlMaskView.h"

@interface CYVideoPlayerTopControlView ()

@property (nonatomic, strong, readonly) CYVideoPlayerControlMaskView *controlMaskView;

@end

@implementation CYVideoPlayerTopControlView
@synthesize controlMaskView = _controlMaskView;

@synthesize backBtn = _backBtn;
@synthesize previewBtn = _previewBtn;
@synthesize moreBtn = _moreBtn;
@synthesize titleBtn = _titleBtn;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    [self _topSetupViews];
    __weak typeof(self) _self = self;
    self.setting = ^(CYVideoPlayerSettings * _Nonnull setting) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        [self.backBtn setImage:setting.backBtnImage forState:UIControlStateNormal];
        [self.moreBtn setImage:setting.moreBtnImage forState:UIControlStateNormal];
        [self.titleBtn setTitle:setting.title forState:UIControlStateNormal];
        if ( setting.previewBtnImage ) {
            [self.previewBtn setImage:setting.previewBtnImage forState:UIControlStateNormal];
        }
        else {
            [self.previewBtn setTitle:@"预览" forState:UIControlStateNormal];
        }
    };
    return self;
}

- (void)clickedBtn:(UIButton *)btn {
    if ( ![_delegate respondsToSelector:@selector(topControlView:clickedBtnTag:)] ) return;
    [_delegate topControlView:self clickedBtnTag:btn.tag];
}

- (void)_topSetupViews {
    [self.containerView addSubview:self.controlMaskView];
    [self.containerView addSubview:self.backBtn];
    [self.containerView addSubview:self.previewBtn];
    [self.containerView addSubview:self.moreBtn];
    [self.containerView addSubview:self.titleBtn];
    
    [_controlMaskView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(_controlMaskView.superview);
    }];
    
    [_backBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(@0);
        //        make.centerY.equalTo(@0);
        make.width.height.offset(49);
        make.left.offset(0);
    }];
    
    [_moreBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.equalTo(@49);
        make.top.equalTo(@0);
        //        make.centerY.equalTo(@0);
        make.right.equalTo(@(-8));
    }];
    
    [_previewBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.width.height.equalTo(@49);
        make.top.equalTo(@0);
        //        make.centerY.equalTo(@0);
        make.right.equalTo(_moreBtn.mas_left).offset(-8);
    }];
    
    [_titleBtn mas_remakeConstraints:^(MASConstraintMaker *make) {
        //        make.centerX.equalTo(_titleBtn.superview.mas_centerX);
        make.height.equalTo(@49);
        make.top.equalTo(@0);
        //        make.centerY.equalTo(@0);
        make.left.equalTo(@100);
//        make.right.equalTo(@(-100));
        make.right.equalTo(_previewBtn.mas_left).offset(-8);
    }];
}

- (UIButton *)backBtn {
    if ( _backBtn ) return _backBtn;
    _backBtn = [CYUIButtonFactory buttonWithImageName:nil target:self sel:@selector(clickedBtn:) tag:CYVideoPlayControlViewTag_Back];
    [_backBtn setImageEdgeInsets:UIEdgeInsetsMake(16.5, 14.5, 16.5, 14.5)];
    return _backBtn;
}

- (UIButton *)previewBtn {
    if ( _previewBtn ) return _previewBtn;
    _previewBtn = [CYUIButtonFactory buttonWithTitle:@"预览" titleColor:[UIColor whiteColor] font:[UIFont systemFontOfSize:14] backgroundColor:nil target:self sel:@selector(clickedBtn:) tag:CYVideoPlayControlViewTag_Preview];
    return _previewBtn;
}

- (UIButton *)moreBtn {
    if ( _moreBtn ) return _moreBtn;
    _moreBtn = [CYUIButtonFactory buttonWithImageName:[CYVideoPlayerResources bundleComponentWithImageName:@"cy_video_player_more"] target:self sel:@selector(clickedBtn:) tag:CYVideoPlayControlViewTag_More];
    [_moreBtn setImageEdgeInsets:UIEdgeInsetsMake(14.5, 9.5, 14.5, 9.5)];
    return _moreBtn;
}

- (UIButton *)titleBtn
{
    if (_titleBtn){
        return _titleBtn;
    }
    
    _titleBtn = [CYUIButtonFactory buttonWithTitle:@"" titleColor:[UIColor whiteColor]];
    
    return _titleBtn;
}


- (CYVideoPlayerControlMaskView *)controlMaskView {
    if ( _controlMaskView ) return _controlMaskView;
    _controlMaskView = [[CYVideoPlayerControlMaskView alloc] initWithStyle:CYMaskStyle_top];
    return _controlMaskView;
}

@end
