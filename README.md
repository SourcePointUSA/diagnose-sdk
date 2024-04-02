# diagnose-sdk

## Getting Started

### `SPDiagnoseConfig.plist`
Make sure to add a property list file called `SPDiagnoseConfig.plist` to your project. With the content:
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

### Adding it as a dependency

At this point, the Diagnose SDK can be declared as a dependency using Swift Package Manager (SPM).

### Setting up the SDK


#### Apps built using SwiftUI

Declare an `@UIApplicationDelegateAdaptor` on your app:
```swift
@main
struct iOSExampleApp: App {
    @UIApplicationDelegateAdaptor(SPDiagnoseAppDelegate.self) var appDelegate
}
```

#### Apps built using Storyboard

On your app delegate, add a reference to `SPDiagnose` and instantiate it during app launch:
```swift
public class SPDiagnoseAppDelegate: NSObject, UIApplicationDelegate {
    var diagnose: SPDiagnose?

    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        diagnose = SPDiagnose()
        return true
    }
}
```

## FAQ

### How does the SDK work?
The Diagnose SDK leverages the iOS native [`URLProtocol`](https://developer.apple.com/documentation/foundation/urlprotocol) interface in order to intercept network calls made by your app and 3rd party libraries.

There are certain limitations, namely the fact that it can only intercept requests that use the [`URLSessionConfiguration.default`](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/1411560-default).

The SDK sends the request domain to Diagnose APIs. Our backend, based on a proprietary dictionary, maps the domain collected to a particular vendor name.

### What if I use a third party library like Alamofire?
We're currently investigating whether we're able to intercept requests made by network libraries without interfering with Apple's App Store policies.

### What data is collected?
* Request domain (and domain **only**, no path, no query params, etc)
* The TCF consent string (stored by CMPs in the UserDefaults according to the [TCF spec](https://github.com/InteractiveAdvertisingBureau/GDPR-Transparency-and-Consent-Framework/blob/master/TCFv2/IAB%20Tech%20Lab%20-%20CMP%20API%20v2.md#in-app-details))
* Request timestamp
* IP address. IP is not collected in the client side, but is registered when our backend receives a request from the SDK.

### Does the SDK access the payload of request / response?
No. The Diagnose SDK does not access the payload of the request and it is blind to the response as well.
No access to cookie or any other data with the exception of the ones listed in the section above.
