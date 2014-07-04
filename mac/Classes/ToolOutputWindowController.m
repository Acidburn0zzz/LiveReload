
#import "ToolOutputWindowController.h"

#import "ToolOutput.h"
#import "Project.h"

#import "EditorManager.h"
#import "EditorKit.h"

#import "Compiler.h"


enum UnparsedErrorState {
    UnparsedErrorStateNone,
    UnparsedErrorStateDefault,
    UnparsedErrorStateConnecting,
    UnparsedErrorStateFail,
    UnparsedErrorStateSuccess
};


static ToolOutputWindowController *lastOutputController = nil;

@interface ToolOutputWindowController () <NSAnimationDelegate, NSTextViewDelegate>

+ (void)setLastOutputController:(ToolOutputWindowController *)controller;

@property (nonatomic, assign) enum UnparsedErrorState state;
@property (nonatomic, readonly) NSString *key;

- (void)loadMessageForOutputType:(enum ToolOutputType)type;
- (void)hideUnparsedNotificationView;

- (void)hide:(BOOL)animated;

- (NSAttributedString *)prepareSpecialMessage:(NSString *)message url:(NSURL *)url;
- (NSAttributedString *)prepareMessageForState:(enum UnparsedErrorState)state;
- (NSURL *)errorReportURL;
- (void)sendErrorReport;

@property (weak) IBOutlet NSTextField *fileNameLabel;
@property (weak) IBOutlet NSTextField *lineNumberLabel;
@property (unsafe_unretained) IBOutlet NSTextView *unparsedNotificationView;
@property (unsafe_unretained) IBOutlet NSTextView  *messageView;
@property (weak) IBOutlet NSScrollView  *messageScroller;
@property (weak) IBOutlet NSButton *jumpToErrorButton;
@property (weak) IBOutlet NSMenuItem *showOutputMenuItem;
@property (weak) IBOutlet NSSegmentedControl *actionControl;
@property (weak) IBOutlet NSMenu *actionMenu;

@end


@implementation ToolOutputWindowController {
    ToolOutput            *_compilerOutput;

    ToolOutputWindowController *_previousWindowController;
    BOOL                   _appearing;
    BOOL                   _suicidal;

    NSArray               *_editors;

    NSInteger              _submissionResponseCode;
    NSMutableData         *_submissionResponseBody;

    NSURL                 *_specialMessageURL;

    CGRect                 _originalActionControlFrame;

    id                     _selfReferenceDuringAnimation;
}


#pragma mark -

+ (void)setLastOutputController:(ToolOutputWindowController *)controller {
    if (lastOutputController != controller) {
        lastOutputController = controller;
    }
}

+ (void)hideOutputWindowWithKey:(NSString *)key {
    if ([lastOutputController.key isEqualToString:key]) {
        [lastOutputController hide:YES];
    }
}


#pragma mark -

- (id)initWithCompilerOutput:(ToolOutput *)compilerOutput key:(NSString *)key {
    self = [super initWithWindowNibName:@"ToolOutputWindowController"];
    if (self) {
        _compilerOutput = compilerOutput;
        _key = [key copy];
    }
    return self;
}

#pragma mark -

- (void)windowDidLoad {
    [super windowDidLoad];

    self.window.level = NSFloatingWindowLevel;
//    [_unparsedNotificationView setEditable:NO];
//    [_unparsedNotificationView setDrawsBackground:NO];
//    [_unparsedNotificationView setDelegate:self];

    [_messageScroller setBorderType:NSNoBorder];
    [_messageScroller setDrawsBackground:NO];


    [self loadMessageForOutputType:_compilerOutput.type];

    [_actionControl setMenu:_actionMenu forSegment:1];

//    _originalActionControlFrame = _actionControl.frame;
    [self updateActionMenu];
}


#pragma mark -

- (NSDictionary *)slideInAnimation {
    NSScreen *primaryScreen = [[NSScreen screens] objectAtIndex:0];
    NSRect screen = primaryScreen.visibleFrame;

    NSRect frame = self.window.frame;
    frame.origin.x = screen.origin.x + screen.size.width - frame.size.width;
    frame.origin.y = screen.origin.y + screen.size.height;
    [self.window setFrame:frame display:YES];
    [self.window orderFrontRegardless];

    NSRect targetFrame = frame;
    targetFrame.origin.y -= frame.size.height;
    return [NSDictionary dictionaryWithObjectsAndKeys:self.window, NSViewAnimationTargetKey, [NSValue valueWithRect:targetFrame], NSViewAnimationEndFrameKey, nil];
}

