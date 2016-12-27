//
//  FCProgressHUD+MJ.h
//  FCProgressHUD
//
//  Created by 凡小超 on 2016/10/12.
//  Copyright © 2016年 凡小超. All rights reserved.
//

#import "FCProgressHUD.h"

@interface FCProgressHUD (MJ)


+ (void)showSuccess:(NSString *)success toView:(UIView *)view;
+ (void)showError:(NSString *)error toView:(UIView *)view;

+ (FCProgressHUD *)showMessage:(NSString *)message toView:(UIView *)view;


+ (void)showSuccess:(NSString *)success;
+ (void)showError:(NSString *)error;

+ (FCProgressHUD *)showMessage:(NSString *)message;

+ (void)hideHUDForView:(UIView *)view;
+ (void)hideHUD;


@end
