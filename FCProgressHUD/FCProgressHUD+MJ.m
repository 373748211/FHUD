//
//  FCProgressHUD+MJ.m
//  FCProgressHUD
//
//  Created by 凡小超 on 2016/10/12.
//  Copyright © 2016年 凡小超. All rights reserved.
//

#import "FCProgressHUD+MJ.h"

@implementation FCProgressHUD (MJ)

#pragma mark  显示消息
+ (void)show:(NSString *)text icon:(NSString *)icon view:(UIView *)view
{
    if (view == nil)
        view = [[UIApplication sharedApplication].windows lastObject];

    //快速显示一个提示消息
    FCProgressHUD *hud = [FCProgressHUD  showHUDAddedTo:view animated:YES];
    hud.label.text =  text;
    
       hud.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:icon]];
    // 再设置模式
    hud.mode = FCProgressHUDModeCustomView;
    
    [hud  hideAnimated:YES afterDeleay:1.3];
}

#pragma mark 显示错误消息
+ (void)showError:(NSString *)error toView:(UIView *)view
{
    [self show:error icon:@"error.png" view:view];
}

+ (void)showSuccess:(NSString *)success toView:(UIView *)view
{
    [self show:success icon:@"success.png" view:view];
}

#pragma mark - 显示一条消息
+ (FCProgressHUD *)showMessage:(NSString *)message toView:(UIView *)view
{
     if (view == nil) view = [[UIApplication sharedApplication].windows lastObject];
       FCProgressHUD *hud = [FCProgressHUD showHUDAddedTo:view animated:YES];
    hud.label.text = message;
    //隐藏时候从父控件中移除
    hud.removeFromSuperViewOnHide = YES;
    
    //YEs代表需要蒙版效果
//    hud.dimBackground = NO;
    hud.backgroundView.style = FCProgressHUDBackgroundStyleSolidColor;
    hud.backgroundView.color = [UIColor clearColor];
    
    [hud  hideAnimated:YES afterDeleay:1.3];
    return hud;
}


+ (void)showSuccess:(NSString *)success
{
    [self showSuccess:success toView:nil];
}

+ (void)showError:(NSString *)error
{
    [self showError:error toView:nil];
}

+ (FCProgressHUD *)showMessage:(NSString *)message
{
    return [self showMessage:message toView:nil];
}

+ (void)hideHUDForView:(UIView *)view
{
    [self hideHUDForView:view animated:YES];                                                                                                                                                           
}

+ (void)hideHUD
{
    [self hideHUDForView:nil];
}
@end
