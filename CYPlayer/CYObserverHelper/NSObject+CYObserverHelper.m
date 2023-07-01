//
//  NSObject+CYObserverHelper.m
//  TmpProject
//
//  Created by yellowei on 2017/12/8.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "NSObject+CYObserverHelper.h"
#import <objc/message.h>

@interface CYObserverHelper : NSObject
@property (nonatomic, unsafe_unretained) id target;
@property (nonatomic, unsafe_unretained) id observer;
@property (nonatomic, strong) NSString *keyPath;
@property (nonatomic, weak) CYObserverHelper *factor;
@end

@implementation CYObserverHelper
- (void)dealloc {
    if ( _factor ) {
        [_target removeObserver:_observer forKeyPath:_keyPath];
    }
}
@end

@implementation NSObject (ObserverHelper)

- (void)cy_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
    
    [self addObserver:observer forKeyPath:keyPath options:NSKeyValueObservingOptionNew context:nil];
    
    CYObserverHelper *helper = [CYObserverHelper new];
    CYObserverHelper *sub = [CYObserverHelper new];
    
    sub.target = helper.target = self;
    sub.observer = helper.observer = observer;
    sub.keyPath = helper.keyPath = keyPath;
    helper.factor = sub;
    sub.factor = helper;
    
    const char *helpeKey = [[keyPath mutableCopy] UTF8String];
    const char *subKey = [[keyPath mutableCopy] UTF8String];
    objc_setAssociatedObject(self, helpeKey, helper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(observer, subKey, sub, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

