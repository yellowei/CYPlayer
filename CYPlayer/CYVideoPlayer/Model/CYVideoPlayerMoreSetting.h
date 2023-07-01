//
//  CYVideoPlayerMoreSetting.h
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/9/25.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class CYVideoPlayerMoreSettingSecondary, UIColor, UIImage;

@interface CYVideoPlayerMoreSetting : NSObject

// MARK: ... This --> Class methods

/*!
 *  CYVideoPlayerMoreSetting.titleColor = [UIColor whiteColor];
 *
 *  default is whiteColor
 *  设置item默认的标题颜色
 */
@property (class, nonatomic, strong) UIColor *titleColor;

/*!
 *  CYVideoPlayerMoreSetting.titleFontSize = 12;
 *
 *  default is 12
 *  设置item默认的字体
 */
@property (class, nonatomic, assign) float titleFontSize;


// MARK: ... This --> Instance Methods.   show 1 level interface

@property (nonatomic, strong, nullable) NSString *title;
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, copy) void(^clickedExeBlock)(CYVideoPlayerMoreSetting *model);

- (instancetype)initWithTitle:(NSString *__nullable)title
                        image:(UIImage *__nullable)image
              clickedExeBlock:(void(^)(CYVideoPlayerMoreSetting *model))block;


// MARK: ... This --> Instance Methods.   show 2 level interface

@property (nonatomic, assign, getter=isShowTowSetting) BOOL showTowSetting;
@property (nonatomic, strong) NSString *twoSettingTopTitle;
@property (nonatomic, strong) NSArray<CYVideoPlayerMoreSettingSecondary *> *twoSettingItems;

- (instancetype)initWithTitle:(NSString *__nullable)title
                        image:(UIImage *__nullable)image
               showTowSetting:(BOOL)showTowSetting                                      // show
           twoSettingTopTitle:(NSString *)twoSettingTopTitle                            // top title
              twoSettingItems:(NSArray<CYVideoPlayerMoreSettingSecondary *> *)items    // items
              clickedExeBlock:(void(^)(CYVideoPlayerMoreSetting *model))block;

@end

NS_ASSUME_NONNULL_END
