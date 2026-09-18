//
//  WevoExceptionCatcher.h
//  WevoTests
//
//  DIAGNOSTIC ONLY — NOT FOR MERGE.
//
//  The NSException we are chasing is raised inside a block that CoreData runs through
//  -[NSManagedObjectContext performBlockAndWait:]. It cannot escape libdispatch's
//  _dispatch_client_callout, which calls std::terminate on any exception crossing it, so
//  @try/@catch at the call site never sees it and NSSetUncaughtExceptionHandler is never
//  reached either.
//
//  objc_setExceptionPreprocessor runs inside objc_exception_throw, before any unwinding,
//  which is early enough to record the reason no matter what happens afterwards.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Records every raised ObjC exception's name and reason to `path` (last one wins), and hands
/// it to `observer` -- which runs on the raising thread, before any unwinding, so it can still
/// report into the currently running test. Idempotent.
void WevoInstallExceptionPreprocessor(NSString *path,
                                      void (^_Nullable observer)(NSString *name, NSString *reason,
                                                                 NSString *userInfo,
                                                                 NSArray<NSString *> *stack));

/// Runs `block`, returning the NSException it raised, or nil. Only catches exceptions that
/// can actually unwind to here -- kept for the self-tests.
NSException *_Nullable WevoCatchNSException(NS_NOESCAPE void (^block)(void));

NS_ASSUME_NONNULL_END
