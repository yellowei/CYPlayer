//
//  CYCTData.h
//  Test
//
//  Created by yellowei on 2017/12/13.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <CoreText/CoreText.h>
#import <UIKit/UIKit.h>
#import "CYCTImageData.h"
#import "CYCTFrameParserConfig.h"

@interface CYCTData : NSObject<NSCopying>

@property (nonatomic, assign) CTFrameRef frameRef;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, assign) CGFloat height_t;
@property (nonatomic, strong) NSArray<CYCTImageData *> *imageDataArray;
@property (nonatomic, strong) NSAttributedString *attrStr;
@property (nonatomic, strong) CYCTFrameParserConfig *config;


- (void)needsDrawing;

- (void)drawingWithContext:(CGContextRef)context;

- (signed long)touchIndexWithPoint:(CGPoint)point;

@end
