//
//  FCProgressHUD.m
//  FCProgressHUD
//
//  Created by 凡小超 on 16/9/24.
//  Copyright © 2016年 凡小超. All rights reserved.
//

#import "FCProgressHUD.h"
#import <tgmath.h>


/**为了兼容ios sdk老版本*/
#ifndef  kCFCoreFoundationVersionNumber_iOS_7_0
     #define kCFCoreFoundationVersionNumber_iOS_7_0 847.20
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_8_0
     #define kCFCoreFoundationVersionNumber_iOS_8_0  1129.15
#endif


#define FCMainThreadAssert()  NSAssert([NSThread isMainThread],@"MBProgressHUD needs to be accessed on the main thread.")


CGFloat  const  FCProgressMaxOffset  =  1000000.f;

static  const  CGFloat FCDefaultPadding  = 4.f;
static  const  CGFloat FCDefaultLabelFontSize = 16.f;
static  const  CGFloat FCDefaultDetailisLabelFontSize = 12.f;



@interface FCProgressHUDRoundedButton : UIButton

@end

@implementation FCProgressHUDRoundedButton

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
    self   = [super initWithFrame:frame];
    if (self) {
        CALayer *layer  = self.layer;
        layer.borderWidth  = 1.f;
    }
    return self;
}


#pragma mark - Layout
- (void)layoutSubviews
{
    [super layoutSubviews];
    //全圆角
    CGFloat  height = CGRectGetHeight(self.bounds);
    self.layer.cornerRadius = ceil(height/2.f);
}

- (CGSize)intrinsicContentSize
{
    //如果我们有controlevents才展示
    if (self.allControlEvents == 0) return CGSizeZero;
    CGSize size  = [super intrinsicContentSize];
    //添加一些侧边填充
    size.width += 20.f;
    return size;
}

#pragma mark - Color
- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state
{
    [super setTitleColor:color forState:state];
    
    [self  setHighlighted:self.highlighted];
    self.layer.borderColor = color.CGColor;
}

- (void) setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    UIColor *baseColor = [self titleColorForState:UIControlStateSelected];
    self.backgroundColor = highlighted ? [baseColor colorWithAlphaComponent:0.1f] :[UIColor clearColor];
}
@end
@interface FCProgressHUD ()
{
    //Deprecated
    UIColor  *_activityIndicatorColor;
    CGFloat _opacity;
}


@property (nonatomic, assign) BOOL useAnimation;
@property (nonatomic, assign, getter=hasFinished) BOOL finished;
@property (nonatomic, strong) UIView *indicator;
@property (nonatomic, strong) NSDate *showStarted;
@property (nonatomic, strong) NSArray *paddingConstrains;
@property (nonatomic, strong) NSArray *bezelConstraints;
@property (nonatomic, strong) UIView *topSpacer;
@property (nonatomic, strong) UIView *bottomSpacer;
@property (nonatomic, weak) NSTimer *graceTimer;
@property (nonatomic, weak) NSTimer *minShowTimer;
@property (nonatomic, weak) NSTimer *hideDelayTimer;


//Deprecated
@property (assign) BOOL taskInProgress;

@end





@implementation FCProgressHUD

#pragma mark - Class methods
+(instancetype)showHUDAddedTo:(UIView *)view animated:(BOOL)animated
{
    FCProgressHUD  *hud = [[self alloc]initWithView:view];
    hud.removeFromSuperViewOnHide =  YES;
    [view addSubview:hud];
    [hud showAnimated:animated];
    return hud;
}

+(BOOL)hideHUDForView:(UIView *)view animated:(BOOL)animated
{
    FCProgressHUD  *hud = [self HUDForView:view];
    if (hud != nil) {
        hud.removeFromSuperViewOnHide = YES;
        [hud  hideAnimated:animated];
        return YES;
    }
    return NO;
}

+ (FCProgressHUD *)HUDForView:(UIView *)view
{
    NSEnumerator  *subviewsEnum = [view.subviews reverseObjectEnumerator];
    for (UIView *subview in subviewsEnum) {
        if ([subview  isKindOfClass:self]) {
            return (FCProgressHUD *)subview;
        }
    }
    return  nil;
}

#pragma mark  - Lifecycle
- (void)commonInit{
     //set属性的默认值
    _animationType =  FCProgressHUDAnimationFade;
    _mode  =  FCProgressHUDModeIndeterminate;
    _margin = 20;
    _opacity = 1.f;
    _defaultMotionEffectsEnabled = YES;
    
    //默认颜色 取决于当前ios的系统版本
    BOOL  isLegacy  =  kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0;
    _contentColor = isLegacy ? [UIColor whiteColor] : [UIColor colorWithWhite:0.f alpha:0.7f];
    //透明背景 (opaque : 不透明)
    self.opaque  = NO;
    self.backgroundColor = [UIColor clearColor];
    //make it invisible for now
    self.alpha = 0.0f;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    //CALayer的allowsGroupOpacity属性，UIView 的alpha属性等同于 CALayer opacity属性。GroupOpacity=YES，子 layer 在视觉上的透明度的上限是其父 layer 的opacity。当父视图的layer.opacity != 1.0时，会开启离屏渲染。
//    layer.opacity == 1.0时，父视图不用管子视图，只需显示当前视图即可。
    self.layer.allowsGroupOpacity = NO;
    
    [self  setupViews];
    [self  updateIndicators];
    [self  registerForNotifications];
}
- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self commonInit];
    }
    return self;
}

- (id)initWithView:(UIView *)view
{
    NSAssert(view, @"View must not be nil");
    return [self  initWithFrame:view.bounds];

}
- (void)dealloc
{
    [self  unregisterFromNotifications];
}
#pragma mark - Show & hide
- (void)showAnimated:(BOOL)animated
{
    FCMainThreadAssert();
    [self.minShowTimer invalidate];
    self.useAnimation = animated;
    self.finished= NO;
    
    //如果 grace time设置了，延迟HUD展示
    if (self.graceTime) {
        NSTimer  *timer  = [NSTimer timerWithTimeInterval:self.graceTime target:self selector:@selector(handleGraceTimer:) userInfo:nil repeats:NO];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        self.graceTimer = timer;
    }
    //否则立刻展示hud
    else{
        [self showUsingAnimation:(BOOL)animated];
    }
}

