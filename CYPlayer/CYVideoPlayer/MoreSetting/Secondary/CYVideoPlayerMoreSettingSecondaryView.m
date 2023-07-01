//
//  CYVideoPlayerMoreSettingSecondaryView.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/12/5.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerMoreSettingSecondaryView.h"
#import <Masonry/Masonry.h>
#import "CYAttributesFactoryHeader.h"
#import "CYVideoPlayerMoreSettingsSecondaryHeaderView.h"
#import "CYVideoPlayerMoreSettingSecondary.h"

@interface CYVideoPlayerMoreSettingSecondaryView (ColDataSourceMethods)<UICollectionViewDataSource>
@end

@interface CYVideoPlayerMoreSettingSecondaryView (UICollectionViewDelegateMethods)<UICollectionViewDelegate>
@end


static NSString *const CYVideoPlayerMoreSettingSecondaryColCellID = @"CYVideoPlayerMoreSettingSecondaryColCell";

static NSString *const CYVideoPlayerMoreSettingsSecondaryHeaderViewID = @"CYVideoPlayerMoreSettingsSecondaryHeaderView";

@interface CYVideoPlayerMoreSettingSecondaryView ()

@property (nonatomic, strong, readonly) UICollectionView *colView;
@property (nonatomic, strong, readwrite) CYVideoPlayerMoreSettingsSecondaryHeaderView *headerView;

@end

@implementation CYVideoPlayerMoreSettingSecondaryView

@synthesize colView = _colView;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    [self _CYVideoPlayerMoreSettingTwoSettingsViewSetupUI];
    return self;
}

- (void)setTwoLevelSettings:(CYVideoPlayerMoreSetting *)twoLevelSettings {
    _twoLevelSettings = twoLevelSettings;
    [self.colView reloadData];
}

// MARK: UI

- (void)_CYVideoPlayerMoreSettingTwoSettingsViewSetupUI {
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85];
    [self addSubview:self.colView];
    [_colView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(_colView.superview);
    }];
    
}

- (UICollectionView *)colView {
    if ( _colView ) return _colView;
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    flowLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
    flowLayout.headerReferenceSize = CGSizeMake(0, [CYVideoPlayerMoreSettingSecondary topTitleFontSize] * 1.2 + 20);
    _colView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:flowLayout];
    [_colView registerClass:NSClassFromString(CYVideoPlayerMoreSettingSecondaryColCellID) forCellWithReuseIdentifier:CYVideoPlayerMoreSettingSecondaryColCellID];
    [_colView registerClass:NSClassFromString(CYVideoPlayerMoreSettingsSecondaryHeaderViewID) forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:CYVideoPlayerMoreSettingsSecondaryHeaderViewID];
    _colView.dataSource = self;
    _colView.delegate = self;
    
    return _colView;
}

@end

@implementation CYVideoPlayerMoreSettingSecondaryView (ColDataSourceMethods)

// MARK: UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.twoLevelSettings.twoSettingItems.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CYVideoPlayerMoreSettingSecondaryColCellID forIndexPath:indexPath];
    [cell setValue:self.twoLevelSettings.twoSettingItems[indexPath.row] forKey:@"model"];
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    self.headerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:CYVideoPlayerMoreSettingsSecondaryHeaderViewID forIndexPath:indexPath];
    self.headerView.model = self.twoLevelSettings;
    return self.headerView;
}

@end



@implementation CYVideoPlayerMoreSettingSecondaryView (UICollectionViewDelegateMethods)

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = floor(self.frame.size.width / 3);
    return CGSizeMake( width, width);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(0, 0, 0, 0);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 0;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 0;
}

@end
