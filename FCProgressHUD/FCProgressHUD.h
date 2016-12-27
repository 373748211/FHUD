//
//  FCProgressHUD.h
//  FCProgressHUD
//
//  Created by 凡小超 on 16/9/24.
//  Copyright © 2016年 凡小超. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FCBackgroundView;
@protocol FCProgressHUDDelegate;


typedef NS_ENUM(NSInteger, FCProgressHUDMode) {
    
    //UIActivityIndicatorView
    FCProgressHUDModeIndeterminate,
    // 圆饼进度
    FCProgressHUDModeDeterminate,
    // 水平进度条
    FCProgressHUDModeDeterminateHorizontalBar,
    // 环形进度
    FCProgressHUDModeAnnularDeterminate,
    // 展示自定义视图
    FCProgressHUDModeCustomView,
    // 仅仅展示label
    FCProgressHUDModeText
};

typedef NS_ENUM(NSInteger, FCProgressHUDAnimation) {
      //不透明度动画
    FCProgressHUDAnimationFade,
    // 不透明度 和 缩放动画（出现放大消失缩小）
    FCProgressHUDAnimationZoom,
    // 不透明度 和缩放动画 （缩小风格）
    FCProgressHUDAnimationZoomOut,
    // 不透明度 和缩放动画 (放大风格)
    FCProgressHUDAnimationZoomIn
};


typedef NS_ENUM(NSInteger, FCProgressHUDBackgroundStyle) {
    
    //纯色背景
    FCProgressHUDBackgroundStyleSolidColor,
    // UIVisualEffectView or UIToolbar.layer background view
    FCProgressHUDBackgroundStyleBlur
};


typedef void(^FCProgressHUDCompletionBlock)();

/**
 如果需要每个属性或每个方法都去指定nonnull和nullable，是一件非常繁琐的事。苹果为了减轻我们的工作量，专门提供了两个宏：NS_ASSUME_NONNULL_BEGIN和NS_ASSUME_NONNULL_END。在这两个宏之间的代码，所有简单指针对象都被假定为nonnull，因此我们只需要去指定那些nullable的指针
   nonull 不能为空 nullable 可以为空
 */
NS_ASSUME_NONNULL_BEGIN




@interface FCProgressHUD : UIView

/**
 创建一个新的HUD,将其添加到提供视图并显示它。此方法的对应hideHUDForView:动画:。
 
 @note 该方法包括了 removeFromSuperViewonHide.当hiden 将会自动从view removed from
 
 @param view  hud将会添加到这个view上面
 
 @param animated  如果设置为yes出现的时候会使用当前的animatetype，如果设置为no 出现的时候将不会使用动画
 */

+ (instancetype)showHUDAddedTo:(UIView *)view animated:(BOOL)animated;

/**
  发现最顶端的 HUD 子视图 并且隐藏它 对应的方法是 showHUDAddedTo:animated:
 
 @note  This method sets removeFromSuperViewOnHide. The HUD will automatically be removed from the view hierarchy when hidden.
 *@param  view 在这个视图搜寻 HUD
 *@param  animated If set to YES the HUD will disappear using the current animationType. If set to NO the HUD will not use
 *@return YES if a HUD was found and removed, NO otherwise.
 */

+ (BOOL)hideHUDForView:(UIView *)view animated:(BOOL)animated;

/**
 *Finds the top-most HUD subview and returns it.
 *@param view the view that is going to be searched
 @ return 最后发现的HUD子视图
 */
+ (nullable FCProgressHUD *)HUDForView:(UIView *)view;

/**
 @param view  the view 实例 将会提供 这个hud的边界  和将要添加上去的view边界相同
 */
- (instancetype)initWithView:(UIView *)view;

/**
 * Dispays the HUD
 *@note  在这个方法响应之后，你需要确保主线程完成它的run loop 如此以便于 the UI 能够被更新
 */
- (void)showAnimated:(BOOL)animated;

- (void)hideAnimated:(BOOL)animated;

- (void)hideAnimated:(BOOL)animated afterDeleay:(NSTimeInterval)delay;


/**
  接受 hud 状态通知
 */
@property (weak, nonatomic) id<FCProgressHUDDelegate>delegate;

