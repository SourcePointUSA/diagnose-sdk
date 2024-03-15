//
//  SPDiagnoseSDK.m
//  SPDiagnoseSDK
//
//  Created by Andre Herculano on 15.03.24.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <SPDiagnoseSDK/SPDiagnoseSDK-Swift.h>


/// Library constructor to observe `UIApplicationDidFinishLaunchingNotification` immediately on app launch.
/// Calls `applicationDidFinishLaunching` on Wormholy class to initialize Wormholy.
/// This is an alternative to a +initialize in Objective-C.
//static void __attribute__ ((constructor)) diagnose_constructor(void) {
//}

// A helper for method swizzling
__attribute__((warn_unused_result)) IMP DiagnoseReplaceMethod(SEL selector,
                                                              IMP newImpl,
                                                              Class affectedClass,
                                                              BOOL isClassMethod)
{
    Method origMethod = isClassMethod ? class_getClassMethod(affectedClass, selector) : class_getInstanceMethod(affectedClass, selector);
    IMP origImpl = method_getImplementation(origMethod);

    if (!class_addMethod(isClassMethod ? object_getClass(affectedClass) : affectedClass, selector, newImpl, method_getTypeEncoding(origMethod)))
    {
        method_setImplementation(origMethod, newImpl);
    }

    return origImpl;
}

typedef NSURLSessionConfiguration*(*SessionConfigConstructor)(id,SEL);
static SessionConfigConstructor orig_defaultSessionConfiguration;
static SessionConfigConstructor orig_ephemeralSessionConfiguration;

static NSURLSessionConfiguration* Diagnose_defaultSessionConfiguration(id self, SEL _cmd)
{
    NSURLSessionConfiguration* config = orig_defaultSessionConfiguration(self,_cmd); // call original method

    [SPDiagnose injectLoggerWithConfiguration:config];
    return config;
}

static NSURLSessionConfiguration* Diagnose_ephemeralSessionConfiguration(id self, SEL _cmd)
{
    NSURLSessionConfiguration* config = orig_ephemeralSessionConfiguration(self,_cmd); // call original method

    [SPDiagnose injectLoggerWithConfiguration:config];
    return config;
}

__attribute__((constructor)) static void sessionConfigurationInjectEntry(void) {

    orig_defaultSessionConfiguration = (SessionConfigConstructor)DiagnoseReplaceMethod(@selector(defaultSessionConfiguration),
                                                                                       (IMP)Diagnose_defaultSessionConfiguration,
                                                                                       [NSURLSessionConfiguration class],
                                                                                       YES);

    orig_ephemeralSessionConfiguration = (SessionConfigConstructor)DiagnoseReplaceMethod(@selector(ephemeralSessionConfiguration),
                                                                                         (IMP)Diagnose_ephemeralSessionConfiguration,
                                                                                         [NSURLSessionConfiguration class],
                                                                                         YES);
}
