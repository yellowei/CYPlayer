//
//  CYAttributeWorker.h
//  CYAttributeWorker
//
//  Created by yellowei on 2017/11/12.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CYAttributedStringKeys.h"

NS_ASSUME_NONNULL_BEGIN

@interface CYAttributeWorker : NSObject

- (instancetype)init NS_DESIGNATED_INITIALIZER;

- (NSAttributedString *)endTask;

#pragma mark - All
/*!
 *  Setting the whole may affect the local range properties,
 *  please set the whole first, and then set the local range properties.
 *
 *  设置整体可能会影响局部范围属性, 请先设置整体, 然后再设置局部范围属性.
 *  也可不设置整体, 只设置局部属性.
 **/
/// 整体 字体
@property (nonatomic, copy, readonly) CYAttributeWorker *(^font)(UIFont *font);
/// 整体 放大
@property (nonatomic, copy, readonly) CYAttributeWorker *(^expansion)(float expansion);
/// 整体 字体颜色
@property (nonatomic, copy, readonly) CYAttributeWorker *(^fontColor)(UIColor *fontColor);
/// 整体 字体阴影
@property (nonatomic, copy, readonly) CYAttributeWorker *(^shadow)(NSShadow *shadow);
/// 整体 背景颜色
@property (nonatomic, copy, readonly) CYAttributeWorker *(^backgroundColor)(UIColor *color);
/// 整体 每行间隔
@property (nonatomic, copy, readonly) CYAttributeWorker *(^lineSpacing)(float spacing);
/// 整体 段后间隔(\n)
@property (nonatomic, copy, readonly) CYAttributeWorker *(^paragraphSpacing)(float paragraphSpacing);
/// 整体 段前间隔(\n)
@property (nonatomic, copy, readonly) CYAttributeWorker *(^paragraphSpacingBefore)(float paragraphSpacingBefore);
/// 首行头缩进
@property (nonatomic, copy, readonly) CYAttributeWorker *(^firstLineHeadIndent)(float padding);
/// 左缩进
@property (nonatomic, copy, readonly) CYAttributeWorker *(^headIndent)(float headIndent);
/// 右缩进(正值从左算起, 负值从右算起)
@property (nonatomic, copy, readonly) CYAttributeWorker *(^tailIndent)(float tailIndent);
/// 整体 字间隔
@property (nonatomic, copy, readonly) CYAttributeWorker *(^letterSpacing)(float spacing);
/// 整体 对齐方式
@property (nonatomic, copy, readonly) CYAttributeWorker *(^alignment)(NSTextAlignment alignment);
/// line break mode
@property (nonatomic, copy, readonly) CYAttributeWorker *(^lineBreakMode)(NSLineBreakMode mode);
/*!
 *  整体 添加下划线
 *  ex:
 *  worker.underline(NSUnderlineByWord |
 *                   NSUnderlinePatternSolid |
 *                   NSUnderlineStyleDouble, [UIColor blueColor])
 **/
@property (nonatomic, copy, readonly) CYAttributeWorker *(^underline)(NSUnderlineStyle style, UIColor *color);
/*!
 *  整体 添加删除线
 *  ex:
 *  worker.strikethrough(NSUnderlineByWord |
 *                       NSUnderlinePatternSolid |
 *                       NSUnderlineStyleDouble, [UIColor blueColor])
 **/
@property (nonatomic, copy, readonly) CYAttributeWorker *(^strikethrough)(NSUnderlineStyle style, UIColor *color);
/// border 如果大于0, 则显示的是空心字体. 如果小于0, 则显示实心字体(就像正常字体那样, 只不过是描边了).
@property (nonatomic, copy, readonly) CYAttributeWorker *(^stroke)(float border, UIColor *color);
/// 整体 凸版
@property (nonatomic, copy, readonly) CYAttributeWorker *(^letterpress)(void);
/// 整体 链接
@property (nonatomic, copy, readonly) CYAttributeWorker *(^link)(void);
/// 整体 段落样式
@property (nonatomic, copy, readonly) CYAttributeWorker *(^paragraphStyle)(NSParagraphStyle *style);
/// 整体 倾斜. 建议值 -1 到 1 之间.
@property (nonatomic, copy, readonly) CYAttributeWorker *(^obliqueness)(float obliqueness);
/// key: NSAttributedStringKey
@property (nonatomic, copy, readonly) CYAttributeWorker *(^addAttribute)(NSAttributedStringKey key, id value);
/// 点击触发动作(需要配合 CYLabel 使用)
@property (nonatomic, copy, readonly) CYAttributeWorker *(^action)(void(^task)(NSRange range, NSAttributedString *matched));



