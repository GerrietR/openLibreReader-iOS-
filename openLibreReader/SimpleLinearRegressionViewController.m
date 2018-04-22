//
//  SimpleLinearRegressionViewController.m
//  openLibreReader
//
//  Created by Gerriet Reents on 31.12.17.
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "SimpleLinearRegressionViewController.h"
#import "SimpleLinearRegressionCalibration.h"
#import "Configuration.h"
#import "Storage.h"
#import <CommonCrypto/CommonDigest.h>

@interface SimpleLinearRegressionViewController ()
@property (nonatomic, strong) IBOutlet UITextField* slope;
@property (nonatomic, strong) IBOutlet UITextField* intercept;
@property (nonatomic, strong) IBOutlet UITextField* bloodglucose;
@property (nonatomic, strong) IBOutlet UILabel* delay;
@property (weak, nonatomic) IBOutlet UIStepper *delayStepper;
@property (weak, nonatomic) IBOutlet UIButton *addCalibration;
@property (weak, nonatomic) IBOutlet UIProgressView *calibrationProgress;
@property (weak, nonatomic) IBOutlet UILabel *calibrationStatus;
@property (weak, nonatomic) IBOutlet UIButton *cancelCalibration;
@property (weak, nonatomic) IBOutlet UIButton *calculateButton;
@property (weak, nonatomic) IBOutlet UILabel *statistics;
@property (weak, nonatomic) IBOutlet UILabel *displayUnit;
@property (nonatomic, strong) IBOutlet UIButton* forget;
@property NSTimer *timer; // retain?
@end

// todo: this file contains some copy&pasted stuff. A cleanup is needed!

@implementation SimpleLinearRegressionViewController

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
    _calculateButton.layer.cornerRadius = 4;
    _forget.layer.cornerRadius = 4;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewWillAppear:(BOOL)animated {
    // todo: should we have an own calibrationData storage?
    NSMutableDictionary* data = [[Storage instance] deviceData];
    _slope.text = [data objectForKey:@"SimpleLinearRegressionSlope"];
    if ([_slope.text isEqualToString:@""])
    {
        _slope.text = [NSString stringWithFormat:@"%.2lf", 1.08]; // some default value from experience
    }
    _intercept.text = [data objectForKey:@"SimpleLinearRegressionIntercept"];
    if ([_intercept.text isEqualToString:@""])
    {
        _intercept.text = [NSString stringWithFormat:@"%.2lf", -19.86]; // some default value from experience
    }
    _bloodglucose.text=@"";
    _delay.text=@"20m";
    [self updateUI];
}

- (void)viewWillDisappear:(BOOL)animated {
    if (_timer)
    {
        [_timer invalidate];
        _timer = nil;
    }
}

-(void)viewDidDisappear:(BOOL)animated {
    for(int i = 0; i < 100; i++) {
        [[self.view viewWithTag:i] resignFirstResponder];
    }
}

-(void)updateUI {
    SimpleLinearRegressionCalibration* c = [SimpleLinearRegressionCalibration instance];
    float progress = 0.0;
    NSTimeInterval remaining = 0.0;
    if ([c isCalibrating:&progress remaining:&remaining ])
    {
        _addCalibration.enabled = false;
        _delayStepper.enabled = false;
        _bloodglucose.enabled = false;
        if([[[[Configuration instance] displayUnit] lowercaseString] isEqualToString:@"mmol"]) {
            NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
            [numberFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US"]];
            NSNumber *number = [numberFormatter numberFromString:[[Configuration instance] valueWithoutUnit:[c getCurrentBG]]];
            [numberFormatter setLocale:[NSLocale currentLocale]];
            [numberFormatter setMaximumFractionDigits:1];
            _bloodglucose.text = [NSString stringWithFormat:@"%@", [numberFormatter stringFromNumber:number]];
        }
        else
        {
            _bloodglucose.text = [NSString stringWithFormat:@"%.0lf", [c getCurrentBG]];
        }
        _cancelCalibration.enabled = true;
        _calibrationProgress.hidden = false;
        _calibrationProgress.progress = progress;
        if (progress < 1.0)
        {
            NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
            formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
            formatter.includesApproximationPhrase = YES;
            formatter.includesTimeRemainingPhrase = YES;
            formatter.allowedUnits = NSCalendarUnitMinute;
            NSString* remainingString = [formatter stringFromTimeInterval:remaining];
            NSString* delayingString = NSLocalizedString(@"Delaying",@"CalibrationMethod.StatusDelay");
            _calibrationStatus.text = [NSString stringWithFormat:@"%@ (%@)", delayingString, remainingString];
        } else {
            _calibrationStatus.text= NSLocalizedString(@"Waiting for next value",@"CalibrationMethod.StatusWait");
        }
        _calibrationStatus.hidden = false;
        _calculateButton.enabled = false;
        if (!_timer) {
            _timer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                      target:self
                                                    selector:@selector(_timerFired:)
                                                    userInfo:nil
                                                     repeats:YES];
        }
    }
    else
    {
        _addCalibration.enabled = true;
        _delayStepper.enabled = true;
        _bloodglucose.enabled = true;
        _cancelCalibration.enabled = false;
        _calibrationProgress.hidden = true;
        _calibrationStatus.hidden = true;
        if ([c getNumberOfCalibration] >= 2)
        {
            _calculateButton.enabled = true;
            _calculateButton.backgroundColor = _calculateButton.tintColor;
        }
        else
        {
            _calculateButton.enabled = false;
            _calculateButton.backgroundColor = UIColor.lightGrayColor;
        }
        if (_timer)
        {
            [_timer invalidate];
            _timer = nil;
        }
    }
    _statistics.text =[ NSString stringWithFormat:@"%@: %lu", NSLocalizedString(@"Number of Calibrations",@"CalibrationMethod.Statistics"), [c getNumberOfCalibration]];
    _displayUnit.text = [[Configuration instance] displayUnit];
}

