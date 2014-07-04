
#import "RunScriptActionRow.h"
#import "LiveReload-Swift-x.h"
#import "ATMacViewCreation.h"
#import "ATAutolayout.h"

@implementation RunScriptActionRow

- (void)loadContent {
    [super loadContent];

    //    self.runLabel = [[NSTextField staticLabelWithString:@"Run"] addedToView:self];
    //    _commandField = [[NSTextField editableField] addedToView:self];
    self.filterPopUp = [[[[NSPopUpButton popUpButton] withBezelStyle:NSRoundRectBezelStyle] withTarget:self action:@selector(filterOptionSelected:)] addedToView:self];

    [self addConstraintsWithVisualFormat:@"|-indentL2-[checkbox(>=200)]-[filterPopUp(>=120)]-(>=buttonBarGapMin)-[optionsButton]-buttonGap-[removeButton]|" options:NSLayoutFormatAlignAllCenterY];
    [self addFullHeightConstraintsForSubview:self.filterPopUp];

    //    [self alignView:self.checkbox toColumnNamed:@"actionRightEdge" alignment:ATStackViewColumnAlignmentTrailing];
    [self alignView:self.filterPopUp toColumnNamed:@"filter"];

    [self.checkbox bind:@"value" toObject:self.representedObject withKeyPath:@"enabled" options:nil];
}

- (void)loadOptionsIntoView:(LROptionsView *)container {
//    _commandLineField = [NSTextField editableField];
//    [_commandLineField makeHeightEqualTo:100];
//    [container addOptionView:_commandLineField label:NSLocalizedString(@"Command line:", nil) flags:LROptionsViewFlagsLabelAlignmentTop];
//
//    [_commandLineField bind:@"value" toObject:self.representedObject withKeyPath:@"command" options:nil];
}

- (void)updateContent {
    [super updateContent];

    UserScriptAction *action = self.representedObject;
    [self.checkbox setTitle:action.label];
}

- (void)updateFilterOptions {
    [self updateFilterOptionsPopUp:self.filterPopUp selectedOption:self.action.inputFilterOption];
}

- (IBAction)filterOptionSelected:(NSPopUpButton *)sender {
    FilterOption *filterOption = sender.selectedItem.representedObject;
    self.action.inputFilterOption = filterOption;
}

+ (NSArray *)representedObjectKeyPathsToObserve {
    return @[@"command", @"inputFilterOption"];
}

@end
