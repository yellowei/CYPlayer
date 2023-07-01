//
//  CYSlider.m
//  dancebaby
//
//  Created by yellowei on 2017/6/12.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYSlider.h"

#import <Masonry/Masonry.h>

#import <objc/message.h>




@interface UIView (CYExtension)
@property (nonatomic, assign) CGFloat ccy_x;
@property (nonatomic, assign) CGFloat ccy_y;
@property (nonatomic, assign) CGFloat ccy_w;
@property (nonatomic, assign) CGFloat ccy_h;
@end


@implementation UIView (CYExtension)
- (void)setCcy_x:(CGFloat)ccy_x {
    CGRect frame    = self.frame;
    frame.origin.x  = ccy_x;
    self.frame      = frame;
}
- (CGFloat)ccy_x {
    return self.frame.origin.x;
}


- (void)setCcy_y:(CGFloat)ccy_y {
    CGRect frame    = self.frame;
    frame.origin.y  = ccy_y;
    self.frame      = frame;
}

- (CGFloat)ccy_y {
    return self.frame.origin.y;
}


- (void)setCcy_w:(CGFloat)ccy_w {
    CGRect frame        = self.frame;
    frame.size.width    = ccy_w;
    self.frame          = frame;
}
- (CGFloat)ccy_w {
    return self.frame.size.width;
}


- (void)setCcy_h:(CGFloat)ccy_h {
    CGRect frame        = self.frame;
    frame.size.height   = ccy_h;
    self.frame          = frame;
}
- (CGFloat)ccy_h {
    return self.frame.size.height;
}
@end





@interface CYContainerView : UIView
/*!
 *  default is YES.
 */
@property (nonatomic, assign, readwrite) BOOL isRound;
@end

@implementation CYContainerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    [self _CYContainerViewSetupUI];
    return self;
}

// MARK: UI

- (void)_CYContainerViewSetupUI {
    self.clipsToBounds = YES;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if ( _isRound ) self.layer.cornerRadius = MIN(self.ccy_w, self.ccy_h) * 0.5;
    else self.layer.cornerRadius = 0;
}

- (void)setIsRound:(BOOL)isRound {
    _isRound = isRound;
    if ( _isRound ) self.layer.cornerRadius = MIN(self.ccy_w, self.ccy_h) * 0.5;
    else self.layer.cornerRadius = 0;
}

@end



// MARK: 观察处理

@interface CYSlider (DBObservers)

- (void)_CYSliderObservers;

- (void)_CYSliderRemoveObservers;

@end




@interface CYSlider ()

@property (nonatomic, strong, readonly) CYContainerView *containerView;

@property (nonatomic, strong, readonly) UIView *bufferProgressView;

@end







@implementation CYSlider

@synthesize containerView = _containerView;
@synthesize trackImageView = _trackImageView;
@synthesize traceImageView = _traceImageView;
@synthesize thumbImageView = _thumbImageView;
@synthesize bufferProgressView = _bufferProgressView;
@synthesize pan = _pan;
@synthesize tap = _tap;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    
    [self _CYSliderObservers];
    
    [self _CYSliderSetupUI];
    
    [self _CYSliderInitialize];
    
    [self _CYSliderPanGR];
    
    [self _CYSliderTapGR];
    
    
    return self;
}

// MARK: Setter

- (void)setIsRound:(BOOL)isRound {
    _isRound = isRound;
    _containerView.isRound = isRound;
}

- (void)setTrackHeight:(CGFloat)trackHeight {
    _trackHeight = trackHeight;
    [self.containerView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.offset(self.trackHeight);
    }];
}

- (void)setValue:(CGFloat)value {
    if ( isnan(value) ) return;
    if      ( value < self.minValue ) value = self.minValue;
    else if ( value > self.maxValue ) value = self.maxValue;
    _value = value;
}

// MARK: 生命周期

- (void)dealloc {
    NSLog(@"%s", __func__);
    [self _CYSliderRemoveObservers];
}


// MARK: 初始化参数

- (void)_CYSliderInitialize {
    
    self.trackHeight = 5.0;
    self.minValue = 0.0;
    self.maxValue = 1.0;
    self.borderWidth = 0.4;
    self.borderColor = [UIColor lightGrayColor];
    self.isRound = YES;
    
    self.enableBufferProgress = NO;
    self.bufferProgress = 0;
    self.bufferProgressColor = [UIColor grayColor];
    
}