- (void)hideAnimated:(BOOL)animated
{
    FCMainThreadAssert();
    [self.graceTimer invalidate];
    self.useAnimation  = animated;
    self.finished = YES;
    
    //如果设置了展示的最小时间，计算hud将被展示多久
    //如果必须的话将延迟这个正在隐藏的操作
    if (self.minShowTime > 0.0 && self.showStarted) {
        NSTimeInterval interv = [[NSDate  date] timeIntervalSinceDate:self.showStarted];
        if (interv < self.minShowTime) {
            NSTimer *timer = [NSTimer timerWithTimeInterval:self.minShowTime - interv target:self selector:@selector(handleMinShowTimer:) userInfo:nil repeats:NO];
            [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
            self.minShowTimer  = timer;
            return;
        }
    }
    //否则立刻隐藏HUD
    [self hideUsingAnimation:self.useAnimation];
}

- (void)hideAnimated:(BOOL)animated afterDeleay:(NSTimeInterval)delay
{
    NSTimer *timer = [NSTimer timerWithTimeInterval:delay target:self selector:@selector(handleHideTimer:) userInfo:@(animated) repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.hideDelayTimer = timer;

}
#pragma mark - Timer callbacks
- (void)handleGraceTimer:(NSTimer *)theTimer
{
     // 只有在任务仍然在执行的时候展示HUD
    if(!self.finished){
        [self  showUsingAnimation:self.useAnimation];
    }
}

- (void)handleMinShowTimer:(NSTimer *)theTimer
{
    [self hideUsingAnimation:self.useAnimation];
}

- (void)handleHideTimer:(NSTimer *)timer
{
    [self hideAnimated:[timer.userInfo boolValue]];
}

#pragma mark - View Hierrarchy
- (void)didMoveToSuperview
{
    [self updateForCurrentOrientationAnimated:NO];
}
#pragma mark - Internal show & hide operations
- (void)showUsingAnimation:(BOOL)animated
{
   //取消一些准备动画
    [self.bezelView.layer  removeAllAnimations];
    [self.backgroundView.layer removeAllAnimations];
    
    //取消一些安排：hideDelayed的调用
    [self.hideDelayTimer invalidate];
    
    self.showStarted  = [NSDate date];
    self.alpha = 1.f;
    
    if (animated) {
        [self animateIn:YES withType:self.animationType completion:NULL];
    }else{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        self.bezelView.alpha = self.opacity;
#pragma clang diagnostic pop
        self.backgroundView.alpha = 1.f;
    }
}

- (void)hideUsingAnimation:(BOOL)animated
{
    if (animated && self.showStarted) {
        self.showStarted = nil;
        [self animateIn:NO withType:self.animationType completion:^(BOOL finished) {
            [self done];
        }];
    }else{
        self.showStarted = nil;
        self.bezelView.alpha = 0.f;
        self.backgroundView.alpha = 1.f;
        [self done];
    }
}
- (void)animateIn:(BOOL)animatingIn withType:(FCProgressHUDAnimation)type completion:(void(^)(BOOL finished))completion
{
     //自动确定正确的缩放动画类型
    if (type == FCProgressHUDAnimationZoom) {
        type  = animatingIn ? FCProgressHUDAnimationZoomIn :FCProgressHUDAnimationZoomOut;
    }
    
    CGAffineTransform  small  = CGAffineTransformMakeScale(0.5f, 0.5f);
    CGAffineTransform  large  = CGAffineTransformMakeScale(1.5f, 1.5f);
    
    //set  starting state
    UIView  *bezelView = self.bezelView;
    if (animatingIn && bezelView.alpha == 0.f && type == FCProgressHUDAnimationZoomIn) {
        bezelView.transform = small;
    }else if (animatingIn && bezelView.alpha == 0.f && type == FCProgressHUDAnimationZoomOut){
        bezelView.transform =  large;
    }
    
    //执行动画
    dispatch_block_t animations = ^{
        if (animatingIn) {
            bezelView.transform = CGAffineTransformIdentity;
        }else if (!animatingIn  && type == FCProgressHUDAnimationZoomIn){
            bezelView.transform = large;
        }else if (!animatingIn && type == FCProgressHUDAnimationZoomOut){
            bezelView.transform = small;
        }
#pragma  clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        bezelView.alpha = animatingIn ? self.opacity : 0.f;
#pragma clang  pop
        self.backgroundView.alpha = animatingIn ? 1.f:0.f;
    };
    
    // 春天的动画是最好的，但仅仅在ios7以上能用
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000 || TARGET_OS_TV
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0) {
        [UIView animateWithDuration:0.3 delay:0. usingSpringWithDamping:1.f initialSpringVelocity:0.f options:UIViewAnimationOptionBeginFromCurrentState animations:animations completion:completion];
        return;
    }
#endif
    [UIView animateWithDuration:0.3 delay:0. options:UIViewAnimationOptionBeginFromCurrentState animations:animations completion:completion];
    
}

- (void)done{
    //取消一些安排好的调用：hideDelayed
    [self.hideDelayTimer  invalidate];
    
    if (self.hasFinished) {
        self.alpha = 0.0f;
        if (self.removeFromSuperViewOnHide) {
            [self removeFromSuperview];
        }
    }

    FCProgressHUDCompletionBlock  completionBlock  = self.completionBlock;
    if (completionBlock) {
        completionBlock();
    }
    
    id<FCProgressHUDDelegate>delegate = self.delegate;
    if ([delegate  respondsToSelector:@selector(hudWasHidden:)]) {
        [delegate performSelector:@selector(hudWasHidden:) withObject:self];
    }
}
#pragma mark - UI
- (void)setupViews{
    UIColor  *defaultColor =  self.contentColor;
    
    FCBackgroundView *backgroundView =   [[FCBackgroundView alloc]initWithFrame:self.bounds];
    backgroundView.style =  FCProgressHUDBackgroundStyleSolidColor;
    backgroundView.backgroundColor = [UIColor clearColor];
    backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    backgroundView.alpha = 0.f;
    [self  addSubview:backgroundView];
    _backgroundView  =  backgroundView;
    
    
    FCBackgroundView *bezelView = [FCBackgroundView new];
    bezelView.translatesAutoresizingMaskIntoConstraints = NO;
    bezelView.layer.cornerRadius = 5.f;
    bezelView.alpha = 0.f;
    [self addSubview:bezelView];
    _bezelView = bezelView;
    [self  updateBezelMotionEffects];
    
    
    UILabel *label = [UILabel new];
    label.adjustsFontSizeToFitWidth = NO;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = defaultColor;
    label.font = [UIFont systemFontOfSize:FCDefaultLabelFontSize];
    label.opaque = NO;
    label.backgroundColor = [UIColor clearColor];
    _label = label;
    
    UILabel *detailsLabel = [UILabel new];
    detailsLabel.adjustsFontSizeToFitWidth = NO;
    detailsLabel.textAlignment = NSTextAlignmentCenter;
    detailsLabel.textColor  = defaultColor;
    detailsLabel.numberOfLines = 0;
    detailsLabel.font = [UIFont boldSystemFontOfSize:FCDefaultDetailisLabelFontSize];
    detailsLabel.opaque = NO;
    detailsLabel.backgroundColor = [UIColor clearColor];
    _detailsLabel = detailsLabel;
    
    UIButton *button = [FCProgressHUDRoundedButton buttonWithType:UIButtonTypeCustom];
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.titleLabel.font = [UIFont boldSystemFontOfSize:FCDefaultDetailisLabelFontSize];
    [button setTitleColor:defaultColor forState:UIControlStateNormal];
    _button = button;
    
    for (UIView *view in @[label,detailsLabel,button]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [view  setContentCompressionResistancePriority:998.f forAxis:UILayoutConstraintAxisHorizontal];
        [view  setContentCompressionResistancePriority:998.f forAxis:UILayoutConstraintAxisVertical];
        [bezelView  addSubview:view];
    }
    
    UIView *topSpacer = [UIView new];
    topSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    topSpacer.hidden = YES;
    [bezelView  addSubview:topSpacer];
    _topSpacer = topSpacer;
    
    UIView *bottomSpacer = [UIView new];
    bottomSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    bottomSpacer.hidden = YES;
    [bezelView  addSubview:bottomSpacer];
    _bottomSpacer = bottomSpacer;
    
}

- (void)updateIndicators
{
    UIView *indicator = self.indicator;
    BOOL  isActivityIndicator =  [indicator isKindOfClass:[UIActivityIndicatorView class]];
    BOOL  isRoundindicator    =  [indicator isKindOfClass:[FCRoundProgressView class]];
    
    FCProgressHUDMode  mode = self.mode;
    if (mode == FCProgressHUDModeIndeterminate) {
        if (!isActivityIndicator) {
            //update to indeterminate indicator
            [indicator  removeFromSuperview];
            indicator = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleWhiteLarge];
            [(UIActivityIndicatorView *)indicator startAnimating];
            [self.bezelView  addSubview:indicator];
        }
    }
    else if (mode == FCProgressHUDModeDeterminateHorizontalBar){
         // Update to bar determinate indicator
        [indicator removeFromSuperview];
        indicator = [[FCBarProgressView alloc]init];
        [self.bezelView   addSubview:indicator];
    }
    else if (mode == FCProgressHUDModeDeterminate || mode == FCProgressHUDModeAnnularDeterminate){
        if (!isRoundindicator) {
              // Update to determinante indicator
            [indicator removeFromSuperview];
            indicator  = [[FCRoundProgressView alloc]init];
            [self.bezelView  addSubview:indicator];
        }
        if (mode == FCProgressHUDModeAnnularDeterminate) {
            [(FCRoundProgressView *)indicator setAnnular:YES];
        }
    }
    else if (mode == FCProgressHUDModeCustomView && self.customView != indicator){
         // Update custom view indicator
        [indicator removeFromSuperview];
        indicator = self.customView ;
        [self.bezelView  addSubview:indicator];
    }
    else if (mode == FCProgressHUDModeText){
        [indicator removeFromSuperview];
        indicator = nil;
    }
    indicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.indicator = indicator;
    
    if ([indicator respondsToSelector:@selector(setProgress:)]) {
        [(id)indicator setValue:@(self.progress) forKey:@"progress"];
    }

    [indicator setContentCompressionResistancePriority:998.f forAxis:UILayoutConstraintAxisHorizontal];
    [indicator setContentCompressionResistancePriority:998.f forAxis:UILayoutConstraintAxisVertical];
    
    
    [self updateViewsForColor:self.contentColor];
    [self setNeedsUpdateConstraints];
}

