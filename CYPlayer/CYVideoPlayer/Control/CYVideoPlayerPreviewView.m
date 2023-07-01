//
//  CYVideoPlayerPreviewView.m
//  CYVideoPlayerProject
//
//  Created by yellowei on 2017/12/4.
//  Copyright © 2017年 yellowei. All rights reserved.
//

#import "CYVideoPlayerPreviewView.h"
#import "CYUIFactory.h"
#import "CYVideoPlayerResources.h"
#import <Masonry/Masonry.h>
#import "CYVideoPlayerAssetCarrier.h"
#import "CYPlayerDecoder.h"

static NSString *CYVideoPlayerPreviewCollectionViewCellID = @"CYVideoPlayerPreviewCollectionViewCell";

@interface CYVideoPlayerPreviewView ()<UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, strong, readonly) UICollectionView *collectionView;

@end

@implementation CYVideoPlayerPreviewView
@synthesize collectionView = _collectionView;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    [self _previewSetupView];
    return self;
}

- (void)setPreviewImages:(NSArray<CYVideoPreviewModel *> *)previewImages {
    _previewImages = previewImages;
    [_collectionView reloadData];
}

- (void)setPreviewFrames:(NSArray<CYVideoFrame *> *)previewFrames
{
    _previewFrames = previewFrames;
    [_collectionView reloadData];
}

- (void)setHidden:(BOOL)hidden {
    if ( hidden == self.isHidden ) return;
    if ( !hidden ) {
        self.alpha = 1;
        self.transform = CGAffineTransformIdentity;
    }
    else {
        self.alpha = 0.001;
        self.transform = CGAffineTransformMakeScale(1, 0.001);
    }
}

- (BOOL)isHidden {
    return self.alpha != 1;
}

#pragma mark

- (void)_previewSetupView {
    [self.containerView addSubview:self.collectionView];
    [_collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(_collectionView.superview);
    }];
}

- (UICollectionView *)collectionView {
    if ( _collectionView ) return _collectionView;
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.backgroundColor = [UIColor clearColor];
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    [_collectionView registerClass:NSClassFromString(CYVideoPlayerPreviewCollectionViewCellID) forCellWithReuseIdentifier:CYVideoPlayerPreviewCollectionViewCellID];
    return _collectionView;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if (_previewImages)
    {
        return _previewImages.count;
    }
    else
    {
        return _previewFrames.count;
    }
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CYVideoPlayerPreviewCollectionViewCellID forIndexPath:indexPath];
    if (_previewImages.count)
    {
        [cell setValue:_previewImages[indexPath.item] forKey:@"model"];
    }
    else
    {
        [cell setValue:_previewFrames[indexPath.item] forKey:@"videoFrame"];
    }
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (_previewImages.count)
    {
        CGSize imageSize = _previewImages.firstObject.image.size;
        CGFloat rate = imageSize.width / imageSize.height;
        CGFloat height = _collectionView.frame.size.height - 16;
        CGFloat width = rate * height;
        return CGSizeMake(width, height);
    }
    else
    {
        CGSize imageSize = CGSizeMake(_previewFrames.firstObject.width, _previewFrames.firstObject.height);
        CGFloat rate = imageSize.width / imageSize.height;
        CGFloat height = _collectionView.frame.size.height - 16;
        CGFloat width = rate * height;
        return CGSizeMake(width, height);
    }
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(8, 8, 8, 8);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 8;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 0;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (_previewImages.count)
    {
        if ( ![self.delegate respondsToSelector:@selector(previewView:didSelectItem:)] ) return;
        [self.delegate previewView:self didSelectItem:_previewImages[indexPath.item]];
    }
    else
    {
        if ( ![self.delegate respondsToSelector:@selector(previewView:didSelectFrame:)] ) return;
        [self.delegate previewView:self didSelectFrame:_previewFrames[indexPath.item]];
    }
    
}

@end
