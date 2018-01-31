//
//  CalibrationViewController.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "ConfigurationViewController.h"
#import "Configuration.h"
#import "ConfigurationTableViewCell.h"
#import "Device.h"

@interface ConfigurationViewController ()
    @property int index;
    @property (weak) IBOutlet UITableView* table;
    @property (strong) NSMutableDictionary* selectionData;
    @property BOOL usedGVC;
    @property (strong) Class configuratedClass;
@end

@implementation ConfigurationViewController

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    self.index=0;
    _selectionData = [NSMutableDictionary new];
    _usedGVC=NO;
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    self.index=0;
    _selectionData = [NSMutableDictionary new];
    _usedGVC=NO;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _table.rowHeight = UITableViewAutomaticDimension;
    _table.estimatedRowHeight = 100.0;
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewWillAppear:(BOOL)animated {
    self.navigationItem.title=[NSString stringWithFormat:NSLocalizedString(@"Configuration %d/%lu",@"Configuration Headline"),(_index+1),(unsigned long)[[[Configuration instance] neededConfigurationSteps] count]];
}
-(void)viewDidAppear:(BOOL)animated {
    if(_usedGVC)
    {
        if([[[Configuration instance] neededConfigurationSteps] count] == _index+1) {
            [self shouldPerformSegueWithIdentifier:@"drillDown" sender:self];//MIND the difference here!
        } else {
            [_selectionData setObject:_configuratedClass forKey:[[[Configuration instance] neededConfigurationSteps] objectAtIndex:_index]];
            [self performSegueWithIdentifier:@"drillDown" sender:self];
        }
        return;
    }
    [super viewDidAppear:animated];
}

#pragma mark - Navigation

-(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if([@"drillDown" isEqualToString:identifier]) {
        if([[[Configuration instance] neededConfigurationSteps] count] == _index+1) {
            identifier = @"unwind";
            if(!_usedGVC) {
                UIViewController* gvc = [_configuratedClass configurationViewController];
                if(gvc) {
                    _usedGVC=YES;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:gvc];
                        //[self.navigationController.parentViewController presentViewController:nav animated:YES completion:nil];
                        [self presentViewController:nav animated:YES completion:nil];
                    });
                    return NO;
                }
            }
        }

        if(!_usedGVC) {
            UIViewController* gvc = [_configuratedClass configurationViewController];
            if(gvc) {
                _usedGVC=YES;
                dispatch_async(dispatch_get_main_queue(), ^{
                    UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:gvc];
                    [self presentViewController:nav animated:YES completion:nil];
                });
                return NO;
            }
        }
        [_selectionData setObject:_configuratedClass forKey:[[[Configuration instance] neededConfigurationSteps] objectAtIndex:_index]];
        if([[[Configuration instance] neededConfigurationSteps] count] == _index+1) {
            [[Configuration instance] saveNeededSteps:_selectionData];
            dispatch_async(dispatch_get_main_queue(), ^{
                //[self performSegueWithIdentifier:@"unwind" sender:self];
                [self.navigationController dismissViewControllerAnimated:YES completion:nil];
            });
            return NO;
        }
    }
    return YES;
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if([segue.destinationViewController isKindOfClass:[self class]]) {
        [((ConfigurationViewController*)segue.destinationViewController).selectionData addEntriesFromDictionary:_selectionData];
        ((ConfigurationViewController*)segue.destinationViewController).index = _index+1;
    }
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[Configuration instance] optionsForStep:[[[[Configuration instance] neededConfigurationSteps] objectAtIndex:_index] intValue]];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ConfigurationTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"configurationCell"];
    cell.headline.text =[[Configuration instance] optionHeadline:(int)indexPath.row forStep:[[[[Configuration instance] neededConfigurationSteps] objectAtIndex:_index] intValue]];
    cell.text.text = [[Configuration instance] optionText:(int)indexPath.row forStep:[[[[Configuration instance] neededConfigurationSteps] objectAtIndex:_index] intValue]];
    return cell;
}
-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    _configuratedClass = [[Configuration instance] option:(int)indexPath.row
                                                  forStep:[[[[Configuration instance] neededConfigurationSteps] objectAtIndex:_index] intValue]];
    return indexPath;
}
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}
@end
