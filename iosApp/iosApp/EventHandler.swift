import Foundation
import DiagnoseSdk
import KMPNativeCoroutinesAsync

struct EventHandler {
    let handler: DiagnoseEventHandler
    
    init(apiUrl: String, databaseName: String, clientId: String, appId: String, regionId: String, ignoredDomains: [String]) async throws {
        let handler = try await asyncFunction(for: NativeUtilsNativeKt.mkDefaultEventHandler(apiUrl: apiUrl, databaseName: databaseName, clientId: clientId, appId: appId, regionId: regionId, ignoredDomains: ignoredDomains))
        self.handler = handler
    }
    
    // called when client state changes
    func onStateChange(state: [String]) async {
        do {
            let _ = try await asyncFunction(for: EventHandlerNativeKt.setState(handler, state: state))
        } catch {
            NSLog("Failed with error: \(error)")
        }
    }
    
    // called when consent string changes
    func onConsentStringChange(consentString: String) async {
        do {
            let _ = try await asyncFunction(for: EventHandlerNativeKt.setConsentString(self.handler, consentString: consentString))
        } catch {
            NSLog("Failed with error: \(error)")
        }
    }
    
    // called on every url interception
    func onUrlIntercepted(url: String, method: String, headers: [(String, String)]) async {
        do {
            let headersCopy = headers.map { KotlinPair<NSString, NSString>(first: $0.0 as NSString, second: $0.1 as NSString) }
            let _ = try await asyncFunction(for: EventHandlerNativeKt.urlReceived(handler, url: url, method: method, headers: headersCopy))
        } catch {
            NSLog("Failed with error: \(error)")
        }
    }
    
    func dumpState() async {
        do {
            let _ = try await asyncFunction(for: EventHandlerNativeKt.dumpState(handler))
        } catch {
            NSLog("Failed with error: \(error)")
        }
    }
}
