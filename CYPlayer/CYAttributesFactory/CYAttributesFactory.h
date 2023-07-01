//
//  CYAttributesFactory.h
//  CYAttributesFactory
//
//  Created by yellowei on 2018/10/1.
//  Copyright © 2017年 yellowei. All rights reserved.
//
//
//  关于属性介绍请移步 => http://www.jianshu.com/p/ebbcfc24f9cb

#import <UIKit/UIKit.h>

@class CYAttributeWorker;

NS_ASSUME_NONNULL_BEGIN

@interface CYAttributesFactory : NSObject

/*!
 *  NSAttributedString *attr = [CYAttributesFactory alteringStr:@"我的故乡" task:^(CYAttributeWorker * _Nonnull worker) {
 *      NSShadow *shadow = [NSShadow new];
 *      shadow.shadowColor = [UIColor greenColor];
 *      shadow.shadowOffset = CGSizeMake(1, 1);
 *      worker.font([UIFont boldSystemFontOfSize:40]).shadow(shadow);
 *  }];
 **/
+ (NSAttributedString *)alteringStr:(NSString *)str task:(void(^)(CYAttributeWorker *worker))task;

+ (NSAttributedString *)alteringAttrStr:(NSAttributedString *)attrStr task:(void(^)(CYAttributeWorker *worker))task;

+ (NSAttributedString *)producingWithImage:(UIImage *)image size:(CGSize)size task:(void(^)(CYAttributeWorker *worker))task;

+ (NSAttributedString *)producingWithTask:(void(^)(CYAttributeWorker *worker))task;

@end

NS_ASSUME_NONNULL_END
