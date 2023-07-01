//
//  CYVideoPlayerResources.h
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/11/29.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CYVideoPlayerResources : NSObject

+ (UIImage *)imageNamed:(NSString *)name;

+ (NSString *)bundleComponentWithImageName:(NSString *)imageName;

+ (NSBundle *)bundle;

@end
