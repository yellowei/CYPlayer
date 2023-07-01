//
//  UINavigationController+CYVideoPlayerAdd.m
//  CYBackGR
//
//  Created by yellowei on 2017/9/26.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "UINavigationController+CYVideoPlayerAdd.h"
#import <objc/message.h>
#import "UIViewController+CYVideoPlayerAdd.h"
#import "CYScreenshotView.h"
#import "NSObject+CYObserverHelper.h"

#define CY_Shift        (-[UIScreen mainScreen].bounds.size.width * 0.382)



#pragma mark -

static CYScreenshotView *CY_screenshotView;
static NSMutableArray<UIImage *> * CY_screenshotImagesM;



#pragma mark - UIViewController

@interface UIViewController (CYExtension)

@property (nonatomic, strong, readonly) CYScreenshotView *CY_screenshotView;
@property (nonatomic, strong, readonly) NSMutableArray<UIImage *> * CY_screenshotImagesM;

@end

@implementation UIViewController (CYExtension)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class vc = [self class];
        
        // dismiss
        Method dismissViewControllerAnimatedCompletion = class_getInstanceMethod(vc, @selector(dismissViewControllerAnimated:completion:));
        Method CY_dismissViewControllerAnimatedCompletion = class_getInstanceMethod(vc, @selector(CY_dismissViewControllerAnimated:completion:));
        
        method_exchangeImplementations(CY_dismissViewControllerAnimatedCompletion, dismissViewControllerAnimatedCompletion);
    });
}

- (void)CY_dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    if ( self.navigationController && self.presentingViewController ) {
        // reset image
        [self CY_dumpingScreenshotWithNum:(NSInteger)self.navigationController.childViewControllers.count - 1]; // 由于最顶层的视图还未截取, 所以这里 - 1. 以下相同.
        [self CY_resetScreenshotImage];
    }
    
    // call origin method
    [self CY_dismissViewControllerAnimated:flag completion:completion];
}

- (void)CY_resetScreenshotImage {
    [[self class] CY_resetScreenshotImage];
}

- (void)CY_updateScreenshot {
    
    if (![[NSThread currentThread] isMainThread]) {
        return;
    }
    // get scrrenshort
    id appDelegate = [UIApplication sharedApplication].delegate;
    UIWindow *window = [appDelegate valueForKey:@"window"];
    if (CGRectIsEmpty(window.bounds)) {
        return;
    }
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(window.frame.size.width, window.frame.size.height), YES, 0);
    [window.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // add to container
    [self.CY_screenshotImagesM addObject:viewImage];
    
    // change screenshotImage
    [self.CY_screenshotView setImage:viewImage];
}

- (void)CY_dumpingScreenshotWithNum:(NSInteger)num {
    if ( num <= 0 || num >= self.CY_screenshotImagesM.count ) return;
    [self.CY_screenshotImagesM removeObjectsInRange:NSMakeRange(self.CY_screenshotImagesM.count - num, num)];
}

- (CYScreenshotView *)CY_screenshotView {
    return [[self class] CY_screenshotView];
}

- (NSMutableArray<UIImage *> *)CY_screenshotImagesM {
    return [[self class] CY_screenshotImagesM];
}

+ (CYScreenshotView *)CY_screenshotView {
    if ( CY_screenshotView ) return CY_screenshotView;
    CY_screenshotView = [CYScreenshotView new];
    CGRect bounds = [UIScreen mainScreen].bounds;
    CGFloat width = MIN(bounds.size.width, bounds.size.height);
    CGFloat height = MAX(bounds.size.width, bounds.size.height);
    CY_screenshotView.frame = CGRectMake(0, 0, width, height);
    CY_screenshotView.hidden = YES;
    return CY_screenshotView;
}

+ (NSMutableArray<UIImage *> *)CY_screenshotImagesM {
    if ( CY_screenshotImagesM ) return CY_screenshotImagesM;
    CY_screenshotImagesM = [NSMutableArray array];
    return CY_screenshotImagesM;
}

+ (void)CY_resetScreenshotImage {
    // remove last screenshot
    [self.CY_screenshotImagesM removeLastObject];
    // update screenshotImage
    if (![[NSThread currentThread] isMainThread]) {
        return;
    }
    [self.CY_screenshotView setImage:[self.CY_screenshotImagesM lastObject]];
}

@end



#pragma mark - UINavigationController
@interface UINavigationController (CYExtension)<UINavigationControllerDelegate>

@property (nonatomic, assign, readwrite) BOOL isObserver;

@end

