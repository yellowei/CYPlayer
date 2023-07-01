//
//  NSObject+CYObserverHelper.h
//  TmpProject
//
//  Created by yellowei on 2017/12/8.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (CYObserverHelper)

- (void)cy_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath;

@end
