//
//  UIScrollView+ZFPlayer.m
//  ZFPlayer
//
// Copyright (c) 2016年 任子丰 ( http://github.com/renzifeng )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "UIScrollView+ZFPlayer.h"
#import <objc/runtime.h>
#import "ZFReachabilityManager.h"
#import "ZFPlayer.h"
#import "ZFKVOController.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wdeprecated-declarations"

UIKIT_STATIC_INLINE void Hook_Method(Class originalClass, SEL originalSel, Class replacedClass, SEL replacedSel, SEL noneSel){
    Method originalMethod = class_getInstanceMethod(originalClass, originalSel);
    Method replacedMethod = class_getInstanceMethod(replacedClass, replacedSel);
    if (!originalMethod) {
        Method noneMethod = class_getInstanceMethod(replacedClass, noneSel);
        class_addMethod(originalClass, originalSel, method_getImplementation(noneMethod), method_getTypeEncoding(noneMethod));
        return;
    }
    BOOL addMethod = class_addMethod(originalClass, replacedSel, method_getImplementation(replacedMethod), method_getTypeEncoding(replacedMethod));
    if (addMethod) {
        /// 如果父类实现，但是当前类未实就崩溃。以下两行的代码是把当前类加进去这个方法，并取到当前类的originalMethod。
        /// The following two lines of code add the current class to the method and take it to the originalMethod of the current class if the superclass implements it, but the current class fails to implement it.
        class_addMethod(originalClass, originalSel, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        Method originalMethod = class_getInstanceMethod(originalClass, originalSel);
        Method newMethod = class_getInstanceMethod(originalClass, replacedSel);
        method_exchangeImplementations(originalMethod, newMethod);
    }
}

@interface UIScrollView ()

@property (nonatomic, assign) CGFloat zf_lastOffsetY;

@property (nonatomic, assign) CGFloat zf_lastOffsetX;

@end

@implementation UIScrollView (ZFPlayer)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL selectors[] = {
            @selector(setDelegate:)
        };
        for (NSInteger index = 0; index < (NSInteger)(sizeof(selectors) / sizeof(SEL)); ++index) {
            SEL originalSelector = selectors[index];
            SEL swizzledSelector = NSSelectorFromString([@"zf_" stringByAppendingString:NSStringFromSelector(originalSelector)]);
            Method originalMethod = class_getInstanceMethod(self, originalSelector);
            Method swizzledMethod = class_getInstanceMethod(self, swizzledSelector);
            if (class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
                class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
            } else {
                method_exchangeImplementations(originalMethod, swizzledMethod);
            }
        }
    });
}

- (void)zf_setDelegate:(id<UIScrollViewDelegate>)delegate {
    if (([self isKindOfClass:[UITableView class]] || [self isKindOfClass:[UICollectionView class]]) && [delegate conformsToProtocol:@protocol(UIScrollViewDelegate)]) {
        SEL originalSelectors[] = {
            @selector(scrollViewDidEndDecelerating:),
            @selector(scrollViewDidEndDragging:willDecelerate:),
            @selector(scrollViewDidScrollToTop:),
            @selector(scrollViewWillBeginDragging:),
            @selector(scrollViewDidScroll:)
        };
        
        SEL replacedSelectors[] = {
            @selector(zf_scrollViewDidEndDecelerating:),
            @selector(zf_scrollViewDidEndDragging:willDecelerate:),
            @selector(zf_scrollViewDidScrollToTop:),
            @selector(zf_scrollViewWillBeginDragging:),
            @selector(zf_scrollViewDidScroll:)
        };
        
        SEL noneSelectors[] = {
            @selector(add_scrollViewDidEndDecelerating:),
            @selector(add_scrollViewDidEndDragging:willDecelerate:),
            @selector(add_scrollViewDidScrollToTop:),
            @selector(add_scrollViewWillBeginDragging:),
            @selector(add_scrollViewDidScroll:)
        };
        
        for (NSInteger index = 0; index < (NSInteger)(sizeof(originalSelectors) / sizeof(SEL)); ++index) {
            Hook_Method([delegate class], originalSelectors[index], [self class], replacedSelectors[index], noneSelectors[index]);
        }
    }
    [self zf_setDelegate:delegate];
}

#pragma mark - Replace_Method