@implementation UINavigationController (CYExtension)

+ (void)load {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // App launching
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(CY_addscreenshotImageViewToWindow) name:UIApplicationDidFinishLaunchingNotification object:nil];
        
        Class nav = [self class];
        
        // Push
        Method pushViewControllerAnimated = class_getInstanceMethod(nav, @selector(pushViewController:animated:));
        Method CY_pushViewControllerAnimated = class_getInstanceMethod(nav, @selector(CY_pushViewController:animated:));
        method_exchangeImplementations(CY_pushViewControllerAnimated, pushViewControllerAnimated);
        
        // Pop
        Method popViewControllerAnimated = class_getInstanceMethod(nav, @selector(popViewControllerAnimated:));
        Method CY_popViewControllerAnimated = class_getInstanceMethod(nav, @selector(CY_popViewControllerAnimated:));
        method_exchangeImplementations(popViewControllerAnimated, CY_popViewControllerAnimated);
        
        // Pop Root VC
        Method popToRootViewControllerAnimated = class_getInstanceMethod(nav, @selector(popToRootViewControllerAnimated:));
        Method CY_popToRootViewControllerAnimated = class_getInstanceMethod(nav, @selector(CY_popToRootViewControllerAnimated:));
        method_exchangeImplementations(popToRootViewControllerAnimated, CY_popToRootViewControllerAnimated);
        
        // Pop To View Controller
        Method popToViewControllerAnimated = class_getInstanceMethod(nav, @selector(popToViewController:animated:));
        Method CY_popToViewControllerAnimated = class_getInstanceMethod(nav, @selector(CY_popToViewController:animated:));
        method_exchangeImplementations(popToViewControllerAnimated, CY_popToViewControllerAnimated);
    });
}

- (void)setIsObserver:(BOOL)isObserver {
    objc_setAssociatedObject(self, @selector(isObserver), @(isObserver), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isObserver {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

// App launching
+ (void)CY_addscreenshotImageViewToWindow {
    UIWindow *window = [(id)[UIApplication sharedApplication].delegate valueForKey:@"window"];
    if (window != nil) {
        NSAssert(window, @"Window was not found and cannot continue!");
        [window insertSubview:self.CY_screenshotView atIndex:0];
    }
    
}

- (void)CY_navSettings {
    self.isObserver = YES;
    
    [self.interactivePopGestureRecognizer cy_addObserver:self forKeyPath:@"state"];
    
    // use custom gesture
    self.useNativeGesture = NO;
    
    // border shadow
    self.view.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.view.bounds].CGPath;
    self.view.layer.shadowOffset = CGSizeMake(-1, 0);
    self.view.layer.shadowColor = [UIColor colorWithWhite:0 alpha:0.2].CGColor;
    self.view.layer.shadowRadius = 1;
    self.view.layer.shadowOpacity = 1;
    
    // delegate
//    self.delegate = (id)[UINavigationController class];
}

// observer
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(UIScreenEdgePanGestureRecognizer *)gesture change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    switch ( gesture.state ) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged:
            break;
        default: {
            // update
            self.useNativeGesture = self.useNativeGesture;
        }
            break;
    }
}

// Push
static UINavigationControllerOperation _navOperation;
- (void)CY_pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    _navOperation = UINavigationControllerOperationPush;
    
    if ( self.interactivePopGestureRecognizer &&
        !self.isObserver ) [self CY_navSettings];
    
    // push update screenshot
//    [self CY_updateScreenshot];
    // call origin method
    [self CY_pushViewController:viewController animated:animated];
}

// Pop
- (UIViewController *)CY_popViewControllerAnimated:(BOOL)animated {
    _navOperation = UINavigationControllerOperationPop;
    // call origin method
    return [self CY_popViewControllerAnimated:animated];
}

// Pop To RootView Controller
- (NSArray<UIViewController *> *)CY_popToRootViewControllerAnimated:(BOOL)animated {
    _navOperation = UINavigationControllerOperationPop;
    [self CY_dumpingScreenshotWithNum:((NSInteger)self.childViewControllers.count - 1) - 1];
    return [self CY_popToRootViewControllerAnimated:animated];
}

// Pop To View Controller
- (NSArray<UIViewController *> *)CY_popToViewController:(UIViewController *)viewController animated:(BOOL)animated {
    _navOperation = UINavigationControllerOperationPop;
    [self.childViewControllers enumerateObjectsUsingBlock:^(__kindof UIViewController * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ( viewController != obj ) return;
        *stop = YES;
        // 由于数组索引从 0 开始, 所以这里 idx + 1, 以下相同
        [self CY_dumpingScreenshotWithNum:((NSInteger)self.childViewControllers.count - 1) - ((NSInteger)idx + 1)];
    }];
    return [self CY_popToViewController:viewController animated:animated];
}

