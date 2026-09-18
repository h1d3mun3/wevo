//
//  WevoExceptionCatcher.m
//  WevoTests
//
//  DIAGNOSTIC ONLY — NOT FOR MERGE. See WevoExceptionCatcher.h.
//

#import "WevoExceptionCatcher.h"
#import <objc/objc-exception.h>
#import <fcntl.h>
#import <unistd.h>

static objc_exception_preprocessor gPreviousPreprocessor = NULL;
static char gReportPath[1024] = {0};
static void (^gObserver)(NSString *, NSString *, NSString *, NSArray<NSString *> *) = nil;

/// Writes with POSIX calls rather than Foundation: this runs on a thread that is about to be
/// torn down, so the fewer allocations the better.
static void WevoWriteReport(const char *text) {
    if (gReportPath[0] == '\0') return;
    int fd = open(gReportPath, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) return;
    size_t len = strlen(text);
    ssize_t written = 0;
    while (written < (ssize_t)len) {
        ssize_t n = write(fd, text + written, len - written);
        if (n <= 0) break;
        written += n;
    }
    close(fd);
}

static id WevoExceptionPreprocessor(id exception) {
    if ([exception isKindOfClass:[NSException class]]) {
        NSException *e = (NSException *)exception;
        NSString *text = [NSString stringWithFormat:
            @"===== RAISED OBJC EXCEPTION (objc_setExceptionPreprocessor) =====\n"
             "name    : %@\n"
             "reason  : %@\n"
             "userInfo: %@\n"
             "stack   :\n%@\n"
             "================================================================\n",
            e.name ?: @"(nil)",
            e.reason ?: @"(nil)",
            e.userInfo ?: @{},
            [[NSThread callStackSymbols] componentsJoinedByString:@"\n"]];
        WevoWriteReport(text.UTF8String);
        // Runs on the raising thread while the test is still current, so an Issue recorded here
        // reaches the result stream even though the process is about to abort.
        if (gObserver) {
            gObserver(e.name ?: @"(nil)", e.reason ?: @"(nil)",
                      [NSString stringWithFormat:@"%@", e.userInfo ?: @{}],
                      [NSThread callStackSymbols]);
        }
    }
    return gPreviousPreprocessor ? gPreviousPreprocessor(exception) : exception;
}

void WevoInstallExceptionPreprocessor(NSString *path,
                                      void (^_Nullable observer)(NSString *name, NSString *reason,
                                                                 NSString *userInfo,
                                                                 NSArray<NSString *> *stack)) {
    static BOOL installed = NO;
    strlcpy(gReportPath, path.fileSystemRepresentation, sizeof(gReportPath));
    gObserver = observer;
    if (installed) return;
    installed = YES;
    gPreviousPreprocessor = objc_setExceptionPreprocessor(&WevoExceptionPreprocessor);
}

NSException *_Nullable WevoCatchNSException(NS_NOESCAPE void (^block)(void)) {
    @try {
        block();
        return nil;
    } @catch (NSException *exception) {
        return exception;
    }
}
