//
//  CYVideoPlayerMoreSettingsColCell.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/9/25.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerMoreSettingsColCell.h"
#import <Masonry/Masonry.h>
#import "CYVideoPlayerMoreSetting.h"
#import "CYAttributesFactoryHeader.h"
#import "CYUIFactoryHeader.h"

@interface CYVideoPlayerMoreSettingsColCell ()

@property (nonatomic, strong, readonly) UIButton *itemBtn;

@end


@implementation CYVideoPlayerMoreSettingsColCell

@synthesize itemBtn = _itemBtn;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    [self _CYVideoPlayerMoreSettingsColCellSetupUI];
    return self;
}

- (void)clickedBtn:(UIButton *)btn {
    if ( self.model.clickedExeBlock ) self.model.clickedExeBlock(self.model);
}

- (void)setModel:(CYVideoPlayerMoreSetting *)model {
    _model = model;

    [_itemBtn setAttributedTitle:[CYAttributesFactory producingWithTask:^(CYAttributeWorker * _Nonnull worker) {
        if ( model.image ) {
            worker.insert(model.image, 0, CGPointZero, model.image.size);
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

- (void)_CYVideoPlayerMoreSettingsColCellSetupUI {
    [self.contentView addSubview:self.itemBtn];
    [_itemBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(_itemBtn.superview);
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