- (void)updateViewsForColor:(UIColor *)color
{
    if(!color) return;
    
    self.label.textColor = color;
    self.detailsLabel.textColor = color;
    [self.button setTitleColor:color forState:UIControlStateNormal];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (self.activityIndicatorColor) {
        color = self.activityIndicatorColor;
    }
#pragma clang diagnostic pop
    
    //如果她们忽略预设颜色，将优先设置UIApperance
    UIView  *indicator = self.indicator;
    if ([indicator  isKindOfClass:[UIActivityIndicatorView class]]) {
        UIActivityIndicatorView  *appearance = nil;
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 90000
        appearance = [UIActivityIndicatorView appearanceWhenContainedIn:[FCProgressHUD class], nil];
#else
     //ios 9+
        appearance = [UIActivityIndicatorView appearanceWhenContainedInInstancesOfClasses:@[[FCProgressHUD class]]];
#endif
        if (appearance.color == nil) {
            ((UIActivityIndicatorView *)indicator).color = color;
        }
    }else if ([indicator  isKindOfClass:[FCRoundProgressView class]]){
        FCRoundProgressView *appearance =  nil;
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 90000
        appearance = [FCRoundProgressView appearanceWhenContainedIn:[FCProgressHUD Class],nil];
#else
        appearance = [FCRoundProgressView  appearanceWhenContainedInInstancesOfClasses:@[[FCProgressHUD  class]]];
#endif
        if (appearance.progressTintColor == nil) {
            ((FCRoundProgressView *)indicator).progressTintColor = color;
        }
        if (appearance.backgroundTintColor == nil) {
            ((FCRoundProgressView *)indicator).backgroundTintColor = [color colorWithAlphaComponent:0.1
                                                                      ];
        }
    }else if ([indicator  isKindOfClass:[FCBarProgressView class]]){
        FCBarProgressView *appearance = nil;
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 90000
        appeanace = [FCBarProgressView appearanceWhenContainedIn:[FCBarProgressView Class],nil];
#else
        appearance = [FCBarProgressView appearanceWhenContainedInInstancesOfClasses:@[[FCBarProgressView class]]];
#endif
        if (appearance.progressColor == nil) {
            ((FCBarProgressView *)indicator).progressColor = color;
        }
        if (appearance.lineColor == nil) {
            ((FCBarProgressView *)indicator).lineColor = color;
        }
    }else
    {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000 || TARGET_OS_TV
        if ([indicator  respondsToSelector:@selector(setTintColor:)]) {
            [indicator setTintColor:color];
        }
#endif
    }
}
- (void)updateBezelMotionEffects
{
   /**
    _IPHONE_OS_VERSION_MAX_ALLOWED编译环境判断，判断当前开发时使用的sdk的版本。
    #if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
    // 所使用的sdk为5.0以上的版本，在此的代码在编译时不会保存，但是允许在低版本ios系统的设备上运行就会崩溃的
    // 例如：你使用xcode6.1开发，SDK版本为8.1来开发项目，并使用新API的新功能，在编译时没有问题，但是允许ios7系统的设备上就会崩溃
    #else
    //不能使用该API的代码编写
    #endif
    所以不能使用它来判断你的项目是否支持低版本ios系统的设备
    __IPHONE_OS_VERSION_MIN_REQUIRED取值来自于：设置中的deployment target，是可变的，根据开发的设置有所不同
    */
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000 || TARGET_OS_TV
    FCBackgroundView  *bezelView = self.bezelView;
    if (![bezelView  respondsToSelector:@selector(addMotionEffect:)]) return;
    
    if (self.defaultMotionEffectsEnabled) {
        CGFloat  effectOffset = 10.0f;
        UIInterpolatingMotionEffect  *effectX = [[UIInterpolatingMotionEffect alloc]initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
        effectX.maximumRelativeValue = @(effectOffset);
        effectX.minimumRelativeValue = @(-effectOffset);
        
        UIInterpolatingMotionEffect  *effectY = [[UIInterpolatingMotionEffect alloc]initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
        effectY.maximumRelativeValue = @(effectOffset);
        effectY.minimumRelativeValue = @(-effectOffset);
        
        UIMotionEffectGroup  *group = [[UIMotionEffectGroup alloc]init];
        group.motionEffects = @[effectX,effectY];
        [bezelView  addMotionEffect:group];
    }else
    {
        NSArray  *effects = [bezelView  motionEffects];
        for (UIMotionEffect *effect in effects) {
            [bezelView  removeMotionEffect:effect];
        }
    }
#endif
}
#pragma mark - Layout
- (void)updateConstraints
{
    UIView  *bezel = self.bezelView;
    UIView  *topSpacer = self.topSpacer;
    UIView  *bottomSpacer = self.bottomSpacer;
    CGFloat margin = self.margin;
    NSMutableArray *bezelConstraints = [NSMutableArray array];
    NSDictionary  *metrics = @{@"margin":@(margin)};
    
    NSMutableArray *subviews = [NSMutableArray arrayWithObjects:self.topSpacer,self.label,self.detailsLabel,self.button,self.bottomSpacer, nil];
    if (self.indicator) [subviews insertObject:self.indicator atIndex:1];
    
    // 移除存在的约束
    [self removeConstraints:self.constraints];
    [topSpacer  removeConstraints:topSpacer.constraints];
    [bottomSpacer  removeConstraints:bottomSpacer.constraints];
    if (self.bezelConstraints) {
        [bezel removeConstraints:self.bezelConstraints];
        self.bezelConstraints = nil;
    }
    CGPoint  offset  = self.offset;
    NSMutableArray *centeringConstraints  = [NSMutableArray array];
    [centeringConstraints addObject:[NSLayoutConstraint  constraintWithItem:bezel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1.f constant:offset.x]];
    [centeringConstraints  addObject:[NSLayoutConstraint  constraintWithItem:bezel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.f constant:offset.y]];
    
    [self applyPriority:998.f toConstraints:centeringConstraints];
    [self  addConstraints:centeringConstraints];
    
    //确保最低边距存在
    NSMutableArray *sideConstraints  = [NSMutableArray array];
    [sideConstraints  addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(>=margin)-[bezel]-(>=margin)-|" options:0 metrics:metrics views:NSDictionaryOfVariableBindings(bezel)]];
    [sideConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(>=margin)-[bezel]-(>=margin)-|" options:0 metrics:metrics views:NSDictionaryOfVariableBindings(bezel)]];
    
    [self applyPriority:999.f toConstraints:sideConstraints];
    [self  addConstraints:sideConstraints];
    
    // 最低bezel的size if set
    CGSize  minimumSize = self.minSize;
    if (!CGSizeEqualToSize(minimumSize, CGSizeZero)) {
        NSMutableArray *minSizeConstraints = [NSMutableArray array];
        [minSizeConstraints addObject:[NSLayoutConstraint constraintWithItem:bezel attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.f constant:minimumSize.width]];
        [minSizeConstraints addObject:[NSLayoutConstraint constraintWithItem:bezel attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.f constant:minimumSize.height]];
        [self applyPriority:997.f toConstraints:minSizeConstraints];
        [bezelConstraints addObjectsFromArray:minSizeConstraints];
    }
    
    //如果设置，保持高度宽度方形相同
    if (self.square) {
        NSLayoutConstraint *square = [NSLayoutConstraint constraintWithItem:bezel attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:bezel attribute:NSLayoutAttributeWidth multiplier:1.f constant:0];
        square.priority = 997.f;
        [bezelConstraints addObject:square];
    }
    
    //顶部和底部空间
    [topSpacer addConstraint:[NSLayoutConstraint constraintWithItem:topSpacer attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.f constant:margin]];
    [bottomSpacer addConstraint:[NSLayoutConstraint constraintWithItem:bottomSpacer attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.f constant:margin]];
    //顶部和底部空间应该相同
    [bezelConstraints addObject:[NSLayoutConstraint constraintWithItem:topSpacer attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:bottomSpacer attribute:NSLayoutAttributeHeight multiplier:1.f constant:0.f]];
    
    //适配bezel的子视图
    NSMutableArray *paddingConstrints = [NSMutableArray array];
    [subviews enumerateObjectsUsingBlock:^(UIView  *view, NSUInteger idx, BOOL * _Nonnull stop) {
         // Center in bezel
        [bezelConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:bezel attribute:NSLayoutAttributeCenterX multiplier:1.f constant:0.f]];
         // Ensure the minimum edge margin is kept
        [bezelConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(>=margin)-[view]-(>=margin)-|" options:0 metrics:metrics views:NSDictionaryOfVariableBindings(view)]];
        //元素间距
        if (idx == 0) {
            // 首先 确保到bezel边界的距离
          [bezelConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:bezel attribute:NSLayoutAttributeTop multiplier:1.f constant:0.f]];
        }else if(idx == subviews.count -1){
            // Last, ensure spacing to bezel edge
            [bezelConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:bezel attribute:NSLayoutAttributeBottom multiplier:1.f constant:0.f]];
        }
        if (idx > 0) {
            NSLayoutConstraint *padding = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:subviews[idx - 1] attribute:NSLayoutAttributeBottom multiplier:1.f constant:0.f];
            [bezelConstraints addObject:padding];
            [paddingConstrints addObject:padding];
        }
    }];
    
    [bezel  addConstraints:bezelConstraints];
    self.bezelConstraints = bezelConstraints;
    
    self.paddingConstrains = [paddingConstrints copy];
    [self   updatePaddingConstraints];
    
    [super updateConstraints];
}

- (void)layoutSubviews
{
    [self  updatePaddingConstraints];
    [super layoutSubviews];

}
- (void)updatePaddingConstraints
{
   //动态设置padding  这取决于视图是否可见
    __block BOOL  hasVisibleAncestors = NO;
    [self.paddingConstrains  enumerateObjectsUsingBlock:^(NSLayoutConstraint *padding, NSUInteger idx, BOOL * _Nonnull stop) {
        UIView *firstView = (UIView *)padding.firstItem;
        UIView *secondView = (UIView *)padding.secondItem;
        
        BOOL firstVisible = !firstView.hidden && !CGSizeEqualToSize(firstView.intrinsicContentSize, CGSizeZero);
        BOOL secondVisible = !secondView.hidden && !CGSizeEqualToSize(secondView.intrinsicContentSize, CGSizeZero);
        
        //如果views都是可见的或者相对于当前视图仍然没有填充的可见的视图
        padding.constant = (firstVisible && (secondVisible || hasVisibleAncestors)) ? FCDefaultPadding : 0.f;
        hasVisibleAncestors |= secondVisible;
    }];
}

- (void)applyPriority:(UILayoutPriority)priority toConstraints:(NSArray *)constraints
{
    for (NSLayoutConstraint *constraint in constraints) {
        constraint.priority = priority;
    }
}

#pragma mark - Properties

- (void)setMode:(FCProgressHUDMode)mode
{
    if (mode != _mode) {
        _mode = mode;
        [self updateIndicators];
    }
}

- (void)setCustomView:(UIView *)customView
{
    if (customView != _customView) {
        _customView = customView;
        if (self.mode == FCProgressHUDModeCustomView) {
            [self  updateIndicators];
        }
    }
}

- (void)setOffset:(CGPoint)offset
{
    if (!CGPointEqualToPoint(offset, _offset)) {
        _offset = offset;
        [self  setNeedsUpdateConstraints];
    }
}

- (void)setMargin:(CGFloat)margin
{
    if (margin != _margin) {
        _margin = margin;
        [self  setNeedsUpdateConstraints];
    }
}

- (void)setMinSize:(CGSize)minSize
{
    if(!CGSizeEqualToSize(minSize, _minSize)){
        _minSize = minSize;
        [self   setNeedsUpdateConstraints];
    }
}

- (void)setSquare:(BOOL)square
{
    if(square != _square){
        _square = square;
        [self  setNeedsUpdateConstraints];
    }
}

- (void)setProgress:(float)progress
{
    if (progress != _progress) {
        _progress = progress;
        UIView *indicator = self.indicator;
        if ([indicator  respondsToSelector:@selector(setProgress:)]) {
             [(id)indicator setValue:@(self.progress) forKey:@"progress"];
        }
    }
}

- (void)setContentColor:(UIColor *)contentColor
{
    if(contentColor != _contentColor && ![contentColor isEqual:_contentColor]){
        _contentColor = contentColor;
        [self  updateViewsForColor:contentColor];
    }
}

- (void)setDefaultMotionEffectsEnabled:(BOOL)defaultMotionEffectsEnabled
{
    if (defaultMotionEffectsEnabled) {
        _defaultMotionEffectsEnabled = defaultMotionEffectsEnabled;
        [self updateBezelMotionEffects];
    }
}
#pragma mark - Notifications
- (void)registerForNotifications {
   
#if !TARGET_OS_TV
    NSNotificationCenter  *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(statusBarOrientationDidChange:)
               name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
#endif
}

- (void)unregisterFromNotifications {
#if !TARGET_OS_TV
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
#endif
}
#if !TARGET_OS_TV
- (void)statusBarOrientationDidChange:(NSNotification *)notification
{
    UIView  *superview = self.superview;
    if (!superview) {
        return;
    }else{
        [self updateForCurrentOrientationAnimated:YES];
    }
}
#endif

- (void)updateForCurrentOrientationAnimated:(BOOL)animated
{
    //在任何情况下和父视图保持同步
    if (self.superview) {
        self.bounds = self.superview.bounds;
    }
    //不需要在iOS 8 +,编译部署目标允许时,为了避免sharedApplication问题扩展目标
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 80000
     //当添加到窗口在ios8以前需要
    BOOL iOS8OrLater = kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0;
    if (iOS8OrLater || ![self.superview isKindOfClass:[UIWindow class]])  return;
    //平滑的制造扩展。由于上述检查将不会调用（ios8+）扩展
    //这是确保我们不得到一个警告关于extension-unsafe API
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if (!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) return;
    UIApplication *applicatopn = [UIApplication performSelector:@selector(sharedApplication)];
    //UIInterfaceOrientatin 设备的旋转方向
    UIInterfaceOrientation orientation = application.statusBarOrientation;
    CGFloat  radians = 0;
    
    if (UIInterfaceOrientationIsLandscape(orientation)) {
        radians = orientation == UIInterfaceOrientationLandscapeLeft ? -(CGFloat)M_PI_2 : (CGFloat)M_PI_2;
        // Window coordinates differ!
        self.bounds = CGRectMake(0, 0, self.bounds.size.height, self.bounds.size.width);
    } else {
        radians = orientation == UIInterfaceOrientationPortraitUpsideDown ? (CGFloat)M_PI : 0.f;
    }
    
    if (animated) {
        [UIView animateWithDuration:0.3 animations:^{
            self.transform = CGAffineTransformMakeRotation(radians);
        }];
    } else {
        self.transform = CGAffineTransformMakeRotation(radians);
    }

#endif
}

@end

@implementation FCRoundProgressView

#pragma mark - Lifecycle
- (id)init
{
    return [self initWithFrame:CGRectMake(0.f, 0.f, 37.f, 37.f)];
    
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        _progress = 0.f;
        _annular = NO;
        _progressTintColor = [[UIColor alloc]initWithWhite:1.f alpha:1.f];
        _backgroundTintColor = [[UIColor alloc]initWithWhite:1.f alpha:1.f];
    }
    return self;
}

