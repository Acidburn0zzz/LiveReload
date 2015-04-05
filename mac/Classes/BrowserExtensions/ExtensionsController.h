
#import <Foundation/Foundation.h>


@interface ExtensionsController : NSObject {
}

+ (ExtensionsController *)sharedExtensionsController;

- (IBAction)installSafariExtension:(id)sender;
- (IBAction)installChromeExtension:(id)sender;
- (IBAction)installFirefoxExtension:(id)sender;
- (IBAction)installExtension:(id)sender;

@end
