
#import "CompilationOptions.h"
#import "FileCompilationOptions.h"
#import "Compiler.h"

#import "ATFunctionalStyle.h"


@implementation CompilationOptions

@synthesize compiler=_compiler;
@synthesize additionalArguments=_additionalArguments;
@synthesize enabled=_enabled;


#pragma mark init/dealloc

- (id)initWithCompiler:(Compiler *)compiler memento:(NSDictionary *)memento {
    self = [super init];
    if (self) {
        _compiler = [compiler retain];
        _globalOptions = [[NSMutableDictionary alloc] init];
        _fileOptions = [[NSMutableDictionary alloc] init];

        id raw = [memento objectForKey:@"options"];
        if (raw) {
            [_globalOptions setValuesForKeysWithDictionary:raw];
        }

        raw = [memento objectForKey:@"files"];
        if (raw) {
            [raw enumerateKeysAndObjectsUsingBlock:^(id filePath, id fileMemento, BOOL *stop) {
                [_fileOptions setObject:[[[FileCompilationOptions alloc] initWithFile:filePath memento:fileMemento] autorelease] forKey:filePath];
            }];
        }

        raw = [memento objectForKey:@"additionalArguments"];
        if (raw) {
            _additionalArguments = [raw copy];
        } else {
            _additionalArguments = @"";
        }

        raw = [memento objectForKey:@"enabled2"];
        if (raw) {
            _enabled = [raw boolValue];
        } else if (!_compiler.optional) {
            _enabled = YES;
        } else if (!!(raw = [memento objectForKey:@"enabled"])) {
            _enabled = [raw boolValue];
        } else {
            _enabled = NO;
        }
    }
    return self;
}

- (void)dealloc {
    [_compiler release], _compiler = nil;
    [_additionalArguments release], _additionalArguments = nil;
    [_globalOptions release], _globalOptions = nil;
    [_fileOptions release], _fileOptions = nil;
    [super dealloc];
}


#pragma mark - Persistence

- (NSDictionary *)memento {
    return [NSDictionary dictionaryWithObjectsAndKeys:_globalOptions, @"options", [_fileOptions dictionaryByMappingValuesToSelector:@selector(memento)], @"files", _additionalArguments, @"additionalArguments", [NSNumber numberWithBool:_enabled], @"enabled", [NSNumber numberWithBool:_enabled], @"enabled2", nil];
}


#pragma mark - Global options

- (void)setAdditionalArguments:(NSString *)additionalArguments {
    if (_additionalArguments != additionalArguments) {
        [_additionalArguments release];
        _additionalArguments = [additionalArguments retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SomethingChanged" object:self];
    }
}

- (id)valueForOptionIdentifier:(NSString *)optionIdentifier {
    return [_globalOptions objectForKey:optionIdentifier];
}

- (void)setValue:(id)value forOptionIdentifier:(NSString *)optionIdentifier {
    [_globalOptions setObject:value forKey:optionIdentifier];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SomethingChanged" object:self];
}



#pragma mark - File options

- (FileCompilationOptions *)optionsForFileAtPath:(NSString *)path create:(BOOL)create {
    FileCompilationOptions *result = [_fileOptions objectForKey:path];
    if (result == nil && create) {
        result = [[[FileCompilationOptions alloc] initWithFile:path memento:nil] autorelease];
        [_fileOptions setObject:result forKey:path];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SomethingChanged" object:self];
    }
    return result;
}

- (NSString *)sourcePathThatCompilesInto:(NSString *)outputPath {
    __block NSString *result = nil;
    [_fileOptions enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        FileCompilationOptions *fileOptions = obj;
        if (fileOptions.enabled && [fileOptions.destinationPath isEqualToString:outputPath]) {
            result = key;
            *stop = YES;
        }
    }];
    return result;
}

- (NSArray *)allFileOptions {
    return [_fileOptions allValues];
}


#pragma mark - Enabled

- (void)setEnabled:(BOOL)enabled {
    if (enabled != _enabled) {
        _enabled = enabled;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SomethingChanged" object:self];
    }
}

- (BOOL)isActive {
    return _enabled;
}

@end