- (NSDictionary *)slideOutAnimation {
    NSRect frame = self.window.frame;
    frame.origin.y -= frame.size.height;
    return [NSDictionary dictionaryWithObjectsAndKeys:self.window, NSViewAnimationTargetKey, [NSValue valueWithRect:frame], NSViewAnimationEndFrameKey, NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil];
}

- (NSDictionary *)fadeOutAnimation {
    return [NSDictionary dictionaryWithObjectsAndKeys:self.window, NSViewAnimationTargetKey, NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil];
}

- (void)show {
    if (lastOutputController) {
        _previousWindowController = lastOutputController;
    }
    [ToolOutputWindowController setLastOutputController:self];

    NSArray *animations;
    if (_previousWindowController) {
        if (_previousWindowController->_appearing) {
            _previousWindowController->_suicidal = YES;
            animations = [NSArray arrayWithObject:[self slideInAnimation]];
        } else {
            animations = [NSArray arrayWithObjects:[self slideInAnimation], [_previousWindowController fadeOutAnimation], nil];
        }
    } else {
        animations = [NSArray arrayWithObject:[self slideInAnimation]];
    }
    NSViewAnimation *animation = [[NSViewAnimation alloc] initWithViewAnimations:animations];
    [animation setDelegate:self];
    [animation setDuration:0.25];
    [animation startAnimation];

    _appearing = YES;
    _selfReferenceDuringAnimation = self; // will be released by animation delegate method
}

- (void)hide:(BOOL)animated {
    if (_appearing) {
        _suicidal = YES;
    } else {
        if (animated) {
             // will be released by animation delegate method

            NSViewAnimation *animation = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:[self fadeOutAnimation]]];
            [animation setDelegate:self];
            [animation setDuration:0.25];
            [animation startAnimation];
            _selfReferenceDuringAnimation = self;
        } else {
            [self.window orderOut:nil];
        }
    }
    [ToolOutputWindowController setLastOutputController:nil];
}

- (void)animationDidEnd:(NSAnimation*)animation {
    if (_appearing) {
        _appearing = NO;
        if (_previousWindowController) {
            _previousWindowController = nil;
        }
        if (_suicidal) {
            [self.window orderOut:nil];
        }
    }
    _selfReferenceDuringAnimation = nil;
}
#pragma mark -
- (void)loadMessageForOutputType:(enum ToolOutputType)type {
//    if ([_compilerOutput.output rangeOfString:@"Nothing to compile. If you're trying to start a new project, you have left off the directory argument"].location != NSNotFound) {
//        NSString *message = @"LiveReload knowledge base _[has an article about this error]_.";
//        NSURL *url = [NSURL URLWithString:@"http://help.livereload.com/kb/troubleshooting/compass-nothing-to-compile"];
//        [_unparsedNotificationView textStorage].attributedString = [self prepareSpecialMessage:message url:url];
//
//        if (type == ToolOutputTypeErrorRaw)
//            type = ToolOutputTypeError;
//        _specialMessageURL = url;
//    } else if (type != ToolOutputTypeErrorRaw) {
//        [self hideUnparsedNotificationView];
//    }

//    CGFloat maxHeight = [[[self window] screen] frame].size.height / 2;
//    CGFloat oldHeight = _messageScroller.frame.size.height;

    switch (type) {
        case ToolOutputTypeLog :
            [_messageView setString:_compilerOutput.output];
            _lineNumberLabel.textColor = [NSColor blackColor];
            _lineNumberLabel.stringValue = (_compilerOutput.line ? [NSString stringWithFormat:@"%d", (int)_compilerOutput.line] : @"");
            break;
        case ToolOutputTypeError :
            [_messageView setString:_compilerOutput.message];
            _lineNumberLabel.textColor = [NSColor blackColor];
            _lineNumberLabel.stringValue = (_compilerOutput.line ? [NSString stringWithFormat:@"%d", (int)_compilerOutput.line] : @"");
            break;
        case ToolOutputTypeErrorRaw :
            [_messageView setString:_compilerOutput.output ?: _compilerOutput.message];
            _lineNumberLabel.textColor = [NSColor redColor];
            _lineNumberLabel.stringValue = @"Unparsed";
            self.state = UnparsedErrorStateDefault;
            break;
    }
    [[_messageView textContainer] setLineFragmentPadding:0.0]; // get rid of the default margin

    _fileNameLabel.stringValue = [_compilerOutput.sourcePath lastPathComponent] ?: @"";

//    [[_messageView layoutManager] glyphRangeForTextContainer:[_messageView textContainer]]; // forces layout manager to relayout container
//    CGFloat windowHeightDelta = _messageView.frame.size.height - oldHeight;
//
//    NSRect windowFrame = self.window.frame;
//    CGFloat finalDelta = MIN(windowFrame.size.height + windowHeightDelta, maxHeight) - windowFrame.size.height;
//    windowFrame.size.height += finalDelta;
//    windowFrame.origin.y -= finalDelta;
//    [self.window setFrame:windowFrame display:YES];
}

