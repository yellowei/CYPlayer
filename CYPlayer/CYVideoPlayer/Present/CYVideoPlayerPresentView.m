//
//  CYVideoPlayerPresentView.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/11/29.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerPresentView.h"
#import <AVFoundation/AVPlayerLayer.h>
#import "CYVideoPlayerAssetCarrier.h"

@interface CYVideoPlayerPresentView ()

@property (nonatomic, strong, readonly) UIImageView *placeholderImageView;

@end

@implementation CYVideoPlayerPresentView

@synthesize placeholderImageView = _placeholderImageView;

+ (Class)layerClass {
    return [AVPlayerLayer class];
}

- (AVPlayerLayer *)avLayer {
    return (AVPlayerLayer *)self.layer;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    [self _presentSetupView];
    [self _addObserver];
    return self;
}


#pragma mark - Observer

- (void)_addObserver {
    [self.avLayer addObserver:self forKeyPath:@"readyForDisplay" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)dealloc {
    [self.avLayer removeObserver:self forKeyPath:@"readyForDisplay"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ( [keyPath isEqualToString:@"readyForDisplay"] ) {
        if ( self.readyForDisplay ) self.readyForDisplay(self, self.avLayer.videoRect);
    }
}

#pragma mark - Setter

- (void)setAsset:(CYVideoPlayerAssetCarrier *)asset {
    if ( asset == _asset ) return;
    _asset = asset;
    self.avLayer.player = asset.player;
}

- (void)setPlaceholder:(UIImage *)placeholder {
    if ( placeholder == _placeholder ) return;
    _placeholder = placeholder;
    _placeholderImageView.image = placeholder;
}

- (void)setState:(CYVideoPlayerPlayState)state {
    _state = state;
    [UIView animateWithDuration:0.25 animations:^{
        switch ( state ) {
            case CYVideoPlayerPlayState_Unknown:
            case CYVideoPlayerPlayState_Prepare: {
                _placeholderImageView.alpha = 1;
            }
                break;
            case CYVideoPlayerPlayState_Playing: {
                _placeholderImageView.alpha = 0.001;
            }
                break;
            case CYVideoPlayerPlayState_Buffing:
            case CYVideoPlayerPlayState_Pause:
            case CYVideoPlayerPlayState_PlayEnd:
            case CYVideoPlayerPlayState_PlayFailed: break;
        }
    }];
}

#pragma mark - Views
- (void)_presentSetupView {
    self.backgroundColor = [UIColor blackColor];
    [self addSubview:self.placeholderImageView];
    _placeholderImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_placeholderImageView]|" options:NSLayoutFormatAlignAllTop | NSLayoutFormatAlignAllBottom metrics:nil views:NSDictionaryOfVariableBindings(_placeholderImageView)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_placeholderImageView]|" options:NSLayoutFormatAlignAllLeading | NSLayoutFormatAlignAllTrailing metrics:nil views:NSDictionaryOfVariableBindings(_placeholderImageView)]];
}

- (UIImageView *)placeholderImageView {
    if ( _placeholderImageView ) return _placeholderImageView;
    _placeholderImageView = [UIImageView new];
    _placeholderImageView.contentMode = UIViewContentModeScaleAspectFill;
    _placeholderImageView.clipsToBounds = YES;
    return _placeholderImageView;
}

@end
