//
//  CYVideoPlayerMoreSettingsSecondaryHeaderView.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/12/5.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerMoreSettingsSecondaryHeaderView.h" 
#import <Masonry/Masonry.h>
#import "CYUIFactory.h"
#import "CYVideoPlayerMoreSetting.h"
#import "CYVideoPlayerMoreSettingSecondaryView.h"
#import "CYVideoPlayerMoreSettingSecondary.h"

@interface CYVideoPlayerMoreSettingsSecondaryHeaderView ()

@property (nonatomic, strong, readonly) UIView *line;
@property (nonatomic, strong, readonly) UILabel *titleLabel;

@end

@implementation CYVideoPlayerMoreSettingsSecondaryHeaderView

@synthesize line = _line;
@synthesize titleLabel = _titleLabel;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    [self _CYVideoPlayerMoreSettingTwoSettingsHeaderViewSetupUI];
    return self;
}


- (void)setModel:(CYVideoPlayerMoreSetting *)model {
    _model = model;
    self.titleLabel.text = model.twoSettingTopTitle;
}

- (void)_CYVideoPlayerMoreSettingTwoSettingsHeaderViewSetupUI {
    [self addSubview:self.line];
    [self addSubview:self.titleLabel];
    
    [_titleLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.leading.offset(15);
        make.trailing.offset(-8);
        make.top.bottom.offset(0);
    }];
    
    [_line mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.leading.equalTo(_titleLabel);
        make.bottom.trailing.offset(0);
        make.height.offset(1);
    }];
}

- (UIView *)line {
    if ( _line ) return _line;
    _line = [UIView new];
    _line.backgroundColor = [UIColor lightGrayColor];
    return _line;
}

- (UILabel *)titleLabel {
    if ( _titleLabel ) return _titleLabel;
    _titleLabel = [CYUILabelFactory labelWithText:@"" textColor:[CYVideoPlayerMoreSettingSecondary titleColor] alignment:NSTextAlignmentLeft font:[UIFont systemFontOfSize:10]];
    _titleLabel.font = [UIFont systemFontOfSize:[CYVideoPlayerMoreSettingSecondary topTitleFontSize]];
    return _titleLabel;
}

@end
