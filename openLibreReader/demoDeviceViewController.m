//
//  demoDeviceViewController.m
//  openLibreReader
//
//  Created by Gerriet Reents on 17.12.17.
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "demoDeviceViewController.h"
#import "Configuration.h"
#import "Storage.h"
#import <CommonCrypto/CommonDigest.h>

@interface demoDeviceViewController ()
@property (nonatomic, strong) IBOutlet UIButton* forget;
@end

@implementation demoDeviceViewController

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
}

-(void)viewDidDisappear:(BOOL)animated {
    // todo: what's happening here?
    for(int i = 0; i < 100; i++) {
        [[self.view viewWithTag:i] resignFirstResponder];
    }
    
    [[Configuration instance] reloadNSUploadService];
}

-(IBAction)next:(id)sender {
    NSMutableDictionary* data = [[Storage instance] deviceData];
    [[Storage instance] saveDeviceData:data];
}

/*
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
*/

-(IBAction)swChange:(id)sender {
    [super dismissViewControllerAnimated:YES completion:nil];
}


-(IBAction)resetConfiguration:(id)sender {
    
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Remove Device",@"blueReader.title") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel",@"blueReader.cancel") style:UIAlertActionStyleDefault handler:nil];
    
    UIAlertAction* remove = [UIAlertAction actionWithTitle:NSLocalizedString(@"Remove Device",@"blueReader.remove") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[Storage instance] setSelectedDeviceClass:nil];
        [self.navigationController popViewControllerAnimated:YES];
        [self.navigationController.tabBarController setSelectedIndex:0];
        [[NSNotificationCenter defaultCenter] postNotificationName:kConfigurationReloadNotification object:nil];
    }];
    [alert addAction:cancel];
    [alert addAction:remove];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

