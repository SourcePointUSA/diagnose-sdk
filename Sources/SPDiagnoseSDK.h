//
//  SPDiagnoseSDK.h
//  SPDiagnoseSDK
//
//  Created by Andre Herculano on 14.03.24.
//

#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "SPDiagnoseSDKSwizzler.h"

FOUNDATION_EXPORT double SPDiagnoseSDKVersionNumber;
FOUNDATION_EXPORT const unsigned char SPDiagnoseSDKVersionString[];