- (void)hideUnparsedNotificationView {
//    if ([_unparsedNotificationView isHidden] == NO ) {
//        CGFloat scrollerHeightDelta = _unparsedNotificationView.frame.size.height + 10;
//
//        NSUInteger mask = self.messageScroller.autoresizingMask;
//        self.messageScroller.autoresizingMask = NSViewNotSizable;
//
//        NSRect scrollerFrame = self.messageScroller.frame;
//        scrollerFrame.size.height += scrollerHeightDelta;
//        scrollerFrame.origin.y -= scrollerHeightDelta;
//        self.messageScroller.frame = scrollerFrame;
//
//        [_unparsedNotificationView setHidden:YES];
//        self.messageScroller.autoresizingMask = mask;
//    }
}

#pragma mark -

- (IBAction)showCompilationLog:(id)sender {
    [self.showOutputMenuItem setEnabled:NO];
    [self loadMessageForOutputType:ToolOutputTypeLog];
}

#pragma mark -

- (NSString *)labelForEditor:(EKEditor *)editor {
    return [NSString stringWithFormat:@"Edit in %@", editor.displayName];
}

- (void)updateActionMenu {
    [[EditorManager sharedEditorManager] updateEditors];

    _editors = [[EditorManager sharedEditorManager].sortedEditors copy];

    EKEditor *preferredEditor = _editors[0];
    [_actionControl setLabel:[self labelForEditor:preferredEditor] forSegment:0];  // this triggers autosizing
//    [_actionControl sizeToFit];
    // move back into place
//    CGRect frame = _actionControl.frame;
//    frame.origin.x = CGRectGetMaxX(_originalActionControlFrame) - frame.size.width;
//    _actionControl.frame = frame;

    NSMenuItem *item;
    while ((item = [_actionMenu itemAtIndex:0]).action == @selector(editInEditorMenuItemClicked:)) {
        [_actionMenu removeItemAtIndex:0];
    }

    NSInteger index = 0;
    for (EKEditor *editor in _editors) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[self labelForEditor:editor] action:@selector(editInEditorMenuItemClicked:) keyEquivalent:@""];
        item.representedObject = editor;
        [_actionMenu insertItem:item atIndex:index++];
    }
}

//    CGFloat defaultWidth = _jumpToErrorButton.frame.size.width;
//    NSString *defaultText = _jumpToErrorButton.title;

//    NSSize defaultSize = [defaultText sizeWithAttributes:[NSDictionary dictionaryWithObject:[_jumpToErrorButton font] forKey:NSFontAttributeName]];
//    CGFloat padding = defaultWidth - defaultSize.width;
//
//    NSSize size = [[_jumpToErrorButton title] sizeWithAttributes:[NSDictionary dictionaryWithObject:[_jumpToErrorButton font] forKey:NSFontAttributeName]];
//    CGFloat width = ceil(size.width + padding);
//
//    NSRect frame = [_jumpToErrorButton frame];
//    CGFloat delta = width - frame.size.width;
//    frame.size.width += delta;
//    frame.origin.x -= delta;
//    [_jumpToErrorButton setFrame:frame];

- (IBAction)editInEditorMenuItemClicked:(NSMenuItem *)sender {
    EKEditor *editor = sender.representedObject;
    [self editInEditor:editor];
}

- (IBAction)jumpToError:(NSSegmentedControl *)sender {
    if (sender.selectedSegment != 0)
        return;
    [self editInEditor:_editors[0]];
}

- (void)editInEditor:(EKEditor *)editor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.05 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
        [[EditorManager sharedEditorManager] moveEditorToFrontOfMostRecentlyUsedList:editor];
        [editor jumpWithRequest:[[EKJumpRequest alloc] initWithFileURL:[NSURL fileURLWithPath:_compilerOutput.sourcePath] line:_compilerOutput.line column:EKJumpRequestValueUnknown] completionHandler:^(NSError *error) {
            if (error)
                NSLog(@"Failed to jump to the error position: %@", error.localizedDescription);
        }];
    });
    [self hide:NO];
}

#pragma mark -

- (IBAction)revealInFinder:(id)sender {
    NSString *root = nil;
    if ([_compilerOutput.project isPathInsideProject:_compilerOutput.sourcePath]) {
        root = _compilerOutput.project.path;
    }
    [[NSWorkspace sharedWorkspace] selectFile:_compilerOutput.sourcePath inFileViewerRootedAtPath:root];
}

