//
//  SecondViewController.m
//  openLibreReader
//
//  Copyright © 2017 Sandra Keßler. All rights reserved.
//

#import "Report.h"
#import "Configuration.h"
#import "Storage.h"

@implementation ReportViewController

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

}

-(IBAction)sendMail:(id)sender {
    NSString *emailTitle = @"openLibreReader Report";
    NSString *messageBody = @"<<Please write your Phone type and iOS Version>>";
    NSArray *toRecipents = [NSArray arrayWithObject:@"bugs@bluetoolz.de"];

    MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
    mc.mailComposeDelegate = self;
    [mc setSubject:emailTitle];
    [mc setMessageBody:messageBody isHTML:NO];
    [mc setToRecipients:toRecipents];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentsDirectory = [paths objectAtIndex:0];

    NSString* file = [documentsDirectory stringByAppendingPathComponent:@"log.sqlite"];

    // Determine the file name and extension

    // Get the resource path and read the file using NSData
    //NSString *filePath = [[NSBundle mainBundle] pathForResource:filename ofType:extension];
    NSData *fileData = [NSData dataWithContentsOfFile:file];

    NSString* mimeType = @"application/vnd.sqlite3";

    // Add attachment
    [mc addAttachmentData:fileData mimeType:mimeType fileName:@"log.sqlite"];

    // Present mail view controller on screen
    [self presentViewController:mc animated:YES completion:NULL];

}

- (void) mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    switch (result)
    {
        case MFMailComposeResultCancelled:
            NSLog(@"Mail cancelled");
            break;
        case MFMailComposeResultSaved:
            NSLog(@"Mail saved");
            break;
        case MFMailComposeResultSent:
            NSLog(@"Mail sent");
            break;
        case MFMailComposeResultFailed:
            NSLog(@"Mail sent failure: %@", [error localizedDescription]);
            break;
        default:
            break;
    }

    // Close the Mail Interface
    [self dismissViewControllerAnimated:YES completion:NULL];
}
@end