#pragma mark - Layout
- (CGSize)intrinsicContentSize
{
    return  CGSizeMake(37.f, 37.f);
}

#pragma mark - Properties
- (void)setProgress:(float)progress
{
    if (progress != _progress) {
        [self  setNeedsDisplay];
    }
}

- (void)setProgressTintColor:(UIColor *)progressTintColor
{
    NSAssert(progressTintColor, @"The color should not be nil.");
    if (progressTintColor  != _progressTintColor && ![progressTintColor isEqual:_progressTintColor]) {
        _progressTintColor = progressTintColor;
        [self setNeedsDisplay];
    }
}

- (void)setBackgroundTintColor:(UIColor *)backgroundTintColor
{
    NSAssert(backgroundTintColor, @"The color should not be nil.");
    if (backgroundTintColor != _backgroundTintColor && ![backgroundTintColor isEqual:_backgroundTintColor]) {
        _backgroundTintColor = backgroundTintColor;
        [self setNeedsDisplay];
    }
}

#pragma mark - Drawing
- (void)drawRect:(CGRect)rect
{
    CGContextRef  context = UIGraphicsGetCurrentContext();
    BOOL isPreiOS7 = kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0;
    
    if (_annular) {
         //draw  background
        CGFloat  lineWidth =  isPreiOS7 ? 5.f : 2.f;
        UIBezierPath *processBackgroundPath = [UIBezierPath bezierPath];
        processBackgroundPath.lineWidth = lineWidth;
        /**
         kCGLineCapButt：该属性值指定不绘制端点，
         线条结尾处直接结束。这是默认值。
         kCGLineCapRound：该属性值指定绘制圆形端点，
         线条结尾处绘制一个直径为线条宽度的半圆。
         kCGLineCapSquare：该属性值指定绘制方形端点。
         线条结尾处绘制半个边长为线条宽度的正方形。需要
         说明的是，这种形状的端点与“butt”形状的端点十分相似，
         只是采用这种形式的端点的线条略长一点而已
         */
        processBackgroundPath.lineCapStyle  = kCGLineCapButt;
        CGPoint  center =  CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        CGFloat  radius = (self.bounds.size.width - lineWidth)/2;
        CGFloat startAngle = - ((float)M_PI / 2); // 90 degrees
        CGFloat endAngle = (2 * (float)M_PI) + startAngle;
//        center：圆心的坐标
//        radius：半径
//        startAngle：起始的弧度
//        endAngle：圆弧结束的弧度
//        clockwise：YES为顺时针，No为逆时针
        [processBackgroundPath addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
        [_backgroundTintColor  set];
        [processBackgroundPath stroke];
        
        //进程
        UIBezierPath *processPath = [UIBezierPath bezierPath];
        processPath.lineCapStyle = isPreiOS7 ? kCGLineCapRound : kCGLineCapSquare;
        processPath.lineWidth = lineWidth;
        endAngle = (self.progress * 2 * (float)M_PI) + startAngle;
        [processPath  addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
        [_progressTintColor  set];
        [processPath  stroke];
    }else
    {
       // 背景
        CGFloat lineWidth = 2.f;
        CGRect  allRect = self.bounds;
        
     CGRect circleRect = CGRectInset(allRect, lineWidth/2.f, lineWidth/2.f);
     CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        [_progressTintColor setStroke];
        [_backgroundTintColor setFill];
        
        CGContextSetLineWidth(context, lineWidth);
        if (isPreiOS7) {
            //填充指定举行的椭圆
            CGContextFillEllipseInRect(context, circleRect);
        }
        CGContextStrokeEllipseInRect(context, circleRect);
        // 90 degrees
        CGFloat startAngle = - ((float)M_PI / 2.f);
        //进程
        if (isPreiOS7) {
            CGFloat  radius = (CGRectGetWidth(self.bounds)/2.f) - lineWidth;
            CGFloat endAngle = (self.progress * 2.f * (float)M_PI) + startAngle;
            [_progressTintColor setFill];
            CGContextMoveToPoint(context, center.x, center.y);
            CGContextAddArc(context, center.x, center.y, radius, startAngle, endAngle, 0);
            CGContextClosePath(context);
            CGContextFillPath(context);
        }else
        {
            UIBezierPath  *processPath = [UIBezierPath bezierPath];
            processPath.lineCapStyle = kCGLineCapButt;
            processPath.lineWidth = lineWidth;
            CGFloat  radius =  (CGRectGetWidth(self.bounds) / 2.f) - (processPath.lineWidth / 2.f);
            CGFloat  endAngle =  (self.progress * 2.f * (float)M_PI) + startAngle;
            [processPath addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
            //设定混合模式
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            [_progressTintColor set];
             [processPath stroke];
        }
    }
}
@end


@implementation FCBarProgressView

#pragma mark - Lifecycle
- (id)init{
       return [self initWithFrame:CGRectMake(.0f, .0f, 120.0f, 20.0f)];
}

- (id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        _progress = 0.f;
        _lineColor = [UIColor whiteColor];
        _progressColor = [UIColor whiteColor];
        _progressRemainingColor = [UIColor clearColor];
        self.backgroundColor  = [UIColor clearColor];
        self.opaque = NO;
    }
    return self;
}

#pragma mark - Layout
- (CGSize)intrinsicContentSize
{
    BOOL isPreiOS7 = kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0;
    return CGSizeMake(120.f, isPreiOS7 ? 20.f : 10.f);
}

#pragma mark - Properties
- (void)setProgress:(float)progress
{
    if (progress != _progress) {
        _progress = progress;
        [self setNeedsDisplay];
    }
}

- (void)setProgressColor:(UIColor *)progressColor {
    NSAssert(progressColor, @"The color should not be nil.");
    if (progressColor != _progressColor && ![progressColor isEqual:_progressColor]) {
        _progressColor = progressColor;
        [self setNeedsDisplay];
    }
}

- (void)setProgressRemainingColor:(UIColor *)progressRemainingColor {
    NSAssert(progressRemainingColor, @"The color should not be nil.");
    if (progressRemainingColor != _progressRemainingColor && ![progressRemainingColor isEqual:_progressRemainingColor]) {
        _progressRemainingColor = progressRemainingColor;
        [self setNeedsDisplay];
    }
}

#pragma mark - Drawing
- (void)drawRect:(CGRect)rect
{
    CGContextRef  context = UIGraphicsGetCurrentContext();
    
    CGContextSetLineWidth(context, 2);
    CGContextSetStrokeColorWithColor(context, _lineColor.CGColor);
    CGContextSetFillColorWithColor(context, _progressRemainingColor.CGColor);
    
    
    //背景
    CGFloat  radius =  (rect.size.height/2) -2;
    CGContextMoveToPoint(context, 2, rect.size.height/2);
    CGContextAddArcToPoint(context, 2, 2, radius + 2, 2, radius);
    CGContextAddLineToPoint(context, rect.size.width - radius - 2, 2);
    CGContextAddArcToPoint(context, rect.size.width - 2, 2, rect.size.width - 2, rect.size.height / 2, radius);
    CGContextAddArcToPoint(context, rect.size.width - 2, rect.size.height - 2, rect.size.width - radius - 2, rect.size.height - 2, radius);
    CGContextAddLineToPoint(context, radius + 2, rect.size.height - 2);
    CGContextAddArcToPoint(context, 2, rect.size.height - 2, 2, rect.size.height/2, radius);
    CGContextFillPath(context);
    
    //边界
    CGContextMoveToPoint(context, 2, rect.size.height/2);
    CGContextAddArcToPoint(context, 2, 2, radius + 2, 2, radius);
    CGContextAddLineToPoint(context, rect.size.width - radius - 2, 2);
    CGContextAddArcToPoint(context, rect.size.width - 2, 2, rect.size.width - 2, rect.size.height / 2, radius);
    CGContextAddArcToPoint(context, rect.size.width - 2, rect.size.height - 2, rect.size.width - radius - 2, rect.size.height - 2, radius);
    CGContextAddLineToPoint(context, radius + 2, rect.size.height - 2);
    CGContextAddArcToPoint(context, 2, rect.size.height - 2, 2, rect.size.height/2, radius);
    CGContextStrokePath(context);
    
    CGContextSetFillColorWithColor(context, [_progressColor CGColor]);
    radius = radius - 2;
    CGFloat amount = self.progress * rect.size.width;
    
    // Progress in the middle area
    if (amount >= radius + 4 && amount <= (rect.size.width - radius - 4)) {
        CGContextMoveToPoint(context, 4, rect.size.height/2);
        CGContextAddArcToPoint(context, 4, 4, radius + 4, 4, radius);
        CGContextAddLineToPoint(context, amount, 4);
        CGContextAddLineToPoint(context, amount, radius + 4);
        
        CGContextMoveToPoint(context, 4, rect.size.height/2);
        CGContextAddArcToPoint(context, 4, rect.size.height - 4, radius + 4, rect.size.height - 4, radius);
        CGContextAddLineToPoint(context, amount, rect.size.height - 4);
        CGContextAddLineToPoint(context, amount, radius + 4);
        
        CGContextFillPath(context);
    }
    
    // Progress in the right arc
    else if (amount > radius + 4) {
        CGFloat x = amount - (rect.size.width - radius - 4);
        
        CGContextMoveToPoint(context, 4, rect.size.height/2);
        CGContextAddArcToPoint(context, 4, 4, radius + 4, 4, radius);
        CGContextAddLineToPoint(context, rect.size.width - radius - 4, 4);
        CGFloat angle = -acos(x/radius);
        if (isnan(angle)) angle = 0;
        CGContextAddArc(context, rect.size.width - radius - 4, rect.size.height/2, radius, M_PI, angle, 0);
        CGContextAddLineToPoint(context, amount, rect.size.height/2);
        
        CGContextMoveToPoint(context, 4, rect.size.height/2);
        CGContextAddArcToPoint(context, 4, rect.size.height - 4, radius + 4, rect.size.height - 4, radius);
        CGContextAddLineToPoint(context, rect.size.width - radius - 4, rect.size.height - 4);
        angle = acos(x/radius);
        if (isnan(angle)) angle = 0;
        CGContextAddArc(context, rect.size.width - radius - 4, rect.size.height/2, radius, -M_PI, angle, 1);
        CGContextAddLineToPoint(context, amount, rect.size.height/2);
        
        CGContextFillPath(context);
    }
    
    // Progress is in the left arc
    else if (amount < radius + 4 && amount > 0) {
        CGContextMoveToPoint(context, 4, rect.size.height/2);
        CGContextAddArcToPoint(context, 4, 4, radius + 4, 4, radius);
        CGContextAddLineToPoint(context, radius + 4, rect.size.height/2);
        
        CGContextMoveToPoint(context, 4, rect.size.height/2);
        CGContextAddArcToPoint(context, 4, rect.size.height - 4, radius + 4, rect.size.height - 4, radius);
        CGContextAddLineToPoint(context, radius + 4, rect.size.height/2);
        
        CGContextFillPath(context);
    }
}
@end


@interface FCBackgroundView ()

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000 || TARGET_OS_TV
@property UIVisualEffectView *effectView;
#endif

@property UIToolbar  *toolbar;

@end
@implementation FCBackgroundView


#pragma mark - Lifecycle
- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0) {
            _style = FCProgressHUDBackgroundStyleBlur;
            if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0) {
                _color = [UIColor colorWithWhite:0.8f alpha:0.6f];
            } else {
                _color = [UIColor colorWithWhite:0.95f alpha:0.6f];
            }
        }else {
            _style = FCProgressHUDBackgroundStyleSolidColor;
            _color = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        }
        self.clipsToBounds = YES;
        
        [self updateForBackgroundStyle];
    }
    return self;
}


