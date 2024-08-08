import Foundation


extension Notification.Name {
    static let SPDiagnoseNetworkIntercepted = Notification.Name("SPDiagnoseNetworkIntercepted")
}

extension SPDiagnose {
    enum Event: CustomStringConvertible {
        var description: String {
            switch self {
                case .network(let domain, let tcString): "Event.network(domain: \(domain), tcString: \(tcString as Any))"
                case .consent(let action): "Event.consent(action: \(action))"
            }
        }

        case network(domain: String, tcString: String?)
        case consent(action: ConsentAction)
    }

    @objc public enum ConsentAction: Int, Encodable, CustomStringConvertible {
        public var description: String {
            switch self {
                case .acceptAll: return "ConsentAction.acceptAll"
                case .rejectAll: return "ConsentAction.rejectAll"
            }
        }

        case acceptAll, rejectAll

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
                case .acceptAll: try container.encode("acceptAll")
                case .rejectAll: try container.encode("rejectAll")
            }
        }
    }

    @objcMembers public class NetworkLogger: URLProtocol {
        override class public func canInit(with request: URLRequest) -> Bool {
            if let domain = request.url?.host {
                SPLogger.log("Request captured: \(domain)")

                NotificationCenter.default.post(
                    name: .SPDiagnoseNetworkIntercepted,
                    object: nil,
                    userInfo: ["domain": domain]
                )
            }
            return false
        }

        /// we need to override `canInit(with task:)` otherwise `canInit(with request:)`
        /// gets called multiple times
        public override class func canInit(with task: URLSessionTask) -> Bool {
            return false
        }
    }

    @objcMembers class NetworkSubscriber: NSObject {
        var onNetworkIntercepted: ((_ domain: String) -> Void)?

        override init() {
            super.init()

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onNotification(_:)),
                name: .SPDiagnoseNetworkIntercepted,
                object: nil
            )
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
        injectLogger(configuration: URLSessionConfiguration.default)
    }

    @objc public static func injectLogger(configuration: URLSessionConfiguration) {
        URLProtocol.registerClass(NetworkLogger.self)
        let protocols = configuration.protocolClasses ?? []
        if !protocols.contains(where: { $0 == NetworkLogger.self }) {
            configuration.protocolClasses = [NetworkLogger.self] + protocols
        }
    }

    public override init() {
        Self.injectLogger()
        let config: SPConfig!
        do {
            config = try SPConfig()
        } catch {
            fatalError("\(error)")
        }

        let dApi = SPDiagnoseAPI(
            accountId: config.accountId,
            propertyId: config.propertyId,
            appName: config.appName,
            key: config.key
        )
        self.api = dApi
        self.networkSubscriber = NetworkSubscriber { domain in
            Task {
                if (domain != SPDiagnoseAPI.baseUrl.host) {
                    await dApi.sendEvent(
                        .network(
                            domain: domain,
                            tcString: UserDefaults.standard.string(forKey: "IABTCF_TCString")
                        )
                    )
                }
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
        Self.injectLogger(configuration: sessionConfig)
    }

    convenience public init(sessionConfigs: [URLSessionConfiguration]) {
        self.init()
        sessionConfigs.forEach { Self.injectLogger(configuration: $0) }
    }

    public func consentEvent(action: SPDiagnose.ConsentAction) async {
        await api.sendEvent(.consent(action: action))
    }
}
