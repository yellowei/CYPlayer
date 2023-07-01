//
//  CYVideoPlayerTipsView.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/8/24.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerTipsView.h"
#import "CYUIFactory.h"
#import "CYBorderlineView.h"
#import <Masonry/Masonry.h>

#define CYThemeColor [UIColor colorWithRed:1 / 255.0 \
                                     green:0 / 255.0 \
                                      blue:13 / 255.0 \
                                     alpha:1]

@interface CYVideoPlayerTipsView ()

@property (nonatomic, strong, readonly) UIVisualEffectView *bottomMaskView;

@property (nonatomic, strong, readonly) UIView *tipsContainerView;

@property (nonatomic, strong, readonly) NSArray<UIView *> *tipsViewsArr;

@property (nonatomic, strong, readonly) UIImageView *imageView;

@end


@implementation CYVideoPlayerTipsView

@synthesize bottomMaskView = _bottomMaskView;
@synthesize titleLabel = _titleLabel;
@synthesize imageView = _imageView;
@synthesize tipsContainerView = _tipsContainerView;
@synthesize tipsViewsArr = _tipsViewsArr;
@synthesize minShowTitleLabel = _minShowTitleLabel;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    [self _CYVideoPlayerTipsViewSetupUI];
    return self;
}

- (void)setValue:(CGFloat)value {
    _value = value;
    
    CGFloat showTipsCount = value * _tipsViewsArr.count;
    
    for ( NSInteger i = 0 ; i < _tipsViewsArr.count ; i ++ ) { _tipsViewsArr[i].hidden = i >= showTipsCount; }
    
    if ( 0 == value ) _imageView.image = _minShowImage;
    else _imageView.image = _normalShowImage;
    
    _tipsContainerView.hidden = (0 == value);
    
    _minShowTitleLabel.hidden = !_tipsContainerView.hidden;
}

// MARK: UI

- (void)_CYVideoPlayerTipsViewSetupUI {
    
    self.layer.cornerRadius = 8;
    self.clipsToBounds = YES;
    
    [self addSubview:self.bottomMaskView];
    [self addSubview:self.titleLabel];
    [self addSubview:self.imageView];
    [self addSubview:self.tipsContainerView];
    [self addSubview:self.minShowTitleLabel];
    
    [_bottomMaskView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(_bottomMaskView.superview);
    }];
    
    [_titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(_titleLabel.superview);
        make.top.offset(12);
    }];
    
    [_imageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.offset(0);
    }];
    
    [_tipsContainerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.offset(12);
        make.trailing.offset(-12);
        make.bottom.offset(-16);
        make.height.offset(7);
    }];
    
    [self.tipsViewsArr enumerateObjectsUsingBlock:^(UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [_tipsContainerView addSubview:obj];
        if ( 0 == idx ) {
            [obj mas_makeConstraints:^(MASConstraintMaker *make) {
                make.leading.top.bottom.offset(0);
                make.width.equalTo(obj.superview).multipliedBy(1.0 / 16);
            }];
        }
        else {
            UIView *beforeView = _tipsViewsArr[idx - 1];
            [obj mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.bottom.offset(0);
                make.leading.equalTo(beforeView.mas_trailing).offset(0);
                make.width.equalTo(beforeView);
            }];
        }
    }];
    
    [_minShowTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(_tipsContainerView);
    }];
}

- (UIVisualEffectView *)bottomMaskView {
    if ( _bottomMaskView ) return _bottomMaskView;
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    _bottomMaskView = [[UIVisualEffectView alloc] initWithEffect:effect];
    return _bottomMaskView;
}

- (UILabel *)titleLabel {
    if ( _titleLabel ) return _titleLabel;
    _titleLabel = [CYUILabelFactory labelWithText:@"" textColor:CYThemeColor alignment:NSTextAlignmentCenter font:[UIFont boldSystemFontOfSize:14]];
    return _titleLabel;
}

- (UIImageView *)imageView {
    if ( _imageView ) return _imageView;
    _imageView = [CYUIImageViewFactory imageViewWithImageName:@"" viewMode:UIViewContentModeScaleAspectFit];
    return _imageView;
}

- (UIView *)tipsContainerView {
    if ( _tipsContainerView ) return _tipsContainerView;
    _tipsContainerView = [UIView new];
    _tipsContainerView.backgroundColor = CYThemeColor;
    return _tipsContainerView;
}

- (NSArray<UIView *> *)tipsViewsArr {
    if ( _tipsViewsArr ) return _tipsViewsArr;
    NSMutableArray<UIView *> *tipsArrM = [NSMutableArray new];
    for ( int i = 0 ; i < 16 ; i ++ ) {
        CYBorderlineView *view = [CYBorderlineView borderlineViewWithSide:CYBorderlineSideAll startMargin:0 endMargin:0 lineColor:CYThemeColor backgroundColor:[UIColor whiteColor]];
        [tipsArrM addObject:view];
        view.hidden = YES;
    }
    _tipsViewsArr = tipsArrM;
    return _tipsViewsArr;
}

- (UILabel *)minShowTitleLabel {
    if ( _minShowTitleLabel  ) return _minShowTitleLabel;
    _minShowTitleLabel = [CYUILabelFactory labelWithText:@"" textColor:CYThemeColor alignment:NSTextAlignmentCenter font:[UIFont systemFontOfSize:12]];
    _minShowTitleLabel.hidden = YES;
    return _minShowTitleLabel;
}

@end
