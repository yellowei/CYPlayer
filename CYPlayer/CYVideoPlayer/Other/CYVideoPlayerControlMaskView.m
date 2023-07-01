//
//  CYVideoPlayerControlMaskView.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/9/25.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerControlMaskView.h"

@interface CYVideoPlayerControlMaskView ()

@property (nonatomic, assign, readwrite) CYMaskStyle style;

@end

@implementation CYVideoPlayerControlMaskView {
    CAGradientLayer *_maskGradientLayer;
}

- (instancetype)initWithStyle:(CYMaskStyle)style {
    self = [super initWithFrame:CGRectZero];
    if ( !self ) return nil;
    self.style = style;
    [self initializeGL];
    return self;
}

- (void)initializeGL {
    self.backgroundColor = [UIColor clearColor];
    _maskGradientLayer = [CAGradientLayer layer];
    switch (_style) {
        case CYMaskStyle_top: {
            _maskGradientLayer.colors = @[(__bridge id)[UIColor colorWithWhite:0 alpha:0.42].CGColor,
                                          (__bridge id)[UIColor clearColor].CGColor];
        }
            break;
        case CYMaskStyle_bottom: {
            _maskGradientLayer.colors = @[(__bridge id)[UIColor clearColor].CGColor,
                                          (__bridge id)[UIColor colorWithWhite:0 alpha:0.42].CGColor];
        }
            break;
    }
    [self.layer addSublayer:_maskGradientLayer];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _maskGradientLayer.frame = self.bounds;
}

@end