- (void)zf_scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [scrollView add_scrollViewDidEndDecelerating:scrollView];
    [self zf_scrollViewDidEndDecelerating:scrollView];
}

- (void)zf_scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [scrollView add_scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
    [self zf_scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
}

- (void)zf_scrollViewDidScrollToTop:(UIScrollView *)scrollView {
    [scrollView add_scrollViewDidScrollToTop:scrollView];
    [self zf_scrollViewDidScrollToTop:scrollView];
}

- (void)zf_scrollViewDidScroll:(UIScrollView *)scrollView {
    [scrollView add_scrollViewDidScroll:scrollView];
    [self zf_scrollViewDidScroll:scrollView];
}

- (void)zf_scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [scrollView add_scrollViewWillBeginDragging:scrollView];
    [self zf_scrollViewWillBeginDragging:scrollView];
}

#pragma mark - Add_Method

- (void)add_scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    BOOL scrollToScrollStop = !scrollView.tracking && !scrollView.dragging && !scrollView.decelerating;
    if (scrollToScrollStop) {
        [scrollView zf_scrollViewDidStopScroll];
    }
}

- (void)add_scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        BOOL dragToDragStop = scrollView.tracking && !scrollView.dragging && !scrollView.decelerating;
        if (dragToDragStop) {
            [scrollView zf_scrollViewDidStopScroll];
        }
    }
}

- (void)add_scrollViewDidScrollToTop:(UIScrollView *)scrollView {
    [scrollView zf_scrollViewDidStopScroll];
}

- (void)add_scrollViewDidScroll:(UIScrollView *)scrollView {
    [scrollView scrollViewScrolling];
}

- (void)add_scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [scrollView scrollViewBeginDragging];
}

#pragma mark - scrollView did stop scroll

- (void)zf_scrollViewDidStopScroll {
    if (!self.zf_enableScrollHook) return;
    @weakify(self)
    [self zf_filterShouldPlayCellWhileScrolled:^(NSIndexPath * _Nonnull indexPath) {
        @strongify(self)
        if (self.zf_scrollViewDidStopScrollCallback) self.zf_scrollViewDidStopScrollCallback(indexPath);
        if (self.scrollViewDidStopScroll) self.scrollViewDidStopScroll(indexPath);
    }];
}

- (void)scrollViewBeginDragging {
    if (!self.zf_enableScrollHook) return;
    self.zf_lastOffsetY = self.contentOffset.y;
    self.zf_lastOffsetX = self.contentOffset.x;
}