#pragma mark - Layout

- (CGSize)intrinsicContentSize {
    // Smallest size possible. Content pushes against this.
    return CGSizeZero;
}

#pragma mark - Appearance

- (void)setStyle:(FCProgressHUDBackgroundStyle)style {
    if (style == FCProgressHUDBackgroundStyleBlur && kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0) {
        style = FCProgressHUDBackgroundStyleSolidColor;
    }
    if (_style != style) {
        _style = style;
        [self updateForBackgroundStyle];
    }
}

- (void)setColor:(UIColor *)color {
    NSAssert(color, @"The color should not be nil.");
    if (color != _color && ![color isEqual:_color]) {
        _color = color;
        [self updateViewsForColor:color];
    }
}
#pragma mark - Views
- (void)updateForBackgroundStyle
{
    FCProgressHUDBackgroundStyle style = self.style;
    if (style == FCProgressHUDBackgroundStyleBlur) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000 || TARGET_OS_TV
        if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0) {
            UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
            UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:effect];
            [self addSubview:effectView];
            effectView.frame = self.bounds;
            effectView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
            self.backgroundColor = self.color;
            self.layer.allowsGroupOpacity = NO;
            self.effectView = effectView;
        } else {
#endif
            UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectInset(self.bounds, -100.f, -100.f)];
            toolbar.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
            toolbar.barTintColor = self.color;
            toolbar.translucent = YES;
            [self addSubview:toolbar];
            self.toolbar = toolbar;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000 || TARGET_OS_TV
        }
