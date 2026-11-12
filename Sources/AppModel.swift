import Foundation
import Combine

/// App-wide state: which DSH host to talk to, the launch token, and connection health.
@MainActor
final class AppModel: ObservableObject {
    static let serverKey = "dsh.server.url"
    static let hostsKey = "dsh.saved.hosts"

    /// Base origin of the active DSH web host, e.g. `http://192.168.0.200:59714`. No trailing slash, no query.
    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: Self.serverKey) }
    }

    /// Recently used origins, newest first. Each authority keeps its own 30-day cookie in the WebView.
    @Published var savedHosts: [String] {
        didSet { UserDefaults.standard.set(savedHosts, forKey: Self.hostsKey) }
    }

    /// One-shot `?token=` value. The host exchanges it for an HttpOnly cookie and 303s to `./`.
    @Published var pendingToken: String?

    /// Set when the host answers 401: the cookie is gone or this authority was never authenticated.
    @Published var needsToken: Bool = false

    /// Last transport-level failure (host off, wrong Wi-Fi, firewall).
    @Published var lastError: String?

    /// Bump to force the web view to (re)load.
    @Published var loadTicket = UUID()

    init() {
        serverURL = UserDefaults.standard.string(forKey: Self.serverKey) ?? ""
        savedHosts = UserDefaults.standard.stringArray(forKey: Self.hostsKey) ?? []
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

    func remember(_ base: String) {
        var next = savedHosts.filter { $0 != base }
        next.insert(base, at: 0)
        savedHosts = Array(next.prefix(6))
    }

    func remove(_ base: String) {
        savedHosts = savedHosts.filter { $0 != base }
    }

    /// Switch to a saved origin. Its cookie (if any) lives in the shared WebView cookie store.
    func select(_ base: String) {
        serverURL = base
        pendingToken = nil
        reload()
    }

    func forgetServer() {
        if !serverURL.isEmpty { remove(serverURL) }
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