- (void)scrollViewScrolling {
    
    if (!self.zf_enableScrollHook) return;

    CGFloat offsetY = self.contentOffset.y;
    CGFloat offsetX = self.contentOffset.x;
    if (offsetY - self.zf_lastOffsetY > 0) {
        self.zf_scrollDerection = ZFPlayerScrollDerectionUp;
    } else if (offsetY - self.zf_lastOffsetY < 0) {
        self.zf_scrollDerection = ZFPlayerScrollDerectionDown;
    } else if (offsetX - self.zf_lastOffsetX > 0) {
        self.zf_scrollDerection = ZFPlayerScrollDerectionLeft;
    } else if (offsetX - self.zf_lastOffsetX < 0) {
        self.zf_scrollDerection = ZFPlayerScrollDerectionRight;
    }
    self.zf_lastOffsetY = offsetY;
    self.zf_lastOffsetX = offsetX;
    // Avoid being paused the first time you play it.
    if (self.contentOffset.y < 0) return;
    if (self.contentOffset.x < 0) return;
    if (self.zf_playingIndexPath) {
        UIView *cell = [self zf_getCellForIndexPath:self.zf_playingIndexPath];
        if (!cell) {
            if (self.zf_playerDidDisappearInScrollView) self.zf_playerDidDisappearInScrollView(self.zf_playingIndexPath);
            return;
        }
        UIView *playerView = [cell viewWithTag:self.zf_containerViewTag];
        CGRect rect1 = [playerView convertRect:playerView.frame toView:self];
        CGRect rect = [self convertRect:rect1 toView:self.superview];
        /// playerView top to scrollView top space.
        CGFloat topSpacing = CGRectGetMinY(rect) - CGRectGetMinY(self.frame) - CGRectGetMinY(playerView.frame) - self.contentInset.top;
        /// playerView bottom to scrollView bottom space.
        CGFloat bottomSpacing = CGRectGetMaxY(self.frame) - CGRectGetMaxY(rect) + CGRectGetMinY(playerView.frame) - self.contentInset.bottom;
        /// playerView Left to scrollView top space.
        CGFloat leftSpacing = CGRectGetMinX(rect) - CGRectGetMinX(self.frame) - CGRectGetMinX(playerView.frame) - self.contentInset.left;
        /// playerView Right to scrollView bottom space.
        CGFloat rightSpacing = CGRectGetMaxX(self.frame) - CGRectGetMaxX(rect) + CGRectGetMinX(playerView.frame) - self.contentInset.right;
        /// The height of the content area.
        CGFloat contentInsetHeight = CGRectGetMaxY(self.frame) - CGRectGetMinY(self.frame) - self.contentInset.top - self.contentInset.bottom;
        /// The width of the content area.
        CGFloat contentInsetWidth = CGRectGetMaxX(self.frame) - CGRectGetMinX(self.frame) - self.contentInset.left - self.contentInset.right;
        
        CGFloat playerDisapperaPercent = 0;
        CGFloat playerApperaPercent = 0;

        if (self.zf_scrollDerection == ZFPlayerScrollDerectionUp) { /// Scroll up
            /// Player is disappearing.
            if (topSpacing <= 0 && CGRectGetHeight(rect) != 0) {
                playerDisapperaPercent = -topSpacing/CGRectGetHeight(rect);
                if (playerDisapperaPercent > 1.0) playerDisapperaPercent = 1.0;
                if (self.zf_playerDisappearingInScrollView) self.zf_playerDisappearingInScrollView(self.zf_playingIndexPath, playerDisapperaPercent);
            }
            /// Top area
            if (topSpacing <= 0 && topSpacing > -CGRectGetHeight(rect)/2) {
                /// When the player will disappear.
                if (self.zf_playerWillDisappearInScrollView) self.zf_playerWillDisappearInScrollView(self.zf_playingIndexPath);
            } else if (topSpacing <= -CGRectGetHeight(rect)) {
                /// When the player did disappeared.
                if (self.zf_playerDidDisappearInScrollView) self.zf_playerDidDisappearInScrollView(self.zf_playingIndexPath);
            } else if (topSpacing > 0 && topSpacing <= contentInsetHeight) {
                /// Player is appearing.
                if (CGRectGetHeight(rect) != 0) {
                    playerApperaPercent = -(topSpacing-contentInsetHeight)/CGRectGetHeight(rect);
                    if (playerApperaPercent > 1.0) playerApperaPercent = 1.0;
                    if (self.zf_playerAppearingInScrollView) self.zf_playerAppearingInScrollView(self.zf_playingIndexPath, playerApperaPercent);
                }
                /// In visable area
                if (topSpacing <= contentInsetHeight && topSpacing > contentInsetHeight-CGRectGetHeight(rect)/2) {
                    /// When the player will appear.
                    if (self.zf_playerWillAppearInScrollView) self.zf_playerWillAppearInScrollView(self.zf_playingIndexPath);
                } else {
                    /// When the player did appeared.
                    if (self.zf_playerDidAppearInScrollView) self.zf_playerDidAppearInScrollView(self.zf_playingIndexPath);
                }
            }
            
        } else if (self.zf_scrollDerection == ZFPlayerScrollDerectionDown) { /// Scroll Down
            /// Player is disappearing.
            if (bottomSpacing <= 0 && CGRectGetHeight(rect) != 0) {
                playerDisapperaPercent = -bottomSpacing/CGRectGetHeight(rect);
                if (playerDisapperaPercent > 1.0) playerDisapperaPercent = 1.0;
                if (self.zf_playerDisappearingInScrollView) self.zf_playerDisappearingInScrollView(self.zf_playingIndexPath, playerDisapperaPercent);
            }
            
            /// Bottom area
            if (bottomSpacing <= 0 && bottomSpacing > -CGRectGetHeight(rect)/2) {
                /// When the player will disappear.
                if (self.zf_playerWillDisappearInScrollView) self.zf_playerWillDisappearInScrollView(self.zf_playingIndexPath);
            } else if (bottomSpacing <= -CGRectGetHeight(rect)) {
                /// When the player did disappeared.
                if (self.zf_playerDidDisappearInScrollView) self.zf_playerDidDisappearInScrollView(self.zf_playingIndexPath);
            } else if (bottomSpacing > 0 && bottomSpacing <= contentInsetHeight) {
                /// Player is appearing.
                if (CGRectGetHeight(rect) != 0) {
                    playerApperaPercent = -(bottomSpacing-contentInsetHeight)/CGRectGetHeight(rect);
                    if (playerApperaPercent > 1.0) playerApperaPercent = 1.0;
                    if (self.zf_playerAppearingInScrollView) self.zf_playerAppearingInScrollView(self.zf_playingIndexPath, playerApperaPercent);
                }
                /// In visable area
                if (bottomSpacing <= contentInsetHeight && bottomSpacing > contentInsetHeight-CGRectGetHeight(rect)/2) {
                    /// When the player will appear.
                    if (self.zf_playerWillAppearInScrollView) self.zf_playerWillAppearInScrollView(self.zf_playingIndexPath);
                } else {
                    /// When the player did appeared.
                    if (self.zf_playerDidAppearInScrollView) self.zf_playerDidAppearInScrollView(self.zf_playingIndexPath);
                }
            }
        } else if (self.zf_scrollDerection == ZFPlayerScrollDerectionLeft) { /// Scroll left
            /// Player is disappearing.
            if (leftSpacing <= 0 && CGRectGetWidth(rect) != 0) {
                playerDisapperaPercent = -leftSpacing/CGRectGetWidth(rect);
                if (playerDisapperaPercent > 1.0) playerDisapperaPercent = 1.0;
                if (self.zf_playerDisappearingInScrollView) self.zf_playerDisappearingInScrollView(self.zf_playingIndexPath, playerDisapperaPercent);
            }
            /// Left area
            if (leftSpacing <= 0 && leftSpacing > -CGRectGetWidth(rect)/2) {
                /// When the player will disappear.
                if (self.zf_playerWillDisappearInScrollView) self.zf_playerWillDisappearInScrollView(self.zf_playingIndexPath);
            } else if (leftSpacing <= -CGRectGetWidth(rect)) {
                /// When the player did disappeared.
                if (self.zf_playerDidDisappearInScrollView) self.zf_playerDidDisappearInScrollView(self.zf_playingIndexPath);
            } else if (leftSpacing > 0 && leftSpacing <= contentInsetWidth) {
                /// Player is appearing.
                if (CGRectGetWidth(rect) != 0) {
                    playerApperaPercent = -(leftSpacing-contentInsetWidth)/CGRectGetWidth(rect);
                    if (playerApperaPercent > 1.0) playerApperaPercent = 1.0;
                    if (self.zf_playerAppearingInScrollView) self.zf_playerAppearingInScrollView(self.zf_playingIndexPath, playerApperaPercent);
                }
                /// In visable area
                if (leftSpacing <= contentInsetWidth && leftSpacing > contentInsetWidth-CGRectGetWidth(rect)/2) {
                    /// When the player will appear.
                    if (self.zf_playerWillAppearInScrollView) self.zf_playerWillAppearInScrollView(self.zf_playingIndexPath);
                } else {
                    /// When the player did appeared.
                    if (self.zf_playerDidAppearInScrollView) self.zf_playerDidAppearInScrollView(self.zf_playingIndexPath);
                }
            }
            
        } else if (self.zf_scrollDerection == ZFPlayerScrollDerectionRight) { /// Scroll right
            /// Player is disappearing.
            if (rightSpacing <= 0 && CGRectGetWidth(rect) != 0) {
                playerDisapperaPercent = -rightSpacing/CGRectGetWidth(rect);
                if (playerDisapperaPercent > 1.0) playerDisapperaPercent = 1.0;
                if (self.zf_playerDisappearingInScrollView) self.zf_playerDisappearingInScrollView(self.zf_playingIndexPath, playerDisapperaPercent);
            }
            
            /// right area
            if (rightSpacing <= 0 && rightSpacing > -CGRectGetWidth(rect)/2) {
                /// When the player will disappear.
                if (self.zf_playerWillDisappearInScrollView) self.zf_playerWillDisappearInScrollView(self.zf_playingIndexPath);
            } else if (rightSpacing <= -CGRectGetWidth(rect)) {
                /// When the player did disappeared.
                if (self.zf_playerDidDisappearInScrollView) self.zf_playerDidDisappearInScrollView(self.zf_playingIndexPath);
            } else if (rightSpacing > 0 && rightSpacing <= contentInsetWidth) {
                /// Player is appearing.
                if (CGRectGetWidth(rect) != 0) {
                    playerApperaPercent = -(rightSpacing-contentInsetWidth)/CGRectGetWidth(rect);
                    if (playerApperaPercent > 1.0) playerApperaPercent = 1.0;
                    if (self.zf_playerAppearingInScrollView) self.zf_playerAppearingInScrollView(self.zf_playingIndexPath, playerApperaPercent);
                }
                /// In visable area
                if (rightSpacing <= contentInsetWidth && rightSpacing > contentInsetWidth-CGRectGetWidth(rect)/2) {
                    /// When the player will appear.
                    if (self.zf_playerWillAppearInScrollView) self.zf_playerWillAppearInScrollView(self.zf_playingIndexPath);
                } else {
                    /// When the player did appeared.
                    if (self.zf_playerDidAppearInScrollView) self.zf_playerDidAppearInScrollView(self.zf_playingIndexPath);
                }
            }
        }
    }
}