#endif
    } else {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000 || TARGET_OS_TV
        if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0) {
            [self.effectView removeFromSuperview];
            self.effectView = nil;
        } else {
#endif
            [self.toolbar removeFromSuperview];
            self.toolbar = nil;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000 || TARGET_OS_TV
        }
#endif
        self.backgroundColor = self.color;
    }


}
- (void)updateViewsForColor:(UIColor *)color
{
    if (self.style == FCProgressHUDBackgroundStyleBlur) {
        if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0) {
            self.backgroundColor = self.color;
        } else {
            self.toolbar.barTintColor = color;
        }
    } else {
        self.backgroundColor = self.color;
    }
}
@end


@implementation FCProgressHUD (Deprecated)

#pragma mark - Class

+ (NSUInteger)hideAllHUDsForView:(UIView *)view animated:(BOOL)animated
{
    NSArray  *huds = [FCProgressHUD allHUDsForView:view];
    for (FCProgressHUD *hud in huds) {
        hud.removeFromSuperViewOnHide = YES;
        [hud hideAnimated:animated];
    }
    return [huds count];
}

+ (NSArray *)allHUDsForView:(UIView *)view
{
    NSMutableArray *huds = [NSMutableArray array];
    NSArray *subviews = view.subviews;
    for (UIView *aView in subviews) {
        if ([aView isKindOfClass:self]) {
            [huds addObject:aView];
        }
    }
    return  [NSArray arrayWithArray:huds];
}

