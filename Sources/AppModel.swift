import Foundation
import Combine

/// App-wide state: which DSH host to talk to, the launch token, and connection health.
@MainActor
final class AppModel: ObservableObject {
    static let serverKey = "dsh.server.url"

    /// Base origin of the DSH web host, e.g. `http://192.168.0.200:59714`. No trailing slash, no query.
    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: Self.serverKey) }
    }

    /// One-shot `?token=` value. The host exchanges it for an HttpOnly cookie and 303s to `./`.
    @Published var pendingToken: String?

    /// Set when the host answers 401: the cookie is gone or the authority changed.
    @Published var needsToken: Bool = false

    /// Last transport-level failure (host off, wrong Wi-Fi, firewall).
    @Published var lastError: String?

    /// Bump to force the web view to (re)load.
    @Published var loadTicket = UUID()

    init() {
        serverURL = UserDefaults.standard.string(forKey: Self.serverKey) ?? ""
    }

    var isConfigured: Bool { !serverURL.isEmpty }

    /// URL the web view should open for this load.
    var launchURL: URL? {
        guard isConfigured, var comps = URLComponents(string: serverURL) else { return nil }
        if let token = pendingToken, !token.isEmpty {
            comps.queryItems = [URLQueryItem(name: "token", value: token)]
        }
        return comps.url
    }

    /// Host of the configured origin, used to keep in-app navigation inside the harness.
    var serverHost: String? { URLComponents(string: serverURL)?.host }

    func reload() {
        lastError = nil
        needsToken = false
        loadTicket = UUID()
    }

    func forgetServer() {
        serverURL = ""
        pendingToken = nil
        needsToken = false
        lastError = nil
    }

    /// Accepts `host:port`, `192.168.0.200:59714/?token=...`, full URLs, and trailing slashes.
    /// Returns the normalized base origin plus a token when the input carried one.
    static func normalize(_ raw: String) -> (base: String, token: String?)? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "http://" + text }
        guard var comps = URLComponents(string: text), let host = comps.host, !host.isEmpty else { return nil }

        var token: String?
        if let items = comps.queryItems,
           let found = items.first(where: { $0.name == "token" })?.value,
           !found.isEmpty {
            token = found
        }

        let scheme = comps.scheme ?? "http"
        comps.path = ""
        comps.query = nil
        comps.fragment = nil
        comps.user = nil
        comps.password = nil

        var base = "\(scheme)://\(host)"
        if let port = comps.port { base += ":\(port)" }
        return (base, token)
    }
}