- (void)zf_filterShouldPlayCellWhileScrolling:(void (^ __nullable)(NSIndexPath *indexPath))handler {
    if (!self.zf_shouldAutoPlay) return;
    NSArray *visiableCells = nil;
    NSIndexPath *indexPath = nil;
    if ([self isKindOfClass:[UITableView class]]) {
        UITableView *tableView = (UITableView *)self;
        visiableCells = [tableView visibleCells];
        // Top
        indexPath = tableView.indexPathsForVisibleRows.firstObject;
        if (self.contentOffset.y <= 0 && (!self.zf_playingIndexPath || [indexPath compare:self.zf_playingIndexPath] == NSOrderedSame)) {
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            UIView *playerView = [cell viewWithTag:self.zf_containerViewTag];
            if (playerView) {
                if (handler) handler(indexPath);
                self.zf_shouldPlayIndexPath = indexPath;
                return;
            }
        }
        
        // Bottom
        indexPath = tableView.indexPathsForVisibleRows.lastObject;
        if (self.contentOffset.y + self.frame.size.height >= self.contentSize.height && (!self.zf_playingIndexPath || [indexPath compare:self.zf_playingIndexPath] == NSOrderedSame)) {
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            UIView *playerView = [cell viewWithTag:self.zf_containerViewTag];
            if (playerView) {
                if (handler) handler(indexPath);
                self.zf_shouldPlayIndexPath = indexPath;
                return;
            }
        }
    } else if ([self isKindOfClass:[UICollectionView class]]) {
        NSInteger contentOffSet = (((NSInteger)self.contentOffset.x) % ((NSInteger)self.frame.size.width));
        NSIndexPath *finalIndexPath;
        if (contentOffSet > ((NSInteger)(self.frame.size.width/2))) {
            finalIndexPath = [NSIndexPath indexPathForRow:((NSInteger)self.contentOffset.x / (NSInteger)self.frame.size.width) + 1 inSection:0];
        } else if (contentOffSet <= ((NSInteger)(self.frame.size.width/2))) {
            finalIndexPath = [NSIndexPath indexPathForRow:((NSInteger)self.contentOffset.x / (NSInteger)self.frame.size.width) inSection:0];
        }
        UICollectionViewCell *cell = [(UICollectionView *)self cellForItemAtIndexPath:finalIndexPath];
        UIView *playerView = [cell viewWithTag:self.zf_containerViewTag];
        if (playerView) {
            if (handler) handler(finalIndexPath);
            self.zf_shouldPlayIndexPath = finalIndexPath;
            return;
        }
    }
    
}