/**
  * 当hud被隐藏之后响应
 */
@property (copy, nullable) FCProgressHUDCompletionBlock  completionBlock;


/**
 宽限期时间  在宽限期时间走完之前如果任务完成，。the hud将不会被展示，这可能是用来防止HUD显示非常短的任务，默认是0
 */
@property (assign, nonatomic) NSTimeInterval  graceTime;

/**
  the hud 展示的最短时间 避免 hud刚要被展示就隐藏的情况
 */
@property (assign, nonatomic) NSTimeInterval minShowTime;

/**
  当隐藏的时候从其父视图隐藏  默认为no
 */
@property (assign, nonatomic) BOOL removeFromSuperViewOnHide;

/**
 HUD  运行的方式 默认是 FCProgressHUDModeIndeterminate
 */
@property (nonatomic, assign) FCProgressHUDMode mode;

/**
 A color that gets forwarded to all labels and supported indicators. Also sets the tintColor for custom views on iOS 7+. Set to nil to manage color individually. Defaults to semi-translucent black on iOS 7 and later and white on earlier iOS versions.
 颜色被转发给所有支持标签和指标。还设置自定义视图的tintColor iOS 7 +。单独管理颜色设置为零。默认为半半透明的黑色和白色的iOS 7和早iOS版本。
 
  iOS后属性带UI_APPEARANCE_SELECTOR 可以统一设置全局作用
 */
@property (strong, nonatomic, nullable) UIColor *contentColor UI_APPEARANCE_SELECTOR;

/**
 The animation type that should be used when the HUD is shown and hidden.
 */
@property (assign,nonatomic)  FCProgressHUDAnimation animationType UI_APPEARANCE_SELECTOR;

/**
 *边框相对于view中心的距离， 可以使用offset 一直移动HUD到 screen 边界 在每一个方向
 *E.g., CGPointMake(0.f, MBProgressMaxOffset) would position the HUD centered on the bottom edge.
 */

@property (assign, nonatomic)  CGPoint offset UI_APPEARANCE_SELECTOR;


/**
*hud 边界 和其子视图里面的空间 的距离
*Defaults to 20.f
 */
@property (nonatomic, assign) CGFloat margin UI_APPEARANCE_SELECTOR;

/**
 * HUD 边框的最小size ，默认是CGSizeZero
 */
@property (nonatomic, assign) CGSize  minSize;

/**
 *如果可能 将HUD边界变成square
 */
@property (assign,nonatomic, getter= isSquare) BOOL  square UI_APPEARANCE_SELECTOR;

/**
 * when enabled 
 * 在ios7.0 以下没效果 默认是yes
 */
@property (assign, nonatomic, getter=areDefaultMotionEffectsEnabled)  BOOL defaultMotionEffectsEnabled  UI_APPEARANCE_SELECTOR;


/**
 *  指示器的进度，从0.0到1.0。默认是0.0
 */
@property (nonatomic, assign) float progress;

/**
  * 视图包含了label和指示器（或者 customView）
 */

@property (nonatomic, strong) FCBackgroundView *bezelView;

/**
 * the view    包含整个view的frame  位于bezelview前面
 */
@property (nonatomic, strong) FCBackgroundView  *backgroundView;

/**
  HUD 处于FCprogressHUDCustomView  the  view 将会显示出来
  * 视图应该实现 intrinsicContentSize 适当的大小 ，最好是使用大约37个元素
 */
@property (nonatomic, strong) UIView * customView;
/**
 *标签包含任意的短消息，这个标签在活动的指示器下面，hud是自适应
 *包含完整的text
 */
@property (nonatomic, strong, readonly) UILabel *label;

/**
 *这个标签包含任意详细的消息在LabelText 下面，支持多行
 */
@property (strong,nonatomic,readonly) UILabel *detailsLabel;
/**
 * 在这个label下面放置一个按钮 仅仅 a target/action 被添加，才是可用的
 */
@property (strong,nonatomic,readonly) UIButton *button;

@end

@protocol FCProgressHUDDelegate <NSObject>

@optional
/**
 * 当hud完全从屏幕中消失响应这个方法
 */
- (void)hudWasHidden:(FCProgressHUD *)hud;