- (IBAction)ignore:(id)sender {
    [self hide:NO];
}

#pragma mark -

- (NSAttributedString *)prepareSpecialMessage:(NSString *)message url:(NSURL *)url {
    NSString *string = message;
    NSRange range = [string rangeOfString:@"_["];
    NSAssert(range.length > 0, @"Partial hyperlink must contain _[ marker");
    NSString *prefix = [string substringToIndex:range.location];
    string = [string substringFromIndex:range.location + range.length];

    range = [string rangeOfString:@"]_"];
    NSAssert(range.length > 0, @"Partial hyperlink must contain ]_ marker");
    NSString *link = [string substringToIndex:range.location];
    NSString *suffix = [string substringFromIndex:range.location + range.length];

    NSMutableAttributedString *as = [[NSMutableAttributedString alloc] init];

    [as appendAttributedString:[[NSAttributedString alloc] initWithString:prefix]];

    [as appendAttributedString:[[NSAttributedString alloc] initWithString:link attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:NSUnderlineStyleSingle], NSUnderlineStyleAttributeName, url, NSLinkAttributeName, nil]]];

    [as appendAttributedString:[[NSAttributedString alloc] initWithString:suffix]];

    return as;
}

- (NSAttributedString *)prepareMessageForState:(enum UnparsedErrorState)state {
    NSString * message;
    NSMutableAttributedString * resultString;
    NSRange range;
    switch (state) {
        case UnparsedErrorStateDefault:
            message = @"LiveReload failed to parse this error message. Please submit the message to our server for analysis.";
            range = [message rangeOfString:@"submit the message"];
            resultString = [[NSMutableAttributedString alloc] initWithString: message];

            [resultString beginEditing];
            [resultString addAttribute:NSLinkAttributeName value:[[self errorReportURL] absoluteString] range:range];
            [resultString endEditing];
            break;

        case UnparsedErrorStateConnecting :
            message = @"Sending the error message to livereload.com…";
            resultString = [[NSMutableAttributedString alloc] initWithString:message];
            break;

        case UnparsedErrorStateFail :
            message = @"Failed to send the message to livereload.com. Retry";
            range = [message rangeOfString:@"Retry"];
            resultString = [[NSMutableAttributedString alloc] initWithString: message];

            [resultString beginEditing];
            [resultString addAttribute:NSLinkAttributeName value:[[self errorReportURL] absoluteString] range:range];
            [resultString endEditing];
            break;

        case UnparsedErrorStateSuccess :
            message = @"The error message has been sent for analysis. Thanks!";
            resultString = [[NSMutableAttributedString alloc] initWithString:message];
            break;

        default: return nil;
    }
    return resultString;
}

- (NSURL *)errorReportURL {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *internalVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://livereload.com/api/submit-error-message.php?v=%@&iv=%@&compiler=%@",
                                 [version stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                                 [internalVersion stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                                 _compilerOutput.compiler.name]];
}

- (void)sendErrorReport {
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[self errorReportURL] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval: 60.0];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[_compilerOutput.output dataUsingEncoding:NSUTF8StringEncoding]];
    [NSURLConnection connectionWithRequest:request delegate:self];
}

- (void)setState:(enum UnparsedErrorState)state {
    _state = state;
//    [[_unparsedNotificationView textStorage] setAttributedString:[self prepareMessageForState:state]];
}

#pragma mark -
#pragma mark NSTextViewDelegate
- (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)link {
    if (_specialMessageURL)
        return NO;
//    if ( textView == _unparsedNotificationView ) {
//        self.state = UnparsedErrorStateConnecting;
//        [self sendErrorReport];
//        return YES;
//    }
    return NO;
}

#pragma mark -
#pragma mark NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    _submissionResponseBody = [[NSMutableData alloc] init];
    _submissionResponseCode = httpResponse.statusCode;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_submissionResponseBody appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSString *responseString = [[NSString alloc] initWithData:_submissionResponseBody encoding:NSUTF8StringEncoding];
    if (_submissionResponseCode == 200 && [responseString isEqualToString:@"OK."]) {
        NSLog(@"Unparsable log submittion succeeded!");
        self.state = UnparsedErrorStateSuccess;
    } else {
        NSLog(@"Unparsable log submission failed with HTTP response code %ld, body:\n%@", (long)_submissionResponseCode, responseString);
        self.state = UnparsedErrorStateFail;
    }
    _submissionResponseBody = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.state = UnparsedErrorStateFail;
    NSLog(@"Unparsable log submission failed with error: %@", [error localizedDescription]);
    _submissionResponseBody = nil;
}

@end
