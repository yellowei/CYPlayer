//
//  CYPlayerGestureControl.m
//  CYPlayerGestureControl
//
//  Created by yellowei on 2017/12/10.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYPlayerGestureControl.h"

@interface CYPlayerGestureControl ()<UIGestureRecognizerDelegate>


@end

@implementation CYPlayerGestureControl
{
    //Gesture
    BOOL                _gestureHandling;
}

@synthesize singleTap = _singleTap;
@synthesize doubleTap = _doubleTap;
@synthesize panGR = _panGR;

- (instancetype)initWithTargetView:(UIView *)view {
    self = [super init];
    if ( !self ) return nil;
    NSAssert(view, @"view can not be empty!");
    
    _targetView = view;
    [self _addGestureToControlView];
    return self;
}

- (void)_addGestureToControlView {
    //    [self.singleTap requireGestureRecognizerToFail:self.doubleTap];
    [self.doubleTap requireGestureRecognizerToFail:self.panGR];
    
    [_targetView addGestureRecognizer:self.singleTap];
    [_targetView addGestureRecognizer:self.doubleTap];
    [_targetView addGestureRecognizer:self.panGR];
    
    self.singleTap.delegate = self;
    self.doubleTap.delegate = self;
    self.panGR.delegate = self;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ( _triggerCondition ) return _triggerCondition(self, gestureRecognizer);
    return YES;
}

- (UITapGestureRecognizer *)singleTap {
    if ( _singleTap ) return _singleTap;
    _singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    _singleTap.delegate = self;
    return _singleTap;
}
- (UITapGestureRecognizer *)doubleTap {
    if ( _doubleTap ) return _doubleTap;
    _doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    _doubleTap.numberOfTapsRequired = 2;
    _doubleTap.delegate = self;
    return _doubleTap;
}
- (UIPanGestureRecognizer *)panGR {
    if ( _panGR ) return _panGR;
    _panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    _panGR.delegate = self;
    return _panGR;
}

- (void)handleSingleTap:(UITapGestureRecognizer *)tap {
    if ( _singleTapped ) _singleTapped(self);
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)tap {
    if ( _doubleTapped ) _doubleTapped(self);
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    
    if (_gestureHandling)
    {
        return;
    }
    _gestureHandling = YES;
    
    CGPoint translate = [pan translationInView:pan.view];
    
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:{
            CGPoint locationPoint = [pan locationInView:pan.view];
            if ( locationPoint.x > _targetView.bounds.size.width / 2 ) {
                self.panLocation = CYPanLocation_Right;
            }
            else {
                self.panLocation = CYPanLocation_Left;
            }
            
            CGPoint velocity = [pan velocityInView:pan.view];
            CGFloat x = fabs(velocity.x);
            CGFloat y = fabs(velocity.y);
            if (x > y) {
                self.panDirection = CYPanDirection_H;
            }
            else {
                self.panDirection = CYPanDirection_V;
            }
            
            if ( _beganPan ) _beganPan(self, _panDirection, _panLocation);
        }
            break;
        case UIGestureRecognizerStateChanged:{
            if ( _changedPan ) _changedPan(self, _panDirection, _panLocation, translate);
        }
            break;
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded:{
            if ( _endedPan ) _endedPan(self, _panDirection, _panLocation);
        }
            break;
        default: break;
    }
    
    [pan setTranslation:CGPointZero inView:pan.view];
    
    _gestureHandling = NO;
}


# pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
//    if ([touch.view isDescendantOfView:self.bottomControlView])
    if ([touch.view isKindOfClass:[UIButton class]])//提高按钮的响应速度
    {
        return NO;
    }
    return YES;
}
@end