- (void)zf_filterShouldPlayCellWhileScrolled:(void (^ __nullable)(NSIndexPath *indexPath))handler {
    if (!self.zf_shouldAutoPlay) return;
    @weakify(self)
    [self zf_filterShouldPlayCellWhileScrolling:^(NSIndexPath *indexPath) {
        @strongify(self)
        if ([ZFReachabilityManager sharedManager].isReachableViaWWAN && !self.zf_WWANAutoPlay) {
            /// 移动网络
            self.zf_shouldPlayIndexPath = indexPath;
            return;
        }
        if (!self.zf_playingIndexPath) {
            if (handler) handler(indexPath);
            self.zf_playingIndexPath = indexPath;
        }
    }];
}

- (UIView *)zf_getCellForIndexPath:(NSIndexPath *)indexPath {
    if ([self isKindOfClass:[UITableView class]]) {
        UITableView *tableView = (UITableView *)self;
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        return cell;
    } else if ([self isKindOfClass:[UICollectionView class]]) {
        UICollectionView *collectionView = (UICollectionView *)self;
        UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
        return cell;
    }
    return nil;
}

- (NSIndexPath *)zf_getIndexPathForCell:(UIView *)cell {
    if ([self isKindOfClass:[UITableView class]]) {
        UITableView *tableView = (UITableView *)self;
        NSIndexPath *indexPath = [tableView indexPathForCell:(UITableViewCell *)cell];
        return indexPath;
    } else if ([self isKindOfClass:[UICollectionView class]]) {
        UICollectionView *collectionView = (UICollectionView *)self;
        NSIndexPath *indexPath = [collectionView indexPathForCell:(UICollectionViewCell *)cell];
        return indexPath;
    }
    return nil;
}

