# Diagnose iOS SDK

Sourcepoint's Diagnose iOS SDK extends the scanning and monitoring capabilities of Diagnose to your iOS mobile apps. Add the Diagnose iOS SDK to understand the privacy risk of your vendors, keep track of your compliance journey, and visualize the vendor supply chain for your mobile apps.

## Table of Contents

- [How it works](#how-it-works)
- [Integrate Diagnose iOS SDK](#integrate-diagnose-ios-sdk)
- [FAQs](#faqs)

## How it works

The Diagnose SDK leverages the iOS native [`URLProtocol`](https://developer.apple.com/documentation/foundation/urlprotocol) interface in order to intercept network calls made by your app and 3rd-party libraries.

There are certain limitations, namely the fact that it can only intercept requests that use the [`URLSessionConfiguration.default`](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/1411560-default).

The SDK sends the request domain to Diagnose APIs. Our backend, based on a proprietary dictionary, maps the domain collected to a particular vendor name.

## Integrate Diagnose iOS SDK

In the following sections, we will cover the necessary steps to configure and integrate the SDK into your iOS app project.

- [`SPDiagnoseConfig.plist`](#spdiagnoseconfigplist)
- [Declare Diagnose SDK as dependency](#declare-diagnose-sdk-as-dependency)
- [Set up using SwiftUI](#set-up-using-swiftui)
- [Set up using Storyboard](#set-up-using-storyboard)
- [Signaling consent](#signaling-consent)

### `SPDiagnoseConfig.plist`

Add a property list file to your project called `SPDiagnoseConfig.plist` to your project. This file contains the key account configurations needed to map your setup to your Diagnose account in the Sourcepoint portal.

Review the table below for all the required key-value pairs in the property list file:

| **Key**    | **Value Type** | **Value Description**                                                                                                                                                                                   |
| ---------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| appName    | string         | Name of your iOS mobile app                                                                                                                                                                             |
| propertyId | integer        | ID of property within the Sourcepoint portal. Your Sourcepoint Account Manager will provide you with this value                                                                                         |
| accountId  | integer        | Associates the property with your organization's Sourcepoint account. Value can be retrieved by contacting your Sourcepoint Account Manager or via the **My Account** page in your Sourcepoint account. |
| key        | integer        | Your Sourcepoint Account Manager will provide you with this value                                                                                                                                       |

```plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>appName</key>
    <string>myApp</string>
    <key>propertyId</key>
    <integer>123</integer>
    <key>accountId</key>
    <integer>22</integer>
    <key>key</key>
    <string>YOUR KEY GOES HERE</string>
</dict>
</plist>
```

### Declare Diagnose SDK as dependency

Once a property list file is added to your project containing the required account credentials, the Diagnose SDK can be declared as a dependency using Swift Package Manager (SPM).

### Set up using SwiftUI

If you are using SwiftUI to build your app, declare an `@UIApplicationDelegateAdaptor` in your app:

```swift
@main
struct iOSExampleApp: App {
    @UIApplicationDelegateAdaptor(SPDiagnoseAppDelegate.self) var appDelegate
}
```

### Set up using Storyboard

If you are using Storyboard to build your app, in your app delegate, add a reference to `SPDiagnose` and instantiate it during app launch:

```swift
public class SPDiagnoseAppDelegate: NSObject, UIApplicationDelegate {
    var diagnose: SPDiagnose?

    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        diagnose = SPDiagnose()
        return true
    }
}
```

### Signaling consent

The Diagnose SDK is CMP agnostic by design. In order to determine the consent status of a given user, your app needs to call the method `updateConsent(status: SPDiagnose.ConsentStatus)`, ideally as soon as the user makes a consent choice (pressiong on a accept all vendors/purposes button for example).

The `SPDiagnose.ConsentStatus` enum can assume the following values:
* `noAction` -> that is the default consent status of a new user, or a user that has not yet made a consent choice.
* `consentedAll` -> used to signal the user _accepted_ all vendors/purposes on a consent prompt.
* `consentedSome` -> used to signal the user has accepted some, but not all, vendors/purposes on a consent prompt, ie. by enabling only some vendors.
* `rejectedAll` -> used to signal the user _rejected_ all vendors/purposes on a consent prompt.

_In the future, when integrate both Diagnose and Dialogue SDKs together, this step won't be necessary. The Dialogue SDK will automatically signal consent choice to Diagnose._

## FAQs

### What if I use a third party library like Alamofire?

We're currently investigating whether we're able to intercept requests made by network libraries without interfering with Apple's App Store policies.

### What data is collected?

- Request domain (and domain **only**, no path, no query params, etc)
- The TCF consent string (stored by CMPs in the UserDefaults according to the [TCF spec](https://github.com/InteractiveAdvertisingBureau/GDPR-Transparency-and-Consent-Framework/blob/master/TCFv2/IAB%20Tech%20Lab%20-%20CMP%20API%20v2.md#in-app-details))
- Request timestamp
- IP address. IP is not collected in the client side, but is registered when our backend receives a request from the SDK.

### Does the SDK access the payload of request / response?

No. The Diagnose SDK does not access the payload of the request and it is blind to the response as well.
No access to cookie or any other data with the exception of the ones listed in the section above.