@end

/**
 * 这个进度视图通过填充一个圆来显示明确的视图
 */

@interface FCRoundProgressView : UIView

/**
 * Progress (0.0 to 1.0)
 */
@property (nonatomic, assign) float progress;
/**
 * 指示进度的颜色
 * 默认是白色
 */
@property (nonatomic, strong) UIColor *progressTintColor;

/**
 *  Indicator 背景(无进度) 颜色
 *  仅仅应用在比ios7老的版本
 *  默认 半透明(translucent)的白色（alpha  0.1）
 */

@property (nonatomic, strong) UIColor  *backgroundTintColor;
/**
 *  展示方式 No ＝圆形物  Yes  为环形  默认为圆形物
 */
@property (nonatomic, assign, getter=isAnnular) BOOL annular;

@end

/**
 * 扁平的进度条
 */
@interface FCBarProgressView : UIView
/**
 * progress (0.0 to 1.0)
 */
@property (nonatomic, assign) float progress;
/**
 * 边界线的颜色
 * 默认是白色
 */
@property (nonatomic, strong) UIColor *lineColor;

/**
 * 背景颜色
 * 默认是clearColor
 */
@property (nonatomic, strong) UIColor *progressRemainingColor;
/**
 * 进度颜色
 * 默认是白色
 */
@property (nonatomic, strong) UIColor *progressColor;

@end
@interface FCBackgroundView : UIView

/**
 *The background style
 *Defaults  to MBProgressHUDBackgroundStyleBlur on ios7 or later MBProgressHUDBackgroundStyleSolidColor
 otherwise.
 @note   due to ios7 not supporting UIVisualEffectView, the blur effect differs slightly between ios7  and later  versions

 */

@property(nonatomic)  FCProgressHUDBackgroundStyle style;

/**
 * 背景颜色或者模糊着色
 */
@property (nonatomic, strong) UIColor *color;

@end


@interface FCProgressHUD (Deprecated)
/**
 在我们编写OC代码的时候经常可以看到这样的警告 一个是方法被废弃了，一个是我们输入的参数不合理。我们知道 编译时异常，要比运行时异常好的多。FOUNDATION_EXPORT void NSLog(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);
 //注意后方的宏定义，我们点击过去之后查看一下
 #define NS_FORMAT_FUNCTION(F,A) __attribute__((format(__NSString__, F, A)))
 FOUNDATION_EXPORT void NSLog(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);
 //注意后方的宏定义，我们点击过去之后查看一下
 #define NS_FORMAT_FUNCTION(F,A) __attribute__((format(__NSString__, F, A)))
 *这句的意思是，参数的第F位是格式化字符串，从A位开始我们开始检查
 *__attribute__ 书写特征是 前后都有两个下划线，并切后面会紧跟一对原括弧，括弧里面是相应的
 __attribute__ 参数。
 *__attribute__((format())) extern int my_printf (void *my_object, const char *my_format, ...) __attribute__((format(printf, 2, 3)));
 这个的意思是第二个参数my_format参数是一个格式化字符串，从第三个参数开始检查
 在Objective-C 中我们使用__string来禁代替format  NSString +stringWithFormat: 和 NSLog()都是一个很好的例子
 *__attribute__((noreturn))
 一些标准库函数,如中止和退出,不能返回。
 noreturn属性指定了其他函数,它永远不会返回。
 *__attribute__((availability))
 此种用法我们间的也比较多，多用于废弃方法
 - (CGSize)sizeWithFont:(UIFont *)font NS_DEPRECATED_IOS(2_0, 7_0, "Use -sizeWithAttributes:") __TVOS_PROHIBITED;
 //来看一下 后边的宏
 #define NS_DEPRECATED_IOS(_iosIntro, _iosDep, ...) CF_DEPRECATED_IOS(_iosIntro, _iosDep, __VA_ARGS__)
 
 define CF_DEPRECATED_IOS(_iosIntro, _iosDep, ...) __attribute__((availability(ios,introduced=_iosIntro,deprecated=_iosDep,message="" __VA_ARGS__)))
 //宏展开以后如下
 __attribute__((availability(ios,introduced=2_0,deprecated=7_0,message=""__VA_ARGS__)));
 //iOS即是iOS平台
 //introduced 从哪个版本开始使用
 //deprecated 从哪个版本开始弃用
 //警告的消息
 //其实还可以再加一个参数例如
 void f(void) __attribute__((availability(macosx,introduced=10.4,deprecated=10.6,obsoleted=10.7)));
 //obsoleted完全禁止使用的版本
 */
