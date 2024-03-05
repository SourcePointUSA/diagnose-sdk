import Foundation


extension Notification.Name {
    static let SPDiagnoseNetworkIntercepted = Notification.Name("SPDiagnoseNetworkIntercepted")
}

extension SPDiagnose {
    enum Event: CustomStringConvertible {
        var description: String {
            switch self {
                case .network(let domain, let tcString): "Event.network(domain: \(domain), tcString: \(tcString as Any))"
            }
        }

        case network(domain: String, tcString: String?)
    }

    @objcMembers class NetworkLogger: URLProtocol {
        static var domains = Set<String>()

        override class func canInit(with request: URLRequest) -> Bool {
            if let domain = request.url?.host, !domains.contains(domain) {
                domains.insert(domain)

                SPLogger.log("Request captured: \(domain)")

                NotificationCenter.default.post(
                    name: .SPDiagnoseNetworkIntercepted,
                    object: nil,
                    userInfo: ["domain": domain]
                )
            }

            return false
        }
    }

    @objcMembers class NetworkSubscriber: NSObject {
        var onNetworkIntercepted: ((_ domain: String) -> Void)?

        override init() {
            super.init()

            NotificationCenter.default.addObserver(self, selector: #selector(onNotification(_:)), name: .SPDiagnoseNetworkIntercepted, object: nil)
        }

        convenience init(onNetworkIntercepted: @escaping ((_ domain: String) -> Void)) {
            self.init()
            self.onNetworkIntercepted = onNetworkIntercepted
        }

        func onNotification(_ notification: Notification) {
            if let domain = notification.userInfo?["domain"] as? String {
                onNetworkIntercepted?(domain)
            }
        }
    }
}

@objcMembers public class SPDiagnose: NSObject {
    let api: SPDiagnoseAPI
    let networkSubscriber: NetworkSubscriber

    static func injectLogger() {
        URLProtocol.registerClass(NetworkLogger.self)
        let config = URLSessionConfiguration.default
        config.protocolClasses = [NetworkLogger.self] + (config.protocolClasses ?? [])
    }

    public override init() {
        Self.injectLogger()
        let dApi = SPDiagnoseAPI()
        self.api = dApi
        self.networkSubscriber = NetworkSubscriber { domain in
            Task {
                // TODO: filter out our own network calls
                await dApi.sendEvent(
                    .network(
                        domain: domain,
                        tcString: UserDefaults.standard.string(forKey: "IABTCF_TCString")
                    )
                )
            }
        }
    }

    init(api: SPDiagnoseAPI, subscriber: NetworkSubscriber) {
        Self.injectLogger()
        self.api = api
        self.networkSubscriber = subscriber
    }

    convenience public init(sessionConfig: URLSessionConfiguration) {
        self.init()
        sessionConfig.protocolClasses = [NetworkLogger.self] + (sessionConfig.protocolClasses ?? [])
    }

    convenience public init(sessionConfigs: [URLSessionConfiguration]) {
        self.init()
        sessionConfigs.forEach { config in
            config.protocolClasses = [NetworkLogger.self] + (config.protocolClasses ?? [])
        }
    }
}
