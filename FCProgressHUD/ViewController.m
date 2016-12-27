//
//  ViewController.m
//  FCProgressHUD
//
//  Created by 凡小超 on 16/9/24.
//  Copyright © 2016年 凡小超. All rights reserved.
//

#import "ViewController.h"
#import "borderVIew.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.view.backgroundColor = [UIColor whiteColor];
    
    borderVIew  *border = [[borderVIew alloc]initWithFrame:CGRectMake(100, 100, 120, 20)];
    border.backgroundColor = [UIColor blueColor];
    [self.view addSubview:border];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