- (void)zf_scrollToRowAtIndexPath:(NSIndexPath *)indexPath completionHandler:(void (^ __nullable)(void))completionHandler {
    [UIView animateWithDuration:0.6 animations:^{
        if ([self isKindOfClass:[UITableView class]]) {
            UITableView *tableView = (UITableView *)self;
            [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
        } else if ([self isKindOfClass:[UICollectionView class]]) {
            UICollectionView *collectionView = (UICollectionView *)self;
            [collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionTop animated:NO];
        }
    } completion:^(BOOL finished) {
        if (completionHandler) completionHandler();
    }];
}

#pragma mark - getter

- (BOOL)zf_enableScrollHook {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (NSIndexPath *)zf_playingIndexPath {
    return objc_getAssociatedObject(self, _cmd);
}

- (NSIndexPath *)zf_shouldPlayIndexPath {
    return objc_getAssociatedObject(self, _cmd);
}

- (NSInteger)zf_containerViewTag {
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

- (ZFPlayerScrollDerection)zf_scrollDerection {
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

- (BOOL)zf_stopWhileNotVisible {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (BOOL)zf_isWWANAutoPlay {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (BOOL)zf_shouldAutoPlay {
    NSNumber *number = objc_getAssociatedObject(self, _cmd);
    if (number) return number.boolValue;
    self.zf_shouldAutoPlay = YES;
    return YES;
}

- (CGFloat)zf_lastOffsetY {
    return [objc_getAssociatedObject(self, _cmd) floatValue];
}

- (CGFloat)zf_lastOffsetX {
    return [objc_getAssociatedObject(self, _cmd) floatValue];
}

- (void (^)(NSIndexPath * _Nonnull))zf_scrollViewDidStopScrollCallback {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))zf_shouldPlayIndexPathCallback {
    return objc_getAssociatedObject(self, _cmd);
}

#pragma mark - setter

- (void)setZf_enableScrollHook:(BOOL)zf_enableScrollHook {
    objc_setAssociatedObject(self, @selector(zf_enableScrollHook), @(zf_enableScrollHook), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_playingIndexPath:(NSIndexPath *)zf_playingIndexPath {
    objc_setAssociatedObject(self, @selector(zf_playingIndexPath), zf_playingIndexPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (zf_playingIndexPath) self.zf_shouldPlayIndexPath = zf_playingIndexPath;
}

- (void)setZf_shouldPlayIndexPath:(NSIndexPath *)zf_shouldPlayIndexPath {
    if (self.zf_shouldPlayIndexPathCallback) self.zf_shouldPlayIndexPathCallback(zf_shouldPlayIndexPath);
    objc_setAssociatedObject(self, @selector(zf_shouldPlayIndexPath), zf_shouldPlayIndexPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.shouldPlayIndexPath = zf_shouldPlayIndexPath;
}

- (void)setZf_containerViewTag:(NSInteger)zf_containerViewTag {
    objc_setAssociatedObject(self, @selector(zf_containerViewTag), @(zf_containerViewTag), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_scrollDerection:(ZFPlayerScrollDerection)zf_scrollDerection {
    objc_setAssociatedObject(self, @selector(zf_scrollDerection), @(zf_scrollDerection), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_stopWhileNotVisible:(BOOL)zf_stopWhileNotVisible {
    objc_setAssociatedObject(self, @selector(zf_stopWhileNotVisible), @(zf_stopWhileNotVisible), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_WWANAutoPlay:(BOOL)zf_WWANAutoPlay {
    objc_setAssociatedObject(self, @selector(zf_isWWANAutoPlay), @(zf_WWANAutoPlay), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_shouldAutoPlay:(BOOL)zf_shouldAutoPlay {
    objc_setAssociatedObject(self, @selector(zf_shouldAutoPlay), @(zf_shouldAutoPlay), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_lastOffsetY:(CGFloat)zf_lastOffsetY {
    objc_setAssociatedObject(self, @selector(zf_lastOffsetY), @(zf_lastOffsetY), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_lastOffsetX:(CGFloat)zf_lastOffsetX {
    objc_setAssociatedObject(self, @selector(zf_lastOffsetX), @(zf_lastOffsetX), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_scrollViewDidStopScrollCallback:(void (^)(NSIndexPath * _Nonnull))zf_scrollViewDidStopScrollCallback {
    objc_setAssociatedObject(self, @selector(zf_scrollViewDidStopScrollCallback), zf_scrollViewDidStopScrollCallback, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_shouldPlayIndexPathCallback:(void (^)(NSIndexPath * _Nonnull))zf_shouldPlayIndexPathCallback {
    objc_setAssociatedObject(self, @selector(zf_shouldPlayIndexPathCallback), zf_shouldPlayIndexPathCallback, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

@implementation UIScrollView (ZFPlayerCannotCalled)

#pragma mark - getter

- (void (^)(NSIndexPath * _Nonnull, CGFloat))zf_playerDisappearingInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull, CGFloat))zf_playerAppearingInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))zf_playerDidAppearInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))zf_playerWillDisappearInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))zf_playerWillAppearInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))zf_playerDidDisappearInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

#pragma mark - setter

- (void)setZf_playerDisappearingInScrollView:(void (^)(NSIndexPath * _Nonnull, CGFloat))zf_playerDisappearingInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerDisappearingInScrollView), zf_playerDisappearingInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerAppearingInScrollView:(void (^)(NSIndexPath * _Nonnull, CGFloat))zf_playerAppearingInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerAppearingInScrollView), zf_playerAppearingInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerDidAppearInScrollView:(void (^)(NSIndexPath * _Nonnull))zf_playerDidAppearInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerDidAppearInScrollView), zf_playerDidAppearInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerWillDisappearInScrollView:(void (^)(NSIndexPath * _Nonnull))zf_playerWillDisappearInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerWillDisappearInScrollView), zf_playerWillDisappearInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerWillAppearInScrollView:(void (^)(NSIndexPath * _Nonnull))zf_playerWillAppearInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerWillAppearInScrollView), zf_playerWillAppearInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerDidDisappearInScrollView:(void (^)(NSIndexPath * _Nonnull))zf_playerDidDisappearInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerDidDisappearInScrollView), zf_playerDidDisappearInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

@implementation UIScrollView (ZFPlayerDeprecated)

#pragma mark - getter

- (NSIndexPath *)shouldPlayIndexPath {
     return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))scrollViewDidStopScroll {
     return objc_getAssociatedObject(self, _cmd);
}

#pragma mark - setter

- (void)setShouldPlayIndexPath:(NSIndexPath *)shouldPlayIndexPath {
    objc_setAssociatedObject(self, @selector(shouldPlayIndexPath), shouldPlayIndexPath, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setScrollViewDidStopScroll:(void (^)(NSIndexPath * _Nonnull))scrollViewDidStopScroll {
    objc_setAssociatedObject(self, @selector(scrollViewDidStopScroll), scrollViewDidStopScroll, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

