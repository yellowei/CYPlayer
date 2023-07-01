//
//  CYAttributesFactory.m
//  CYAttributesFactory
//
//  Created by yellowei on 2018/10/1.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYAttributesFactory.h"
#import "CYAttributeWorker.h"

/*
 *  1. 派发任务
 *  2. 工厂接收
 *  3. 工厂根据任务, 分配工人完成任务
 */

@interface CYAttributesFactory ()

@end

@implementation CYAttributesFactory

+ (NSAttributedString *)alteringStr:(NSString *)str task:(void(^)(CYAttributeWorker *worker))task {
    if ( !str ) return nil;
    CYAttributeWorker *worker = [CYAttributeWorker new];
    worker.insert(str, 0);
    task(worker);
    return [worker endTask];
}

+ (NSAttributedString *)alteringAttrStr:(NSAttributedString *)attrStr task:(void(^)(CYAttributeWorker *worker))task {
    if ( !attrStr ) return nil;
    CYAttributeWorker *worker = [CYAttributeWorker new];
    worker.insert(attrStr, 0);
    task(worker);
    return [worker endTask];
}

+ (NSAttributedString *)producingWithImage:(UIImage *)image size:(CGSize)size task:(void(^)(CYAttributeWorker *worker))task {
    if ( !image ) return nil;
    CYAttributeWorker *worker = [CYAttributeWorker new];
    worker.insert(image, 0, CGPointZero, size);
    task(worker);
    return [worker endTask];
}

+ (NSAttributedString *)producingWithTask:(void(^)(CYAttributeWorker *worker))task {
    return [self alteringStr:@"" task:task];
}

@end