#pragma mark - Range
/*!
 *  range Edit 1:
 *  [CYAttributesFactory alteringStr:@"I am a bad man!" task:^(CYAttributeWorker * _Nonnull worker) {
 *      worker.alteringRange(NSMakeRange(0, 1), ^(CYAttributeWorker * _Nonnull range) {
 *           range
 *              .nextFont([UIFont boldSystemFontOfSize:30])
 *              .nextFontColor([UIColor orangeColor]);
 *      });
 *  }];
 **/
@property (nonatomic, copy, readonly) CYAttributeWorker *(^rangeEdit)(NSRange range, void(^task)(CYAttributeWorker *range));
/*!
 *  range Edit 2:
 *  [CYAttributesFactory alteringStr:[NSString stringWithFormat:@"%@%@%@", pre, mid, end] task:^(CYAttributeWorker * _Nonnull worker) {
 *      worker
 *      .nextFont([UIFont boldSystemFontOfSize:12])
 *      .nextFontColor([UIColor yellowColor])
 *      .nextAlignment(NSTextAlignmentRight)
 *      .range(NSMakeRange(pre.length, mid.length));  // -->>>>> must set it up.
 *  }];
 **/
@property (nonatomic, copy, readonly) void(^range)(NSRange range);
/// 指定范围内的 字体
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextFont)(UIFont *font);
/// 指定范围内的 字体放大
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextExpansion)(float nextExpansion);
/// 指定范围内的 字体颜色
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextFontColor)(UIColor *fontColor);
/// 指定范围内的 阴影
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextShadow)(NSShadow *shadow);
/// 指定范围内的 背景颜色
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextBackgroundColor)(UIColor *color);
/// 指定范围内的 字间隔
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextLetterSpacing)(float spacing);
/// 指定范围内的 行间隔
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextLineSpacing)(float lineSpacing);
/// 指定范围内的 段后间隔(\n)
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextParagraphSpacing)(float paragraphSpacing);
/// 指定范围内的 段前间隔(\n)
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextParagraphSpacingBefore)(float paragraphSpacingBefore);
/// 指定范围内的 首行头缩进
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextFirstLineHeadIndent)(float padding);
/// 指定范围内的 左缩进
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextHeadIndent)(float headIndent);
/// 指定范围内的 右缩进(正值从左算起, 负值从右算起)
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextTailIndent)(float tailIndent);
/// 指定范围内的 对齐方式
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextAlignment)(NSTextAlignment alignment);
/// 指定范围内的 下划线
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextUnderline)(NSUnderlineStyle style, UIColor *color);
/// 指定范围内的 删除线
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextStrikethough)(NSUnderlineStyle style, UIColor *color);
/// 指定范围内的 填充. 效果同 storke.
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextStroke)(float border, UIColor *color);
/// 指定范围内的 凸版
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextLetterpress)(void);
/// 指定范围内为链接
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextLink)(void);
/// 指定范围内上下的偏移量. 正值向上, 负数向下.
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextOffset)(float offset);
/// 指定范围内倾斜. 建议值 -1 到 1 之间.
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextObliqueness)(float obliqueness);
/// attrKey: NSAttributedStringKey
@property (nonatomic, copy, readonly) CYAttributeWorker *(^next)(NSAttributedStringKey attrKey, id value);
/// Action, 需要使用 CYLabel
@property (nonatomic, copy, readonly) CYAttributeWorker *(^nextAction)(void(^task)(NSRange range, NSAttributedString *matched));



#pragma mark - Insert
/*!
 *  Insert a image at the specified position.
 *  You can get the length of the text through [worker.length].
 *  If index = -1, it will be inserted at the end of the text.
 *
 *  可以通过 worker.length 来获取文本的length
 *  指定位置 插入图片.
 *  如果 index = -1, 将会插到文本最后
 **/
