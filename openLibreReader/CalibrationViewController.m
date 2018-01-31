//
//  SimpleLinearRegressionViewController.m
//  openLibreReader
//
//  Created by Gerriet Reents on 31.12.17.
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "CalibrationViewController.h"
#import "Configuration.h"
#import "Storage.h"
#import <CommonCrypto/CommonDigest.h>

@interface CalibrationViewController ()
@property (nonatomic, strong) IBOutlet UIButton* forget;
@end

// todo: this file contains some copy&pasted stuff. A cleanup is needed!

@implementation CalibrationViewController

-(instancetype)init {
    self = [super init];
    return self;
}
-(instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewWillAppear:(BOOL)animated {
    // todo: should we have an own calibrationData storage?
    NSMutableDictionary* data = [[Storage instance] deviceData];

/*    if(self.navigationItem.leftBarButtonItem == nil) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(use:)];
    }*/
}

-(void)viewDidDisappear:(BOOL)animated {
    for(int i = 0; i < 100; i++) {
        [[self.view viewWithTag:i] resignFirstResponder];
    }
}

-(IBAction)next:(id)sender {
    NSMutableDictionary* data = [[Storage instance] deviceData];
    [[Storage instance] saveDeviceData:data];
}
-(IBAction)check:(id)sender {
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [textField selectAll:nil];
}

-(BOOL)textFieldShouldReturn:(UITextField*)textField {
    NSInteger nextTag = textField.tag + 1;
    UIResponder* nextResponder = [textField.superview viewWithTag:nextTag];
    if (nextResponder) {
        [nextResponder becomeFirstResponder];
    } else {
        [textField resignFirstResponder];
    }
    return NO;
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    return YES;
}

-(IBAction)use:(id)sender {
    [super dismissViewControllerAnimated:YES completion:nil];
}


-(IBAction)resetConfiguration:(id)sender {
    
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Remove calibration method",@"CalibrationMethod.title") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel",@"CalibrationMethod.cancel") style:UIAlertActionStyleDefault handler:nil];
    
    UIAlertAction* remove = [UIAlertAction actionWithTitle:NSLocalizedString(@"Remove method",@"CalibrationMethod.remove") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[Storage instance] setSelectedCalibrationClass:nil];
        [self.navigationController popViewControllerAnimated:YES];
        [self.navigationController.tabBarController setSelectedIndex:0];
        [[NSNotificationCenter defaultCenter] postNotificationName:kConfigurationReloadNotification object:nil];
        [super dismissViewControllerAnimated:YES completion:nil];

    }];
    [alert addAction:cancel];
    [alert addAction:remove];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