#pragma mark - Lifecycle
- (id)initWithWindow:(UIWindow *)window
{
    return [self initWithView:window];
}

#pragma mark - Show & Hide
- (void)show:(BOOL)animated {
    [self showAnimated:animated];
}

- (void)hide:(BOOL)animated {
    [self hideAnimated:animated];
}

- (void)hide:(BOOL)animated afterDelay:(NSTimeInterval)delay {
    [self hideAnimated:animated afterDeleay:delay];
}

#pragma mark - Threading
- (void)showWhileExecuting:(SEL)method onTarget:(id)target withObject:(id)object animated:(BOOL)animated
{
    [self showAnimated:animated whileExecutingBlock:^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        // Start executing the requested task
        [target performSelector:method withObject:object];
#pragma clang diagnostic pop
    }];

}
- (void)showAnimated:(BOOL)animated whileExecutingBlock:(dispatch_block_t)block {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    [self showAnimated:animated whileExecutingBlock:block onQueue:queue completionBlock:NULL];
}

- (void)showAnimated:(BOOL)animated whileExecutingBlock:(dispatch_block_t)block completionBlock:(void (^)())completion {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    [self showAnimated:animated whileExecutingBlock:block onQueue:queue completionBlock:completion];
}

- (void)showAnimated:(BOOL)animated whileExecutingBlock:(dispatch_block_t)block onQueue:(dispatch_queue_t)queue {
    [self showAnimated:animated whileExecutingBlock:block onQueue:queue completionBlock:NULL];
}

