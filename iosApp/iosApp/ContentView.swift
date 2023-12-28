import SwiftUI

func initialize() async throws -> EventHandler {
    let apiUrl = "http://localhost:8080"
    let databaseName = "diagnoseSdk"
    let clientId = "1234"
    let regionId = "DE"
    let ignoredDomains : [String] = []
    let appId = "5678"
    return try await EventHandler(apiUrl: apiUrl, databaseName: databaseName, clientId: clientId, appId: appId, regionId: regionId, ignoredDomains: ignoredDomains)
}

struct ContentView: View {
    
    @State
    var wrapper: EventHandler? = nil

    var body: some View {
        VStack {
            Button("Init") {
                Task {
                    do {
                        self.wrapper = try await initialize()
                    } catch {
                        NSLog("Failed with error: \(error)")
                    }
                }
            }
            Button("Consent String") {
                Task {
                    await self.wrapper?.onConsentStringChange(consentString: "consentString")
                }
            }
            Button("State") {
                Task {
                    await wrapper?.onStateChange(state: ["state"])
                }
            }
            Button("Url") {
                Task {
                    let url = "https://google.com"
                    let headers = [("ContentLength", "2134")]
                    await wrapper?.onUrlIntercepted(url: url, method: "GET", headers: headers)
                }
            }
            Button("Dump") {
                Task {
                    await wrapper?.dumpState()
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
