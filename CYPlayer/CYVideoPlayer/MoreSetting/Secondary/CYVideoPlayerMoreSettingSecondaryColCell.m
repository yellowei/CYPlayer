//
//  CYVideoPlayerMoreSettingSecondaryColCell.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/12/5.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerMoreSettingSecondaryColCell.h"
#import <Masonry/Masonry.h>
#import "CYVideoPlayerMoreSettingSecondary.h"
#import "CYAttributesFactoryHeader.h"
#import "CYUIFactory.h"

@interface CYVideoPlayerMoreSettingSecondaryColCell ()

@property (nonatomic, strong, readonly) UIButton *itemBtn;

@end

@implementation CYVideoPlayerMoreSettingSecondaryColCell

@synthesize itemBtn = _itemBtn;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    [self _CYVideoPlayerMoreSettingTwoSettingsCellSetupUI];
    return self;
}

- (void)clickedBtn:(UIButton *)btn {
    if ( self.model.clickedExeBlock ) self.model.clickedExeBlock(self.model);
}

- (void)setModel:(CYVideoPlayerMoreSettingSecondary *)model {
    _model = model;
    [_itemBtn setAttributedTitle:[CYAttributesFactory producingWithTask:^(CYAttributeWorker * _Nonnull worker) {
        
        if ( model.image ) {
            worker.insert(model.image, 0, CGPointZero, CGSizeMake(50, 50));
        }
        
        if ( model.title ) {
            worker.insert([NSString stringWithFormat:@"\n%@", model.title], -1);;
        }
        
        worker
        .font([UIFont systemFontOfSize:[CYVideoPlayerMoreSetting titleFontSize]])
        .fontColor([CYVideoPlayerMoreSetting titleColor])
        .alignment(NSTextAlignmentCenter)
        .lineSpacing(6);
    }] forState:UIControlStateNormal];
}

- (void)_CYVideoPlayerMoreSettingTwoSettingsCellSetupUI {
    [self.contentView addSubview:self.itemBtn];
    [_itemBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.contentView);
    }];
}

- (UIButton *)itemBtn {
    if ( _itemBtn ) return _itemBtn;
    _itemBtn = [CYUIButtonFactory buttonWithTarget:self sel:@selector(clickedBtn:)];
    _itemBtn.titleLabel.numberOfLines = 0;
    _itemBtn.titleLabel.textAlignment = NSTextAlignmentCenter;
    return _itemBtn;
}

@end