+ (NSArray *)allHUDsForView:(UIView *)view __attribute__((deprecated("Store references when using more than one HUD per view.")));
+ (NSUInteger)hideAllHUDsForView:(UIView *)view animated:(BOOL)animated __attribute__((deprecated("Store references when using more than one HUD per view")));

- (id)initWithWindow:(UIWindow *)window __attribute__((deprecated("Use initWithView: instead.")));

- (void)show:(BOOL)animated __attribute__((deprecated("Use showAnimated: instead.")));
- (void)hide:(BOOL)animated __attribute__((deprecated("Use hideAnimated: instead.")));
- (void)hide:(BOOL)animated afterDelay:(NSTimeInterval)delay __attribute__((deprecated("Use hideAnimated: afterDelay: instead.")));

- (void)showWhileExecuting:(SEL)method onTarget:(id)target withObject:(id)object animated:(BOOL)animated __attribute__((deprecated("Use GCD directly")));
- (void)showAnimated:(BOOL)animated whileExecutingBlock:(dispatch_block_t)block __attribute__((deprecated("Use GCD directly")));
- (void)showAnimated:(BOOL)animated whileExecutingBlock:(dispatch_block_t)block completionBlock:(nullable FCProgressHUDCompletionBlock)completion __attribute__((deprecated("Use GCD directly.")));

- (void)showAnimated:(BOOL)animated whileExecutingBlock:(dispatch_block_t)block onQueue:(dispatch_queue_t)queue __attribute__((deprecated("Use GCD directly.")));
- (void)showAnimated:(BOOL)animated whileExecutingBlock:(dispatch_block_t)block onQueue:(dispatch_queue_t)queue  competionBlock:(nullable  FCProgressHUDCompletionBlock)completion __attribute__((deprecated("Use GCD directly.")));


@property (assign) BOOL taskInProgress __attribute__((deprecated("No longer Need")));


@property (nonatomic, copy) NSString *labelText __attribute__((deprecated("Use label.text instead.")));
@property (nonatomic, strong) UIFont *labelFont __attribute__((deprecated("Use label.font instead.")));
@property (nonatomic, strong) UIColor *labelColor __attribute__((deprecated("Use label.textColor instead.")));

@property (nonatomic, copy) NSString *detailsLabelText __attribute__((deprecated("Use detailsLabel.text instead.")));
@property (nonatomic, strong) UIFont *detailsLabelFont __attribute__((deprecated("Use detailsLabel.font instead.")));
@property (nonatomic, strong) UIColor *detailsLabelColor __attribute__((deprecated("Use detailsLabel.textColor instead.")));

@property (nonatomic, assign) CGFloat opacity __attribute__((deprecated("Customize bezelView properties instead.")));
@property (nonatomic, strong) UIColor *color __attribute__((deprecated("Customize the bezelView color instead.")));
@property (nonatomic, assign) CGFloat xOffset __attribute__((deprecated("Set offset.x instead.")));
@property (nonatomic, assign) CGFloat yOffset __attribute__((deprecated("Set offset.y instead.")));
@property (nonatomic, assign) CGFloat cornerRadius __attribute__((deprecated("Set bezelView.layer.cornerRadius instead.")));
@property (nonatomic, assign) BOOL dimBackground __attribute__((deprecated("Customize HUD background properties instead.")));
@property (strong, nonatomic) UIColor *activityIndicatorColor __attribute__((deprecated("Use UIAppearance to customize UIActivityIndicatorView. E.g.: [UIActivityIndicatorView appearanceWhenContainedIn:[MBProgressHUD class], nil].color = [UIColor redColor];")));

@property (atomic, assign,readonly) CGSize size __attribute__((deprecated("Get the bezelView.frame.size instead.")));
@end
NS_ASSUME_NONNULL_END