@property (nonatomic, copy, readonly) CYAttributeWorker *(^insertImage)(UIImage *image, NSInteger index, CGPoint offset, CGSize size);
/*!
 *  You can get the length of the text through [worker.length].
 *  If index = -1, it will be inserted at the end of the text.
 *
 *  可以通过 worker.length 来获取文本的length
 *  指定位置 插入文本.
 *  如果 index = -1, 将会插到文本最后.
 **/
@property (nonatomic, copy, readonly) CYAttributeWorker *(^insertAttr)(NSAttributedString *attrStr, NSInteger index);
/*!
 *  You can get the length of the text through [worker.length].
 *  If index = -1, it will be inserted at the end of the text.
 *
 *  可以通过 worker.length 来获取文本的length
 *  指定位置 插入文本.
 *  如果 index = -1, 将会插到文本最后
 **/
@property (nonatomic, copy, readonly) CYAttributeWorker *(^insertText)(NSString *text, NSInteger index);
/**
 *  insert = NSString or NSAttributedString or UIImage
 *  insert(string, 0)
 *  insert(attributedString, 0)
 *  insert([UIImage imageNamed:name], 10, CGPointMake(0, -20), CGSizeMake(50, 50))
 */
@property (nonatomic, copy, readonly) CYAttributeWorker *(^insert)(id strOrAttrStrOrImg, NSInteger index, ...);
/*!
 *  worker.insert(@" recur ", worker.lastInsertedRange.location);
 *  worker.lastInserted(^(CYAttributeWorker * _Nonnull worker) {
 *      worker
 *      .nextFont([UIFont systemFontOfSize:30])
 *      .nextFontColor([UIColor redColor]);
 *  });
 */
@property (nonatomic, copy, readonly) CYAttributeWorker *(^lastInserted)(void(^rangeTask)(CYAttributeWorker *worker));
@property (nonatomic, assign, readonly) NSRange lastInsertedRange;

#pragma mark - Replace
/// value == NSString Or NSAttributedString
@property (nonatomic, copy, readonly) CYAttributeWorker *(^replace)(NSRange range, id strOrAttrStr);
/// oldPart and newPart == NSString Or NSAttributedString
@property (nonatomic, copy, readonly) CYAttributeWorker *(^replaceIt)(id oldPart, id newPart);


#pragma mark - Remove
/// 指定范围 删除文本
@property (nonatomic, copy, readonly) CYAttributeWorker *(^removeText)(NSRange range);
/// 指定范围 删除属性
@property (nonatomic, copy, readonly) CYAttributeWorker *(^removeAttribute)(NSAttributedStringKey key, NSRange range);
/// 除字体大小, 清除文本其他属性
@property (nonatomic, copy, readonly) void (^clean)(void);


#pragma mark - Regular Expression
/// 正则匹配
@property (nonatomic, copy, readonly) CYAttributeWorker *(^regexp)(NSString *ex, void(^task)(CYAttributeWorker *regexp));
/// 正则匹配
@property (nonatomic, copy, readonly) CYAttributeWorker *(^regexpRanges)(NSString *ex, void(^task)(NSArray<NSValue *> *ranges));


#pragma mark - Other
/// 获取当前文本的长度
@property (nonatomic, assign, readonly) NSInteger length;
/// 获取指定范围的宽度. (必须设置过字体)
@property (nonatomic, copy, readonly) CGFloat(^width)(NSRange range);
/// 获取指定范围的大小. (必须设置过字体)
@property (nonatomic, copy, readonly) CGSize(^size)(NSRange range);
/// 获取指定范围的大小. (必须设置过字体)
@property (nonatomic, copy, readonly) CGRect(^boundsByMaxWidth)(CGFloat maxWidth);
/// 获取指定范围的大小. (必须设置过字体)
@property (nonatomic, copy, readonly) CGRect(^boundsByMaxHeight)(CGFloat maxHeight);
/// 获取指定范围的文本
@property (nonatomic, copy, readonly) NSAttributedString *(^attrStrByRange)(NSRange range);

@end

NS_ASSUME_NONNULL_END

