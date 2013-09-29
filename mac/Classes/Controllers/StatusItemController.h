
#import <Cocoa/Cocoa.h>

@class MainWindowController;
@class StatusItemView;

@interface StatusItemController : NSObject {
    NSStatusItem *_statusItem;
    StatusItemView *_statusItemView;
    MainWindowController *_mainWindowController;
}

@property(nonatomic, strong) IBOutlet MainWindowController *mainWindowController;

- (void)initStatusBarIcon;

@property(nonatomic, readonly) NSPoint statusItemPosition;

@property(nonatomic, readonly) NSView *statusItemView;

@end
