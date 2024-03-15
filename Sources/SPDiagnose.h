//
//  SPDiagnose.h
//  SPDiagnose
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

#import "SPDiagnoseSwizzler.h"

FOUNDATION_EXPORT double SPDiagnoseVersionNumber;
FOUNDATION_EXPORT const unsigned char SPDiagnoseVersionString[];
