//
//  CYVideoPlayerBaseView.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/11/30.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerBaseView.h"
#import <Masonry/Masonry.h>
#import "CYUIFactory.h"

@implementation CYVideoPlayerBaseView

@synthesize containerView = _containerView;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    [self _baseSetupView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsPlayerNotification:) name:CYSettingsPlayerNotification object:nil];
    return self;
}

- (void)settingsPlayerNotification:(NSNotification *)notifi {
    if ( _setting ) _setting(notifi.object);
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)_baseSetupView {
    [self addSubview:self.containerView];
    [_containerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(_containerView.superview);
    }];
}

- (UIView *)containerView {
    if ( _containerView ) return _containerView;
    _containerView = [CYUIViewFactory viewWithBackgroundColor:nil];
    return _containerView;
}

@end