// navController delegate
static __weak UIViewController *_tmpShowViewController;
+ (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if ( _navOperation == UINavigationControllerOperationPush ) { return;}
    _tmpShowViewController = viewController;
}

+ (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if ( _navOperation != UINavigationControllerOperationPop ) return;
    if ( _tmpShowViewController != viewController ) return;
    
    // reset
    [self CY_resetScreenshotImage];
    _tmpShowViewController = nil;
    _navOperation = UINavigationControllerOperationNone;
}

@end






#pragma mark - Gesture
@implementation UINavigationController (CYVideoPlayerAdd)

- (UIPanGestureRecognizer *)cy_pan {
    UIPanGestureRecognizer *cy_pan = objc_getAssociatedObject(self, _cmd);
    if ( cy_pan ) return cy_pan;
    cy_pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(CY_handlePanGR:)];
    [self.view addGestureRecognizer:cy_pan];
    cy_pan.delegate = self;
    objc_setAssociatedObject(self, _cmd, cy_pan, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return cy_pan;
}

- (BOOL)isFadeAreaWithPoint:(CGPoint)point {
    if ( !self.topViewController.cy_fadeAreaViews && !self.topViewController.cy_fadeArea ) return NO;
    __block BOOL isFadeArea = NO;
    UIView *view = self.topViewController.view;
    if ( 0 != self.topViewController.cy_fadeArea ) {
        [self.topViewController.cy_fadeArea enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            CGRect rect = [self.view convertRect:[obj CGRectValue] fromView:view];
            if ( !CGRectContainsPoint(rect, point) ) return ;
            isFadeArea = YES;
            *stop = YES;
        }];
    }
    
    if ( !isFadeArea && 0 != self.topViewController.cy_fadeAreaViews.count ) {
        [self.topViewController.cy_fadeAreaViews enumerateObjectsUsingBlock:^(UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            CGRect rect = [self.view convertRect:obj.frame fromView:view];
            if ( !CGRectContainsPoint(rect, point) ) return ;
            isFadeArea = YES;
            *stop = YES;
        }];
    }
    return isFadeArea;
}

- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)gestureRecognizer {
    if ( self.childViewControllers.count <= 1 ) return NO;
    CGPoint point = [gestureRecognizer locationInView:gestureRecognizer.view];
    if ( [self isFadeAreaWithPoint:point] ) return NO;

    CGPoint translate = [gestureRecognizer translationInView:self.view];
    BOOL possible = translate.x > 0 && translate.y == 0;
    if ( possible ) return YES;
    else return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([otherGestureRecognizer isMemberOfClass:NSClassFromString(@"UIScrollViewPanGestureRecognizer")] ||
        [otherGestureRecognizer isMemberOfClass:NSClassFromString(@"UIScrollViewPagingSwipeGestureRecognizer")]) {
        if ( [otherGestureRecognizer.view isKindOfClass:[UIScrollView class]] ) {
            return [self CY_considerScrollView:(UIScrollView *)otherGestureRecognizer.view otherGestureRecognizer:otherGestureRecognizer];
        }
    }
    
    if ( [otherGestureRecognizer isKindOfClass:NSClassFromString(@"UIPanGestureRecognizer")] ) {
        return NO;
    }
    return YES;
}

- (BOOL)CY_considerScrollView:(UIScrollView *)subScrollView otherGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ( 0 != subScrollView.contentOffset.x ) return NO;
    
    CGPoint translate = [self.cy_pan translationInView:self.view];
    if ( translate.x <= 0 ) return NO;
    else {
        [otherGestureRecognizer setValue:@(UIGestureRecognizerStateCancelled) forKey:@"state"];
        return YES;
    }
}

- (void)CY_handlePanGR:(UIPanGestureRecognizer *)pan {
    CGFloat offset = [pan translationInView:self.view].x;
    
    switch (pan.state) {
        case UIGestureRecognizerStateBegan: {
            [self CY_ViewWillBeginDragging];
        }
            break;
        case UIGestureRecognizerStateChanged: {
            if ( offset < 0 ) return;
            [self CY_ViewDidDrag:offset];
        }
            break;
        case UIGestureRecognizerStatePossible:
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed: {
            [self CY_ViewDidEndDragging:offset];
        }
            break;
    }
}

