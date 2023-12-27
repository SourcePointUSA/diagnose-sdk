import SwiftUI
import DiagnoseSdk
import KMPNativeCoroutinesAsync

struct DiagnoseEventHandlerWrapper {
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
            // TODO log errors better
            print("Failed with error: \(error)")
        }
    }
    
    // called when consent string changes
    func onConsentStringChange(consentString: String) async {
        do {
            let _ = try await asyncFunction(for: EventHandlerNativeKt.setConsentString(self.handler, consentString: consentString))
        } catch {
            // TODO log errors better
            print("Failed with error: \(error)")
        }
    }
    
    // called on every url interception
    func onUrlIntercepted(url: String, method: String, headers: [(String, String)]) async {
        do {
            let headersCopy = headers.map { KotlinPair<NSString, NSString>(first: $0.0 as NSString, second: $0.1 as NSString) }
            let _ = try await asyncFunction(for: EventHandlerNativeKt.urlReceived(handler, url: url, method: method, headers: headersCopy))
        } catch {
            // TODO log errors better
            print("Failed with error: \(error)")
        }
    }
    
    func reportHome() async {
        do {
            let _ = try await asyncFunction(for: EventHandlerNativeKt.dumpState(handler))
        } catch {
            // TODO log errors better
            print("Failed with error: \(error)")
        }
    }
}

func initialize() async throws {
    let apiUrl = "http://localhost:8080"
    let databaseName = "diagnoseSdk"
    let clientId = "1234"
    let regionId = "DE"
    let ignoredDomains : [String] = []
    let appId = "5678"
    // initialize the receiver
    let wrapper = try await DiagnoseEventHandlerWrapper(apiUrl: apiUrl, databaseName: databaseName, clientId: clientId, appId: appId, regionId: regionId, ignoredDomains: ignoredDomains)
    // try calling random stuff
    await wrapper.onConsentStringChange(consentString: "consentString")
    await wrapper.onStateChange(state: ["state"])
    let url = "https://google.com"
    let headers = [("ContentLength", "2134")]
    await wrapper.onUrlIntercepted(url: url, method: "GET", headers: headers)
    await wrapper.reportHome()
}

struct ContentView: View {
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
            Text("Hello, world!")
            Button("Init") {
                print("Before task")
                Task {
                    print("Starting task")
                    do {
                        try await initialize()
                    } catch {
                        print("Failed with error: \(error)")
                    }
                    print("Done task")
                }
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
