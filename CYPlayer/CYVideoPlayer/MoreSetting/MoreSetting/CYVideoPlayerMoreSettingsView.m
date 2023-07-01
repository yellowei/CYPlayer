//
//  CYVideoPlayerMoreSettingsView.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/9/25.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerMoreSettingsView.h"
#import "CYVideoPlayerMoreSettingsFooterSlidersView.h"
#import <Masonry/Masonry.h>
#import "CYSlider.h"


static NSString *const CYVideoPlayerMoreSettingsColCellID = @"CYVideoPlayerMoreSettingsColCell";

static NSString *const CYVideoPlayerMoreSettingsFooterSlidersViewID = @"CYVideoPlayerMoreSettingsFooterSlidersView";


@interface CYVideoPlayerMoreSettingsView ()<UICollectionViewDataSource, UICollectionViewDelegate>

@property (nonatomic, strong, readonly) UICollectionView *colView;

@end

@implementation CYVideoPlayerMoreSettingsView {
    CYVideoPlayerMoreSettingsFooterSlidersView *_footerView;
}

@synthesize colView = _colView;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    [self _CYVideoPlayerMoreSettingsViewSetupUI];
    return self;
}

- (void)setMoreSettings:(NSArray<CYVideoPlayerMoreSetting *> *)moreSettings {
    _moreSettings = moreSettings;
    [self.colView reloadData];
}

- (void)setFooterViewModel:(CYMoreSettingsFooterViewModel *)footerViewModel {
    _footerViewModel = footerViewModel;
    _footerView.model = footerViewModel;
}

- (void)_CYVideoPlayerMoreSettingsViewSetupUI {
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85];
    [self addSubview:self.colView];
    [_colView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(_colView.superview);
    }];
    [self.colView reloadData];
}

- (UICollectionView *)colView {
    if ( _colView ) return _colView;
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    flowLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
    flowLayout.footerReferenceSize = CGSizeMake(0, 200);
    _colView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:flowLayout];
    [_colView registerClass:NSClassFromString(CYVideoPlayerMoreSettingsColCellID) forCellWithReuseIdentifier:CYVideoPlayerMoreSettingsColCellID];
    [_colView registerClass:NSClassFromString(CYVideoPlayerMoreSettingsFooterSlidersViewID) forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:CYVideoPlayerMoreSettingsFooterSlidersViewID];
    _colView.dataSource = self;
    _colView.delegate = self;
    return _colView;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _moreSettings.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CYVideoPlayerMoreSettingsColCellID forIndexPath:indexPath];
    [cell setValue:_moreSettings[indexPath.row] forKey:@"model"];
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    _footerView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:CYVideoPlayerMoreSettingsFooterSlidersViewID forIndexPath:indexPath];
    _footerView.model = _footerViewModel;
    return _footerView;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = floor(self.frame.size.width / 3);
    return CGSizeMake( width, width);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    if ( 0 == section ) return UIEdgeInsetsMake(20, 0, 0, 0);
    return UIEdgeInsetsMake(0, 0, 0, 0);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 0;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 0;
}

@end