- (UIScrollView *)CY_findingPossibleRootScrollView {
    __block UIScrollView *scrollView = nil;
    [self.topViewController.view.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ( ![obj isKindOfClass:[UIScrollView class]] ) return;
        *stop = YES;
        scrollView = obj;
    }];
    return scrollView;
}

- (void)CY_ViewWillBeginDragging {
    [self.view endEditing:YES]; // 让键盘消失
    
    self.CY_screenshotView.hidden = NO;
    
    [self CY_findingPossibleRootScrollView].scrollEnabled = NO;
    
    // call block
    if ( self.topViewController.cy_viewWillBeginDragging ) self.topViewController.cy_viewWillBeginDragging(self.topViewController);
    
    // begin animation
    self.CY_screenshotView.transform = CGAffineTransformMakeTranslation(CY_Shift, 0);
}

- (void)CY_ViewDidDrag:(CGFloat)offset {
    self.view.transform = CGAffineTransformMakeTranslation(offset, 0);
    
    // call block
    if ( self.topViewController.cy_viewDidDrag ) self.topViewController.cy_viewDidDrag(self.topViewController);
    
    // continuous animation
    CGFloat rate = offset / self.view.frame.size.width;
    self.CY_screenshotView.transform = CGAffineTransformMakeTranslation(CY_Shift - CY_Shift * rate, 0);
    [self.CY_screenshotView setShadeAlpha:1 - rate];
}

- (void)CY_ViewDidEndDragging:(CGFloat)offset {
    [self CY_findingPossibleRootScrollView].scrollEnabled = YES;
    
    CGFloat rate = offset / self.view.frame.size.width;
    if ( rate < self.scMaxOffset ) {
        [UIView animateWithDuration:0.25 animations:^{
            self.view.transform = CGAffineTransformIdentity;
            // reset status
            self.CY_screenshotView.transform = CGAffineTransformMakeTranslation(CY_Shift, 0);
            [self.CY_screenshotView setShadeAlpha:1];
        } completion:^(BOOL finished) {
            self.CY_screenshotView.hidden = YES;
        }];
    }
    else {
        [UIView animateWithDuration:0.25 animations:^{
            self.view.transform = CGAffineTransformMakeTranslation(self.view.frame.size.width, 0);
            // finished animation
            self.CY_screenshotView.transform = CGAffineTransformMakeTranslation(0, 0);
            [self.CY_screenshotView setShadeAlpha:0.001];
        } completion:^(BOOL finished) {
            [self popViewControllerAnimated:NO];
            self.view.transform = CGAffineTransformIdentity;
            self.CY_screenshotView.hidden = YES;
        }];
    }
    
    // call block
    if ( self.topViewController.cy_viewDidEndDragging ) self.topViewController.cy_viewDidEndDragging(self.topViewController);
}

@end







#pragma mark - Settings

@implementation UINavigationController (Settings)

- (void)setCy_backgroundColor:(UIColor *)cy_backgroundColor {
    objc_setAssociatedObject(self, @selector(cy_backgroundColor), cy_backgroundColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.navigationBar.barTintColor = cy_backgroundColor;
    self.view.backgroundColor = cy_backgroundColor;
}

- (UIColor *)cy_backgroundColor {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setScMaxOffset:(float)scMaxOffset {
    objc_setAssociatedObject(self, @selector(scMaxOffset), @(scMaxOffset), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (float)scMaxOffset {
    float offset = [objc_getAssociatedObject(self, _cmd) floatValue];
    if ( 0 == offset ) return 0.35;
    else return offset;
}

- (void)setUseNativeGesture:(BOOL)useNativeGesture {
    if ( self.cy_DisableGestures ) return;
    objc_setAssociatedObject(self, @selector(useNativeGesture), @(useNativeGesture), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    switch (self.interactivePopGestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged:  break;
        default: {
            self.interactivePopGestureRecognizer.enabled = useNativeGesture;
            self.cy_pan.enabled = !useNativeGesture;
        }
            break;
    }
}

- (BOOL)useNativeGesture {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setCy_DisableGestures:(BOOL)cy_DisableGestures {
    if ( cy_DisableGestures == self.cy_DisableGestures ) return;
    objc_setAssociatedObject(self, @selector(cy_DisableGestures), @(cy_DisableGestures), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if ( self.useNativeGesture ) {
        self.interactivePopGestureRecognizer.enabled = !cy_DisableGestures;
    }
    else {
        self.cy_pan.enabled = !cy_DisableGestures;
    }
}

- (BOOL)cy_DisableGestures {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

@end