- (void)showAnimated:(BOOL)animated whileExecutingBlock:(dispatch_block_t)block onQueue:(dispatch_queue_t)queue completionBlock:(nullable FCProgressHUDCompletionBlock)completion {
    self.taskInProgress = YES;
    self.completionBlock = completion;
    dispatch_async(queue, ^(void) {
        block();
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self cleanUp];
        });
    });
    [self showAnimated:animated];
}

- (void)cleanUp {
    self.taskInProgress = NO;
    [self hideAnimated:self.useAnimation];
}

- (NSString *)labelText {
    return self.label.text;
}

- (void)setLabelText:(NSString *)labelText {
       FCMainThreadAssert();
    self.label.text = labelText;
}

- (UIFont *)labelFont {
    return self.label.font;
}

- (void)setLabelFont:(UIFont *)labelFont {
    FCMainThreadAssert();
    self.label.font = labelFont;
}

- (UIColor *)labelColor {
    return self.label.textColor;
}

- (void)setLabelColor:(UIColor *)labelColor {
       FCMainThreadAssert();
    self.label.textColor = labelColor;
}

- (NSString *)detailsLabelText {
    return self.detailsLabel.text;
}

- (void)setDetailsLabelText:(NSString *)detailsLabelText {
       FCMainThreadAssert();
    self.detailsLabel.text = detailsLabelText;
}

- (UIFont *)detailsLabelFont {
    return self.detailsLabel.font;
}

- (void)setDetailsLabelFont:(UIFont *)detailsLabelFont {
      FCMainThreadAssert();
    self.detailsLabel.font = detailsLabelFont;
}

- (UIColor *)detailsLabelColor {
    return self.detailsLabel.textColor;
}

- (void)setDetailsLabelColor:(UIColor *)detailsLabelColor {
      FCMainThreadAssert();
    self.detailsLabel.textColor = detailsLabelColor;
}

- (CGFloat)opacity {
    return _opacity;
}

- (void)setOpacity:(CGFloat)opacity {
    FCMainThreadAssert();
    _opacity = opacity;
}

- (UIColor *)color {
    return self.bezelView.color;
}

- (void)setColor:(UIColor *)color {
    FCMainThreadAssert();
    self.bezelView.color = color;
}

- (CGFloat)yOffset {
    return self.offset.y;
}

- (void)setYOffset:(CGFloat)yOffset {
      FCMainThreadAssert();
    self.offset = CGPointMake(self.offset.x, yOffset);
}

- (CGFloat)xOffset {
    return self.offset.x;
}

- (void)setXOffset:(CGFloat)xOffset {
       FCMainThreadAssert();
    self.offset = CGPointMake(xOffset, self.offset.y);
}

- (CGFloat)cornerRadius {
    return self.bezelView.layer.cornerRadius;
}

- (void)setCornerRadius:(CGFloat)cornerRadius {
     FCMainThreadAssert();
    self.bezelView.layer.cornerRadius = cornerRadius;
}

- (BOOL)dimBackground {
    FCBackgroundView *backgroundView = self.backgroundView;
    UIColor *dimmedColor =  [UIColor colorWithWhite:0.f alpha:.2f];
    return backgroundView.style == FCProgressHUDBackgroundStyleSolidColor && [backgroundView.color isEqual:dimmedColor];
}

- (void)setDimBackground:(BOOL)dimBackground {
    FCMainThreadAssert();
    self.backgroundView.style = FCProgressHUDBackgroundStyleSolidColor;
    self.backgroundView.color = dimBackground ? [UIColor colorWithWhite:0.f alpha:.2f] : [UIColor clearColor];
}

- (CGSize)size {
    return self.bezelView.frame.size;
}

- (UIColor *)activityIndicatorColor {
    return _activityIndicatorColor;
}

- (void)setActivityIndicatorColor:(UIColor *)activityIndicatorColor {
    if (activityIndicatorColor != _activityIndicatorColor) {
        _activityIndicatorColor = activityIndicatorColor;
        UIActivityIndicatorView *indicator = (UIActivityIndicatorView *)self.indicator;
        if ([indicator isKindOfClass:[UIActivityIndicatorView class]]) {
            [indicator setColor:activityIndicatorColor];
        }
    }
}
@end

