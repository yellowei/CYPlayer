//
//  CYCTImageData.h
//  Test
//
//  Created by yellowei on 2017/12/14.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CYCTImageData : NSObject

@property (nonatomic, strong) NSTextAttachment *imageAttachment;
@property (nonatomic, assign) int postion;
@property (nonatomic, assign) CGRect imagePosition; // Core Text Coordinate

@end
