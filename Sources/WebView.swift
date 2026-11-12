import SwiftUI
import WebKit
import UIKit

/// Thin WKWebView host. Keeps the harness inside the app, refreshable, and cookie-authenticated.
struct WebView: UIViewRepresentable {
    let url: URL?
    let ticket: UUID
    let model: AppModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Diagnostics bridge: the page reports its own boot state and every JS/WS/fetch failure.
        config.userContentController.add(context.coordinator, name: Coordinator.diagHandler)
        config.userContentController.addUserScript(
            WKUserScript(source: Coordinator.diagnosticsScript,
                         injectionTime: .atDocumentStart,
                         forMainFrameOnly: true)
        )

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.isOpaque = false
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        let bg = UIColor(red: 0.055, green: 0.062, blue: 0.075, alpha: 1)
        webView.backgroundColor = bg
        webView.scrollView.backgroundColor = bg
        webView.underPageBackgroundColor = bg

        let refresh = UIRefreshControl()
        refresh.tintColor = .lightGray
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        context.coordinator.webView = webView
        context.coordinator.load(url: url, ticket: ticket)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(url: url, ticket: ticket)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        static let diagHandler = "dshDiag"

        /// Runs at documentStart, so it sees the very first script failure.
        static let diagnosticsScript = """
        (function () {
          if (window.__dshDiagInstalled) { return; }
          window.__dshDiagInstalled = true;
          function send(kind, text) {
            try { window.webkit.messageHandlers.dshDiag.postMessage(kind + ' | ' + text); } catch (e) {}
          }
          window.addEventListener('error', function (e) {
            var t = e.target;
            if (t && t !== window && (t.src || t.href)) {
              send('resource', (t.tagName || '?') + ' ' + (t.src || t.href));
              return;
            }
            send('error', (e.message || 'unknown') + ' @ ' + (e.filename || '') + ':' + (e.lineno || 0));
          }, true);
          window.addEventListener('unhandledrejection', function (e) {
            var r = e.reason;
            send('rejection', String(r && (r.stack || r.message || r)));
          });
          var origError = console.error;
          console.error = function () {
            try { send('console.error', Array.prototype.map.call(arguments, function (a) { return String(a); }).join(' ')); } catch (e) {}
            return origError.apply(console, arguments);
          };
          var origFetch = window.fetch;
          if (origFetch) {
            window.fetch = function () {
              var p = origFetch.apply(this, arguments);
              p.then(function (r) { if (!r.ok) { send('fetch', r.status + ' ' + r.url); } },
                     function (e) { send('fetch-fail', String(e)); });
              return p;
            };
          }
          var OrigWS = window.WebSocket;
          if (OrigWS) {
            function DiagWS(u, p) {
              send('ws-open', String(u));
              var s = p === undefined ? new OrigWS(u) : new OrigWS(u, p);
              s.addEventListener('error', function () { send('ws-error', String(u)); });
              s.addEventListener('close', function (e) { send('ws-close', String(u) + ' code=' + e.code + (e.reason ? (' ' + e.reason) : '')); });
              s.addEventListener('open', function () { send('ws-ready', String(u)); });
              return s;
            }
            DiagWS.prototype = OrigWS.prototype;
            DiagWS.CONNECTING = 0; DiagWS.OPEN = 1; DiagWS.CLOSING = 2; DiagWS.CLOSED = 3;
            window.WebSocket = DiagWS;
          }
          setTimeout(function () {
            var root = document.getElementById('root') || document.body;
            send('state',
                 'children=' + (root ? root.children.length : -1) +
                 ' scripts=' + document.scripts.length +
                 ' boot=' + (typeof window.__DSH_BOOT__) +
                 ' origin=' + location.origin +
                 ' secure=' + window.isSecureContext);
          }, 3500);
        })();
        """

        private let model: AppModel
        weak var webView: WKWebView?
        private var lastTicket: UUID?

        init(model: AppModel) {
            self.model = model
        }

        /// Loads only when the ticket changes, so clearing the one-shot token never triggers a reload.
        func load(url: URL?, ticket: UUID) {
            guard let url else { return }
            if ticket == lastTicket { return }
            lastTicket = ticket
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            webView?.load(request)
        }

        @objc func handleRefresh(_ sender: UIRefreshControl) {
            webView?.reload()
        }

        // MARK: - Diagnostics

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == Self.diagHandler else { return }
            model.note(String(describing: message.body))
            if let text = message.body as? String, text.hasPrefix("ws-ready") {
                model.lastError = nil
            }
        }

        // MARK: - Navigation policy

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let target = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            let scheme = (target.scheme ?? "").lowercased()

            if scheme != "http" && scheme != "https" {
                if scheme == "about" || scheme == "data" || scheme == "blob" {
                    decisionHandler(.allow)
                } else {
                    openExternally(target)
                    decisionHandler(.cancel)
                }
                return
            }

            if let host = model.serverHost, let targetHost = target.host, targetHost != host {
                openExternally(target)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let http = navigationResponse.response as? HTTPURLResponse, http.statusCode == 401 {
                model.needsToken = true
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        // MARK: - Completion

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.scrollView.refreshControl?.endRefreshing()
            model.lastError = nil
            let hasTokenQuery = webView.url
                .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
                .queryItems?
                .contains(where: { $0.name == "token" }) ?? false
            if !hasTokenQuery {
                model.pendingToken = nil
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            model.note("webcontent | process terminated, reloading")
            webView.reload()
        }

        // MARK: - UI delegate

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let target = navigationAction.request.url {
                webView.load(URLRequest(url: target))
            }
            return nil
        }

        // MARK: - Helpers

        private func report(_ error: Error) {
            let ns = error as NSError
            if ns.code == NSURLErrorCancelled { return }
            webView?.scrollView.refreshControl?.endRefreshing()
            model.lastError = "\(ns.localizedDescription) (code \(ns.code))"
        }

        private func openExternally(_ url: URL) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