// MARK: Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    if ( self.enableBufferProgress ) [self setBufferProgress:self.bufferProgress];
}

- (CGFloat)rate {
    if ( 0 == self.maxValue - self.minValue ) return 0;
    return (self.value - self.minValue) / (self.maxValue - self.minValue);
}

// MARK: PanGR

- (void)_CYSliderPanGR {
    _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGR:)];
    [self addGestureRecognizer:_pan];
}

- (void)_CYSliderTapGR {
    _tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGR:)];
    [self addGestureRecognizer:_tap];
}

- (void)handleTapGR:(UITapGestureRecognizer *)tap {
    CGPoint startPoint = [tap locationInView:tap.view];
    CGFloat value = startPoint.x / tap.view.ccy_w;
    value = value * (self.maxValue - self.minValue) + self.minValue;
    self.value = value;
    
    if ([self.delegate respondsToSelector:@selector(sliderClick:)] )
    {
        [self.delegate sliderClick:self];
    }
    
    switch (tap.state) {
        case UIGestureRecognizerStateBegan:
        {
            NSLog(@"");
        }
            break;
        case UIGestureRecognizerStateEnded:
        {
            NSLog(@"");
        }
            break;
            
        default:
            break;
    }
}

- (void)handlePanGR:(UIPanGestureRecognizer *)pan {
    CGPoint startPoint = [pan locationInView:pan.view];
    switch (pan.state) {
        case UIGestureRecognizerStateBegan: {
            _isDragging = YES;
            CGFloat value = startPoint.x / pan.view.ccy_w;
            value = value * (self.maxValue - self.minValue) + self.minValue;
            self.value = value;
            self.thumbImageView.image = self.thumbnail_sel;
            [self.thumbImageView mas_updateConstraints:^(MASConstraintMaker *make) {
                make.width.height.equalTo(@32);
            }];
            if ( ![self.delegate respondsToSelector:@selector(sliderWillBeginDragging:)] ) break;
            [self.delegate sliderWillBeginDragging:self];
        }
        case UIGestureRecognizerStateChanged: {
            CGFloat value = startPoint.x / pan.view.ccy_w;
           value = value * (self.maxValue - self.minValue) + self.minValue;
            self.value = value;
            if ( ![self.delegate respondsToSelector:@selector(sliderDidDrag:)] ) break;
            [self.delegate sliderDidDrag:self];
        }
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled: {
            _isDragging = NO;
            self.thumbImageView.image = self.thumbnail_nor;
            [self.thumbImageView mas_updateConstraints:^(MASConstraintMaker *make) {
                make.width.height.equalTo(@10);
            }];
            if ( ![self.delegate respondsToSelector:@selector(sliderDidEndDragging:)] ) break;
            [self.delegate sliderDidEndDragging:self];
        }
            break;
        default:
            break;
    }
    
//    CGPoint offset = [pan velocityInView:pan.view];
//    self.value += offset.x / 10000;
}

// MARK: UI

- (void)_CYSliderSetupUI {
    self.backgroundColor = [UIColor clearColor];
    [self addSubview:self.containerView];
    [self.containerView addSubview:self.trackImageView];
    [self.containerView addSubview:self.bufferProgressView];
    [self.containerView addSubview:self.traceImageView];
    
    [_containerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.offset(0);
        make.trailing.offset(0);
        make.center.offset(0);
    }];
    
    [_trackImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.offset(0);
    }];
    
    [_bufferProgressView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.leading.bottom.offset(0);
        make.width.offset(0);
    }];
    
    [_traceImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.leading.bottom.offset(0);
        make.width.offset(0.001);
    }];
}

- (UIView *)containerView {
    if ( _containerView ) return _containerView;
    _containerView = [CYContainerView new];
    return _containerView;
}

- (UIImageView *)trackImageView {
    if ( _trackImageView ) return _trackImageView;
    _trackImageView = [self imageViewWithImageStr:@""];
    _trackImageView.backgroundColor = [UIColor whiteColor];
    return _trackImageView;
}

- (UIImageView *)traceImageView {
    if ( _traceImageView ) return _traceImageView;
    _traceImageView = [self imageViewWithImageStr:@""];
    _traceImageView.frame = CGRectZero;
    _traceImageView.backgroundColor = [UIColor greenColor];
    return _traceImageView;
}

