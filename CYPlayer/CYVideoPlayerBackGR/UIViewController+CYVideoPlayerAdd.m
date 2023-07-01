//
//  UIViewController+CYVideoPlayerAdd.m
//  CYBackGR
//
//  Created by yellowei on 2017/9/27.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "UIViewController+CYVideoPlayerAdd.h"
#import <objc/message.h>

@implementation UIViewController (CYVideoPlayerAdd)

- (void)setCy_fadeArea:(NSArray<NSValue *> *)cy_fadeArea {
    objc_setAssociatedObject(self, @selector(cy_fadeArea), cy_fadeArea, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray<NSValue *> *)cy_fadeArea {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setCy_fadeAreaViews:(NSArray<UIView *> *)cy_fadeAreaViews {
    objc_setAssociatedObject(self, @selector(cy_fadeAreaViews), cy_fadeAreaViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray<UIView *> *)cy_fadeAreaViews {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setCy_viewWillBeginDragging:(void (^)(__kindof UIViewController *))cy_viewWillBeginDragging {
    objc_setAssociatedObject(self, @selector(cy_viewWillBeginDragging), cy_viewWillBeginDragging, OBJC_ASSOCIATION_COPY);
}

- (void (^)(__kindof UIViewController *))cy_viewWillBeginDragging {
    return objc_getAssociatedObject(self, _cmd);
}


- (void)setCy_viewDidDrag:(void (^)(__kindof UIViewController *))cy_viewDidDrag {
    objc_setAssociatedObject(self, @selector(cy_viewDidDrag), cy_viewDidDrag, OBJC_ASSOCIATION_COPY);
}

- (void (^)(__kindof UIViewController *))cy_viewDidDrag {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setCy_viewDidEndDragging:(void (^)(__kindof UIViewController *))cy_viewDidEndDragging {
    objc_setAssociatedObject(self, @selector(cy_viewDidEndDragging), cy_viewDidEndDragging, OBJC_ASSOCIATION_COPY);
}

- (void (^)(__kindof UIViewController *))cy_viewDidEndDragging {
    return objc_getAssociatedObject(self, _cmd);
}

@end
