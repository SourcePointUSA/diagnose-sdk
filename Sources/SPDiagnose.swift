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
    var networkSubscriber: NetworkSubscriber?

    @objc public static func injectLogger(configuration: URLSessionConfiguration) {
        URLProtocol.registerClass(NetworkLogger.self)
        let protocols = configuration.protocolClasses ?? []
        if !protocols.contains(where: { $0 == NetworkLogger.self }) {
            configuration.protocolClasses = [NetworkLogger.self] + protocols
        }
    }

    convenience public override init() {
        let config: SPConfig!
        do {
            config = try SPConfig()
        } catch {
            fatalError("\(error)")
        }

        let api = SPDiagnoseAPI(
            accountId: config.accountId,
            propertyId: config.propertyId,
            appName: config.appName,
            key: config.key
        )
        let subscriber = NetworkSubscriber { domain in
            Task {
                if domain != SPDiagnoseAPI.baseUrl.host {
                    await api.sendEvent(
                        .network(
                            domain: domain,
                            tcString: UserDefaults.standard.string(forKey: "IABTCF_TCString")
                        )
                    )
                }
            }
        }
        self.init(api: api, subscriber: nil)
        sampleAndSubscribe(subscriber)
    }

    func sampleAndSubscribe(_ subscriber: NetworkSubscriber) {
        Task(priority: .high) {
            let response = try await api.getMetaData()
            if Sampling.shared.updateAndSample(newRate: response.samplingRate) == true {
                self.networkSubscriber = subscriber
            }
        }
    }

    init(api: SPDiagnoseAPI, subscriber: NetworkSubscriber?) {
        Self.injectLogger(configuration: URLSessionConfiguration.default)
        self.api = api
        self.networkSubscriber = subscriber
    }

    public func consentEvent(action: SPDiagnose.ConsentAction) async {
        if Sampling.shared.hit == true {
            await api.sendEvent(.consent(action: action))
        }
    }
}