- (UIImageView *)thumbImageView {
    if ( _thumbImageView ) return _thumbImageView;
    _thumbImageView = [self imageViewWithImageStr:@""];
    [self addSubview:self.thumbImageView];
    [_thumbImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(_thumbImageView.superview);
        make.centerX.equalTo(_traceImageView.mas_trailing);
        make.width.height.equalTo(@10);
    }];
    return _thumbImageView;
}

- (UIImageView *)imageViewWithImageStr:(NSString *)imageStr {
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:imageStr]];
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    return imageView;
}

- (UIView *)bufferProgressView {
    if ( _bufferProgressView ) return _bufferProgressView;
    _bufferProgressView = [UIView new];
    return _bufferProgressView;
}

@end



// MARK: Observers

@implementation CYSlider (DBObservers)

- (void)_CYSliderObservers {
    [self addObserver:self forKeyPath:@"value" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)_CYSliderRemoveObservers {
    [self removeObserver:self forKeyPath:@"value"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context  {
    if ( ![keyPath isEqualToString:@"value"] ) return;
    CGFloat rate = self.rate;
    if ( 0 != self.containerView.ccy_w ) {
        CGFloat minX = 0;
        minX = _thumbImageView.ccy_w / 3.0 * 0.25 / self.containerView.ccy_w;//其中"3.0",是手势会触发放大的效果,放大系数
        // spacing
        if ( rate < minX ) rate = minX;
        else if ( rate > (1 - minX) ) rate = 1 - minX;
    }
    
    __weak __typeof(&*self)weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.traceImageView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.leading.bottom.offset(0);
            make.width.equalTo(weakSelf.traceImageView.superview).multipliedBy(rate);
        }];
    });
}

@end





#pragma mark - Buffer


@implementation CYSlider (CYBufferProgress)

- (BOOL)enableBufferProgress {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setEnableBufferProgress:(BOOL)enableBufferProgress {
    objc_setAssociatedObject(self, @selector(enableBufferProgress), @(enableBufferProgress), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.bufferProgressView.hidden = !enableBufferProgress;
    });
    
}

- (UIColor *)bufferProgressColor {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setBufferProgressColor:(UIColor *)bufferProgressColor {
    if ( !bufferProgressColor ) return;
    objc_setAssociatedObject(self, @selector(bufferProgressColor), bufferProgressColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.bufferProgressView.backgroundColor = bufferProgressColor;
    });
    
}

- (CGFloat)bufferProgress {
    return [objc_getAssociatedObject(self, _cmd) floatValue];
}

- (void)setBufferProgress:(CGFloat)bufferProgress {
    if      ( bufferProgress > 1 ) bufferProgress = 1;
    else if ( bufferProgress < 0 ) bufferProgress = 0;
    objc_setAssociatedObject(self, @selector(bufferProgress), @(bufferProgress), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( !self.bufferProgressView.superview ) return ;
        [self.bufferProgressView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.width.offset(bufferProgress * self.containerView.ccy_w);
        }];
    });
    
}

@end



#pragma mark - Border


@implementation CYSlider (BorderLine)

- (void)setVisualBorder:(BOOL)visualBorder {
    if ( self.visualBorder == visualBorder ) return;
    objc_setAssociatedObject(self, @selector(visualBorder), @(visualBorder), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if ( visualBorder ) {
        _containerView.layer.borderColor = self.borderColor.CGColor;
        _containerView.layer.borderWidth = self.borderWidth;
    }
    else {
        _containerView.layer.borderColor = nil;
        _containerView.layer.borderWidth = 0;
    }
}

- (BOOL)visualBorder {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setBorderColor:(UIColor *)borderColor {
    objc_setAssociatedObject(self, @selector(borderColor), borderColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if ( self.visualBorder ) _containerView.layer.borderColor = borderColor.CGColor;
}

- (UIColor *)borderColor {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setBorderWidth:(CGFloat)borderWidth {
    objc_setAssociatedObject(self, @selector(borderWidth), @(borderWidth), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if ( self.visualBorder ) _containerView.layer.borderWidth = borderWidth;
}

- (CGFloat)borderWidth {
    return [objc_getAssociatedObject(self, _cmd) doubleValue];
}

@end