- (void)_timerFired:(NSTimer *)timer {
    [self updateUI];
}


-(IBAction)next:(id)sender {
  /*  SimpleLinearRegressionCalibration* model = [SimpleLinearRegressionCalibration instance];
    if(sender == _slope) {
        double v = [[_slope.text stringByReplacingOccurrencesOfString:@"," withString:@"."] doubleValue];
        [model setSlope:v];
    } else if(sender == _intercept) {
        double v = [[_intercept.text stringByReplacingOccurrencesOfString:@"," withString:@"."] doubleValue];
        [model setIntercept:v];
    }*/
}

- (IBAction)cancelCalibration:(id)sender {
    SimpleLinearRegressionCalibration* c = [SimpleLinearRegressionCalibration instance];
    [c cancelCalibration];
    [self updateUI];
}

- (IBAction)addCalibration:(id)sender {
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setLocale:[NSLocale currentLocale]];
    SimpleLinearRegressionCalibration* c = [SimpleLinearRegressionCalibration instance];
    NSNumber *number = [numberFormatter numberFromString: _bloodglucose.text];
    float bloodglucose = [number floatValue];
    if([[[[Configuration instance] displayUnit] lowercaseString] isEqualToString:@"mmol"]) {
        bloodglucose = [[Configuration instance] fromValue:bloodglucose];
    }
    [c startCalibration:bloodglucose delay:_delayStepper.value ];
    if (!_timer) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                  target:self
                                                selector:@selector(_timerFired:)
                                                userInfo:nil
                                                 repeats:YES];
    }
}
- (IBAction)calculateRegressionParameters:(id)sender {
    SimpleLinearRegressionCalibration* c = [SimpleLinearRegressionCalibration instance];
    double intercept = 0.0;
    double slope = 0.0;
    [c linearRegression:&slope intercept:&intercept];
    _slope.text = [NSString stringWithFormat:@"%.2lf", slope];
    _intercept.text = [NSString stringWithFormat:@"%.2lf", intercept];
}

-(IBAction)check:(id)sender {
}

- (void)dismissKeyboards {
    if (_bloodglucose.isEditing)
    {
        [_bloodglucose endEditing:YES];
    }
    if (_slope.isEditing)
    {
        [_slope endEditing:YES];
    }
    if (_intercept.isEditing)
    {
        [_intercept endEditing:YES];
    }
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self dismissKeyboards];
}

- (IBAction)stepperValueChanged:(id)sender {
    [self dismissKeyboards];
    if (sender == _delayStepper)
    {
        NSUInteger value = _delayStepper.value;
        _delay.text = [NSString stringWithFormat:@"%02lum", (unsigned long)value];
    }
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
    SimpleLinearRegressionCalibration* model = [SimpleLinearRegressionCalibration instance];
    
    double v = [[_slope.text stringByReplacingOccurrencesOfString:@"," withString:@"."] doubleValue];
    [model setSlope:v];
    double w = [[_intercept.text stringByReplacingOccurrencesOfString:@"," withString:@"."] doubleValue];
    [model setIntercept:w];
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
    }];
    [alert addAction:cancel];
    [alert addAction:remove];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

