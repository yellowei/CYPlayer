//
//  CYVideoPlayerCenterControlView.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/12/4.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerCenterControlView.h"
#import "CYUIFactoryHeader.h"
#import "CYVideoPlayerResources.h"
#import <Masonry/Masonry.h>
#import "CYAttributesFactoryHeader.h"

@interface CYVideoPlayerCenterControlView ()

@end

@implementation CYVideoPlayerCenterControlView
@synthesize failedBtn = _failedBtn;
@synthesize replayBtn = _replayBtn;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    [self _centerSetupView];
    __weak typeof(self) _self = self;
    self.setting = ^(CYVideoPlayerSettings * _Nonnull setting) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        [self.replayBtn setAttributedTitle:[CYAttributesFactory producingWithTask:^(CYAttributeWorker * _Nonnull worker) {
            if ( setting.replayBtnImage ) {
                worker.insert(setting.replayBtnImage, 0, CGPointZero, setting.replayBtnImage.size);
            }
            
            if ( setting.replayBtnTitle ) {
                worker.insert([NSString stringWithFormat:@"\n%@", setting.replayBtnTitle], -1);
            }
            
            worker
            .font([UIFont systemFontOfSize:16])
            .fontColor([UIColor whiteColor])
            .alignment(NSTextAlignmentCenter)
            .lineSpacing(6);
        }] forState:UIControlStateNormal];
    };
    return self;
}

- (void)clickedBtn:(UIButton *)btn {
    if ( ![_delegate respondsToSelector:@selector(centerControlView:clickedBtnTag:)] ) return;
    [_delegate centerControlView:self clickedBtnTag:btn.tag];
}

- (void)_centerSetupView {
    [self.containerView addSubview:self.failedBtn];
    [self.containerView addSubview:self.replayBtn];
    [_failedBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.offset(0);
        make.width.equalTo(_failedBtn.mas_height);
    }];
    
    [_replayBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.offset(0);
        make.width.equalTo(_replayBtn.mas_height);
    }];
}

- (UIButton *)failedBtn {
    if ( _failedBtn ) return _failedBtn;
    _failedBtn = [CYUIButtonFactory buttonWithTitle:@" 加载失败 \n 点击重试 " titleColor:[UIColor whiteColor] font:[UIFont systemFontOfSize:14] backgroundColor:nil target:self sel:@selector(clickedBtn:) tag:CYVideoPlayControlViewTag_LoadFailed];
    _failedBtn.layer.cornerRadius = 2.0;
    _failedBtn.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.3];
    _failedBtn.clipsToBounds = YES;
    return _failedBtn;
}
- (UIButton *)replayBtn {
    if ( _replayBtn ) return _replayBtn;
    _replayBtn = [CYUIButtonFactory buttonWithImageName:@"" target:self sel:@selector(clickedBtn:) tag:CYVideoPlayControlViewTag_Replay];
    _replayBtn.titleLabel.numberOfLines = 0;
    _replayBtn.layer.cornerRadius = 2.0;
    _replayBtn.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.3];
    _replayBtn.clipsToBounds = YES;
    return _replayBtn;
}
@end
