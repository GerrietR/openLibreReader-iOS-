//
//  SecondViewController.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "nightscoutDeviceViewController.h"
#import "Configuration.h"
#import "Storage.h"
#import <CommonCrypto/CommonDigest.h>

@interface nightscoutDeviceViewController ()
    @property (nonatomic, strong) IBOutlet UITextField* url;
    @property (nonatomic, strong) IBOutlet UITextField* password;
@property (nonatomic, strong) IBOutlet UIButton* check;
@property (nonatomic, strong) IBOutlet UIButton* forget;
@end

@implementation nightscoutDeviceViewController

-(instancetype)init {
    self = [super init];
    if(self)
        _hideOnSuccess = NO;
    return self;
}
-(instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if(self)
        _hideOnSuccess = NO;
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
    NSMutableDictionary* data = [[Storage instance] deviceData];
    _url.text = [data objectForKey:@"nightscoutURL"];
    _password.text = [data objectForKey:@"nightscoutHash"];
    if(_hideOnSuccess)
        _forget.hidden = YES;
}

-(void)viewDidDisappear:(BOOL)animated {
    for(int i = 0; i < 100; i++) {
        [[self.view viewWithTag:i] resignFirstResponder];
    }

    [[Configuration instance] reloadNSUploadService];
}

+ (NSString *)sha1:(NSString*)input
{
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];

    CC_SHA1(data.bytes, (unsigned int)data.length, digest);

    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    return output;
}
-(IBAction)next:(id)sender {
    NSMutableDictionary* data = [[Storage instance] deviceData];
    if(sender == _url) {
        NSLog(@"got %@ as new value for url",_url.text);
        NSURL* url = [NSURL URLWithString:_url.text];
        NSString* u = nil;
        if([[url port] intValue]!=0) {
            u = [NSString stringWithFormat:@"%@://%@:%d",[url scheme],[url host],[[url port] intValue]];
        } else {
            u = [NSString stringWithFormat:@"%@://%@",[url scheme],[url host]];
        }
        [data setObject:u forKey:@"nightscoutURL"];
    } else if(sender == _password) {
        NSLog(@"got new value for password");
        NSString* l = [nightscoutDeviceViewController sha1:_password.text];
        [data setObject:l forKey:@"nightscoutHash"];
    }
    [[Storage instance] saveDeviceData:data];
}
-(IBAction)check:(id)sender {
    [_password resignFirstResponder];
    [_url resignFirstResponder];

    [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:NO block:^(NSTimer * _Nonnull timer) {

        if(_check.enabled) {
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
            [request setHTTPMethod:@"GET"];
            [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
            NSMutableDictionary* data = [[Storage instance] deviceData];

            [request addValue:[data objectForKey:@"nightscoutHash"] forHTTPHeaderField:@"api-secret"];
            [request setURL:[NSURL URLWithString:[[data objectForKey:@"nightscoutURL"] stringByAppendingString:@"/api/v1/verifyauth"]]];

            NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration
                                                        defaultSessionConfiguration];
            NSLog(@"requesting: %@",[request description]);
            NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
            NSURLSessionDataTask *postDataTask = [session dataTaskWithRequest:request
                                                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
                                                  {
                                                      UIAlertController* alert = nil;
                                                      BOOL canHide = NO;
                                                      if (!error && [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] rangeOfString:@"UNAUTHORIZED"].length==0) {
                                                          alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Connection Successful!",@"nsUpload.titleSuccess") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
                                                          canHide = YES;
                                                      } else {
                                                          alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Connection not Successful!",@"nsUpload.titleNoSuccess") message:NSLocalizedString(@"Please check URL and Password, please enter only the URL you would use in a Webbrowser.",@"nsUpload.failMessage") preferredStyle:UIAlertControllerStyleActionSheet];
                                                      }
                                                      UIAlertAction* cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"close",@"nsUpload.close") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                                          if(_hideOnSuccess && canHide) {
                                                              [[Configuration instance].device reload];
                                                              [super dismissViewControllerAnimated:YES completion:nil];
                                                          }
                                                      }];
                                                      [alert addAction:cancel];
                                                      [self presentViewController:alert animated:YES completion:nil];
                                                  }];
            [postDataTask resume];
        }
    }];
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
